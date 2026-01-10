"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkOrderTripConsistency = void 0;
exports.checkOrderTripConsistencyCore = checkOrderTripConsistencyCore;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const constants_1 = require("../shared/constants");
const db = (0, firestore_1.getFirestore)();
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * Core logic for checking order and trip data consistency
 * Can be called directly from other functions
 */
async function checkOrderTripConsistencyCore(orderId, organizationId) {
    var _a;
    const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        return { consistent: false, errors: ['Order not found'], fixes: [], orderId, organizationId };
    }
    const orderData = orderDoc.data();
    const scheduledTrips = orderData.scheduledTrips || [];
    const errors = [];
    const fixes = [];
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
        const tripData = tripDoc.data();
        // Check orderId matches
        if (tripData.orderId !== orderId) {
            errors.push(`Trip ${tripRef.tripId} has orderId ${tripData.orderId} but expected ${orderId}`);
        }
        // Check itemIndex matches
        const tripItemIndex = (_a = tripData.itemIndex) !== null && _a !== void 0 ? _a : 0;
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
        const tripInOrder = scheduledTrips.find((t) => t.tripId === tripDoc.id);
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
    const totalScheduledTrips = orderData.totalScheduledTrips || 0;
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
    const items = orderData.items || [];
    items.forEach((item, index) => {
        const itemTrips = scheduledTrips.filter((t) => { var _a; return ((_a = t.itemIndex) !== null && _a !== void 0 ? _a : 0) === index; });
        const itemScheduledTrips = item.scheduledTrips || 0;
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
exports.checkOrderTripConsistency = (0, https_1.onCall)(async (request) => {
    const { orderId, organizationId } = request.data;
    return await checkOrderTripConsistencyCore(orderId, organizationId);
});
//# sourceMappingURL=check-order-trip-consistency.js.map