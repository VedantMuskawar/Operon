import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import { PENDING_ORDERS_COLLECTION, TRANSACTIONS_COLLECTION } from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { STANDARD_TRIGGER_OPTS } from '../shared/function-config';

const db = getFirestore();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * When a trip's tripStatus is updated:
 * Update the corresponding trip entry in PENDING_ORDERS.scheduledTrips array
 */
export const onTripStatusUpdated = onDocumentUpdated(
  {
    document: `${SCHEDULED_TRIPS_COLLECTION}/{tripId}`,
    ...STANDARD_TRIGGER_OPTS,
  },
  async (event) => {
    const tripId = event.params.tripId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) {
      console.error('[Trip Status Update] No trip data found', {tripId});
      return;
    }

    const beforeStatus = before.tripStatus as string | undefined;
    const afterStatus = after.tripStatus as string | undefined;

    // Only proceed if tripStatus actually changed
    if (beforeStatus === afterStatus) {
      console.log('[Trip Status Update] Trip status unchanged, skipping', {
        tripId,
        status: afterStatus,
      });
      return;
    }

    // Validate: DM is mandatory for dispatch
    if (afterStatus === 'dispatched') {
      const dmNumber = after.dmNumber;
      if (!dmNumber) {
        console.error('[Trip Status Update] Cannot dispatch trip without DM number', {
          tripId,
          orderId: after.orderId,
        });
        // Revert the status change by updating the trip back to previous status
        if (event.data?.after) {
          await event.data.after.ref.update({
            tripStatus: beforeStatus || 'scheduled',
            orderStatus: beforeStatus || 'scheduled',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        throw new Error('DM must be generated before dispatching trip');
      }
    }

    const orderId = after.orderId as string | undefined;
    if (!orderId) {
      console.error('[Trip Status Update] No orderId found in trip', {tripId});
      return;
    }

    console.log('[Trip Status Update] Processing trip status change', {
      tripId,
      orderId,
      beforeStatus,
      afterStatus,
    });

    try {
      const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);

      await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          console.log('[Trip Status Update] Order not found - trip is independent', {
            orderId,
            tripId,
            newStatus: afterStatus,
          });
          // Trip can continue independently - this is correct behavior
          // Don't try to update non-existent order
          return;
        }

        const orderData = orderDoc.data()!;
        
        // Check if order is cancelled - trip can still continue independently
        const orderStatus = (orderData.status as string) || 'pending';
        if (orderStatus === 'cancelled') {
          console.log('[Trip Status Update] Order is cancelled - trip is independent', {
            orderId,
            tripId,
            newStatus: afterStatus,
          });
          // Trip can continue independently even if order is cancelled
          // Don't update cancelled order
          return;
        }
        
        const scheduledTrips = (orderData.scheduledTrips as any[]) || [];

        // Get itemIndex and productId from trip data
        const tripItemIndex = (after.itemIndex as number) ?? 0;
        const tripProductId = (after.productId as string) || null;
        
        // Find and update the trip in the scheduledTrips array
        const updatedScheduledTrips = scheduledTrips.map((trip) => {
          if (trip.tripId === tripId) {
            return {
              ...trip,
              itemIndex: tripItemIndex, // ✅ Ensure itemIndex is set
              productId: tripProductId || trip.productId || null, // ✅ Ensure productId is set
              tripStatus: afterStatus,
              // Include dispatch-related fields if status is dispatched
              ...(afterStatus === 'dispatched' && {
                dispatchedAt: after.dispatchedAt || null,
                initialReading: after.initialReading || null,
                dispatchedBy: after.dispatchedBy || null,
                dispatchedByRole: after.dispatchedByRole || null,
              }),
              // Include delivery-related fields if status is delivered
              ...(afterStatus === 'delivered' && {
                deliveredAt: after.deliveredAt || null,
                deliveryPhotoUrl: after.deliveryPhotoUrl || null,
                deliveredBy: after.deliveredBy || null,
                deliveredByRole: after.deliveredByRole || null,
              }),
              // Include return-related fields if status is returned
              ...(afterStatus === 'returned' && {
                returnedAt: after.returnedAt || null,
                finalReading: after.finalReading || null,
                returnedBy: after.returnedBy || null,
                returnedByRole: after.returnedByRole || null,
                paymentDetails: after.paymentDetails || null,
              }),
              // Remove dispatch fields if status is not dispatched
              ...(afterStatus !== 'dispatched' && {
                dispatchedAt: null,
                initialReading: null,
                dispatchedBy: null,
                dispatchedByRole: null,
              }),
              // Remove delivery fields if status is not delivered
              ...(afterStatus !== 'delivered' && {
                deliveredAt: null,
                deliveryPhotoUrl: null,
                deliveredBy: null,
                deliveredByRole: null,
              }),
              // Remove return fields if status is not returned
              ...(afterStatus !== 'returned' && {
                returnedAt: null,
                finalReading: null,
                returnedBy: null,
                returnedByRole: null,
                paymentDetails: null,
              }),
            };
          }
          return trip;
        });

        // Check if trip exists in array
        const tripExists = scheduledTrips.some((trip) => trip.tripId === tripId);
        if (!tripExists) {
          console.warn('[Trip Status Update] Trip not found in scheduledTrips array', {
            tripId,
            orderId,
          });
          return;
        }

        transaction.update(orderRef, {
          scheduledTrips: updatedScheduledTrips,
          updatedAt: new Date(),
        });

        console.log('[Trip Status Update] Order updated', {
          orderId,
          tripId,
          newStatus: afterStatus,
        });
      });

      // #region agent log
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:181',message:'Checking status for DM update',data:{tripId,afterStatus,beforeStatus,isReturned:afterStatus==='returned'},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
      // #endregion
      // If status is delivered, update DELIVERY_MEMO document
      if (afterStatus === 'delivered') {
        await _updateDeliveryMemo(tripId, after);
      } else if (beforeStatus === 'delivered' && afterStatus !== 'delivered') {
        // If status changed FROM delivered to something else (e.g., dispatched or returned), revert DELIVERY_MEMO
        await _revertDeliveryMemo(tripId);
      }

      // If status is returned, update DELIVERY_MEMO document with tripStatus
      // #region agent log
      console.log('[DEBUG] Checking if status is returned for DM update', {tripId, afterStatus, isReturned: afterStatus === 'returned', hypothesisId: 'A'});
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:189',message:'Returned status check',data:{tripId,afterStatus,isReturned:afterStatus==='returned'},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
      // #endregion
      if (afterStatus === 'returned') {
        await _updateDeliveryMemoForReturn(tripId, after);
      } else if (beforeStatus === 'returned' && afterStatus !== 'returned') {
        // If status changed FROM returned to something else, revert return fields in DELIVERY_MEMO
        await _revertDeliveryMemoReturn(tripId);
      }

      // If status changed FROM dispatched to something else (e.g., scheduled), cancel credit transaction
      if (beforeStatus === 'dispatched' && afterStatus !== 'dispatched') {
        const creditTransactionId = after.creditTransactionId as string | undefined;
        if (creditTransactionId) {
          await _cancelCreditTransaction(tripId, creditTransactionId);
        }
      }
    } catch (error) {
      console.error('[Trip Status Update] Error updating order', {
        tripId,
        orderId,
        error,
      });
      throw error;
    }
  },
);

