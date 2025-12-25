import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {getFirestore} from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {PENDING_ORDERS_COLLECTION} from '../shared/constants';

const db = getFirestore();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * When a trip's tripStatus is updated:
 * Update the corresponding trip entry in PENDING_ORDERS.scheduledTrips array
 */
export const onTripStatusUpdated = onDocumentUpdated(
  `${SCHEDULED_TRIPS_COLLECTION}/{tripId}`,
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

        // Find and update the trip in the scheduledTrips array
        const updatedScheduledTrips = scheduledTrips.map((trip) => {
          if (trip.tripId === tripId) {
            return {
              ...trip,
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

      // If status is delivered, update DELIVERY_MEMO document
      if (afterStatus === 'delivered') {
        await _updateDeliveryMemo(tripId, after);
      } else if (beforeStatus === 'delivered' && afterStatus !== 'delivered') {
        // If status changed FROM delivered to something else (e.g., dispatched or returned), revert DELIVERY_MEMO
        await _revertDeliveryMemo(tripId);
      }

      // If status is returned, let onTripReturnedCreateDM handle creating a new DM
      // Don't update existing DM - we want a fresh DM document for returns
      // Note: onTripReturnedCreateDM will create a new DM if one doesn't exist
      if (beforeStatus === 'returned' && afterStatus !== 'returned') {
        // If status changed FROM returned to something else, revert return fields in DELIVERY_MEMO
        await _revertDeliveryMemoReturn(tripId);
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

// Removed _updateDeliveryMemoForReturn - we now create a new DM on return via onTripReturnedCreateDM
// This ensures a fresh delivery memo document is created for returns, not an update to existing DM

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

