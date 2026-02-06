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
exports.rebuildClientLedgers = void 0;
exports.rebuildTransactionAnalyticsForOrg = rebuildTransactionAnalyticsForOrg;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Get previous financial year label
 */
function getPreviousFinancialYear(currentFY) {
    const match = currentFY.match(/FY(\d{2})(\d{2})/);
    if (!match) {
        throw new Error(`Invalid financial year format: ${currentFY}`);
    }
    const startYear = parseInt(match[1], 10);
    const endYear = parseInt(match[2], 10);
    const prevStartYear = startYear - 1;
    const prevEndYear = endYear - 1;
    return `FY${String(prevStartYear).padStart(2, '0')}${String(prevEndYear).padStart(2, '0')}`;
}
/**
 * Get opening balance from previous financial year
 */
async function getOpeningBalance(organizationId, clientId, currentFY) {
    try {
        const previousFY = getPreviousFinancialYear(currentFY);
        const previousLedgerId = `${clientId}_${previousFY}`;
        const previousLedgerRef = db.collection(constants_1.CLIENT_LEDGERS_COLLECTION).doc(previousLedgerId);
        const previousLedgerDoc = await previousLedgerRef.get();
        if (previousLedgerDoc.exists) {
            const previousLedgerData = previousLedgerDoc.data();
            return previousLedgerData.currentBalance || 0;
        }
    }
    catch (error) {
        console.warn('[Ledger Rebuild] Error fetching previous FY balance, defaulting to 0', {
            organizationId,
            clientId,
            currentFY,
            error,
        });
    }
    return 0;
}
/**
 * Get financial year date range
 */
function getFinancialYearDates(financialYear) {
    const match = financialYear.match(/FY(\d{2})(\d{2})/);
    if (!match) {
        throw new Error(`Invalid financial year format: ${financialYear}`);
    }
    const startYear = 2000 + parseInt(match[1], 10);
    const endYear = 2000 + parseInt(match[2], 10);
    const start = new Date(Date.UTC(startYear, 3, 1, 0, 0, 0));
    const end = new Date(Date.UTC(endYear, 3, 1, 0, 0, 0));
    return { start, end };
}
/**
 * Rebuild client ledger for a specific client and financial year
 */
async function rebuildClientLedger(organizationId, clientId, financialYear) {
    const ledgerId = `${clientId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
    // Get opening balance from previous FY
    const openingBalance = await getOpeningBalance(organizationId, clientId, financialYear);
    // Get FY date range
    const fyDates = getFinancialYearDates(financialYear);
    // Get all monthly transaction documents for this client in this FY
    // Documents are stored as: TRANSACTIONS/{yearMonth} where yearMonth = YYYYMM
    const transactionsSubRef = ledgerRef.collection('TRANSACTIONS');
    const monthlyDocsSnapshot = await transactionsSubRef.get();
    // Extract all transactions from monthly documents and flatten into single array
    const allTransactions = [];
    monthlyDocsSnapshot.forEach((monthlyDoc) => {
        const monthlyData = monthlyDoc.data();
        const transactions = monthlyData.transactions || [];
        allTransactions.push(...transactions);
    });
    // Sort transactions by transactionDate (ascending)
    allTransactions.sort((a, b) => {
        var _a, _b, _c, _d;
        const dateA = (_b = (_a = a.transactionDate) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date(0);
        const dateB = (_d = (_c = b.transactionDate) === null || _c === void 0 ? void 0 : _c.toDate()) !== null && _d !== void 0 ? _d : new Date(0);
        return dateA.getTime() - dateB.getTime();
    });
    let currentBalance = openingBalance;
    let totalReceivables = 0; // Total receivables (credit transactions - what client owes us)
    let transactionCount = 0;
    const transactionIds = [];
    let lastTransactionId;
    let lastTransactionDate;
    let lastTransactionAmount;
    let firstTransactionDate;
    allTransactions.forEach((tx) => {
        const type = tx.type;
        const amount = tx.amount;
        const ledgerType = tx.ledgerType || 'clientLedger';
        // Use ledgerDelta logic (same as in updateClientLedger)
        // For ClientLedger: Credit = increment receivable, Debit = decrement receivable
        const ledgerDelta = ledgerType === 'clientLedger'
            ? (type === 'credit' ? amount : -amount)
            : (type === 'credit' ? amount : -amount); // Default to same semantics
        transactionIds.push(tx.transactionId);
        transactionCount++;
        // All transactions in database are active (cancelled ones are deleted)
        currentBalance += ledgerDelta;
        // Track total receivables (only credit transactions)
        // Credit = client owes us (receivables)
        // Debit = client paid us (reduces receivables, but not tracked as receivables)
        if (type === 'credit') {
            totalReceivables += amount;
        }
        lastTransactionId = tx.transactionId;
        lastTransactionDate = tx.transactionDate;
        lastTransactionAmount = amount;
        // Set first transaction date
        if (!firstTransactionDate) {
            firstTransactionDate = tx.transactionDate;
        }
    });
    // Update or create ledger document
    // For ClientLedger: Only track receivables (currentBalance), not expenses/income
    await ledgerRef.set({
        ledgerId,
        organizationId,
        clientId,
        financialYear,
        fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
        fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
        openingBalance,
        currentBalance, // Total receivables balance (what client owes)
        totalReceivables, // Total receivables created (credit transactions)
        transactionCount,
        transactionIds,
        lastTransactionId: lastTransactionId || null,
        lastTransactionDate: lastTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
        lastTransactionAmount: lastTransactionAmount || null,
        firstTransactionDate: firstTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
        metadata: {},
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
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
exports.rebuildClientLedgers = (0, scheduler_1.onSchedule)(Object.assign({ schedule: '0 0 * * *', timeZone: 'UTC' }, function_config_1.SCHEDULED_FUNCTION_OPTS), async () => {
    const now = new Date();
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(now);
    const ledgersSnapshot = await db
        .collection(constants_1.CLIENT_LEDGERS_COLLECTION)
        .where('financialYear', '==', fyLabel)
        .get();
    const rebuildPromises = ledgersSnapshot.docs.map(async (ledgerDoc) => {
        const ledgerData = ledgerDoc.data();
        const organizationId = ledgerData.organizationId;
        const clientId = ledgerData.clientId;
        const financialYear = ledgerData.financialYear;
        if (!organizationId || !clientId || !financialYear) {
            console.warn('[Client Ledger Rebuild] Missing required fields', {
                ledgerId: ledgerDoc.id,
                organizationId,
                clientId,
                financialYear,
            });
            return;
        }
        try {
            await rebuildClientLedger(organizationId, clientId, financialYear);
            console.log('[Client Ledger Rebuild] Successfully rebuilt', {
                organizationId,
                clientId,
                financialYear,
            });
        }
        catch (error) {
            console.error('[Client Ledger Rebuild] Error rebuilding ledger', {
                organizationId,
                clientId,
                financialYear,
                error,
            });
        }
    });
    await Promise.all(rebuildPromises);
    console.log(`[Client Ledger Rebuild] Rebuilt ${ledgersSnapshot.size} client ledgers`);
});
//# sourceMappingURL=transaction-rebuild.js.map