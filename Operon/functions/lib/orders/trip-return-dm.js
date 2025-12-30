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
exports.onTripReturnedCreateDM = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * On trip status change to "returned", update the existing Delivery Memo document.
 *
 * Flow:
 * 1. Find existing DM document by tripId
 * 2. Add return-related fields (returnedAt, meters, etc.)
 * 3. If payment type is 'pay_on_delivery', add payment details array
 * Note: DM status is NOT changed - it remains as is (typically 'active')
 */
exports.onTripReturnedCreateDM = functions.firestore
    .document(`${SCHEDULE_TRIPS_COLLECTION}/{tripId}`)
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f;
    // #region agent log
    console.log('[DEBUG] onTripReturnedCreateDM triggered', { tripId: context.params.tripId, hypothesisId: 'A' });
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:20', message: 'onTripReturnedCreateDM triggered', data: { tripId: context.params.tripId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
    // #endregion
    const before = change.before.data();
    const after = change.after.data();
    const tripId = context.params.tripId;
    // #region agent log
    console.log('[DEBUG] Before/after data check', { tripId, hasBefore: !!before, hasAfter: !!after, beforeStatus: before === null || before === void 0 ? void 0 : before.tripStatus, afterStatus: after === null || after === void 0 ? void 0 : after.tripStatus, hypothesisId: 'A' });
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:25', message: 'Before/after data check', data: { tripId, hasBefore: !!before, hasAfter: !!after, beforeStatus: before === null || before === void 0 ? void 0 : before.tripStatus, afterStatus: after === null || after === void 0 ? void 0 : after.tripStatus }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
    // #endregion
    if (!before || !after)
        return;
    // Only act on status change to returned
    const beforeStatusCheck = (before.tripStatus || before.orderStatus) === 'returned';
    // #region agent log
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:28', message: 'Before status check', data: { tripId, beforeStatusCheck, beforeTripStatus: before.tripStatus, beforeOrderStatus: before.orderStatus }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
    // #endregion
    if (beforeStatusCheck)
        return;
    const afterStatus = (after.tripStatus || after.orderStatus || '').toLowerCase();
    // #region agent log
    console.log('[DEBUG] After status check', { tripId, afterStatus, isReturned: afterStatus === 'returned', hypothesisId: 'A' });
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:30', message: 'After status check', data: { tripId, afterStatus, isReturned: afterStatus === 'returned' }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
    // #endregion
    if (afterStatus !== 'returned') {
        console.log('[DEBUG] Exiting early - status is not returned', { tripId, afterStatus });
        return;
    }
    const organizationId = after.organizationId;
    // #region agent log
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:32', message: 'OrganizationId check', data: { tripId, hasOrganizationId: !!organizationId, organizationId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'A' }) }).catch(() => { });
    // #endregion
    if (!organizationId) {
        console.warn('[Trip Return DM] Missing organizationId, skipping', { tripId });
        return;
    }
    // Find existing DM document
    // #region agent log
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:39', message: 'Querying DELIVERY_MEMOs BEFORE query', data: { tripId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'B' }) }).catch(() => { });
    // #endregion
    const dmQuery = await db
        .collection(DELIVERY_MEMOS_COLLECTION)
        .where('tripId', '==', tripId)
        .limit(1)
        .get();
    // #region agent log
    console.log('[DEBUG] DM query result', { tripId, isEmpty: dmQuery.empty, docCount: dmQuery.docs.length, hypothesisId: 'B' });
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:45', message: 'DM query result', data: { tripId, isEmpty: dmQuery.empty, docCount: dmQuery.docs.length }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'B' }) }).catch(() => { });
    // #endregion
    if (dmQuery.empty) {
        console.warn('[Trip Return DM] No DM document found for trip', { tripId });
        return;
    }
    const dmDoc = dmQuery.docs[0];
    const paymentType = ((_a = after.paymentType) === null || _a === void 0 ? void 0 : _a.toLowerCase()) || '';
    // Prepare update data
    // Note: Do NOT change DM status - keep it as is (typically 'active')
    const updateData = {
        tripStatus: after.tripStatus || 'returned',
        orderStatus: after.orderStatus || '',
        returnedAt: after.returnedAt || new Date(),
        returnedBy: after.returnedBy || null,
        returnedByRole: after.returnedByRole || null,
        meters: {
            initialReading: (_b = after.initialReading) !== null && _b !== void 0 ? _b : null,
            finalReading: (_c = after.finalReading) !== null && _c !== void 0 ? _c : null,
            distanceTravelled: (_d = after.distanceTravelled) !== null && _d !== void 0 ? _d : null,
        },
        updatedAt: new Date(),
    };
    // #region agent log
    console.log('[DEBUG] UpdateData prepared BEFORE update', { tripId, dmId: dmDoc.id, updateDataTripStatus: updateData.tripStatus, afterTripStatus: after.tripStatus, updateDataKeys: Object.keys(updateData), hypothesisId: 'D' });
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:55', message: 'UpdateData prepared BEFORE update', data: { tripId, dmId: dmDoc.id, updateDataTripStatus: updateData.tripStatus, afterTripStatus: after.tripStatus }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'D' }) }).catch(() => { });
    // #endregion
    // If Pay on Delivery, add mode of payment array
    if (paymentType === 'pay_on_delivery') {
        const paymentDetails = after.paymentDetails || [];
        updateData.paymentDetails = paymentDetails;
        updateData.paymentStatus = after.paymentStatus || 'pending';
        updateData.totalPaidOnReturn = (_e = after.totalPaidOnReturn) !== null && _e !== void 0 ? _e : null;
        updateData.remainingAmount = (_f = after.remainingAmount) !== null && _f !== void 0 ? _f : null;
    }
    // Update delivery memo document
    // #region agent log
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:79', message: 'About to update DM document', data: { tripId, dmId: dmDoc.id, updateDataKeys: Object.keys(updateData) }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
    // #endregion
    try {
        await dmDoc.ref.update(updateData);
        // #region agent log
        console.log('[DEBUG] DM update SUCCESS', { tripId, dmId: dmDoc.id, hypothesisId: 'C' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:82', message: 'DM update SUCCESS', data: { tripId, dmId: dmDoc.id }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
    }
    catch (updateError) {
        // #region agent log
        console.error('[DEBUG] DM update FAILED', { tripId, dmId: dmDoc.id, error: updateError === null || updateError === void 0 ? void 0 : updateError.message, errorStack: updateError === null || updateError === void 0 ? void 0 : updateError.stack, hypothesisId: 'C' });
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'trip-return-dm.ts:85', message: 'DM update FAILED', data: { tripId, dmId: dmDoc.id, error: updateError === null || updateError === void 0 ? void 0 : updateError.message, errorStack: updateError === null || updateError === void 0 ? void 0 : updateError.stack }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'run1', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        throw updateError;
    }
    console.log('[Trip Return DM] DM updated on return', {
        tripId,
        dmId: dmDoc.id,
        paymentType,
        hasPaymentDetails: paymentType === 'pay_on_delivery' && !!updateData.paymentDetails,
    });
});
//# sourceMappingURL=trip-return-dm.js.map