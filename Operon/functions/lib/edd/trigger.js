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
exports.processEddRecalcQueueScheduled = exports.onOrderWriteEddRecalc = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const constants_1 = require("../shared/constants");
const function_config_1 = require("../shared/function-config");
const simulation_engine_1 = require("./simulation-engine");
const db = (0, firestore_helpers_1.getFirestore)();
const DEBOUNCE_SECONDS = 60;
function shallowEqual(a, b) {
    if (a === b)
        return true;
    if (a == null || b == null)
        return false;
    if (typeof a !== 'object' || typeof b !== 'object')
        return a === b;
    const ka = Object.keys(a).sort();
    const kb = Object.keys(b).sort();
    if (ka.length !== kb.length)
        return false;
    for (let i = 0; i < ka.length; i++) {
        if (ka[i] !== kb[i])
            return false;
        const key = ka[i];
        const va = a[key];
        const vb = b[key];
        if (typeof va === 'object' && va !== null && typeof vb === 'object' && vb !== null) {
            if (!shallowEqual(va, vb))
                return false;
        }
        else if (va !== vb)
            return false;
    }
    return true;
}
function orderRelevantChange(before, after) {
    var _a, _b, _c, _d;
    if (!before.exists)
        return true; // create
    if (!after.exists)
        return true; // delete
    const b = before.data();
    const a = after.data();
    if (b.status !== a.status)
        return true;
    if (b.priority !== a.priority)
        return true;
    const bItems = (_a = b.items) !== null && _a !== void 0 ? _a : [];
    const aItems = (_b = a.items) !== null && _b !== void 0 ? _b : [];
    if (bItems.length !== aItems.length)
        return true;
    if (!shallowEqual(bItems, aItems))
        return true;
    const bTrips = (_c = b.scheduledTrips) !== null && _c !== void 0 ? _c : [];
    const aTrips = (_d = a.scheduledTrips) !== null && _d !== void 0 ? _d : [];
    if (bTrips.length !== aTrips.length)
        return true;
    if (b.totalScheduledTrips !== a.totalScheduledTrips)
        return true;
    // Check for autoSchedule changes (especially suggestedVehicleId which affects EDD)
    const bAutoSchedule = b.autoSchedule;
    const aAutoSchedule = a.autoSchedule;
    if (!shallowEqual(bAutoSchedule, aAutoSchedule))
        return true;
    return false;
}
async function getAffectedVehicleIds(orderId, organizationId, before, after) {
    var _a;
    const out = new Set();
    const suggested = (_a = (after.exists ? after.data() : before.exists ? before.data() : {})) === null || _a === void 0 ? void 0 : _a.autoSchedule;
    if (suggested === null || suggested === void 0 ? void 0 : suggested.suggestedVehicleId) {
        out.add(suggested.suggestedVehicleId);
    }
    const tripsSnap = await db
        .collection(constants_1.SCHEDULE_TRIPS_COLLECTION)
        .where('orderId', '==', orderId)
        .get();
    for (const doc of tripsSnap.docs) {
        const v = doc.data().vehicleId;
        if (v)
            out.add(v);
    }
    return out;
}
/**
 * onWrite PENDING_ORDERS: enqueue EDD recalc for affected vehicles (debounced 60s).
 */
exports.onOrderWriteEddRecalc = (0, firestore_1.onDocumentWritten)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const change = event.data;
    if (!change)
        return;
    const before = change.before;
    const after = change.after;
    const orderId = event.params.orderId;
    if (!orderRelevantChange(before, after)) {
        return;
    }
    const snapshot = after.exists ? after : before;
    if (!snapshot.exists)
        return;
    const data = snapshot.data();
    const organizationId = data.organizationId;
    if (!organizationId) {
        return;
    }
    const vehicleIds = await getAffectedVehicleIds(orderId, organizationId, before, after);
    if (vehicleIds.size === 0) {
        return;
    }
    const scheduledAt = new Date(Date.now() + DEBOUNCE_SECONDS * 1000);
    const orgRef = db.collection(constants_1.ORGANIZATIONS_COLLECTION).doc(organizationId);
    const queueRef = orgRef.collection(constants_1.EDD_RECALC_QUEUE);
    await Promise.all(Array.from(vehicleIds).map((vehicleId) => queueRef.doc(vehicleId).set({
        scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
        organizationId,
        vehicleId,
        enqueuedAt: admin.firestore.FieldValue.serverTimestamp(),
    })));
    console.log('[EDD Trigger] Enqueued recalc', {
        orderId,
        organizationId,
        vehicleIds: Array.from(vehicleIds),
        scheduledAt: scheduledAt.toISOString(),
    });
});
/**
 * Scheduled processor for EDD_RECALC_QUEUE. Runs every 2 minutes, processes due items.
 */
exports.processEddRecalcQueueScheduled = (0, scheduler_1.onSchedule)(Object.assign({ schedule: '*/2 * * * *', timeZone: 'UTC' }, function_config_1.SCHEDULED_FUNCTION_OPTS), async () => {
    const now = admin.firestore.Timestamp.now();
    const orgsSnap = await db.collection(constants_1.ORGANIZATIONS_COLLECTION).get();
    for (const orgDoc of orgsSnap.docs) {
        const orgId = orgDoc.id;
        const queueRef = db
            .collection(constants_1.ORGANIZATIONS_COLLECTION)
            .doc(orgId)
            .collection(constants_1.EDD_RECALC_QUEUE);
        const dueSnap = await queueRef.where('scheduledAt', '<=', now).get();
        for (const doc of dueSnap.docs) {
            const d = doc.data();
            const vehicleId = doc.id;
            const organizationId = d.organizationId || orgId;
            try {
                await (0, simulation_engine_1.recalculateVehicleQueue)(vehicleId, organizationId);
            }
            catch (e) {
                console.error('[EDD Queue] Recalc failed', { vehicleId, organizationId, error: e });
            }
            await doc.ref.delete();
        }
    }
});
//# sourceMappingURL=trigger.js.map