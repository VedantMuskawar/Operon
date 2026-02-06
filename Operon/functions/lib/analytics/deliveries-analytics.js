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
exports.rebuildDeliveriesAnalyticsForOrg = rebuildDeliveriesAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Rebuild deliveries analytics for a single organization and financial year.
 * Tracks: total quantity delivered, quantity by region (city/region), top 20 clients by order value.
 */
async function rebuildDeliveriesAnalyticsForOrg(organizationId, financialYear, fyStart, fyEnd) {
    // Group deliveries by month - will write to multiple monthly documents
    const dmSnapshot = await db
        .collection(constants_1.DELIVERY_MEMOS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('status', '==', 'delivered')
        .get();
    // Group deliveries by month and by day (daily data only)
    const deliveriesByMonthDay = {};
    const clientNameMap = {};
    dmSnapshot.forEach((doc) => {
        var _a, _b, _c, _d, _e;
        const dm = doc.data();
        const scheduledDate = (_b = (_a = dm.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a);
        const deliveredAt = (_d = (_c = dm.deliveredAt) === null || _c === void 0 ? void 0 : _c.toDate) === null || _d === void 0 ? void 0 : _d.call(_c);
        const dmDate = deliveredAt || scheduledDate;
        if (!dmDate || dmDate < fyStart || dmDate >= fyEnd) {
            return;
        }
        const monthKey = (0, date_helpers_1.getYearMonth)(dmDate);
        const dateString = (0, date_helpers_1.formatDate)(dmDate);
        if (!deliveriesByMonthDay[monthKey]) {
            deliveriesByMonthDay[monthKey] = {
                quantityDaily: {},
                quantityByRegionDaily: {},
                clientTotalsDaily: {},
            };
        }
        let qty = 0;
        const items = dm.items || [];
        for (const item of items) {
            const fixedQty = (_e = item === null || item === void 0 ? void 0 : item.fixedQuantityPerTrip) !== null && _e !== void 0 ? _e : 0;
            qty += fixedQty;
        }
        deliveriesByMonthDay[monthKey].quantityDaily[dateString] =
            (deliveriesByMonthDay[monthKey].quantityDaily[dateString] || 0) + qty;
        const dz = dm.deliveryZone || {};
        const city = dz.city_name || dz.city || 'Unknown';
        const region = dz.region || city;
        if (!deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString]) {
            deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString] = {};
        }
        const regionMap = deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString];
        regionMap[city] = (regionMap[city] || 0) + qty;
        if (region !== city) {
            regionMap[region] = (regionMap[region] || 0) + qty;
        }
        const tripPricing = dm.tripPricing || {};
        const totalAmount = tripPricing.total || 0;
        const clientId = dm.clientId || '';
        if (clientId) {
            if (!clientNameMap[clientId]) {
                clientNameMap[clientId] = dm.clientName || 'Unknown';
            }
            if (!deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString]) {
                deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString] = {};
            }
            const dayClients = deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString];
            if (!dayClients[clientId]) {
                dayClients[clientId] = { amount: 0, count: 0 };
            }
            dayClients[clientId].amount += totalAmount;
            dayClients[clientId].count += 1;
        }
    });
    const monthPromises = Object.entries(deliveriesByMonthDay).map(async ([monthKey, monthData]) => {
        const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.DELIVERIES_SOURCE_KEY}_${organizationId}_${monthKey}`);
        await (0, firestore_helpers_1.seedDeliveriesAnalyticsDoc)(analyticsRef, monthKey, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.quantityDeliveredDaily': monthData.quantityDaily,
            'metrics.quantityByRegionDaily': monthData.quantityByRegionDaily,
            'metrics.clientTotalsDaily': monthData.clientTotalsDaily,
        }, { merge: true });
    });
    await Promise.all(monthPromises);
}
//# sourceMappingURL=deliveries-analytics.js.map