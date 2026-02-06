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
exports.rebuildTripWagesAnalyticsForOrg = rebuildTripWagesAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Rebuild trip wages analytics for a single organization and financial year.
 * Tracks: wages paid by fixed quantity bucket, total trip wages per month.
 */
async function rebuildTripWagesAnalyticsForOrg(organizationId, financialYear, fyStart, fyEnd) {
    const tripWagesSnapshot = await db
        .collection(constants_1.TRIP_WAGES_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('status', '==', 'processed')
        .get();
    // Group wages by month
    const wagesByMonth = {};
    tripWagesSnapshot.forEach((doc) => {
        var _a, _b, _c, _d, _e;
        const tw = doc.data();
        const totalWages = tw.totalWages || 0;
        const quantityDelivered = (_a = tw.quantityDelivered) !== null && _a !== void 0 ? _a : 0;
        const qtyKey = String(quantityDelivered);
        const createdAt = (_c = (_b = tw.createdAt) === null || _b === void 0 ? void 0 : _b.toDate) === null || _c === void 0 ? void 0 : _c.call(_b);
        const paymentDate = (_e = (_d = tw.paymentDate) === null || _d === void 0 ? void 0 : _d.toDate) === null || _e === void 0 ? void 0 : _e.call(_d);
        const wageDate = paymentDate || createdAt;
        if (!wageDate || wageDate < fyStart || wageDate >= fyEnd) {
            return;
        }
        const monthKey = (0, date_helpers_1.getYearMonth)(wageDate);
        if (!wagesByMonth[monthKey]) {
            wagesByMonth[monthKey] = {
                totalTripWages: 0,
                wagesByQuantity: {},
            };
        }
        wagesByMonth[monthKey].totalTripWages += totalWages;
        wagesByMonth[monthKey].wagesByQuantity[qtyKey] =
            (wagesByMonth[monthKey].wagesByQuantity[qtyKey] || 0) + totalWages;
    });
    // Write to each month's document
    const monthPromises = Object.entries(wagesByMonth).map(async ([monthKey, monthData]) => {
        const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.TRIP_WAGES_ANALYTICS_SOURCE_KEY}_${organizationId}_${monthKey}`);
        await (0, firestore_helpers_1.seedTripWagesAnalyticsDoc)(analyticsRef, monthKey, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.totalTripWagesMonthly': monthData.totalTripWages,
            'metrics.wagesPaidByFixedQuantityMonthly': monthData.wagesByQuantity,
        }, { merge: true });
    });
    await Promise.all(monthPromises);
}
//# sourceMappingURL=trip-wages-analytics.js.map