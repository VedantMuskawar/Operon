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
const firestore_2 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const db = (0, firestore_2.getFirestore)();
const TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
// Function configuration for v2 functions
// TEMPORARY: Using us-central1 to avoid Eventarc service identity errors in asia-south1
// TODO: Switch back to 'asia-south1' after enabling Eventarc API and setting IAM permissions
// See functions/DEPLOYMENT_FIX.md for details
const functionOptions = {
    region: 'us-central1', // Temporary: Changed from asia-south1 to avoid Eventarc issues
    timeoutSeconds: 60,
    maxInstances: 10,
};
/**
 * When a trip is scheduled:
 * 1. Update PENDING_ORDER: Add to scheduledTrips array, increment totalScheduledTrips, decrement estimatedTrips
 * 2. If estimatedTrips becomes 0: Set status to 'fully_scheduled' (don't delete order)
 */
exports.onScheduledTripCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: 'SCHEDULE_TRIPS/{tripId}' }, functionOptions), async (event) => {
    var _a, _b;
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
    console.log('[Trip Scheduling] Processing scheduled trip', { tripId, orderId });
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
        const preOrder = await db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId).get();
        if (!preOrder.exists) {
            console.warn('[Trip Scheduling] Order not found, deleting trip', { orderId, tripId });
            await tripRef.delete();
            return;
        }
        const preData = preOrder.data() || {};
        const preItems = preData.items || [];
        if (preItems.length === 0) {
            console.warn('[Trip Scheduling] Order has no items, deleting trip', { orderId, tripId });
            await tripRef.delete();
            return;
        }
        // Get itemIndex and productId from trip data (required for multi-product support)
        const itemIndex = (_b = tripData.itemIndex) !== null && _b !== void 0 ? _b : 0;
        const productId = tripData.productId || null;
        // Validate itemIndex
        if (itemIndex < 0 || itemIndex >= preItems.length) {
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
        const preEstimatedTrips = preItem.estimatedTrips || 0;
        const preScheduledTrips = preItem.scheduledTrips || 0;
        // Validate productId matches if provided
        if (productId && preItem.productId !== productId) {
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
            console.warn('[Trip Scheduling] No trips remaining to schedule for this item', {
                orderId,
                tripId,
                itemIndex,
                remaining: preEstimatedTrips,
            });
            await tripRef.delete();
            return;
        }
        if (preScheduledTrips >= preEstimatedTrips) {
            console.warn('[Trip Scheduling] All trips already scheduled for this item', {
                orderId,
                tripId,
                itemIndex,
                scheduledTrips: preScheduledTrips,
                estimatedTrips: preEstimatedTrips,
            });
            await tripRef.delete();
            return;
        }
        const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
        await db.runTransaction(async (transaction) => {
            var _a, _b;
            const orderDoc = await transaction.get(orderRef);
            if (!orderDoc.exists) {
                console.warn('[Trip Scheduling] Order not found', { orderId });
                return;
            }
            const orderData = orderDoc.data();
            const items = orderData.items || [];
            if (items.length === 0) {
                console.error('[Trip Scheduling] Order has no items', { orderId });
                transaction.delete(tripRef);
                return;
            }
            // Get itemIndex and productId from trip data (required for multi-product support)
            const itemIndex = (_a = tripData.itemIndex) !== null && _a !== void 0 ? _a : 0;
            const productId = tripData.productId || ((_b = items[itemIndex]) === null || _b === void 0 ? void 0 : _b.productId) || null;
            // Validate itemIndex
            if (itemIndex < 0 || itemIndex >= items.length) {
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
                console.error('[Trip Scheduling] Item not found at index', { orderId, tripId, itemIndex });
                transaction.delete(tripRef);
                return;
            }
            // Validate productId matches if provided
            if (productId && targetItem.productId !== productId) {
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
            let estimatedTrips = targetItem.estimatedTrips || 0;
            let scheduledTrips = targetItem.scheduledTrips || 0;
            if (estimatedTrips <= 0) {
                console.warn('[Trip Scheduling] No trips remaining to schedule for this item', {
                    orderId,
                    tripId,
                    itemIndex,
                    productId,
                });
                transaction.delete(tripRef);
                return;
            }
            if (scheduledTrips >= estimatedTrips) {
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
            // Get existing scheduledTrips array
            const scheduledTripsArray = orderData.scheduledTrips || [];
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
                scheduledTrips: [...scheduledTripsArray, tripEntry],
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
exports.onScheduledTripDeleted = (0, firestore_1.onDocumentDeleted)(Object.assign({ document: 'SCHEDULE_TRIPS/{tripId}' }, functionOptions), async (event) => {
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
            const itemIndex = (_a = deletedTrip === null || deletedTrip === void 0 ? void 0 : deletedTrip.itemIndex) !== null && _a !== void 0 ? _a : 0;
            const productId = (deletedTrip === null || deletedTrip === void 0 ? void 0 : deletedTrip.productId) || null;
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