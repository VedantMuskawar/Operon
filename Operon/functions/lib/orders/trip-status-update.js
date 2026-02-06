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
exports.onTripStatusUpdated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * When a trip's tripStatus is updated:
 * Update the corresponding trip entry in PENDING_ORDERS.scheduledTrips array
 */
exports.onTripStatusUpdated = (0, firestore_1.onDocumentUpdated)(Object.assign({ document: `${SCHEDULED_TRIPS_COLLECTION}/{tripId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c;
    const tripId = event.params.tripId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after) {
        console.error('[Trip Status Update] No trip data found', { tripId });
        return;
    }
    const beforeStatus = before.tripStatus;
    const afterStatus = after.tripStatus;
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
            if ((_c = event.data) === null || _c === void 0 ? void 0 : _c.after) {
                await event.data.after.ref.update({
                    tripStatus: beforeStatus || 'scheduled',
                    orderStatus: beforeStatus || 'scheduled',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            throw new Error('DM must be generated before dispatching trip');
        }
    }
    const orderId = after.orderId;
    if (!orderId) {
        console.error('[Trip Status Update] No orderId found in trip', { tripId });
        return;
    }
    console.log('[Trip Status Update] Processing trip status change', {
        tripId,
        orderId,
        beforeStatus,
        afterStatus,
    });
    try {
        const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
        await db.runTransaction(async (transaction) => {
            var _a;
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
            const orderData = orderDoc.data();
            // Check if order is cancelled - trip can still continue independently
            const orderStatus = orderData.status || 'pending';
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
            const scheduledTrips = orderData.scheduledTrips || [];
            // Get itemIndex and productId from trip data
            const tripItemIndex = (_a = after.itemIndex) !== null && _a !== void 0 ? _a : 0;
            const tripProductId = after.productId || null;
            // Find and update the trip in the scheduledTrips array
            const updatedScheduledTrips = scheduledTrips.map((trip) => {
                if (trip.tripId === tripId) {
                    return Object.assign(Object.assign(Object.assign(Object.assign(Object.assign(Object.assign(Object.assign(Object.assign({}, trip), { itemIndex: tripItemIndex, productId: tripProductId || trip.productId || null, tripStatus: afterStatus }), (afterStatus === 'dispatched' && {
                        dispatchedAt: after.dispatchedAt || null,
                        initialReading: after.initialReading || null,
                        dispatchedBy: after.dispatchedBy || null,
                        dispatchedByRole: after.dispatchedByRole || null,
                    })), (afterStatus === 'delivered' && {
                        deliveredAt: after.deliveredAt || null,
                        deliveryPhotoUrl: after.deliveryPhotoUrl || null,
                        deliveredBy: after.deliveredBy || null,
                        deliveredByRole: after.deliveredByRole || null,
                    })), (afterStatus === 'returned' && {
                        returnedAt: after.returnedAt || null,
                        finalReading: after.finalReading || null,
                        returnedBy: after.returnedBy || null,
                        returnedByRole: after.returnedByRole || null,
                        paymentDetails: after.paymentDetails || null,
                    })), (afterStatus !== 'dispatched' && {
                        dispatchedAt: null,
                        initialReading: null,
                        dispatchedBy: null,
                        dispatchedByRole: null,
                    })), (afterStatus !== 'delivered' && {
                        deliveredAt: null,
                        deliveryPhotoUrl: null,
                        deliveredBy: null,
                        deliveredByRole: null,
                    })), (afterStatus !== 'returned' && {
                        returnedAt: null,
                        finalReading: null,
                        returnedBy: null,
                        returnedByRole: null,
                        paymentDetails: null,
                    }));
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
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:181', message: 'Checking status for DM update', data: { tripId, afterStatus, beforeStatus, isReturned: afterStatus === 'returned' }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
        // #endregion
        // If status is delivered, update DELIVERY_MEMO document
        if (afterStatus === 'delivered') {
            await _updateDeliveryMemo(tripId, after);
        }
        else if (beforeStatus === 'delivered' && afterStatus !== 'delivered') {
            // If status changed FROM delivered to something else (e.g., dispatched or returned), revert DELIVERY_MEMO
            await _revertDeliveryMemo(tripId);
        }
        // If status is returned, update DELIVERY_MEMO document with tripStatus
        // #region agent log
        console.log('[DEBUG] Checking if status is returned for DM update', { tripId, afterStatus, isReturned: afterStatus === 'returned', hypothesisId: 'A' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:189', message: 'Returned status check', data: { tripId, afterStatus, isReturned: afterStatus === 'returned' }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
        // #endregion
        if (afterStatus === 'returned') {
            await _updateDeliveryMemoForReturn(tripId, after);
        }
        else if (beforeStatus === 'returned' && afterStatus !== 'returned') {
            // If status changed FROM returned to something else, revert return fields in DELIVERY_MEMO
            await _revertDeliveryMemoReturn(tripId);
        }
        // If status changed FROM dispatched to something else (e.g., scheduled), cancel credit transaction
        if (beforeStatus === 'dispatched' && afterStatus !== 'dispatched') {
            const creditTransactionId = after.creditTransactionId;
            if (creditTransactionId) {
                await _cancelCreditTransaction(tripId, creditTransactionId);
            }
        }
    }
    catch (error) {
        console.error('[Trip Status Update] Error updating order', {
            tripId,
            orderId,
            error,
        });
        throw error;
    }
});
const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';
async function _updateDeliveryMemo(tripId, tripData) {
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
        const updateData = {
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
    }
    catch (error) {
        console.error('[Trip Status Update] Error updating delivery memo', {
            tripId,
            error,
        });
        // Don't throw - delivery memo update failure shouldn't block trip status update
    }
}
async function _revertDeliveryMemo(tripId) {
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
        const updateData = {
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
    }
    catch (error) {
        console.error('[Trip Status Update] Error reverting delivery memo', {
            tripId,
            error,
        });
        // Don't throw - delivery memo update failure shouldn't block trip status update
    }
}
async function _updateDeliveryMemoForReturn(tripId, tripData) {
    var _a, _b, _c, _d, _e, _f;
    try {
        // #region agent log
        console.log('[DEBUG] _updateDeliveryMemoForReturn called', { tripId, tripStatus: tripData.tripStatus, hypothesisId: 'A' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:314', message: '_updateDeliveryMemoForReturn called', data: { tripId, tripStatus: tripData.tripStatus }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
        // #endregion
        // Find DELIVERY_MEMO document by tripId
        // Only update dispatch DMs (source !== 'trip_return_trigger'), not return DMs
        const dmQuery = await db
            .collection(DELIVERY_MEMOS_COLLECTION)
            .where('tripId', '==', tripId)
            .limit(10) // Get multiple to filter by source
            .get();
        // #region agent log
        console.log('[DEBUG] DM query for return', { tripId, docCount: dmQuery.docs.length, hypothesisId: 'B' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:322', message: 'DM query for return', data: { tripId, docCount: dmQuery.docs.length }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'B' }) }).catch(() => { });
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
        const updateData = {
            tripStatus: tripData.tripStatus || 'returned',
            orderStatus: tripData.orderStatus || '',
            returnedAt: tripData.returnedAt || new Date(),
            returnedBy: tripData.returnedBy || null,
            returnedByRole: tripData.returnedByRole || null,
            meters: {
                initialReading: (_a = tripData.initialReading) !== null && _a !== void 0 ? _a : null,
                finalReading: (_b = tripData.finalReading) !== null && _b !== void 0 ? _b : null,
                distanceTravelled: (_c = tripData.distanceTravelled) !== null && _c !== void 0 ? _c : null,
            },
            updatedAt: new Date(),
        };
        // If Pay on Delivery, add payment details
        const paymentType = ((_d = tripData.paymentType) === null || _d === void 0 ? void 0 : _d.toLowerCase()) || '';
        if (paymentType === 'pay_on_delivery') {
            const paymentDetails = tripData.paymentDetails || [];
            updateData.paymentDetails = paymentDetails;
            updateData.paymentStatus = tripData.paymentStatus || 'pending';
            updateData.totalPaidOnReturn = (_e = tripData.totalPaidOnReturn) !== null && _e !== void 0 ? _e : null;
            updateData.remainingAmount = (_f = tripData.remainingAmount) !== null && _f !== void 0 ? _f : null;
        }
        // #region agent log
        console.log('[DEBUG] About to update DM with return data', { tripId, dmId: dispatchDmDoc.id, updateDataTripStatus: updateData.tripStatus, hypothesisId: 'C' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:350', message: 'About to update DM with return data', data: { tripId, dmId: dispatchDmDoc.id, updateDataTripStatus: updateData.tripStatus }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        await dispatchDmDoc.ref.update(updateData);
        // #region agent log
        console.log('[DEBUG] DM updated with return status SUCCESS', { tripId, dmId: dispatchDmDoc.id, hypothesisId: 'C' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:356', message: 'DM updated with return status SUCCESS', data: { tripId, dmId: dispatchDmDoc.id }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        console.log('[Trip Status Update] Delivery memo updated for return', {
            tripId,
            dmId: dispatchDmDoc.id,
        });
    }
    catch (error) {
        // #region agent log
        console.error('[DEBUG] DM update for return FAILED', { tripId, error: error === null || error === void 0 ? void 0 : error.message, hypothesisId: 'C' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-status-update.ts:365', message: 'DM update for return FAILED', data: { tripId, error: error === null || error === void 0 ? void 0 : error.message }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        console.error('[Trip Status Update] Error updating delivery memo for return', {
            tripId,
            error,
        });
        // Don't throw - delivery memo update failure shouldn't block trip status update
    }
}
async function _revertDeliveryMemoReturn(tripId) {
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
        const updateData = {
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
    }
    catch (error) {
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
async function _cancelCreditTransaction(tripId, creditTransactionId) {
    try {
        const creditTxnRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc(creditTransactionId);
        const creditTxnDoc = await creditTxnRef.get();
        if (!creditTxnDoc.exists) {
            console.log('[Trip Status Update] Credit transaction not found', {
                tripId,
                transactionId: creditTransactionId,
            });
            return;
        }
        const creditTxnData = creditTxnDoc.data();
        const currentStatus = creditTxnData === null || creditTxnData === void 0 ? void 0 : creditTxnData.status;
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
        }
        else {
            console.log('[Trip Status Update] Credit transaction already cancelled', {
                tripId,
                transactionId: creditTransactionId,
            });
        }
    }
    catch (error) {
        console.error('[Trip Status Update] Error cancelling credit transaction', {
            tripId,
            creditTransactionId,
            error,
        });
        // Don't throw - transaction cancellation failure shouldn't block trip status update
    }
}
//# sourceMappingURL=trip-status-update.js.map