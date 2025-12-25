import {onDocumentCreated, onDocumentDeleted} from 'firebase-functions/v2/firestore';
import {getFirestore} from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {PENDING_ORDERS_COLLECTION, TRANSACTIONS_COLLECTION} from '../shared/constants';

const db = getFirestore();
const TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * When a trip is scheduled:
 * 1. Update PENDING_ORDER: Add to scheduledTrips array, increment totalScheduledTrips, decrement estimatedTrips
 * 2. If estimatedTrips becomes 0: Set status to 'fully_scheduled' (don't delete order)
 */
export const onScheduledTripCreated = onDocumentCreated(
  'SCHEDULE_TRIPS/{tripId}',
  async (event) => {
    const tripData = event.data?.data();
    if (!tripData) {
      console.error('[Trip Scheduling] No trip data found');
      return;
    }

    const orderId = tripData.orderId as string;
    const tripId = event.params.tripId;
    const tripRef = db.collection(TRIPS_COLLECTION).doc(tripId);

    console.log('[Trip Scheduling] Processing scheduled trip', {tripId, orderId});

    try {
      // Enforce uniqueness: same date + vehicle + slot should not exist
      const scheduledDate = tripData.scheduledDate;
      const vehicleId = tripData.vehicleId;
      const slot = tripData.slot;
      if (scheduledDate && vehicleId && slot !== undefined) {
        const clashSnap = await db
          .collection(TRIPS_COLLECTION)
          .where('scheduledDate', '==', scheduledDate)
          .where('vehicleId', '==', vehicleId)
          .where('slot', '==', slot)
          .limit(5)
          .get();
        const otherDocs = clashSnap.docs.filter((d) => d.id !== tripId);
        if (otherDocs.length > 0) {
          console.warn('[Trip Scheduling] Slot already booked', {
            tripId,
            orderId,
            vehicleId,
            slot,
            scheduledDate,
          });
          await tripRef.delete();
          return;
        }
      }

      // Pre-check order existence and remaining trips; delete trip if invalid
      const preOrder = await db.collection(PENDING_ORDERS_COLLECTION).doc(orderId).get();
      if (!preOrder.exists) {
        console.warn('[Trip Scheduling] Order not found, deleting trip', {orderId, tripId});
        await tripRef.delete();
        return;
      }
      const preData = preOrder.data() || {};
      const preItems = (preData.items as any[]) || [];
      if (preItems.length === 0) {
        console.warn('[Trip Scheduling] Order has no items, deleting trip', {orderId, tripId});
        await tripRef.delete();
        return;
      }
      const preFirstItem = preItems[0];
      const preEstimatedTrips = (preFirstItem.estimatedTrips as number) || 0;
      if (preEstimatedTrips <= 0) {
        console.warn('[Trip Scheduling] No trips remaining to schedule, deleting trip', {
          orderId,
          tripId,
          remaining: preEstimatedTrips,
        });
        await tripRef.delete();
        return;
      }
      // Pre-check scheduledQuantity/unscheduledQuantity if present
      const preUnscheduledQuantity = (preData.unscheduledQuantity as number) ?? null;
      if (preUnscheduledQuantity !== null && preUnscheduledQuantity <= 0) {
        console.warn('[Trip Scheduling] No unscheduled quantity remaining, deleting trip', {
          orderId,
          tripId,
          preUnscheduledQuantity,
        });
        await tripRef.delete();
        return;
      }

      const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);
      
      await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        
        if (!orderDoc.exists) {
          console.warn('[Trip Scheduling] Order not found', {orderId});
          return;
        }

        const orderData = orderDoc.data()!;
        const items = (orderData.items as any[]) || [];
        
        if (items.length === 0) {
          console.error('[Trip Scheduling] Order has no items', {orderId});
          transaction.delete(tripRef);
          return;
        }

        // Get the first item (assuming single product per order for now)
        const firstItem = items[0];
        let estimatedTrips = (firstItem.estimatedTrips as number) || 0;

        if (estimatedTrips <= 0) {
          console.warn('[Trip Scheduling] No trips remaining to schedule', {orderId, tripId});
          transaction.delete(tripRef);
          return;
        }

        // Prepare trip entry for scheduledTrips array
        const tripEntry = {
          tripId,
          scheduleTripId: tripData.scheduleTripId || null, // Include scheduleTripId if available
          scheduledDate: tripData.scheduledDate,
          scheduledDay: tripData.scheduledDay,
          vehicleId: tripData.vehicleId,
          vehicleNumber: tripData.vehicleNumber,
          driverName: tripData.driverName || null,
          slot: tripData.slot,
          slotName: tripData.slotName,
          customerNumber: tripData.customerNumber,
          paymentType: tripData.paymentType,
          tripStatus: 'scheduled',
          scheduledAt: tripData.createdAt,
          scheduledBy: tripData.createdBy,
        };

        // Get existing scheduledTrips array
        const scheduledTrips = (orderData.scheduledTrips as any[]) || [];
        const totalScheduledTrips = (orderData.totalScheduledTrips as number) || 0;

        // Update order
        const updateData: any = {
          scheduledTrips: [...scheduledTrips, tripEntry],
          totalScheduledTrips: totalScheduledTrips + 1,
          updatedAt: new Date(),
        };

        // Decrement estimatedTrips
        estimatedTrips -= 1;
        items[0].estimatedTrips = estimatedTrips;
        updateData.items = items;

        // If estimatedTrips becomes 0, set status to 'fully_scheduled' instead of deleting
        if (estimatedTrips === 0) {
          updateData.status = 'fully_scheduled';
          console.log('[Trip Scheduling] All trips scheduled, marking order as fully_scheduled', {orderId});
        } else {
          // Ensure status is 'pending' if trips remain
          updateData.status = 'pending';
        }

        transaction.update(orderRef, updateData);

        console.log('[Trip Scheduling] Order updated', {
          orderId,
          remainingTrips: estimatedTrips,
          totalScheduled: totalScheduledTrips + 1,
          status: estimatedTrips === 0 ? 'fully_scheduled' : 'pending',
        });
      });
    } catch (error) {
      console.error('[Trip Scheduling] Error processing scheduled trip', {
        tripId,
        orderId,
        error,
      });
      throw error;
    }
  },
);

