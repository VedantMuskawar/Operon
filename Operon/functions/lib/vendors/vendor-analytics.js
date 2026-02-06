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
exports.rebuildVendorAnalyticsCore = rebuildVendorAnalyticsCore;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Core logic to rebuild vendor analytics for all organizations.
 * Called by unified analytics scheduler.
 */
async function rebuildVendorAnalyticsCore(fyLabel) {
    const vendorsSnapshot = await db.collection(constants_1.VENDORS_COLLECTION).get();
    const vendorsByOrg = {};
    vendorsSnapshot.forEach((doc) => {
        var _a;
        const organizationId = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.organizationId;
        if (organizationId) {
            if (!vendorsByOrg[organizationId]) {
                vendorsByOrg[organizationId] = [];
            }
            vendorsByOrg[organizationId].push(doc);
        }
    });
    // Calculate total payable (current balance across all vendors) - this is org-wide, not month-specific
    const totalPayableByOrg = {};
    Object.entries(vendorsByOrg).forEach(([organizationId, orgVendors]) => {
        let totalPayable = 0;
        orgVendors.forEach((doc) => {
            var _a;
            const currentBalance = ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.currentBalance) || 0;
            totalPayable += currentBalance;
        });
        totalPayableByOrg[organizationId] = totalPayable;
    });
    const analyticsUpdates = Object.entries(vendorsByOrg).map(async ([organizationId, orgVendors]) => {
        const vendorTypeMap = {};
        orgVendors.forEach((doc) => {
            var _a;
            const vendorId = doc.id;
            const vendorType = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.vendorType;
            if (vendorType) {
                vendorTypeMap[vendorId] = vendorType;
            }
        });
        const purchaseTransactionsSnapshot = await db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('ledgerType', '==', 'vendorLedger')
            .where('type', '==', 'credit')
            .get();
        // Group purchases by month and by day (daily data only): month -> date -> vendorType -> amount
        const purchasesByMonthDay = {};
        purchaseTransactionsSnapshot.forEach((doc) => {
            const transactionData = doc.data();
            const vendorId = transactionData.vendorId;
            const vendorType = vendorId ? vendorTypeMap[vendorId] : undefined;
            if (!vendorId || !vendorType) {
                return;
            }
            const transactionDate = transactionData.transactionDate
                || transactionData.paymentDate
                || transactionData.createdAt;
            const amount = transactionData.amount || 0;
            if (transactionDate) {
                const dateObj = transactionDate.toDate();
                const monthKey = (0, date_helpers_1.getYearMonth)(dateObj);
                const dateString = (0, date_helpers_1.formatDate)(dateObj);
                if (!purchasesByMonthDay[monthKey]) {
                    purchasesByMonthDay[monthKey] = {};
                }
                if (!purchasesByMonthDay[monthKey][dateString]) {
                    purchasesByMonthDay[monthKey][dateString] = {};
                }
                purchasesByMonthDay[monthKey][dateString][vendorType] =
                    (purchasesByMonthDay[monthKey][dateString][vendorType] || 0) + amount;
            }
        });
        // Write to each month's document (daily data only)
        const monthPromises = Object.entries(purchasesByMonthDay).map(async ([monthKey, dailyMap]) => {
            const analyticsRef = db
                .collection(constants_1.ANALYTICS_COLLECTION)
                .doc(`${constants_1.VENDORS_SOURCE_KEY}_${organizationId}_${monthKey}`);
            await (0, firestore_helpers_1.seedVendorAnalyticsDoc)(analyticsRef, monthKey, organizationId);
            await analyticsRef.set({
                generatedAt: admin.firestore.FieldValue.serverTimestamp(),
                'metrics.totalPayable': totalPayableByOrg[organizationId],
                'metrics.purchasesDaily': dailyMap,
            }, { merge: true });
        });
        await Promise.all(monthPromises);
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Vendor Analytics] Rebuilt analytics for ${Object.keys(vendorsByOrg).length} organizations`);
}
//# sourceMappingURL=vendor-analytics.js.map