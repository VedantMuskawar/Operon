import * as admin from 'firebase-admin';
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import {
  TRANSACTIONS_COLLECTION,
  PENDING_ORDERS_COLLECTION,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { getFirestore } from '../shared/firestore-helpers';
import { LIGHT_TRIGGER_OPTS, STANDARD_TRIGGER_OPTS } from '../shared/function-config';

const db = getFirestore();
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * Helper function to mark trips with orderDeleted flag when order is deleted
 * This is for audit purposes only - trips remain independent and functional
 * 
 * @param orderId - The order ID
 * @param deletedBy - User who deleted the order
 * @param tripsSnapshot - Optional pre-fetched trips snapshot (to avoid race conditions)
 */
async function markTripsAsOrderDeleted(
  orderId: string,
  deletedBy?: string,
  tripsSnapshot?: FirebaseFirestore.QuerySnapshot,
): Promise<void> {
  try {
    // Use provided snapshot or fetch new one
    let tripsToMark: FirebaseFirestore.QueryDocumentSnapshot[];
    
    if (tripsSnapshot) {
      tripsToMark = tripsSnapshot.docs;
    } else {
      const fetchedSnapshot = await db
        .collection(SCHEDULE_TRIPS_COLLECTION)
        .where('orderId', '==', orderId)
        .get();
      tripsToMark = fetchedSnapshot.docs;
    }

    if (tripsToMark.length === 0) {
      console.log('[Order Deletion] No trips to mark', { orderId });
      return;
    }

    console.log('[Order Deletion] Marking trips with orderDeleted flag', {
      orderId,
      tripsCount: tripsToMark.length,
    });

    // Mark trips with orderDeleted flag (for audit, not for deletion)
    // Use allSettled to continue even if some updates fail
    const markingPromises = tripsToMark.map(async (doc) => {
      try {
        // Check if trip still exists before updating
        const tripDoc = await doc.ref.get();
        if (!tripDoc.exists) {
          console.warn('[Order Deletion] Trip no longer exists, skipping', {
            orderId,
            tripId: doc.id,
          });
          return;
        }

        await doc.ref.update({
          orderDeleted: true,
          orderDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
          orderDeletedBy: deletedBy || 'system',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log('[Order Deletion] Marked trip', {
          orderId,
          tripId: doc.id,
        });
      } catch (updateError) {
        console.error('[Order Deletion] Failed to mark individual trip', {
          orderId,
          tripId: doc.id,
          error: updateError,
        });
        // Continue with other trips
      }
    });

    const markingResults = await Promise.allSettled(markingPromises);
    const successfulMarks = markingResults.filter(r => r.status === 'fulfilled').length;
    const failedMarks = markingResults.filter(r => r.status === 'rejected').length;

    console.log('[Order Deletion] Trip marking results', {
      orderId,
      total: tripsToMark.length,
      successful: successfulMarks,
      failed: failedMarks,
    });
  } catch (error) {
    console.error('[Order Deletion] Error marking trips', {
      orderId,
      error,
    });
    // Don't throw - trip marking failure shouldn't block order deletion
  }
}

/**
 * Cloud Function: Triggered when an order is deleted
 * Automatically deletes all associated transactions and marks trips for audit
 */
export const onOrderDeleted = onDocumentDeleted(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const orderId = event.params.orderId;
    const snapshot = event.data;
    if (!snapshot) return;
    const data = snapshot.data();
    const deletedBy = (data as any)?.deletedBy as string | undefined;
    
    console.log('[Order Deletion] Processing order deletion', {
      orderId,
      deletedBy,
    });

    // First, get trips count and snapshot BEFORE any operations
    // This ensures we have the trip references even if something fails later
    let tripsSnapshot: FirebaseFirestore.QuerySnapshot | null = null;
    let tripsCount = 0;
    
    try {
      tripsSnapshot = await db
        .collection(SCHEDULE_TRIPS_COLLECTION)
        .where('orderId', '==', orderId)
        .get();

      tripsCount = tripsSnapshot.size;

      if (tripsCount > 0) {
        console.log('[Order Deletion] Order has scheduled trips - trips will remain independent', {
          orderId,
          tripsCount,
        });
      }
    } catch (tripError) {
      console.error('[Order Deletion] Error fetching trips', {
        orderId,
        error: tripError,
      });
      // Continue even if trip fetch fails
    }

    // Process transaction deletion
    try {
      // Find all transactions associated with this order
      const transactionsSnapshot = await db
        .collection(TRANSACTIONS_COLLECTION)
        .where('orderId', '==', orderId)
        .get();

      if (transactionsSnapshot.empty) {
        console.log('[Order Deletion] No transactions found for order', {
          orderId,
        });
      } else {
        console.log('[Order Deletion] Found transactions to delete', {
          orderId,
          transactionCount: transactionsSnapshot.size,
        });

        // Check if trips exist with active status (scheduled, dispatched, delivered, or returned)
        // If trips exist, preserve advance payment transactions
        let shouldPreserveAdvance = false;
        if (tripsCount > 0 && tripsSnapshot) {
          const activeStatuses = ['scheduled', 'dispatched', 'delivered', 'returned'];
          const hasActiveTrip = tripsSnapshot.docs.some((tripDoc) => {
            const tripData = tripDoc.data();
            const tripStatus = (tripData.tripStatus as string) || '';
            return activeStatuses.includes(tripStatus.toLowerCase());
          });
          
          if (hasActiveTrip) {
            shouldPreserveAdvance = true;
            console.log('[Order Deletion] Active trips exist - preserving advance payment transactions', {
              orderId,
              tripsCount,
            });
          }
        }

        // Delete all associated transactions with retry logic
        // This will trigger onTransactionDeleted which will properly revert ledger and analytics
        const deletionPromises = transactionsSnapshot.docs.map(async (txDoc) => {
          const txId = txDoc.id;
          const txData = txDoc.data();
          const txType = txData.type as string;
          const txCategory = txData.category as string;
          
          // Preserve advance payment transactions if trips exist
          if (shouldPreserveAdvance && (txCategory === 'advance' || txType === 'advance')) {
            console.log('[Order Deletion] Preserving advance payment transaction', {
              orderId,
              transactionId: txId,
              reason: 'Active trips exist',
            });
            return; // Skip deletion
          }
          
          const currentStatus = txData.status as string;

          // Retry deletion up to 3 times
          let retries = 0;
          const maxRetries = 3;
          
          while (retries < maxRetries) {
            try {
              await txDoc.ref.delete();
              console.log('[Order Deletion] Deleted transaction', {
                orderId,
                transactionId: txId,
                previousStatus: currentStatus,
                retries,
              });
              return; // Success
            } catch (error) {
              retries++;
              if (retries >= maxRetries) {
                console.error('[Order Deletion] Failed to delete transaction after retries', {
                  orderId,
                  transactionId: txId,
                  error,
                  retries,
                });
                // Mark transaction for manual cleanup
                try {
                  await txDoc.ref.update({
                    needsCleanup: true,
                    cleanupReason: `Order ${orderId} was deleted but transaction deletion failed`,
                    cleanupRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                } catch (updateError) {
                  console.error('[Order Deletion] Failed to mark transaction for cleanup', {
                    orderId,
                    transactionId: txId,
                    error: updateError,
                  });
                }
                // Don't throw - continue with other transactions
                return;
              }
              // Exponential backoff
              await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
              console.warn('[Order Deletion] Retrying transaction deletion', {
                orderId,
                transactionId: txId,
                retry: retries,
                maxRetries,
              });
            }
          }
        });

        // Use Promise.allSettled to continue even if some deletions fail
        const deletionResults = await Promise.allSettled(deletionPromises);
        
        const successfulDeletions = deletionResults.filter(r => r.status === 'fulfilled').length;
        const failedDeletions = deletionResults.filter(r => r.status === 'rejected').length;
        
        console.log('[Order Deletion] Transaction deletion results', {
          orderId,
          total: transactionsSnapshot.size,
          successful: successfulDeletions,
          failed: failedDeletions,
        });
      }
    } catch (transactionError) {
      console.error('[Order Deletion] Error processing transaction deletion', {
        orderId,
        error: transactionError,
      });
      // Continue to trip marking even if transaction deletion fails
    }

    // Mark trips with orderDeleted flag (for audit trail, not for deletion)
    // This happens AFTER transaction deletion, and even if transaction deletion fails
    if (tripsCount > 0 && tripsSnapshot) {
      try {
        await markTripsAsOrderDeleted(orderId, deletedBy, tripsSnapshot);
      } catch (tripMarkingError) {
        console.error('[Order Deletion] Error marking trips', {
          orderId,
          error: tripMarkingError,
        });
        // Don't throw - trip marking failure shouldn't block order deletion
      }
    }

    console.log('[Order Deletion] Successfully processed order deletion', {
      orderId,
      tripsMarked: tripsCount,
    });
  },
);

/**
 * Helper function to generate order number
 * Format: ORD-{YYYY}-{NNN} (e.g., ORD-2024-001)
 */
async function generateOrderNumber(organizationId: string): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `ORD-${year}-`;
  
  try {
    // Query for orders with orderNumber starting with prefix
    // Note: This query requires a composite index on (organizationId, orderNumber)
    // If index doesn't exist, we'll use a simpler approach
    const ordersSnapshot = await db
      .collection(PENDING_ORDERS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('orderNumber', '>=', prefix)
      .where('orderNumber', '<', `${prefix}Z`)
      .orderBy('orderNumber', 'desc')
      .limit(1)
      .get();
    
    let nextNumber = 1;
    if (!ordersSnapshot.empty) {
      const lastOrder = ordersSnapshot.docs[0];
      const lastOrderNumber = lastOrder.data().orderNumber as string;
      if (lastOrderNumber && lastOrderNumber.startsWith(prefix)) {
        const parts = lastOrderNumber.split('-');
        if (parts.length === 3 && parts[2]) {
          const lastSequence = parseInt(parts[2], 10);
          if (!isNaN(lastSequence) && lastSequence > 0) {
            nextNumber = lastSequence + 1;
          }
        }
      }
    }
    
    return `${prefix}${String(nextNumber).padStart(3, '0')}`;
  } catch (error: any) {
    // If query fails (e.g., missing index), use timestamp-based fallback
    if (error.code === 'failed-precondition') {
      console.warn('[Order Number] Index missing, using timestamp-based fallback', { organizationId });
      const timestamp = Date.now();
      return `${prefix}${String(timestamp % 1000).padStart(3, '0')}`;
    }
    throw error;
  }
}

/**
 * Cloud Function: Triggered when an order is created
 * Generates order number and creates advance transaction if advance payment was provided
 */
export const onPendingOrderCreated = onDocumentCreated(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...STANDARD_TRIGGER_OPTS,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const orderId = event.params.orderId;
    const orderData = snapshot.data();
    const organizationId = orderData.organizationId as string;

    // Idempotency: skip if advance transaction already created for this order
    const existingAdvance = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('orderId', '==', orderId)
      .where('category', '==', 'advance')
      .limit(1)
      .get();
    if (!existingAdvance.empty) {
      console.log('[Order Created] Advance transaction already exists, skipping', { orderId });
      return;
    }

    // Generate order number if not already set
    let orderNumber = orderData.orderNumber as string | undefined;
    if (!orderNumber || orderNumber.trim() === '') {
      try {
        orderNumber = await generateOrderNumber(organizationId);
        await snapshot.ref.update({
          orderNumber: orderNumber,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[Order Created] Generated order number', {
          orderId,
          orderNumber,
        });
      } catch (error) {
        console.error('[Order Created] Failed to generate order number', {
          orderId,
          error,
        });
        // Continue execution even if order number generation fails
      }
    } else {
      orderNumber = orderData.orderNumber as string | undefined;
    }
    
    const advanceAmount = (orderData.advanceAmount as number | undefined) || 0;
    
    // Only create transaction if advance amount > 0
    if (!advanceAmount || advanceAmount <= 0) {
      console.log('[Order Created] No advance payment, skipping transaction creation', {
        orderId,
        orderNumber,
      });
      return;
    }

    const clientId = orderData.clientId as string;
    const totalAmount = (orderData.pricing as any)?.totalAmount as number | undefined;
    const remainingAmount = (orderData.remainingAmount as number | undefined) || 
      (totalAmount ? totalAmount - advanceAmount : undefined);
    const advancePaymentAccountId = (orderData.advancePaymentAccountId as string | undefined) || 'cash';
    const createdBy = (orderData.createdBy as string | undefined) || 'system';
    const clientName = (orderData.clientName as string | undefined) || undefined;

    // Validate required fields
    if (!organizationId || !clientId) {
      console.error('[Order Created] Missing required fields for advance transaction', {
        orderId,
        organizationId,
        clientId,
      });
      
      // Mark order with error flag
      await snapshot.ref.update({
        advanceTransactionError: 'Missing required fields: organizationId or clientId',
        advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    // Validate advance amount doesn't exceed total
    if (totalAmount && advanceAmount > totalAmount) {
      console.error('[Order Created] Advance amount exceeds order total', {
        orderId,
        advanceAmount,
        totalAmount,
      });
      
      // Mark order with error flag
      await snapshot.ref.update({
        advanceTransactionError: `Advance amount (${advanceAmount}) exceeds order total (${totalAmount})`,
        advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      // Get payment account type if payment account ID is provided
      let paymentAccountType = 'cash';
      if (advancePaymentAccountId && advancePaymentAccountId !== 'cash') {
        try {
          // Fetch payment account details from ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS
          const accountRef = db
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection('PAYMENT_ACCOUNTS')
            .doc(advancePaymentAccountId);
          
          const accountDoc = await accountRef.get();
          if (!accountDoc.exists) {
            console.error('[Order Created] Payment account not found', {
              orderId,
              advancePaymentAccountId,
            });
            
            await snapshot.ref.update({
              advanceTransactionError: `Payment account ${advancePaymentAccountId} not found`,
              advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
          }
          
          const accountData = accountDoc.data();
          
          // Validate account is active
          if (accountData?.isActive === false) {
            console.error('[Order Created] Payment account is inactive', {
              orderId,
              advancePaymentAccountId,
            });
            
            await snapshot.ref.update({
              advanceTransactionError: `Payment account ${advancePaymentAccountId} is inactive`,
              advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return;
          }
          
          paymentAccountType = (accountData?.type as string) || 'other';
        } catch (error) {
          console.error('[Order Created] Error validating payment account', {
            orderId,
            advancePaymentAccountId,
            error,
          });
          
          await snapshot.ref.update({
            advanceTransactionError: `Error validating payment account: ${error instanceof Error ? error.message : String(error)}`,
            advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
      }

      // Calculate financial year
      const now = new Date();
      const { fyLabel: financialYear } = getFinancialContext(now);

      // Create advance transaction with retry logic
      let retries = 0;
      const maxRetries = 3;
      let transactionCreated = false;
      let transactionRef: FirebaseFirestore.DocumentReference | null = null;

      const transactionData = {
        organizationId,
        clientId,
        ...(clientName ? { clientName } : {}),
        ledgerType: 'clientLedger',
        type: 'debit', // Debit = client paid upfront (decreases receivable)
        category: 'advance', // Advance payment on order
        amount: advanceAmount,
        paymentAccountId: advancePaymentAccountId,
        paymentAccountType: paymentAccountType,
        orderId: orderId,
        description: `Advance payment for order ${orderNumber || orderId}`,
        metadata: {
          orderTotal: totalAmount || 0,
          advanceAmount,
          remainingAmount: remainingAmount || 0,
          ...(clientName ? { clientName } : {}),
        },
        createdBy: createdBy,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        financialYear: financialYear,
      };

      while (retries < maxRetries && !transactionCreated) {
        try {
          transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
          await transactionRef.set(transactionData);
          
          transactionCreated = true;
          
          console.log('[Order Created] Successfully created advance transaction', {
            orderId,
            transactionId: transactionRef.id,
            advanceAmount,
            financialYear,
            retries,
          });
        } catch (error) {
          retries++;
          if (retries >= maxRetries) {
            console.error('[Order Created] Failed to create advance transaction after retries', {
              orderId,
              error,
              retries,
            });
            
            // Mark order with error flag for manual retry
            await snapshot.ref.update({
              advanceTransactionFailed: true,
              advanceTransactionError: error instanceof Error ? error.message : String(error),
              advanceTransactionRetries: retries,
              advanceTransactionFailedAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            break;
          }
          
          // Exponential backoff
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
          console.warn('[Order Created] Retrying advance transaction creation', {
            orderId,
            retry: retries,
            maxRetries,
          });
        }
      }
    } catch (error) {
      console.error('[Order Created] Error creating advance transaction', {
        orderId,
        error,
      });
      
      // Mark order with error flag
      try {
        await snapshot.ref.update({
          advanceTransactionFailed: true,
          advanceTransactionError: error instanceof Error ? error.message : String(error),
          advanceTransactionFailedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        console.error('[Order Created] Failed to mark order with error flag', {
          orderId,
          error: updateError,
        });
      }
      // Don't throw - we don't want to block order creation if transaction creation fails
      // The transaction can be created manually if needed
    }
  },
);

/**
 * Cloud Function: Triggered when an order is updated
 * Cleans up auto-schedule data if order is cancelled
 */
export const onOrderUpdated = onDocumentUpdated(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const orderId = event.params.orderId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const afterRef = event.data?.after.ref;
    if (!before || !after || !afterRef) return;

    const beforeStatus = (before.status as string) || 'pending';
    const afterStatus = (after.status as string) || 'pending';

    // Only process if status changed to cancelled
    if (beforeStatus !== 'cancelled' && afterStatus === 'cancelled') {
      console.log('[Order Update] Order cancelled, cleaning up auto-schedule data', {
        orderId,
        previousStatus: beforeStatus,
      });

      try {
        await afterRef.update({
          autoSchedule: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[Order Update] Successfully cleaned up auto-schedule data', {
          orderId,
        });
      } catch (error) {
        console.error('[Order Update] Error cleaning up auto-schedule data', {
          orderId,
          error,
        });
      }
    }
  },
);

