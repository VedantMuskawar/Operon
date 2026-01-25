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
exports.rebuildVendorAnalytics = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Cloud Function: Scheduled function to rebuild vendor analytics
 * Runs every 24 hours to recalculate analytics for all organizations
 */
exports.rebuildVendorAnalytics = functions.pubsub
    .schedule('every 24 hours')
    .timeZone('UTC')
    .onRun(async () => {
    const now = new Date();
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(now);
    // Get all vendors and group by organizationId
    const vendorsSnapshot = await db.collection(constants_1.VENDORS_COLLECTION).get();
    // Group vendors by organizationId
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
    // Process analytics for each organization
    const analyticsUpdates = Object.entries(vendorsByOrg).map(async ([organizationId, orgVendors]) => {
        const analyticsRef = db
            .collection(constants_1.ANALYTICS_COLLECTION)
            .doc(`${constants_1.VENDORS_SOURCE_KEY}_${organizationId}_${fyLabel}`);
        // Calculate total payable (sum of currentBalance from all vendors, irrespective of time)
        let totalPayable = 0;
        orgVendors.forEach((doc) => {
            var _a;
            const currentBalance = ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.currentBalance) || 0;
            totalPayable += currentBalance;
        });
        // Query all vendor purchase transactions (credit transactions = purchases)
        const purchaseTransactionsSnapshot = await db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('ledgerType', '==', 'vendorLedger')
            .where('type', '==', 'credit')
            .get();
        // Build vendor type lookup map from vendor documents
        const vendorTypeMap = {};
        orgVendors.forEach((doc) => {
            var _a;
            const vendorId = doc.id;
            const vendorType = (_a = doc.data()) === null || _a === void 0 ? void 0 : _a.vendorType;
            if (vendorType) {
                vendorTypeMap[vendorId] = vendorType;
            }
        });
        // Group purchases by vendor type and month
        const purchasesByVendorType = {};
        purchaseTransactionsSnapshot.forEach((doc) => {
            const transactionData = doc.data();
            const vendorId = transactionData.vendorId;
            const vendorType = vendorId ? vendorTypeMap[vendorId] : undefined;
            if (!vendorId || !vendorType) {
                console.warn('[Vendor Analytics] Transaction missing vendorId or vendorType', {
                    transactionId: doc.id,
                    vendorId,
                    vendorType,
                });
                return;
            }
            // Use transactionDate (primary) or paymentDate (fallback) or createdAt
            const transactionDate = transactionData.transactionDate
                || transactionData.paymentDate
                || transactionData.createdAt;
            const amount = transactionData.amount || 0;
            if (transactionDate) {
                const dateObj = transactionDate.toDate();
                const monthKey = (0, date_helpers_1.getYearMonth)(dateObj);
                // Initialize vendor type if not exists
                if (!purchasesByVendorType[vendorType]) {
                    purchasesByVendorType[vendorType] = {};
                }
                // Add amount to month
                purchasesByVendorType[vendorType][monthKey] = (purchasesByVendorType[vendorType][monthKey] || 0) + amount;
            }
        });
        await (0, firestore_helpers_1.seedVendorAnalyticsDoc)(analyticsRef, fyLabel, organizationId);
        // Build update data with nested structure
        const updateData = {
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            'metrics.totalPayable': totalPayable,
        };
        // Set purchases by vendor type - use dot notation for nested structure
        for (const [vendorType, monthlyData] of Object.entries(purchasesByVendorType)) {
            for (const [monthKey, amount] of Object.entries(monthlyData)) {
                updateData[`metrics.purchasesByVendorType.values.${vendorType}.${monthKey}`] = amount;
            }
        }
        await analyticsRef.set(updateData, { merge: true });
    });
    await Promise.all(analyticsUpdates);
    console.log(`[Vendor Analytics] Rebuilt analytics for ${Object.keys(vendorsByOrg).length} organizations`);
});
//# sourceMappingURL=vendor-analytics.js.map