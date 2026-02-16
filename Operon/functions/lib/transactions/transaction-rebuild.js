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
exports.rebuildTransactionAnalyticsForOrg = rebuildTransactionAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Rebuild transaction analytics for a specific organization and financial year.
 * Now writes to monthly documents instead of a single yearly document.
 * Exported for use by unified analytics rebuild.
 */
async function rebuildTransactionAnalyticsForOrg(organizationId, financialYear) {
    // Calculate financial year date range from FY label (e.g., "FY2526" -> April 2025 to March 2026)
    const match = financialYear.match(/FY(\d{2})(\d{2})/);
    if (!match) {
        throw new Error(`Invalid financial year format: ${financialYear}`);
    }
    // Get all transactions for this organization in this FY
    const transactionsSnapshot = await db
        .collection(constants_1.TRANSACTIONS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('financialYear', '==', financialYear)
        .select('status', 'category', 'type', 'amount', 'paymentAccountId', 'paymentAccountType', 'ledgerType', 'createdAt')
        .get();
    // Group transactions by month
    const transactionsByMonth = {};
    transactionsSnapshot.forEach((doc) => {
        var _a, _b;
        const tx = doc.data();
        const createdAt = tx.createdAt;
        const transactionDate = createdAt ? createdAt.toDate() : (_b = (_a = doc.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
        const monthKey = (0, date_helpers_1.getYearMonth)(transactionDate);
        if (!transactionsByMonth[monthKey]) {
            transactionsByMonth[monthKey] = [];
        }
        transactionsByMonth[monthKey].push(doc);
    });
    // Process each month separately
    const monthUpdates = Object.entries(transactionsByMonth).map(async ([monthKey, monthDocs]) => {
        const analyticsDocId = `${constants_1.TRANSACTIONS_SOURCE_KEY}_${organizationId}_${monthKey}`;
        const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
        const incomeDaily = {};
        const receivablesDaily = {};
        const expenseDaily = {};
        const byType = {};
        const byPaymentAccount = {};
        const byPaymentMethodType = {};
        const incomeByCategory = {};
        const receivablesByCategory = {};
        let totalPayableToVendors = 0;
        let transactionCount = 0;
        let completedTransactionCount = 0;
        const receivableAging = {
            current: 0,
            days31to60: 0,
            days61to90: 0,
            over90: 0,
        };
        monthDocs.forEach((doc) => {
            var _a, _b;
            const tx = doc.data();
            const status = tx.status;
            const category = tx.category;
            const type = tx.type;
            const amount = tx.amount;
            const paymentAccountId = tx.paymentAccountId;
            const paymentAccountType = tx.paymentAccountType;
            transactionCount++;
            if (status === 'completed') {
                completedTransactionCount++;
            }
            const ledgerType = tx.ledgerType;
            const isClientLedgerDebit = ledgerType === 'clientLedger' && type === 'debit';
            const isClientLedgerCredit = ledgerType === 'clientLedger' && type === 'credit';
            const isExpenseByCategory = category !== 'income';
            const multiplier = 1;
            const createdAt = tx.createdAt;
            const transactionDate = createdAt ? createdAt.toDate() : (_b = (_a = doc.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
            const dateString = (0, date_helpers_1.formatDate)(transactionDate);
            if (isClientLedgerDebit) {
                incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
                incomeByCategory[category] = (incomeByCategory[category] || 0) + (amount * multiplier);
            }
            if (isClientLedgerCredit) {
                receivablesDaily[dateString] = (receivablesDaily[dateString] || 0) + (amount * multiplier);
                receivablesByCategory[category] = (receivablesByCategory[category] || 0) + (amount * multiplier);
                receivableAging.current += amount;
            }
            if (isExpenseByCategory) {
                expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
            }
            if (!byType[type]) {
                byType[type] = { count: 0, total: 0, daily: {} };
            }
            byType[type].count += multiplier;
            byType[type].total += (amount * multiplier);
            byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
            const accountId = paymentAccountId || 'cash';
            if (!byPaymentAccount[accountId]) {
                byPaymentAccount[accountId] = {
                    accountId,
                    accountName: accountId === 'cash' ? 'Cash' : accountId,
                    accountType: paymentAccountType || (accountId === 'cash' ? 'cash' : 'other'),
                    count: 0,
                    total: 0,
                    daily: {},
                };
            }
            byPaymentAccount[accountId].count += multiplier;
            byPaymentAccount[accountId].total += (amount * multiplier);
            byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
            const methodType = paymentAccountType || 'cash';
            if (!byPaymentMethodType[methodType]) {
                byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {} };
            }
            byPaymentMethodType[methodType].count += multiplier;
            byPaymentMethodType[methodType].total += (amount * multiplier);
            byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
            if (ledgerType === 'vendorLedger' && type === 'credit') {
                totalPayableToVendors += amount;
            }
        });
        // Clean daily data
        const cleanedIncomeDaily = (0, date_helpers_1.cleanDailyData)(incomeDaily, 90);
        const cleanedReceivablesDaily = (0, date_helpers_1.cleanDailyData)(receivablesDaily, 90);
        const cleanedExpenseDaily = (0, date_helpers_1.cleanDailyData)(expenseDaily, 90);
        Object.keys(byType).forEach((type) => {
            byType[type].daily = (0, date_helpers_1.cleanDailyData)(byType[type].daily, 90);
        });
        Object.keys(byPaymentAccount).forEach((accountId) => {
            byPaymentAccount[accountId].daily = (0, date_helpers_1.cleanDailyData)(byPaymentAccount[accountId].daily, 90);
        });
        Object.keys(byPaymentMethodType).forEach((methodType) => {
            byPaymentMethodType[methodType].daily = (0, date_helpers_1.cleanDailyData)(byPaymentMethodType[methodType].daily, 90);
        });
        // Calculate totals for this month
        const totalIncome = Object.values(cleanedIncomeDaily).reduce((sum, val) => sum + (val || 0), 0);
        const totalReceivables = Object.values(cleanedReceivablesDaily).reduce((sum, val) => sum + (val || 0), 0);
        const netReceivables = totalReceivables - totalIncome;
        const totalExpense = Object.values(cleanedExpenseDaily).reduce((sum, val) => sum + (val || 0), 0);
        const netIncome = totalIncome - totalExpense;
        await analyticsRef.set({
            source: constants_1.TRANSACTIONS_SOURCE_KEY,
            organizationId,
            month: monthKey,
            financialYear,
            incomeDaily: cleanedIncomeDaily,
            receivablesDaily: cleanedReceivablesDaily,
            expenseDaily: cleanedExpenseDaily,
            incomeByCategory,
            receivablesByCategory,
            byType,
            byPaymentAccount,
            byPaymentMethodType,
            totalIncome,
            totalReceivables,
            netReceivables,
            receivableAging,
            totalExpense,
            netIncome,
            transactionCount,
            completedTransactionCount,
            totalPayableToVendors,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    await Promise.all(monthUpdates);
}
/**
 * Cloud Function: Scheduled function to rebuild all client ledgers
 * Runs every 24 hours (midnight UTC) to recalculate ledger balances
 */
// Function removed: replaced by LedgerMaintenanceManager
//# sourceMappingURL=transaction-rebuild.js.map