/**
 * When a trip is cancelled (deleted):
 * 1. Delete SCHEDULE_TRIPS document (already deleted by user)
 * 2. Update PENDING_ORDER: Remove from scheduledTrips, decrement totalScheduledTrips, increment estimatedTrips
 *    Note: Order always exists now (not deleted when fully scheduled), so no recreation needed
 */
export const onScheduledTripDeleted = onDocumentDeleted(
  'SCHEDULE_TRIPS/{tripId}',
  async (event) => {
    const tripData = event.data?.data();
    if (!tripData) {
      console.error('[Trip Cancellation] No trip data found');
      return;
    }

    const orderId = tripData.orderId as string;
    const tripId = event.params.tripId;
    const creditTransactionId = tripData.creditTransactionId as string | undefined;

    console.log('[Trip Cancellation] Processing cancelled trip', {tripId, orderId, creditTransactionId});

    try {
      const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);
      
      await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        
        // Order should always exist now (not deleted when fully scheduled)
        // However, if order was deleted, trip is independent and deletion should succeed
        if (!orderDoc.exists) {
          console.log('[Trip Cancellation] Order already deleted - trip is independent', {
            orderId,
            tripId,
          });
          // Trip deletion succeeds - this is correct behavior
          // The trip was independent, so no order update needed
          return;
        }

        // Order exists, update it
        const orderData = orderDoc.data()!;
        const items = (orderData.items as any[]) || [];
        const scheduledTrips = (orderData.scheduledTrips as any[]) || [];
        const totalScheduledTrips = (orderData.totalScheduledTrips as number) || 0;

        // Remove cancelled trip from scheduledTrips array
        const updatedScheduledTrips = scheduledTrips.filter(
          (trip) => trip.tripId !== tripId,
        );

        // Increment estimatedTrips
        if (items.length > 0) {
          const currentEstimatedTrips = (items[0].estimatedTrips as number) || 0;
          items[0].estimatedTrips = currentEstimatedTrips + 1;
        }

        // Update status back to 'pending' if trips are now available
        const newEstimatedTrips = items[0]?.estimatedTrips || 0;
        const updateData: any = {
          scheduledTrips: updatedScheduledTrips,
          totalScheduledTrips: Math.max(0, totalScheduledTrips - 1),
          items,
          updatedAt: new Date(),
        };

        // If estimatedTrips > 0, set status back to 'pending'
        if (newEstimatedTrips > 0) {
          updateData.status = 'pending';
        }

        transaction.update(orderRef, updateData);

        console.log('[Trip Cancellation] Order updated', {
          orderId,
          remainingTrips: newEstimatedTrips,
          totalScheduled: Math.max(0, totalScheduledTrips - 1),
          status: newEstimatedTrips > 0 ? 'pending' : 'fully_scheduled',
        });
      });

      // Cancel credit transaction if it exists
      if (creditTransactionId) {
        try {
          const creditTxnRef = db.collection(TRANSACTIONS_COLLECTION).doc(creditTransactionId);
          const creditTxnDoc = await creditTxnRef.get();
          
          if (creditTxnDoc.exists) {
            const creditTxnData = creditTxnDoc.data();
            const currentStatus = creditTxnData?.status as string;
            
            // Only cancel if not already cancelled
            if (currentStatus !== 'cancelled') {
              await creditTxnRef.update({
                status: 'cancelled',
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                cancelledBy: 'system',
                cancellationReason: 'Trip cancelled',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
              
              console.log('[Trip Cancellation] Credit transaction cancelled', {
                tripId,
                transactionId: creditTransactionId,
              });
            }
          }
        } catch (txnError) {
          console.error('[Trip Cancellation] Error cancelling credit transaction', {
            tripId,
            creditTransactionId,
            error: txnError,
          });
          // Don't throw - transaction cancellation failure shouldn't prevent trip cancellation
        }
      }
    } catch (error) {
      console.error('[Trip Cancellation] Error processing cancelled trip', {
        tripId,
        orderId,
        error,
      });
      throw error;
    }
  },
);

/**
 * When a trip is scheduled, create a credit transaction for pay_later and pay_on_delivery orders
 * This creates the credit entry immediately when the trip is scheduled
 */
// Removed onScheduledTripCreateCredit - Credit transactions are now created after DM generation
// This ensures DM number is available to include in the credit transaction

