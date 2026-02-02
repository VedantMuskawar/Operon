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
exports.rebuildProductionsAnalyticsForOrg = rebuildProductionsAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Rebuild productions analytics for a single organization and financial year.
 * Tracks: total production (bricks produced/stacked) per month and year.
 */
async function rebuildProductionsAnalyticsForOrg(organizationId, financialYear, fyStart, fyEnd) {
    const analyticsDocId = `${constants_1.PRODUCTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
    const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
    const batchesSnapshot = await db
        .collection(constants_1.PRODUCTION_BATCHES_COLLECTION)
        .where('organizationId', '==', organizationId)
        .get();
    const totalProductionMonthly = {};
    let totalProductionYearly = 0;
    const totalRawMaterialsMonthly = {};
    batchesSnapshot.forEach((doc) => {
        var _a, _b, _c;
        const batch = doc.data();
        const batchDate = (_b = (_a = batch.batchDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a);
        if (!batchDate || batchDate < fyStart || batchDate >= fyEnd) {
            return;
        }
        const monthKey = (0, date_helpers_1.getYearMonth)(batchDate);
        const produced = batch.totalBricksProduced || 0;
        const stacked = batch.totalBricksStacked || 0;
        const total = produced + stacked;
        totalProductionMonthly[monthKey] = (totalProductionMonthly[monthKey] || 0) + total;
        totalProductionYearly += total;
        // Raw materials: if metadata.rawMaterialsConsumed or similar exists, aggregate
        const metadata = batch.metadata || {};
        const rawConsumed = (_c = metadata.rawMaterialsConsumed) !== null && _c !== void 0 ? _c : 0;
        if (rawConsumed > 0) {
            totalRawMaterialsMonthly[monthKey] =
                (totalRawMaterialsMonthly[monthKey] || 0) + rawConsumed;
        }
    });
    await (0, firestore_helpers_1.seedProductionsAnalyticsDoc)(analyticsRef, financialYear, organizationId);
    await analyticsRef.set({
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalProductionMonthly.values': totalProductionMonthly,
        'metrics.totalProductionYearly': totalProductionYearly,
        'metrics.totalRawMaterialsMonthly.values': totalRawMaterialsMonthly,
    }, { merge: true });
}
//# sourceMappingURL=productions-analytics.js.map