import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  VENDORS_COLLECTION,
  VENDOR_LEDGERS_COLLECTION,
} from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { getFinancialContext } from '../shared/financial-year';

const db = getFirestore();

/**
 * Generate vendor code in format: VND-{YYYY}-{NNN}
 * Example: VND-2024-001, VND-2024-002
 */
async function generateVendorCode(
  organizationId: string,
): Promise<string> {
  const currentYear = new Date().getFullYear();
  const yearPrefix = `VND-${currentYear}-`;

  // Query all vendors for this organization with codes starting with year prefix
  const vendorsSnapshot = await db
    .collection(VENDORS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('vendorCode', '>=', yearPrefix)
    .where('vendorCode', '<', `VND-${currentYear + 1}-`)
    .orderBy('vendorCode', 'desc')
    .limit(1)
    .get();

  let nextSequence = 1;

  if (!vendorsSnapshot.empty) {
    const lastCode = vendorsSnapshot.docs[0].data()?.vendorCode as string | undefined;
    if (lastCode) {
      // Extract sequence number from last code (e.g., "VND-2024-001" -> 1)
      const match = lastCode.match(/-(\d{3})$/);
      if (match) {
        const lastSequence = parseInt(match[1], 10);
        nextSequence = lastSequence + 1;
      }
    }
  }

  // Format sequence with leading zeros (001, 002, etc.)
  const sequenceStr = String(nextSequence).padStart(3, '0');
  return `${yearPrefix}${sequenceStr}`;
}

/**
 * Create initial vendor ledger for current financial year
 */
async function createVendorLedger(
  vendorId: string,
  organizationId: string,
  openingBalance: number,
): Promise<void> {
  const { fyLabel: financialYear } = getFinancialContext(new Date());
  const ledgerId = `${vendorId}_${financialYear}`;
  const ledgerRef = db.collection(VENDOR_LEDGERS_COLLECTION).doc(ledgerId);

  const ledgerData: any = {
    ledgerId,
    vendorId,
    organizationId,
    financialYear,
    openingBalance,
    currentBalance: openingBalance,
    totalPayables: 0,
    totalPayments: 0,
    transactionCount: 0,
    creditCount: 0,
    debitCount: 0,
    transactionIds: [],
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };

  await ledgerRef.set(ledgerData);
  console.log('[Vendor Ledger] Created ledger', {
    ledgerId,
    vendorId,
    financialYear,
    openingBalance,
  });
}

/**
 * Cloud Function: Triggered when a vendor is created
 * - Auto-generates vendor code
 * - Creates initial ledger for current financial year
 * - Updates search indexes
 */
export const onVendorCreated = functions.firestore
  .document(`${VENDORS_COLLECTION}/{vendorId}`)
  .onCreate(async (snapshot, context) => {
    const vendorId = context.params.vendorId;
    const vendorData = snapshot.data();

    if (!vendorData) {
      console.warn('[Vendor] No data found for vendor', { vendorId });
      return;
    }

    const organizationId = vendorData.organizationId as string | undefined;
    if (!organizationId) {
      console.warn('[Vendor] Vendor created without organizationId', { vendorId });
      return;
    }

    const openingBalance = (vendorData.openingBalance as number) || 0;
    const name = (vendorData.name as string) || '';
    const phoneNumber = vendorData.phoneNumber as string | undefined;
    const phones = (vendorData.phones as Array<{ number: string; normalized: string }>) || [];

    // Generate vendor code if not already set
    let vendorCode = vendorData.vendorCode as string | undefined;
    if (!vendorCode || vendorCode.trim() === '') {
      try {
        vendorCode = await generateVendorCode(organizationId);
        await snapshot.ref.update({
          vendorCode,
        });
        console.log('[Vendor] Generated vendor code', { vendorId, vendorCode });
      } catch (error) {
        console.error('[Vendor] Error generating vendor code', {
          vendorId,
          error,
        });
        // Continue even if code generation fails
      }
    }

    // Update search indexes
    const updates: any = {
      name_lowercase: name.toLowerCase(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Build phone index from all phones
    const phoneIndex: string[] = [];
    if (phoneNumber) {
      const normalized = phoneNumber.replace(/[^0-9+]/g, '');
      if (normalized) phoneIndex.push(normalized);
    }
    for (const phone of phones) {
      if (phone.normalized && !phoneIndex.includes(phone.normalized)) {
        phoneIndex.push(phone.normalized);
      }
    }
    if (phoneIndex.length > 0) {
      updates.phoneIndex = phoneIndex;
    }

    // Update phoneNumberNormalized if not set
    if (phoneNumber && !vendorData.phoneNumberNormalized) {
      updates.phoneNumberNormalized = phoneNumber.replace(/[^0-9+]/g, '');
    }

    await snapshot.ref.update(updates);

    // Create initial ledger for current financial year
    try {
      await createVendorLedger(vendorId, organizationId, openingBalance);
    } catch (error) {
      console.error('[Vendor] Error creating ledger', {
        vendorId,
        organizationId,
        error,
      });
    }

    console.log('[Vendor] Vendor created successfully', {
      vendorId,
      vendorCode,
      organizationId,
    });
  });

/**
 * Cloud Function: Triggered when a vendor is updated
 * - Updates search indexes
 * - Validates status changes (prevents delete/suspend with non-zero balance)
 * - Prevents openingBalance and vendorCode updates
 */
export const onVendorUpdated = functions.firestore
  .document(`${VENDORS_COLLECTION}/{vendorId}`)
  .onUpdate(async (change, context) => {
    const vendorId = context.params.vendorId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!beforeData || !afterData) {
      console.warn('[Vendor] Missing data in update', { vendorId });
      return;
    }

    // Skip if only updatedAt changed (prevents infinite loops)
    const beforeUpdatedAt = beforeData.updatedAt;
    const afterUpdatedAt = afterData.updatedAt;
    const beforeKeys = Object.keys(beforeData).filter(k => k !== 'updatedAt');
    const afterKeys = Object.keys(afterData).filter(k => k !== 'updatedAt');
    
    // Check if only updatedAt changed
    if (beforeUpdatedAt !== afterUpdatedAt && beforeKeys.length === afterKeys.length) {
      let onlyUpdatedAtChanged = true;
      for (const key of beforeKeys) {
        if (JSON.stringify(beforeData[key]) !== JSON.stringify(afterData[key])) {
          onlyUpdatedAtChanged = false;
          break;
        }
      }
      if (onlyUpdatedAtChanged) {
        console.log('[Vendor] Only updatedAt changed, skipping to prevent infinite loop', { vendorId });
        return;
      }
    }

    const updates: any = {};

    // Update search indexes if name or phones changed
    const nameBefore = (beforeData.name as string) || '';
    const nameAfter = (afterData.name as string) || '';
    if (nameBefore !== nameAfter) {
      updates.name_lowercase = nameAfter.toLowerCase();
    }

    // Update phone index if phones changed
    const phonesBefore = (beforeData.phones as Array<{ number: string; normalized: string }>) || [];
    const phonesAfter = (afterData.phones as Array<{ number: string; normalized: string }>) || [];
    const phoneNumberAfter = (afterData.phoneNumber as string) || '';

    if (JSON.stringify(phonesBefore) !== JSON.stringify(phonesAfter) || 
        beforeData.phoneNumber !== phoneNumberAfter) {
      const phoneIndex: string[] = [];
      if (phoneNumberAfter) {
        const normalized = phoneNumberAfter.replace(/[^0-9+]/g, '');
        if (normalized) phoneIndex.push(normalized);
      }
      for (const phone of phonesAfter) {
        if (phone.normalized && !phoneIndex.includes(phone.normalized)) {
          phoneIndex.push(phone.normalized);
        }
      }
      if (phoneIndex.length > 0) {
        updates.phoneIndex = phoneIndex;
      }
    }

    // Validate: Prevent openingBalance updates
    const openingBalanceBefore = (beforeData.openingBalance as number) || 0;
    const openingBalanceAfter = (afterData.openingBalance as number) || 0;
    if (openingBalanceBefore !== openingBalanceAfter) {
      console.warn('[Vendor] Attempted to update openingBalance, reverting', {
        vendorId,
        before: openingBalanceBefore,
        after: openingBalanceAfter,
      });
      // Revert opening balance
      updates.openingBalance = openingBalanceBefore;
    }

    // Validate: Prevent vendorCode updates
    const vendorCodeBefore = (beforeData.vendorCode as string) || '';
    const vendorCodeAfter = (afterData.vendorCode as string) || '';
    if (vendorCodeBefore !== vendorCodeAfter && vendorCodeBefore !== '') {
      console.warn('[Vendor] Attempted to update vendorCode, reverting', {
        vendorId,
        before: vendorCodeBefore,
        after: vendorCodeAfter,
      });
      // Revert vendor code
      updates.vendorCode = vendorCodeBefore;
    }

    // Validate status changes
    const statusBefore = (beforeData.status as string) || 'active';
    const statusAfter = (afterData.status as string) || 'active';
    const currentBalance = (afterData.currentBalance as number) || 0;

    if (statusBefore !== statusAfter) {
      // Check if trying to delete or suspend with non-zero balance
      if ((statusAfter === 'deleted' || statusAfter === 'suspended') && currentBalance !== 0) {
        console.warn('[Vendor] Cannot delete/suspend vendor with pending balance', {
          vendorId,
          status: statusAfter,
          currentBalance,
        });
        // Revert status
        updates.status = statusBefore;
      }
    }

    // Only update timestamp if there are actual field changes
    // This prevents infinite loops where only updatedAt changes trigger another update
    const hasActualChanges = Object.keys(updates).length > 0;
    if (hasActualChanges) {
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      await change.after.ref.update(updates);
      console.log('[Vendor] Updated vendor', { vendorId, updates });
    }
  });