const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';

async function _updateDeliveryMemo(
  tripId: string,
  tripData: any,
): Promise<void> {
  try {
    // Find DELIVERY_MEMO document by tripId
    // Only update dispatch DMs (source !== 'trip_return_trigger'), not return DMs
    const dmQuery = await db
      .collection(DELIVERY_MEMOS_COLLECTION)
      .where('tripId', '==', tripId)
      .where('status', '==', 'active')
      .limit(10) // Get multiple to filter by source
      .get();
    
    // Filter to only dispatch DMs (exclude return DMs)
    const dispatchDMs = dmQuery.docs.filter((doc) => {
      const data = doc.data();
      return data.source !== 'trip_return_trigger';
    });
    
    if (dispatchDMs.length === 0) {
      console.log('[Trip Status Update] No active dispatch delivery memo found for trip', {
        tripId,
      });
      return;
    }
    
    const dispatchDmDoc = dispatchDMs[0];
    const updateData: any = {
      status: 'delivered',
      deliveredAt: tripData.deliveredAt || new Date(),
      deliveryPhotoUrl: tripData.deliveryPhotoUrl || null,
      deliveredBy: tripData.deliveredBy || null,
      deliveredByRole: tripData.deliveredByRole || null,
      updatedAt: new Date(),
    };

    await dispatchDmDoc.ref.update(updateData);

    console.log('[Trip Status Update] Delivery memo updated', {
      tripId,
      dmId: dispatchDmDoc.id,
    });
  } catch (error) {
    console.error('[Trip Status Update] Error updating delivery memo', {
      tripId,
      error,
    });
    // Don't throw - delivery memo update failure shouldn't block trip status update
  }
}

