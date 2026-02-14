"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onScheduledTripDeleted = exports.onScheduledTripCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const function_config_1 = require("../shared/function-config");
const trip_scheduling_logic_1 = require("./trip-scheduling-logic");
const check_order_trip_consistency_1 = require("../maintenance/check-order-trip-consistency");
const db = (0, firestore_helpers_1.getFirestore)();
const TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
async function applyOrderTripConsistencyFixes(orderId, fixes) {
    if (fixes.length == 0)
        return;
    const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
    await db.runTransaction(async (transaction) => {
        var _a;
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            return;
        }
        const orderData = orderDoc.data() || {};
        const updateData = {};
        for (const fix of fixes) {
            switch (fix.type) {
                case 'remove_orphaned_trip_ref': {
                    const scheduledTrips = (orderData.scheduledTrips || []).filter((t) => t.tripId !== fix.tripId);
                    updateData.scheduledTrips = scheduledTrips;
                    updateData.totalScheduledTrips = scheduledTrips.length;
                    break;
                }
                case 'sync_trip_status': {
                    const updatedTrips = (orderData.scheduledTrips || []).map((t) => {
                        if (t.tripId === fix.tripId) {
                            return Object.assign(Object.assign({}, t), { tripStatus: fix.correctStatus });
                        }
                        return t;
                    });
                    updateData.scheduledTrips = updatedTrips;
                    break;
                }
                case 'add_missing_trip_ref': {
                    const tripData = fix.tripData || {};
                    const newTripRef = {
                        tripId: fix.tripId,
                        scheduleTripId: tripData.scheduleTripId || null,
                        itemIndex: (_a = tripData.itemIndex) !== null && _a !== void 0 ? _a : 0,
                        productId: tripData.productId || null,
                        scheduledDate: tripData.scheduledDate,
                        scheduledDay: tripData.scheduledDay,
                        vehicleId: tripData.vehicleId,
                        vehicleNumber: tripData.vehicleNumber,
                        slot: tripData.slot,
                        tripStatus: tripData.tripStatus || 'scheduled',
                    };
                    const existingTrips = orderData.scheduledTrips || [];
                    updateData.scheduledTrips = [...existingTrips, newTripRef];
                    updateData.totalScheduledTrips =
                        (orderData.totalScheduledTrips || 0) + 1;
                    break;
                }
                case 'sync_trip_count': {
                    updateData.totalScheduledTrips = fix.correctCount;
                    break;
                }
                case 'sync_item_trip_count': {
                    const items = [...(orderData.items || [])];
                    if (items[fix.itemIndex]) {
                        items[fix.itemIndex].scheduledTrips = fix.correctCount;
                        updateData.items = items;
                    }
                    break;
                }
                case 'sync_item_index': {
                    const tripsWithIndex = (orderData.scheduledTrips || []).map((t) => {
                        if (t.tripId === fix.tripId) {
                            return Object.assign(Object.assign({}, t), { itemIndex: fix.correctIndex });
                        }
                        return t;
                    });
                    updateData.scheduledTrips = tripsWithIndex;
                    break;
                }
                default:
                    break;
            }
        }
        if (Object.keys(updateData).length > 0) {
            const effectiveItems = updateData.items || orderData.items || [];
            updateData.hasAvailableTrips = computeHasAvailableTrips(effectiveItems);
            updateData.updatedAt = new Date();
            transaction.update(orderRef, updateData);
        }
    });
}
// #region agent log
const DEBUG_INGEST = 'http://127.0.0.1:7242/ingest/891e077a-a8b1-43e8-b6e4-f8063ea749ad';
function debugLog(p) {
    fetch(DEBUG_INGEST, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(Object.assign(Object.assign({}, p), { timestamp: Date.now() })) }).catch(() => { });
}
// #endregion
function computeHasAvailableTrips(items) {
    return items.some((item) => {
        if (!item || typeof item !== 'object')
            return false;
        const estimatedTrips = Math.max(0, Math.floor(Number(item.estimatedTrips)) || 0);
        const scheduledTrips = Math.max(0, Math.floor(Number(item.scheduledTrips)) || 0);
        return estimatedTrips > scheduledTrips;
    });
}
/**
 * When a trip is scheduled:
 * 1. Update PENDING_ORDER: Add to scheduledTrips array, increment totalScheduledTrips, decrement estimatedTrips
 * 2. If estimatedTrips becomes 0: Set status to 'fully_scheduled' (don't delete order)
 */
