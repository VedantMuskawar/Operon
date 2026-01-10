import {onCall} from 'firebase-functions/v2/https';
import {getFirestore} from 'firebase-admin/firestore';
import {PENDING_ORDERS_COLLECTION} from '../shared/constants';

const db = getFirestore();
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';

/**
 * Core logic for checking order and trip data consistency
 * Can be called directly from other functions
 */
export async function checkOrderTripConsistencyCore(orderId: string, organizationId?: string) {
  const orderRef = db.collection(PENDING_ORDERS_COLLECTION).doc(orderId);
  const orderDoc = await orderRef.get();
  
  if (!orderDoc.exists) {
    return {consistent: false, errors: ['Order not found'], fixes: [] as any[], orderId, organizationId};
  }
  
  const orderData = orderDoc.data()!;
  const scheduledTrips = (orderData.scheduledTrips as any[]) || [];
  const errors: string[] = [];
  const fixes: any[] = [];
  
  // Check each trip in scheduledTrips array
  for (const tripRef of scheduledTrips) {
    const tripDoc = await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripRef.tripId).get();
    
    if (!tripDoc.exists) {
      errors.push(`Trip ${tripRef.tripId} in scheduledTrips but trip document doesn't exist`);
      fixes.push({
        type: 'remove_orphaned_trip_ref',
        tripId: tripRef.tripId,
        orderId
      });
      continue;
    }
    
    const tripData = tripDoc.data()!;
    
    // Check orderId matches
    if (tripData.orderId !== orderId) {
      errors.push(`Trip ${tripRef.tripId} has orderId ${tripData.orderId} but expected ${orderId}`);
    }
    
    // Check itemIndex matches
    const tripItemIndex = tripData.itemIndex ?? 0;
    if (tripRef.itemIndex !== undefined && tripRef.itemIndex !== tripItemIndex) {
      errors.push(`Trip ${tripRef.tripId} itemIndex mismatch. Order: ${tripRef.itemIndex}, Trip: ${tripItemIndex}`);
      fixes.push({
        type: 'sync_item_index',
        tripId: tripRef.tripId,
        orderId,
        currentIndex: tripRef.itemIndex,
        correctIndex: tripItemIndex
      });
    }
    
    // Check productId matches
    const tripProductId = tripData.productId || null;
    if (tripRef.productId && tripProductId && tripRef.productId !== tripProductId) {
      errors.push(`Trip ${tripRef.tripId} productId mismatch. Order: ${tripRef.productId}, Trip: ${tripProductId}`);
    }
    
    // Check tripStatus matches
    if (tripRef.tripStatus !== tripData.tripStatus) {
      errors.push(`Trip ${tripRef.tripId} status mismatch. Order: ${tripRef.tripStatus}, Trip: ${tripData.tripStatus}`);
      fixes.push({
        type: 'sync_trip_status',
        tripId: tripRef.tripId,
        orderId,
        currentStatus: tripRef.tripStatus,
        correctStatus: tripData.tripStatus
      });
    }
  }
  
  // Check for orphaned trips (trips with orderId but not in scheduledTrips)
  const orphanedTripsQuery = await db
    .collection(SCHEDULE_TRIPS_COLLECTION)
    .where('orderId', '==', orderId)
    .get();
  
  for (const tripDoc of orphanedTripsQuery.docs) {
    const tripInOrder = scheduledTrips.find((t: any) => t.tripId === tripDoc.id);
    if (!tripInOrder) {
      errors.push(`Trip ${tripDoc.id} has orderId ${orderId} but not in scheduledTrips array`);
      fixes.push({
        type: 'add_missing_trip_ref',
        tripId: tripDoc.id,
        orderId,
        tripData: tripDoc.data()
      });
    }
  }
  
  // Check scheduledTrips count matches totalScheduledTrips
  const totalScheduledTrips = (orderData.totalScheduledTrips as number) || 0;
  if (scheduledTrips.length !== totalScheduledTrips) {
    errors.push(`scheduledTrips.length (${scheduledTrips.length}) != totalScheduledTrips (${totalScheduledTrips})`);
    fixes.push({
      type: 'sync_trip_count',
      orderId,
      currentCount: scheduledTrips.length,
      correctCount: totalScheduledTrips
    });
  }
  
  // Check item-level scheduledTrips counts
  const items = (orderData.items as any[]) || [];
  items.forEach((item: any, index: number) => {
    const itemTrips = scheduledTrips.filter((t: any) => (t.itemIndex ?? 0) === index);
    const itemScheduledTrips = (item.scheduledTrips as number) || 0;
    if (itemScheduledTrips !== itemTrips.length) {
      errors.push(`Item ${index}: scheduledTrips count (${itemScheduledTrips}) != actual trips (${itemTrips.length})`);
      fixes.push({
        type: 'sync_item_trip_count',
        orderId,
        itemIndex: index,
        currentCount: itemScheduledTrips,
        correctCount: itemTrips.length
      });
    }
  });
  
  return {
    consistent: errors.length === 0,
    errors,
    fixes,
    orderId,
    organizationId
  };
}

/**
 * Check order and trip data consistency
 * Ensures scheduledTrips array matches actual trip documents
 */
export const checkOrderTripConsistency = onCall(async (request) => {
  const {orderId, organizationId} = request.data;
  return await checkOrderTripConsistencyCore(orderId, organizationId);
});

