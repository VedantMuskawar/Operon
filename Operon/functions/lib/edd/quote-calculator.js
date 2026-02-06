"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDeliveryQuote = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const constants_1 = require("../shared/constants");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const BUFFER_DAYS_NORMAL = 1;
/**
 * Staggered fit: find earliest sequence of `tripsNeeded` dates from freeSlots
 * with 1-day gap (Normal priority). Returns [D1, D2, ...] or [] if not fittable.
 */
function staggeredFit(freeSlots, tripsNeeded) {
    var _a;
    const sorted = Object.keys(freeSlots).sort();
    const out = [];
    let lastDate = null;
    const slots = Object.assign({}, freeSlots);
    for (const key of sorted) {
        if (out.length >= tripsNeeded)
            break;
        const cap = (_a = slots[key]) !== null && _a !== void 0 ? _a : 0;
        if (cap < 1)
            continue;
        const parts = key.split('-').map(Number);
        const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
        if (lastDate != null && BUFFER_DAYS_NORMAL >= 1) {
            const minNext = new Date(lastDate);
            minNext.setUTCDate(minNext.getUTCDate() + 2);
            if (d < minNext)
                continue;
        }
        out.push(key);
        slots[key] = cap - 1;
        lastDate = d;
    }
    return out.length >= tripsNeeded ? out : [];
}
/**
 * Callable: getDeliveryQuote(totalQuantity, productType, organizationId).
 * Returns QuoteResult[] sorted by estimatedCompletionDate ascending.
 */
exports.getDeliveryQuote = (0, https_1.onCall)(Object.assign({}, function_config_1.CALLABLE_OPTS), async (request) => {
    var _a, _b, _c, _d, _e, _f;
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be signed in.');
    }
    const { totalQuantity, productType, organizationId } = (request.data || {});
    if (typeof totalQuantity !== 'number' || totalQuantity <= 0) {
        throw new https_1.HttpsError('invalid-argument', 'totalQuantity must be a positive number.');
    }
    if (typeof productType !== 'string' || !productType.trim()) {
        throw new https_1.HttpsError('invalid-argument', 'productType is required.');
    }
    if (typeof organizationId !== 'string' || !organizationId.trim()) {
        throw new https_1.HttpsError('invalid-argument', 'organizationId is required.');
    }
    const orgRef = db.collection(constants_1.ORGANIZATIONS_COLLECTION).doc(organizationId);
    const vehiclesSnap = await orgRef.collection('VEHICLES').where('isActive', '==', true).get();
    const candidates = [];
    for (const doc of vehiclesSnap.docs) {
        const d = doc.data();
        const pc = (_a = d.productCapacities) !== null && _a !== void 0 ? _a : {};
        const cap = (_c = (_b = pc[productType]) !== null && _b !== void 0 ? _b : d.vehicleCapacity) !== null && _c !== void 0 ? _c : 0;
        if (cap > 0) {
            candidates.push({
                vehicleId: doc.id,
                vehicleName: (_d = d.vehicleNumber) !== null && _d !== void 0 ? _d : doc.id,
                capacityPerTrip: cap,
            });
        }
    }
    const results = [];
    const forecastCol = orgRef.collection(constants_1.VEHICLE_AVAILABILITY_FORECAST);
    for (const c of candidates) {
        const forecastDoc = await forecastCol.doc(c.vehicleId).get();
        const freeSlots = (_f = (_e = forecastDoc.data()) === null || _e === void 0 ? void 0 : _e.freeSlots) !== null && _f !== void 0 ? _f : {};
        const tripsRequired = Math.ceil(totalQuantity / c.capacityPerTrip);
        const scheduleBreakdown = staggeredFit(freeSlots, tripsRequired);
        if (scheduleBreakdown.length < tripsRequired)
            continue;
        const estimatedStartDate = scheduleBreakdown[0];
        const estimatedCompletionDate = scheduleBreakdown[scheduleBreakdown.length - 1];
        results.push({
            vehicleId: c.vehicleId,
            vehicleName: c.vehicleName,
            tripsRequired,
            estimatedStartDate,
            estimatedCompletionDate,
            scheduleBreakdown,
        });
    }
    results.sort((a, b) => (a.estimatedCompletionDate < b.estimatedCompletionDate ? -1 : a.estimatedCompletionDate > b.estimatedCompletionDate ? 1 : 0));
    return results;
});
//# sourceMappingURL=quote-calculator.js.map