exports.onScheduledTripCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: 'SCHEDULE_TRIPS/{tripId}' }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c;
    const tripData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!tripData) {
        console.error('[Trip Scheduling] No trip data found');
        return;
    }
    // Skip validation for migrated trips
    if (tripData._migrated === true) {
        console.log('[Trip Scheduling] Skipping validation for migrated trip', {
            tripId: event.params.tripId,
            migrationSource: tripData._migrationSource || 'unknown',
        });
        return;
    }
    const orderId = tripData.orderId;
    const tripId = event.params.tripId;
    const tripRef = db.collection(TRIPS_COLLECTION).doc(tripId);
    // #region agent log
    debugLog({ location: 'trip-scheduling.ts:onCreate:entry', message: 'Trip created', data: { tripId, orderId, itemIndex: (_b = tripData.itemIndex) !== null && _b !== void 0 ? _b : 0, productId: tripData.productId || null, itemsInTripData: !!tripData.items }, hypothesisId: 'H2,H5' });
    // #endregion
    console.log('[Trip Scheduling] Processing scheduled trip', { tripId, orderId });
    try {
        // Enforce uniqueness: same date + vehicle + slot should not exist for *active* trips only.
        // Only count scheduled/in_progress trips (match client isSlotAvailable). Ignore cancelled/delivered/returned.
        const scheduledDate = tripData.scheduledDate;
        const vehicleId = tripData.vehicleId;
        const slot = tripData.slot;
        const organizationId = tripData.organizationId;
        if (scheduledDate && vehicleId && slot !== undefined) {
            let scheduledDateValue = null;
            if (typeof scheduledDate.toDate === 'function') {
                scheduledDateValue = scheduledDate.toDate();
            }
            else if (scheduledDate instanceof Date) {
                scheduledDateValue = scheduledDate;
            }
            else if (typeof scheduledDate === 'string' || typeof scheduledDate === 'number') {
                const parsed = new Date(scheduledDate);
                scheduledDateValue = Number.isNaN(parsed.getTime()) ? null : parsed;
            }
            let clashQuery = db
                .collection(TRIPS_COLLECTION)
                .where('vehicleId', '==', vehicleId)
                .where('slot', '==', slot)
                .where('isActive', '==', true);
            if (scheduledDateValue) {
                const startOfDay = new Date(Date.UTC(scheduledDateValue.getUTCFullYear(), scheduledDateValue.getUTCMonth(), scheduledDateValue.getUTCDate()));
                const endOfDay = new Date(Date.UTC(scheduledDateValue.getUTCFullYear(), scheduledDateValue.getUTCMonth(), scheduledDateValue.getUTCDate() + 1));
                clashQuery = clashQuery
                    .where('scheduledDate', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
                    .where('scheduledDate', '<', admin.firestore.Timestamp.fromDate(endOfDay));
            }
            else {
                clashQuery = clashQuery.where('scheduledDate', '==', scheduledDate);
            }
            if (organizationId) {
                clashQuery = clashQuery.where('organizationId', '==', organizationId);
            }
            const clashSnap = await clashQuery.limit(5).get();
            const activeStatuses = ['scheduled', 'in_progress'];
            const otherDocs = clashSnap.docs.filter((d) => {
                if (d.id === tripId)
                    return false;
                const status = d.data().tripStatus || '';
                return activeStatuses.includes(status.toLowerCase());
            });
            if (otherDocs.length > 0) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:slotClash', message: 'Trip deleted: slot already booked', data: { tripId, orderId, vehicleId, slot }, hypothesisId: 'H5' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: slotClash', { tripId, orderId, vehicleId, slot });
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
        const preOrder = await db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId).get();
        if (!preOrder.exists) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:orderNotFound', message: 'Trip deleted: order not found', data: { tripId, orderId }, hypothesisId: 'H5' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: orderNotFound', { tripId, orderId });
            console.warn('[Trip Scheduling] Order not found, deleting trip', { orderId, tripId });
            await tripRef.delete();
            return;
        }
        const preData = preOrder.data() || {};
        const preItems = preData.items || [];
        if (preItems.length === 0) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:noItems', message: 'Trip deleted: order has no items', data: { tripId, orderId }, hypothesisId: 'H5' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: noItems', { tripId, orderId });
            console.warn('[Trip Scheduling] Order has no items, deleting trip', { orderId, tripId });
            await tripRef.delete();
            return;
        }
        // Get itemIndex and productId from trip data (required for multi-product support)
        const itemIndex = (_c = tripData.itemIndex) !== null && _c !== void 0 ? _c : 0;
        const productId = tripData.productId || null;
        // Validate itemIndex
        if (itemIndex < 0 || itemIndex >= preItems.length) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:invalidItemIndex', message: 'Trip deleted: invalid itemIndex', data: { tripId, orderId, itemIndex, itemsLength: preItems.length }, hypothesisId: 'H2' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: invalidItemIndex', { tripId, orderId, itemIndex, itemsLength: preItems.length });
            console.warn('[Trip Scheduling] Invalid itemIndex, deleting trip', {
                orderId,
                tripId,
                itemIndex,
                itemsLength: preItems.length,
            });
            await tripRef.delete();
            return;
        }
        // Get the specific item this trip belongs to
        const preItem = preItems[itemIndex];
        // Number() handles Firestore Long/other numeric types; default 0 if missing/NaN
        let preEstimatedTrips = Math.max(0, Math.floor(Number(preItem.estimatedTrips)) || 0);
        const preScheduledTripsArray = preData.scheduledTrips || [];
        const preScheduledTripsFromOrder = (0, trip_scheduling_logic_1.countScheduledTripsForItem)({
            scheduledTrips: preScheduledTripsArray,
            itemIndex,
            productId,
            fallbackProductId: preItem.productId,
        });
        // Single-trip / legacy: when item reports 0 estimated trips, allow one trip (keeps single-trip orders schedulable)
        if (preEstimatedTrips <= 0) {
            preEstimatedTrips = 1;
        }
        // #region agent log
        debugLog({ location: 'trip-scheduling.ts:preCheck:afterCompat', message: 'Pre-check item state', data: { tripId, orderId, itemIndex, rawEstimated: preItem.estimatedTrips, preScheduledTrips: preScheduledTripsFromOrder, preEstimatedTripsAfterCompat: preEstimatedTrips, preItemProductId: preItem.productId, tripProductId: productId }, hypothesisId: 'H1,H2' });
        // #endregion
        // Validate productId matches if provided
        if (productId && preItem.productId !== productId) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:productIdMismatch', message: 'Trip deleted: productId mismatch', data: { tripId, orderId, productId, itemProductId: preItem.productId }, hypothesisId: 'H2' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: productIdMismatch', { tripId, orderId, tripProductId: productId, itemProductId: preItem.productId });
            console.warn('[Trip Scheduling] ProductId mismatch, deleting trip', {
                orderId,
                tripId,
                tripProductId: productId,
                itemProductId: preItem.productId,
            });
            await tripRef.delete();
            return;
        }
        if (preEstimatedTrips <= 0) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:noTripsRemaining', message: 'Trip deleted: no trips remaining', data: { tripId, orderId, itemIndex, preEstimatedTrips }, hypothesisId: 'H1' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: noTripsRemaining', { tripId, orderId, itemIndex, preEstimatedTrips, rawEstimated: preItem.estimatedTrips });
            console.warn('[Trip Scheduling] No trips remaining to schedule for this item', {
                orderId,
                tripId,
                itemIndex,
                remaining: preEstimatedTrips,
            });
            await tripRef.delete();
            return;
        }
        let allowAllScheduledOverride = false;
        let actualScheduledTripsCount = null;
        try {
            let actualTripsQuery = db
                .collection(TRIPS_COLLECTION)
                .where('orderId', '==', orderId)
                .where('isActive', '==', true)
                .where('tripStatus', 'in', ['scheduled', 'in_progress']);
            if (productId) {
                actualTripsQuery = actualTripsQuery.where('productId', '==', productId);
            }
            if (itemIndex !== undefined && itemIndex !== null) {
                actualTripsQuery = actualTripsQuery.where('itemIndex', '==', itemIndex);
            }
            const actualTripsSnap = await actualTripsQuery.get();
            actualScheduledTripsCount = actualTripsSnap.docs.filter((doc) => doc.id !== tripId).length;
            if (actualScheduledTripsCount < preEstimatedTrips) {
                allowAllScheduledOverride = true;
                console.warn('[Trip Scheduling] Override allScheduled based on actual trips', {
                    orderId,
                    tripId,
                    itemIndex,
                    productId,
                    preScheduledTripsFromOrder,
                    preEstimatedTrips,
                    actualScheduledTripsCount,
                });
            }
        }
        catch (overrideError) {
            console.error('[Trip Scheduling] Failed to verify actual scheduled trips', {
                orderId,
                tripId,
                itemIndex,
                productId,
                error: overrideError,
            });
        }
        if (actualScheduledTripsCount !== null &&
            actualScheduledTripsCount !== preScheduledTripsFromOrder) {
            console.warn('[Trip Scheduling] Mismatch detected; attempting auto-repair', {
                orderId,
                tripId,
                itemIndex,
                productId,
                preScheduledTripsFromOrder,
                actualScheduledTripsCount,
            });
            try {
                const consistency = await (0, check_order_trip_consistency_1.checkOrderTripConsistencyCore)(orderId, organizationId);
                if (!consistency.consistent && consistency.fixes.length > 0) {
                    await applyOrderTripConsistencyFixes(orderId, consistency.fixes);
                    console.warn('[Trip Scheduling] Auto-repair applied', {
                        orderId,
                        tripId,
                        fixesApplied: consistency.fixes.length,
                    });
                }
            }
            catch (repairError) {
                console.error('[Trip Scheduling] Auto-repair failed', {
                    orderId,
                    tripId,
                    error: repairError,
                });
            }
        }
        const effectivePreScheduledTrips = actualScheduledTripsCount !== null && actualScheduledTripsCount !== void 0 ? actualScheduledTripsCount : preScheduledTripsFromOrder;
        if (effectivePreScheduledTrips >= preEstimatedTrips && !allowAllScheduledOverride) {
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:preCheck:allScheduled', message: 'Trip deleted: all trips already scheduled', data: { tripId, orderId, itemIndex, preScheduledTripsFromOrder, actualScheduledTripsCount, preEstimatedTrips }, hypothesisId: 'H1' });
            // #endregion
            console.warn('[Trip Scheduling] DELETE_REASON: allScheduled', { tripId, orderId, itemIndex, preScheduledTripsFromOrder, actualScheduledTripsCount, preEstimatedTrips });
            console.warn('[Trip Scheduling] All trips already scheduled for this item', {
                orderId,
                tripId,
                itemIndex,
                scheduledTrips: effectivePreScheduledTrips,
                estimatedTrips: preEstimatedTrips,
            });
            await tripRef.delete();
            return;
        }
        const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
        await db.runTransaction(async (transaction) => {
            var _a, _b, _c;
            const orderDoc = await transaction.get(orderRef);
            if (!orderDoc.exists) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:orderNotFound', message: 'Transaction: order not found, skipping update', data: { orderId, tripId }, hypothesisId: 'H3' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnOrderNotFound', { orderId, tripId });
                console.warn('[Trip Scheduling] Order not found', { orderId });
                return;
            }
            const orderData = orderDoc.data();
            const items = orderData.items || [];
            if (items.length === 0) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:noItems', message: 'Transaction: no items, deleting trip', data: { orderId, tripId }, hypothesisId: 'H3' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnNoItems', { orderId, tripId });
                console.error('[Trip Scheduling] Order has no items', { orderId });
                transaction.delete(tripRef);
                return;
            }
            // Get itemIndex and productId from trip data (required for multi-product support)
            const itemIndex = (_a = tripData.itemIndex) !== null && _a !== void 0 ? _a : 0;
            const productId = tripData.productId || ((_b = items[itemIndex]) === null || _b === void 0 ? void 0 : _b.productId) || null;
            // Validate itemIndex
            if (itemIndex < 0 || itemIndex >= items.length) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:invalidItemIndex', message: 'Transaction: invalid itemIndex, deleting trip', data: { orderId, tripId, itemIndex, itemsLength: items.length }, hypothesisId: 'H2' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnInvalidItemIndex', { orderId, tripId, itemIndex, itemsLength: items.length });
                console.error('[Trip Scheduling] Invalid itemIndex', {
                    orderId,
                    tripId,
                    itemIndex,
                    itemsLength: items.length,
                });
                transaction.delete(tripRef);
                return;
            }
            // Get the specific item this trip belongs to
            const targetItem = items[itemIndex];
            if (!targetItem) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:itemNotFound', message: 'Transaction: item not found at index, deleting trip', data: { orderId, tripId, itemIndex }, hypothesisId: 'H2' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnItemNotFound', { orderId, tripId, itemIndex });
                console.error('[Trip Scheduling] Item not found at index', { orderId, tripId, itemIndex });
                transaction.delete(tripRef);
                return;
            }
            // Validate productId matches if provided
            if (productId && targetItem.productId !== productId) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:productIdMismatch', message: 'Transaction: productId mismatch, deleting trip', data: { orderId, tripId, productId, itemProductId: targetItem.productId }, hypothesisId: 'H2' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnProductIdMismatch', { orderId, tripId, productId, itemProductId: targetItem.productId });
                console.error('[Trip Scheduling] ProductId mismatch', {
                    orderId,
                    tripId,
                    itemIndex,
                    tripProductId: productId,
                    itemProductId: targetItem.productId,
                });
                transaction.delete(tripRef);
                return;
            }
            let estimatedTrips = Math.max(0, Math.floor(Number(targetItem.estimatedTrips)) || 0);
            const scheduledTripsArrayForUpdate = orderData.scheduledTrips || [];
            const alreadyLinked = scheduledTripsArrayForUpdate.some((trip) => (trip === null || trip === void 0 ? void 0 : trip.tripId) === tripId);
            if (alreadyLinked) {
                console.log('[Trip Scheduling] Trip already linked to order, skipping update', {
                    orderId,
                    tripId,
                });
                return;
            }
            let scheduledTrips = (0, trip_scheduling_logic_1.countScheduledTripsForItem)({
                scheduledTrips: scheduledTripsArrayForUpdate,
                itemIndex,
                productId,
                fallbackProductId: targetItem.productId,
            });
            if (allowAllScheduledOverride && scheduledTrips >= estimatedTrips) {
                // Auto-correct when order counters are stale but actual trips allow scheduling.
                estimatedTrips = scheduledTrips + 1;
            }
            // Single-trip / legacy: when item reports 0 estimated trips, allow one trip
            if (estimatedTrips <= 0) {
                estimatedTrips = 1;
            }
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:txn:afterCompat', message: 'Transaction: item state after compat', data: { tripId, orderId, itemIndex, rawEstimated: targetItem.estimatedTrips, estimatedTrips, scheduledTrips }, hypothesisId: 'H1' });
            // #endregion
            if (estimatedTrips <= 0) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:noTripsRemaining', message: 'Transaction: no trips remaining, deleting trip', data: { tripId, orderId, itemIndex, estimatedTrips }, hypothesisId: 'H1' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnNoTripsRemaining', { tripId, orderId, itemIndex, estimatedTrips, rawEstimated: targetItem.estimatedTrips });
                console.warn('[Trip Scheduling] No trips remaining to schedule for this item', {
                    orderId,
                    tripId,
                    itemIndex,
                    productId,
                });
                transaction.delete(tripRef);
                return;
            }
            if (scheduledTrips >= estimatedTrips && !allowAllScheduledOverride) {
                // #region agent log
                debugLog({ location: 'trip-scheduling.ts:txn:allScheduled', message: 'Transaction: all scheduled, deleting trip', data: { tripId, orderId, itemIndex, scheduledTrips, estimatedTrips }, hypothesisId: 'H1' });
                // #endregion
                console.warn('[Trip Scheduling] DELETE_REASON: txnAllScheduled', { tripId, orderId, itemIndex, scheduledTrips, estimatedTrips });
                console.warn('[Trip Scheduling] All trips already scheduled for this item', {
                    orderId,
                    tripId,
                    itemIndex,
                    productId,
                    scheduledTrips,
                    estimatedTrips,
                });
                transaction.delete(tripRef);
                return;
            }
            // Prepare trip entry for scheduledTrips array
            // IMPORTANT: Firestore doesn't allow null values, so we only include fields if they have values
            const tripEntry = {
                tripId,
                itemIndex: itemIndex, // ✅ Store which item this trip belongs to
                productId: productId || targetItem.productId, // ✅ Store product reference
                scheduledDate: tripData.scheduledDate,
                scheduledDay: tripData.scheduledDay || '',
                vehicleId: tripData.vehicleId,
                vehicleNumber: tripData.vehicleNumber,
                slot: tripData.slot,
                slotName: tripData.slotName || '',
                customerNumber: tripData.customerNumber,
                paymentType: tripData.paymentType,
                tripStatus: 'scheduled',
                scheduledAt: tripData.createdAt,
                scheduledBy: tripData.createdBy,
            };
            // Only include optional fields if they have non-null values
            if (tripData.scheduleTripId) {
                tripEntry.scheduleTripId = tripData.scheduleTripId;
            }
            if (tripData.driverName) {
                tripEntry.driverName = tripData.driverName;
            }
            if (tripData.driverId) {
                tripEntry.driverId = tripData.driverId;
            }
            if (tripData.driverPhone) {
                tripEntry.driverPhone = tripData.driverPhone;
            }
            const totalScheduledTrips = orderData.totalScheduledTrips || 0;
            // Clean items array to remove any null values before updating
            const cleanedItems = items.map((item) => {
                if (!item || typeof item !== 'object')
                    return item;
                const cleaned = {};
                for (const [key, value] of Object.entries(item)) {
                    if (value !== null && value !== undefined) {
                        cleaned[key] = value;
                    }
                }
                return cleaned;
            });
            // Update order
            const updateData = {
                scheduledTrips: [...scheduledTripsArrayForUpdate, tripEntry],
                totalScheduledTrips: totalScheduledTrips + 1,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            // Update item-level trip counts
            estimatedTrips -= 1;
            scheduledTrips += 1;
            targetItem.estimatedTrips = estimatedTrips;
            targetItem.scheduledTrips = scheduledTrips;
            // Clean the target item to remove nulls
            const cleanedTargetItem = {};
            for (const [key, value] of Object.entries(targetItem)) {
                if (value !== null && value !== undefined) {
                    cleanedTargetItem[key] = value;
                }
            }
            cleanedItems[itemIndex] = cleanedTargetItem;
            updateData.items = cleanedItems;
            // Check if all items are fully scheduled
            const allItemsFullyScheduled = items.every((item) => {
                const itemEstimatedTrips = item.estimatedTrips || 0;
                return itemEstimatedTrips === 0;
            });
            // If all items are fully scheduled, set status to 'fully_scheduled'
            if (allItemsFullyScheduled) {
                updateData.status = 'fully_scheduled';
                console.log('[Trip Scheduling] All trips scheduled for all items, marking order as fully_scheduled', {
                    orderId,
                    itemIndex,
                    productId,
                });
            }
            else {
                // Ensure status is 'pending' if trips remain
                updateData.status = 'pending';
            }
            updateData.hasAvailableTrips = computeHasAvailableTrips(cleanedItems);
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:txn:beforeUpdate', message: 'Transaction: about to update order', data: { tripId, orderId, updateDataKeys: Object.keys(updateData), allItemsFullyScheduled, scheduledTripsArrayLen: (_c = updateData.scheduledTrips) === null || _c === void 0 ? void 0 : _c.length, totalScheduledTrips: updateData.totalScheduledTrips }, hypothesisId: 'H3' });
            // #endregion
            transaction.update(orderRef, updateData);
            console.log('[Trip Scheduling] Order updated', {
                orderId,
                tripId,
                itemIndex,
                productId: productId || targetItem.productId,
                remainingTrips: estimatedTrips,
                scheduledTrips: scheduledTrips,
                totalScheduled: totalScheduledTrips + 1,
                status: allItemsFullyScheduled ? 'fully_scheduled' : 'pending',
            });
        });
    }
    catch (error) {
        // #region agent log
        debugLog({ location: 'trip-scheduling.ts:onCreate:catch', message: 'Trip scheduling threw', data: { tripId, orderId, error: String(error) }, hypothesisId: 'H3' });
        // #endregion
        console.error('[Trip Scheduling] Error processing scheduled trip', {
            tripId,
            orderId,
            error,
        });
        throw error;
    }
});
/**
 * When a trip is cancelled (deleted):
 * 1. Delete SCHEDULE_TRIPS document (already deleted by user)
 * 2. Update PENDING_ORDER: Remove from scheduledTrips, decrement totalScheduledTrips, increment estimatedTrips
 *    Note: Order always exists now (not deleted when fully scheduled), so no recreation needed
 */
