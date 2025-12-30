import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { getFirestore } from '../shared/firestore-helpers';

const db = getFirestore();

const RAW_MATERIALS_COLLECTION = 'RAW_MATERIALS';
const STOCK_HISTORY_COLLECTION = 'STOCK_HISTORY';
const TRANSACTIONS_COLLECTION = 'TRANSACTIONS';

/**
 * Update raw material stock when a purchase transaction is created
 */
export const onPurchaseTransactionCreated = functions.firestore
  .document(`${TRANSACTIONS_COLLECTION}/{transactionId}`)
  .onCreate(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;

    const organizationId = transaction?.organizationId as string;
    const ledgerType = (transaction?.ledgerType as string) || 'clientLedger';
    const category = (transaction?.category as string) || '';
    const metadata = (transaction?.metadata as Record<string, any>) || {};

    // Only process vendor purchase transactions with raw materials
    if (ledgerType !== 'vendorLedger' || category !== 'vendorPurchase') {
      console.log('[Stock] Skipping transaction - not a vendor purchase', {
        transactionId,
        ledgerType,
        category,
      });
      return;
    }

    const rawMaterials = metadata.rawMaterials as Array<{
      materialId: string;
      materialName: string;
      quantity: number;
      unitPrice: number;
      unitOfMeasurement: string;
    }> | undefined;

    if (!rawMaterials || rawMaterials.length === 0) {
      console.log('[Stock] No raw materials in transaction metadata', {
        transactionId,
      });
      return;
    }

    if (!organizationId) {
      console.error('[Stock] Missing organizationId', { transactionId });
      return;
    }

    const vendorId = transaction?.vendorId as string | undefined;
    const invoiceNumber = transaction?.referenceNumber as string | undefined;
    const createdBy = transaction?.createdBy as string | undefined;
    const transactionDate = transaction?.transactionDate as admin.firestore.Timestamp | undefined;
    const createdAt = transactionDate || admin.firestore.Timestamp.now();

    console.log('[Stock] Processing raw materials purchase', {
      transactionId,
      organizationId,
      vendorId,
      invoiceNumber,
      materialCount: rawMaterials.length,
    });

    try {
      // Process all materials in a single transaction for atomicity
      await db.runTransaction(async (transaction) => {
        const materialRefs: Array<{
          ref: FirebaseFirestore.DocumentReference;
          materialId: string;
          material: typeof rawMaterials[0];
        }> = [];

        // First, read all material documents to get current stock
        for (const material of rawMaterials) {
          const materialId = material.materialId;
          const quantity = material.quantity;

          if (!materialId || quantity <= 0) {
            console.warn('[Stock] Invalid material data', {
              transactionId,
              materialId,
              quantity,
            });
            continue;
          }

          const materialRef = db
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection(RAW_MATERIALS_COLLECTION)
            .doc(materialId);

          materialRefs.push({
            ref: materialRef,
            materialId: materialId,
            material: material,
          });
        }

        // Read all material documents in the transaction
        const materialDocs = await Promise.all(
          materialRefs.map(({ ref }) => transaction.get(ref))
        );

        // Verify all materials exist and prepare updates
        const updates: Array<{
          materialRef: FirebaseFirestore.DocumentReference;
          historyRef: FirebaseFirestore.DocumentReference;
          balanceBefore: number;
          balanceAfter: number;
          quantity: number;
          materialId: string;
          material: typeof rawMaterials[0];
        }> = [];

        for (let i = 0; i < materialRefs.length; i++) {
          const { ref, materialId, material } = materialRefs[i];
          const materialDoc = materialDocs[i];

          if (!materialDoc.exists) {
            console.error('[Stock] Material not found', {
              transactionId,
              materialId,
              organizationId,
            });
            continue;
          }

          const materialData = materialDoc.data()!;
          const currentStock = (materialData.stock as number) || 0;
          const balanceBefore = currentStock;
          const balanceAfter = currentStock + material.quantity;

          const historyEntryId = `${transactionId}_${materialId}`;
          const historyRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(historyEntryId);

          updates.push({
            materialRef: ref,
            historyRef: historyRef,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            quantity: material.quantity,
            materialId: materialId,
            material: material,
          });
        }

        // Apply all updates atomically within the transaction
        for (const update of updates) {
          // Update material stock
          transaction.update(update.materialRef, {
            stock: update.balanceAfter,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Create stock history entry
          const historyEntry = {
            entryId: `${transactionId}_${update.materialId}`,
            materialId: update.materialId,
            type: 'in', // Stock in (purchase)
            quantity: update.quantity,
            balanceBefore: update.balanceBefore,
            balanceAfter: update.balanceAfter,
            reason: 'purchase',
            transactionId: transactionId,
            vendorId: vendorId || null,
            invoiceNumber: invoiceNumber || null,
            notes: `Purchase from vendor: ${update.quantity} ${update.material.unitOfMeasurement}`,
            createdBy: createdBy || 'system',
            createdAt: createdAt,
          };

          transaction.set(update.historyRef, historyEntry);

          console.log('[Stock] Prepared atomic update', {
            transactionId,
            materialId: update.materialId,
            materialName: update.material.materialName,
            quantity: update.quantity,
            balanceBefore: update.balanceBefore,
            balanceAfter: update.balanceAfter,
          });
        }

        // All updates are committed atomically when transaction completes
        console.log('[Stock] Transaction prepared for all materials', {
          transactionId,
          materialCount: updates.length,
        });
      });

      console.log('[Stock] Successfully processed all materials atomically', {
        transactionId,
        materialCount: rawMaterials.length,
      });
    } catch (error) {
      console.error('[Stock] Error processing raw materials', {
        transactionId,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      // Don't throw - we don't want to fail the transaction creation
      // The stock update can be retried manually if needed
    }
  });

/**
 * Reverse raw material stock when a purchase transaction is deleted
 */
export const onPurchaseTransactionDeleted = functions.firestore
  .document(`${TRANSACTIONS_COLLECTION}/{transactionId}`)
  .onDelete(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;

    const organizationId = transaction?.organizationId as string;
    const ledgerType = (transaction?.ledgerType as string) || 'clientLedger';
    const category = (transaction?.category as string) || '';
    const metadata = (transaction?.metadata as Record<string, any>) || {};

    // Only process vendor purchase transactions with raw materials
    if (ledgerType !== 'vendorLedger' || category !== 'vendorPurchase') {
      console.log('[Stock] Skipping transaction deletion - not a vendor purchase', {
        transactionId,
        ledgerType,
        category,
      });
      return;
    }

    const rawMaterials = metadata.rawMaterials as Array<{
      materialId: string;
      materialName: string;
      quantity: number;
      unitPrice: number;
      unitOfMeasurement: string;
    }> | undefined;

    if (!rawMaterials || rawMaterials.length === 0) {
      console.log('[Stock] No raw materials in deleted transaction metadata', {
        transactionId,
      });
      return;
    }

    if (!organizationId) {
      console.error('[Stock] Missing organizationId in deleted transaction', { transactionId });
      return;
    }

    console.log('[Stock] Reversing raw materials purchase (deletion)', {
      transactionId,
      organizationId,
      materialCount: rawMaterials.length,
    });

    try {
      // Process all materials in a single transaction for atomicity
      await db.runTransaction(async (transaction) => {
        const materialRefs: Array<{
          ref: FirebaseFirestore.DocumentReference;
          materialId: string;
          material: typeof rawMaterials[0];
        }> = [];

        // First, prepare all material references
        for (const material of rawMaterials) {
          const materialId = material.materialId;
          const quantity = material.quantity;

          if (!materialId || quantity <= 0) {
            console.warn('[Stock] Invalid material data in deleted transaction', {
              transactionId,
              materialId,
              quantity,
            });
            continue;
          }

          const materialRef = db
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection(RAW_MATERIALS_COLLECTION)
            .doc(materialId);

          materialRefs.push({
            ref: materialRef,
            materialId: materialId,
            material: material,
          });
        }

        // Read all material documents AND original history entries in the transaction (all reads must happen before writes)
        const materialDocs = await Promise.all(
          materialRefs.map(({ ref }) => transaction.get(ref))
        );

        // Also read all original history entries during the read phase
        const originalHistoryRefs = materialRefs.map(({ ref, materialId }) => {
          const originalHistoryEntryId = `${transactionId}_${materialId}`;
          return ref.collection(STOCK_HISTORY_COLLECTION).doc(originalHistoryEntryId);
        });
        const originalHistoryDocs = await Promise.all(
          originalHistoryRefs.map(ref => transaction.get(ref))
        );

        // Verify all materials exist and prepare updates
        const updates: Array<{
          materialRef: FirebaseFirestore.DocumentReference;
          originalHistoryRef: FirebaseFirestore.DocumentReference;
          originalHistoryExists: boolean;
          reversalHistoryRef: FirebaseFirestore.DocumentReference;
          balanceBefore: number;
          balanceAfter: number;
          quantity: number;
          materialId: string;
        }> = [];

        for (let i = 0; i < materialRefs.length; i++) {
          const { ref, materialId, material } = materialRefs[i];
          const materialDoc = materialDocs[i];
          const originalHistoryDoc = originalHistoryDocs[i];

          if (!materialDoc.exists) {
            console.warn('[Stock] Material not found when reversing purchase', {
              transactionId,
              materialId,
              organizationId,
            });
            continue;
          }

          const materialData = materialDoc.data()!;
          const currentStock = (materialData.stock as number) || 0;
          const balanceBefore = currentStock;
          // Reverse: subtract the quantity that was added
          const balanceAfter = Math.max(0, currentStock - material.quantity);

          // References for original and reversal history entries
          const originalHistoryEntryId = `${transactionId}_${materialId}`;
          const reversalHistoryEntryId = `${transactionId}_${materialId}_reversal`;
          const originalHistoryRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(originalHistoryEntryId);
          const reversalHistoryRef = ref.collection(STOCK_HISTORY_COLLECTION).doc(reversalHistoryEntryId);

          updates.push({
            materialRef: ref,
            originalHistoryRef: originalHistoryRef,
            originalHistoryExists: originalHistoryDoc.exists,
            reversalHistoryRef: reversalHistoryRef,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            quantity: material.quantity,
            materialId: materialId,
          });
        }

        // Apply all updates atomically within the transaction
        for (const update of updates) {
          // Update material stock (reverse the purchase)
          transaction.update(update.materialRef, {
            stock: update.balanceAfter,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Find the material info for the notes
          const materialInfo = materialRefs.find(m => m.materialId === update.materialId)?.material;
          
          // Create stock history entry for the reversal
          const historyEntry = {
            entryId: `${transactionId}_${update.materialId}_reversal`,
            materialId: update.materialId,
            type: 'out', // Stock out (reversal of purchase)
            quantity: update.quantity,
            balanceBefore: update.balanceBefore,
            balanceAfter: update.balanceAfter,
            reason: 'purchase_deletion',
            transactionId: transactionId,
            vendorId: null,
            invoiceNumber: null,
            notes: `Purchase reversal: ${update.quantity} ${materialInfo?.unitOfMeasurement || ''} (Transaction deleted)`,
            createdBy: 'system',
            createdAt: admin.firestore.Timestamp.now(),
          };

          transaction.set(update.reversalHistoryRef, historyEntry);

          // Delete the original stock history entry if it exists (we already read it in the read phase)
          if (update.originalHistoryExists) {
            transaction.delete(update.originalHistoryRef);
          }

          console.log('[Stock] Prepared atomic reversal update', {
            transactionId,
            materialId: update.materialId,
            quantity: update.quantity,
            balanceBefore: update.balanceBefore,
            balanceAfter: update.balanceAfter,
          });
        }

        // All updates are committed atomically when transaction completes
        console.log('[Stock] Transaction prepared for all material reversals', {
          transactionId,
          materialCount: updates.length,
        });
      });

      console.log('[Stock] Successfully reversed all materials atomically', {
        transactionId,
        materialCount: rawMaterials.length,
      });
    } catch (error) {
      console.error('[Stock] Error reversing raw materials purchase', {
        transactionId,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      // Don't throw - we don't want to fail the transaction deletion
      // The stock reversal can be retried manually if needed
    }
  });