async function _revertDeliveryMemo(tripId: string): Promise<void> {
  try {
    // Find DELIVERY_MEMO document by tripId
    const dmQuery = await db
      .collection(DELIVERY_MEMOS_COLLECTION)
      .where('tripId', '==', tripId)
      .where('status', '==', 'delivered')
      .limit(1)
      .get();

    if (dmQuery.empty) {
      console.log('[Trip Status Update] No delivered delivery memo found for trip', {
        tripId,
      });
      return;
    }

    const dmDoc = dmQuery.docs[0];
    const updateData: any = {
      status: 'active', // Revert to active
      deliveredAt: null,
      deliveryPhotoUrl: null,
      deliveredBy: null,
      deliveredByRole: null,
      updatedAt: new Date(),
    };

    await dmDoc.ref.update(updateData);

    console.log('[Trip Status Update] Delivery memo reverted', {
      tripId,
      dmId: dmDoc.id,
    });
  } catch (error) {
    console.error('[Trip Status Update] Error reverting delivery memo', {
      tripId,
      error,
    });
    // Don't throw - delivery memo update failure shouldn't block trip status update
  }
}

async function _updateDeliveryMemoForReturn(
  tripId: string,
  tripData: any,
): Promise<void> {
  try {
    // #region agent log
    console.log('[DEBUG] _updateDeliveryMemoForReturn called', {tripId, tripStatus: tripData.tripStatus, hypothesisId: 'A'});
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:314',message:'_updateDeliveryMemoForReturn called',data:{tripId,tripStatus:tripData.tripStatus},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'A'})}).catch(()=>{});
    // #endregion
    // Find DELIVERY_MEMO document by tripId
    // Only update dispatch DMs (source !== 'trip_return_trigger'), not return DMs
    const dmQuery = await db
      .collection(DELIVERY_MEMOS_COLLECTION)
      .where('tripId', '==', tripId)
      .limit(10) // Get multiple to filter by source
      .get();
    
    // #region agent log
    console.log('[DEBUG] DM query for return', {tripId, docCount: dmQuery.docs.length, hypothesisId: 'B'});
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:322',message:'DM query for return',data:{tripId,docCount:dmQuery.docs.length},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'B'})}).catch(()=>{});
    // #endregion
    
    // Filter to only dispatch DMs (exclude return DMs)
    const dispatchDMs = dmQuery.docs.filter((doc) => {
      const data = doc.data();
      return data.source !== 'trip_return_trigger';
    });
    
    if (dispatchDMs.length === 0) {
      console.log('[Trip Status Update] No dispatch delivery memo found for trip return', {
        tripId,
      });
      return;
    }
    
    const dispatchDmDoc = dispatchDMs[0];
    const updateData: any = {
      tripStatus: tripData.tripStatus || 'returned',
      orderStatus: tripData.orderStatus || '',
      returnedAt: tripData.returnedAt || new Date(),
      returnedBy: tripData.returnedBy || null,
      returnedByRole: tripData.returnedByRole || null,
      meters: {
        initialReading: tripData.initialReading ?? null,
        finalReading: tripData.finalReading ?? null,
        distanceTravelled: tripData.distanceTravelled ?? null,
      },
      updatedAt: new Date(),
    };

    // If Pay on Delivery, add payment details
    const paymentType = (tripData.paymentType as string)?.toLowerCase() || '';
    if (paymentType === 'pay_on_delivery') {
      const paymentDetails = tripData.paymentDetails || [];
      updateData.paymentDetails = paymentDetails;
      updateData.paymentStatus = tripData.paymentStatus || 'pending';
      updateData.totalPaidOnReturn = tripData.totalPaidOnReturn ?? null;
      updateData.remainingAmount = tripData.remainingAmount ?? null;
    }

    // #region agent log
    console.log('[DEBUG] About to update DM with return data', {tripId, dmId: dispatchDmDoc.id, updateDataTripStatus: updateData.tripStatus, hypothesisId: 'C'});
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:350',message:'About to update DM with return data',data:{tripId,dmId:dispatchDmDoc.id,updateDataTripStatus:updateData.tripStatus},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'C'})}).catch(()=>{});
    // #endregion

    await dispatchDmDoc.ref.update(updateData);

    // #region agent log
    console.log('[DEBUG] DM updated with return status SUCCESS', {tripId, dmId: dispatchDmDoc.id, hypothesisId: 'C'});
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:356',message:'DM updated with return status SUCCESS',data:{tripId,dmId:dispatchDmDoc.id},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'C'})}).catch(()=>{});
    // #endregion

    console.log('[Trip Status Update] Delivery memo updated for return', {
      tripId,
      dmId: dispatchDmDoc.id,
    });
  } catch (error) {
    // #region agent log
    console.error('[DEBUG] DM update for return FAILED', {tripId, error: (error as any)?.message, hypothesisId: 'C'});
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'trip-status-update.ts:365',message:'DM update for return FAILED',data:{tripId,error:(error as any)?.message},timestamp:Date.now(),sessionId:'debug-session',runId:'run1',hypothesisId:'C'})}).catch(()=>{});
    // #endregion
    console.error('[Trip Status Update] Error updating delivery memo for return', {
      tripId,
      error,
    });
    // Don't throw - delivery memo update failure shouldn't block trip status update
  }
}