exports.onScheduledTripDeleted = (0, firestore_1.onDocumentDeleted)(Object.assign({ document: 'SCHEDULE_TRIPS/{tripId}' }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a;
    const tripData = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!tripData) {
        console.error('[Trip Cancellation] No trip data found');
        return;
    }
    const orderId = tripData.orderId;
    const tripId = event.params.tripId;
    const creditTransactionId = tripData.creditTransactionId;
    console.log('[Trip Cancellation] Processing cancelled trip', { tripId, orderId, creditTransactionId });
    try {
        const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
        await db.runTransaction(async (transaction) => {
            var _a;
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
            const orderData = orderDoc.data();
            const items = orderData.items || [];
            const scheduledTrips = orderData.scheduledTrips || [];
            const totalScheduledTrips = orderData.totalScheduledTrips || 0;
            // Find the trip being deleted to get its itemIndex
            const deletedTrip = scheduledTrips.find((trip) => trip.tripId === tripId);
            // #region agent log
            debugLog({ location: 'trip-scheduling.ts:onDelete:deletedTrip', message: 'Trip deleted handler', data: { tripId, orderId, deletedTripFound: !!deletedTrip, scheduledTripsLen: scheduledTrips.length }, hypothesisId: 'H4' });
            // #endregion
            // If trip was never in scheduledTrips, it was deleted by validation in onScheduledTripCreated
            // (e.g. slot clash, order not found). Do NOT update order - would incorrectly increment estimatedTrips.
            if (!deletedTrip) {
                console.log('[Trip Cancellation] Trip was never in scheduledTrips (deleted by validation), skipping order update', {
                    tripId,
                    orderId,
                });
                return;
            }
            const itemIndex = (_a = deletedTrip.itemIndex) !== null && _a !== void 0 ? _a : 0;
            const productId = deletedTrip.productId || null;
            // Remove cancelled trip from scheduledTrips array
            const updatedScheduledTrips = scheduledTrips.filter((trip) => trip.tripId !== tripId);
            // Update item-level trip counts
            if (items.length > 0 && itemIndex >= 0 && itemIndex < items.length) {
                const targetItem = items[itemIndex];
                if (targetItem) {
                    // Validate productId if provided
                    if (productId && targetItem.productId !== productId) {
                        console.warn('[Trip Cancellation] ProductId mismatch, using itemIndex', {
                            orderId,
                            tripId,
                            itemIndex,
                            tripProductId: productId,
                            itemProductId: targetItem.productId,
                        });
                    }
                    const currentEstimatedTrips = targetItem.estimatedTrips || 0;
                    const currentScheduledTrips = targetItem.scheduledTrips || 0;
                    targetItem.estimatedTrips = currentEstimatedTrips + 1;
                    targetItem.scheduledTrips = Math.max(0, currentScheduledTrips - 1);
                }
            }
            else if (items.length > 0) {
                // Fallback to first item for backward compatibility
                const currentEstimatedTrips = items[0].estimatedTrips || 0;
                const currentScheduledTrips = items[0].scheduledTrips || 0;
                items[0].estimatedTrips = currentEstimatedTrips + 1;
                items[0].scheduledTrips = Math.max(0, currentScheduledTrips - 1);
            }
            // Check if any item has remaining trips
            const hasRemainingTrips = items.some((item) => {
                const itemEstimatedTrips = item.estimatedTrips || 0;
                return itemEstimatedTrips > 0;
            });
            const updateData = {
                scheduledTrips: updatedScheduledTrips,
                totalScheduledTrips: Math.max(0, totalScheduledTrips - 1),
                items,
                updatedAt: new Date(),
            };
            // If any item has remaining trips, set status back to 'pending'
            if (hasRemainingTrips) {
                updateData.status = 'pending';
            }
            updateData.hasAvailableTrips = computeHasAvailableTrips(items);
            transaction.update(orderRef, updateData);
            const targetItem = items[itemIndex] || items[0];
            const newEstimatedTrips = (targetItem === null || targetItem === void 0 ? void 0 : targetItem.estimatedTrips) || 0;
            console.log('[Trip Cancellation] Order updated', {
                orderId,
                tripId,
                itemIndex,
                productId: productId || (targetItem === null || targetItem === void 0 ? void 0 : targetItem.productId),
                remainingTrips: newEstimatedTrips,
                scheduledTrips: (targetItem === null || targetItem === void 0 ? void 0 : targetItem.scheduledTrips) || 0,
                totalScheduled: Math.max(0, totalScheduledTrips - 1),
                status: hasRemainingTrips ? 'pending' : 'fully_scheduled',
            });
        });
        // Cancel credit transaction if it exists
        if (creditTransactionId) {
            try {
                const creditTxnRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc(creditTransactionId);
                const creditTxnDoc = await creditTxnRef.get();
                if (creditTxnDoc.exists) {
                    const creditTxnData = creditTxnDoc.data();
                    const currentStatus = creditTxnData === null || creditTxnData === void 0 ? void 0 : creditTxnData.status;
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
            }
            catch (txnError) {
                console.error('[Trip Cancellation] Error cancelling credit transaction', {
                    tripId,
                    creditTransactionId,
                    error: txnError,
                });
                // Don't throw - transaction cancellation failure shouldn't prevent trip cancellation
            }
        }
    }
    catch (error) {
        console.error('[Trip Cancellation] Error processing cancelled trip', {
            tripId,
            orderId,
            error,
        });
        throw error;
    }
});
/**
 * When a trip is scheduled, create a credit transaction for pay_later and pay_on_delivery orders
 * This creates the credit entry immediately when the trip is scheduled
 */
// Removed onScheduledTripCreateCredit - Credit transactions are now created after DM generation
// This ensures DM number is available to include in the credit transaction
//# sourceMappingURL=trip-scheduling.js.map