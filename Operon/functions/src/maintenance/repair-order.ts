import {onCall} from 'firebase-functions/v2/https';
import {getFirestore} from 'firebase-admin/firestore';
import {PENDING_ORDERS_COLLECTION} from '../shared/constants';
import {checkOrderTripConsistencyCore} from './check-order-trip-consistency';

const db = getFirestore();

/**
 * Repair order data inconsistencies
 * Automatically fixes common data issues
 */
export const repairOrder = onCall(async (request) => {
  const {orderId, organizationId, autoFix = false} = request.data;
  
  // First, check consistency
  const consistencyCheck = await checkOrderTripConsistencyCore(orderId, organizationId);
  
  if (consistencyCheck.consistent) {
    return {repaired: false, message: 'Order is already consistent'};
  }
  
  if (!autoFix) {
    return {
      needsRepair: true,
      fixes: consistencyCheck.fixes,
      message: 'Run with autoFix=true to apply fixes'
    };
  }
  
  const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);
  const fixesApplied: string[] = [];
  
  await db.runTransaction(async (transaction) => {
    const orderDoc = await transaction.get(orderRef);
    if (!orderDoc.exists) {
      throw new Error('Order not found');
    }
    
    const orderData = orderDoc.data()!;
    const updateData: any = {};
    
    // Apply fixes
    for (const fix of consistencyCheck.fixes) {
      switch (fix.type) {
        case 'remove_orphaned_trip_ref':
          // Remove trip reference from scheduledTrips array
          const scheduledTrips = ((orderData.scheduledTrips as any[]) || []).filter(
            (t: any) => t.tripId !== fix.tripId
          );
          updateData.scheduledTrips = scheduledTrips;
          updateData.totalScheduledTrips = scheduledTrips.length;
          fixesApplied.push(`Removed orphaned trip reference: ${fix.tripId}`);
          break;
          
        case 'sync_trip_status':
          // Update trip status in scheduledTrips array
          const updatedTrips = ((orderData.scheduledTrips as any[]) || []).map((t: any) => {
            if (t.tripId === fix.tripId) {
              return {...t, tripStatus: fix.correctStatus};
            }
            return t;
          });
          updateData.scheduledTrips = updatedTrips;
          fixesApplied.push(`Synced trip status: ${fix.tripId}`);
          break;
          
        case 'add_missing_trip_ref':
          // Add missing trip to scheduledTrips array
          const tripData = fix.tripData;
          const newTripRef = {
            tripId: fix.tripId,
            scheduleTripId: tripData.scheduleTripId || null,
            itemIndex: tripData.itemIndex ?? 0,
            productId: tripData.productId || null,
            scheduledDate: tripData.scheduledDate,
            scheduledDay: tripData.scheduledDay,
            vehicleId: tripData.vehicleId,
            vehicleNumber: tripData.vehicleNumber,
            slot: tripData.slot,
            tripStatus: tripData.tripStatus || 'scheduled'
          };
          const existingTrips = (orderData.scheduledTrips as any[]) || [];
          updateData.scheduledTrips = [...existingTrips, newTripRef];
          updateData.totalScheduledTrips = (orderData.totalScheduledTrips as number || 0) + 1;
          fixesApplied.push(`Added missing trip reference: ${fix.tripId}`);
          break;
          
        case 'sync_trip_count':
          // Sync totalScheduledTrips with array length
          updateData.totalScheduledTrips = fix.correctCount;
          fixesApplied.push(`Synced trip count: ${fix.correctCount}`);
          break;
          
        case 'sync_item_trip_count':
          // Sync item-level scheduledTrips count
          const items = [...((orderData.items as any[]) || [])];
          if (items[fix.itemIndex]) {
            items[fix.itemIndex].scheduledTrips = fix.correctCount;
            updateData.items = items;
            fixesApplied.push(`Synced item ${fix.itemIndex} trip count: ${fix.correctCount}`);
          }
          break;
          
        case 'sync_item_index':
          // Sync itemIndex in scheduledTrips array
          const tripsWithIndex = ((orderData.scheduledTrips as any[]) || []).map((t: any) => {
            if (t.tripId === fix.tripId) {
              return {...t, itemIndex: fix.correctIndex};
            }
            return t;
          });
          updateData.scheduledTrips = tripsWithIndex;
          fixesApplied.push(`Synced itemIndex for trip: ${fix.tripId}`);
          break;
      }
    }
    
    if (Object.keys(updateData).length > 0) {
      updateData.updatedAt = new Date();
      transaction.update(orderRef, updateData);
    }
  });
  
  return {
    repaired: true,
    fixesApplied,
    orderId,
    organizationId
  };
});