async function _revertDeliveryMemoReturn(tripId: string): Promise<void> {
  try {
    // Find DELIVERY_MEMO document by tripId
    const dmQuery = await db
      .collection(DELIVERY_MEMOS_COLLECTION)
      .where('tripId', '==', tripId)
      .where('status', '==', 'returned')
      .limit(1)
      .get();

    if (dmQuery.empty) {
      console.log('[Trip Status Update] No returned delivery memo found for trip', {
        tripId,
      });
      return;
    }

    const dmDoc = dmQuery.docs[0];
    const updateData: any = {
      status: 'delivered', // Revert to delivered
      returnedAt: null,
      finalReading: null,
      distanceTravelled: null,
      returnedBy: null,
      returnedByRole: null,
      paymentDetails: null,
      totalPaidOnReturn: null,
      paymentStatus: null,
      remainingAmount: null,
      returnTransactions: null,
      updatedAt: new Date(),
    };

    await dmDoc.ref.update(updateData);

    console.log('[Trip Status Update] Delivery memo return reverted', {
      tripId,
      dmId: dmDoc.id,
    });
  } catch (error) {
    console.error('[Trip Status Update] Error reverting delivery memo return', {
      tripId,
      error,
    });
    // Don't throw - delivery memo update failure shouldn't block trip status update
  }
}

/**
 * Cancel credit transaction when trip is reverted from dispatched to scheduled
 */
async function _cancelCreditTransaction(
  tripId: string,
  creditTransactionId: string,
): Promise<void> {
  try {
    const creditTxnRef = db.collection(TRANSACTIONS_COLLECTION).doc(creditTransactionId);
    const creditTxnDoc = await creditTxnRef.get();
    
    if (!creditTxnDoc.exists) {
      console.log('[Trip Status Update] Credit transaction not found', {
        tripId,
        transactionId: creditTransactionId,
      });
      return;
    }

    const creditTxnData = creditTxnDoc.data();
    const currentStatus = creditTxnData?.status as string;
    
    // Only cancel if not already cancelled
    if (currentStatus !== 'cancelled') {
      await creditTxnRef.update({
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelledBy: 'system',
        cancellationReason: 'Trip dispatch reverted',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log('[Trip Status Update] Credit transaction cancelled', {
        tripId,
        transactionId: creditTransactionId,
      });
    } else {
      console.log('[Trip Status Update] Credit transaction already cancelled', {
        tripId,
        transactionId: creditTransactionId,
      });
    }
  } catch (error) {
    console.error('[Trip Status Update] Error cancelling credit transaction', {
      tripId,
      creditTransactionId,
      error,
    });
    // Don't throw - transaction cancellation failure shouldn't block trip status update
  }
}