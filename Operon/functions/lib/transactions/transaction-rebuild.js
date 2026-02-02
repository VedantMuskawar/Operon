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
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
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
 * Exported for use by unified analytics rebuild.
 */
async function rebuildTransactionAnalyticsForOrg(organizationId, financialYear) {
    var _a;
    const analyticsDocId = `${constants_1.TRANSACTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
    const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
    // Get all transactions for this organization in this FY
    const transactionsSnapshot = await db
        .collection(constants_1.TRANSACTIONS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('financialYear', '==', financialYear)
        .get();
    const incomeDaily = {};
    const expenseDaily = {};
    const incomeWeekly = {};
    const expenseWeekly = {};
    const incomeMonthly = {};
    const expenseMonthly = {};
    const byType = {};
    const byPaymentAccount = {};
    const byPaymentMethodType = {};
    const fuelPurchaseMonthly = {};
    let fuelPurchaseYearly = 0;
    const fuelByVehicleMonthly = {};
    const fuelByVehicleYearly = {};
    const fuelDistanceByVehicleMonthly = {};
    const fuelDistanceByVehicleYearly = {};
    const fuelAverageByVehicleMonthly = {};
    const fuelAverageByVehicleYearly = {};
    let totalPayableToVendors = 0;
    let transactionCount = 0;
    let completedTransactionCount = 0;
    transactionsSnapshot.forEach((doc) => {
        var _a, _b;
        const tx = doc.data();
        const status = tx.status;
        const category = tx.category;
        const type = tx.type;
        const amount = tx.amount;
        const paymentAccountId = tx.paymentAccountId;
        const paymentAccountType = tx.paymentAccountType;
        // All transactions in database are active (cancelled ones are deleted)
        transactionCount++;
        if (status === 'completed') {
            completedTransactionCount++;
        }
        const isIncome = category === 'income';
        const multiplier = 1; // All transactions here are non-cancelled
        // Get transaction date
        const createdAt = tx.createdAt;
        const transactionDate = createdAt ? createdAt.toDate() : (_b = (_a = doc.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
        const dateString = (0, date_helpers_1.formatDate)(transactionDate);
        const weekString = (0, date_helpers_1.getISOWeek)(transactionDate);
        const monthString = (0, date_helpers_1.formatMonth)(transactionDate);
        // Update daily/weekly/monthly breakdowns
        if (isIncome) {
            incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
            incomeWeekly[weekString] = (incomeWeekly[weekString] || 0) + (amount * multiplier);
            incomeMonthly[monthString] = (incomeMonthly[monthString] || 0) + (amount * multiplier);
        }
        else {
            expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
            expenseWeekly[weekString] = (expenseWeekly[weekString] || 0) + (amount * multiplier);
            expenseMonthly[monthString] = (expenseMonthly[monthString] || 0) + (amount * multiplier);
        }
        // Update by type breakdown
        if (!byType[type]) {
            byType[type] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
        }
        byType[type].count += multiplier;
        byType[type].total += (amount * multiplier);
        byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
        byType[type].weekly[weekString] = (byType[type].weekly[weekString] || 0) + (amount * multiplier);
        byType[type].monthly[monthString] = (byType[type].monthly[monthString] || 0) + (amount * multiplier);
        // Update by payment account breakdown
        const accountId = paymentAccountId || 'cash';
        if (!byPaymentAccount[accountId]) {
            byPaymentAccount[accountId] = {
                accountId,
                accountName: accountId === 'cash' ? 'Cash' : accountId,
                accountType: paymentAccountType || (accountId === 'cash' ? 'cash' : 'other'),
                count: 0,
                total: 0,
                daily: {},
                weekly: {},
                monthly: {},
            };
        }
        byPaymentAccount[accountId].count += multiplier;
        byPaymentAccount[accountId].total += (amount * multiplier);
        byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
        // Update by payment method type breakdown
        const methodType = paymentAccountType || 'cash';
        if (!byPaymentMethodType[methodType]) {
            byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
        }
        byPaymentMethodType[methodType].count += multiplier;
        byPaymentMethodType[methodType].total += (amount * multiplier);
        byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
        byPaymentMethodType[methodType].weekly[weekString] = (byPaymentMethodType[methodType].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentMethodType[methodType].monthly[monthString] = (byPaymentMethodType[methodType].monthly[monthString] || 0) + (amount * multiplier);
        // Total payable to vendors: vendorLedger + type credit
        const ledgerType = tx.ledgerType;
        if (ledgerType === 'vendorLedger' && type === 'credit') {
            totalPayableToVendors += amount;
        }
        // Fuel purchases: metadata.purchaseType === 'fuel' or (category vendorPurchase + metadata.purchaseType fuel)
        const metadata = tx.metadata || {};
        const purchaseType = metadata.purchaseType;
        const isFuelPurchase = purchaseType === 'fuel' ||
            (category === 'vendorPurchase' && purchaseType === 'fuel');
        if (isFuelPurchase && amount > 0) {
            const monthKey = (0, date_helpers_1.getYearMonth)(transactionDate);
            fuelPurchaseMonthly[monthKey] = (fuelPurchaseMonthly[monthKey] || 0) + amount;
            fuelPurchaseYearly += amount;
            const vehicleNumber = metadata.vehicleNumber || 'unknown';
            if (!fuelByVehicleMonthly[vehicleNumber]) {
                fuelByVehicleMonthly[vehicleNumber] = {};
                fuelByVehicleYearly[vehicleNumber] = 0;
                fuelDistanceByVehicleMonthly[vehicleNumber] = {};
                fuelDistanceByVehicleYearly[vehicleNumber] = 0;
            }
            fuelByVehicleMonthly[vehicleNumber][monthKey] =
                (fuelByVehicleMonthly[vehicleNumber][monthKey] || 0) + amount;
            fuelByVehicleYearly[vehicleNumber] += amount;
            const linkedTrips = metadata.linkedTrips || [];
            let totalDistance = 0;
            for (const trip of linkedTrips) {
                totalDistance += trip.distanceKm || 0;
            }
            if (totalDistance > 0) {
                fuelDistanceByVehicleMonthly[vehicleNumber][monthKey] =
                    (fuelDistanceByVehicleMonthly[vehicleNumber][monthKey] || 0) + totalDistance;
                fuelDistanceByVehicleYearly[vehicleNumber] += totalDistance;
            }
        }
    });
    // Compute fuel average (amount / distance = cost per km) per vehicle per month/year
    for (const [vehicle, monthlyAmounts] of Object.entries(fuelByVehicleMonthly)) {
        if (!fuelAverageByVehicleMonthly[vehicle]) {
            fuelAverageByVehicleMonthly[vehicle] = {};
        }
        for (const [monthKey, amt] of Object.entries(monthlyAmounts)) {
            const dist = ((_a = fuelDistanceByVehicleMonthly[vehicle]) === null || _a === void 0 ? void 0 : _a[monthKey]) || 0;
            if (dist > 0) {
                fuelAverageByVehicleMonthly[vehicle][monthKey] = amt / dist;
            }
        }
    }
    for (const [vehicle, yearlyAmt] of Object.entries(fuelByVehicleYearly)) {
        const yearlyDist = fuelDistanceByVehicleYearly[vehicle] || 0;
        if (yearlyDist > 0) {
            fuelAverageByVehicleYearly[vehicle] = yearlyAmt / yearlyDist;
        }
    }
    // Clean daily data (keep only last 90 days)
    const cleanedIncomeDaily = (0, date_helpers_1.cleanDailyData)(incomeDaily, 90);
    const cleanedExpenseDaily = (0, date_helpers_1.cleanDailyData)(expenseDaily, 90);
    // Clean daily data for each breakdown
    Object.keys(byType).forEach((type) => {
        byType[type].daily = (0, date_helpers_1.cleanDailyData)(byType[type].daily, 90);
    });
    Object.keys(byPaymentAccount).forEach((accountId) => {
        byPaymentAccount[accountId].daily = (0, date_helpers_1.cleanDailyData)(byPaymentAccount[accountId].daily, 90);
    });
    Object.keys(byPaymentMethodType).forEach((methodType) => {
        byPaymentMethodType[methodType].daily = (0, date_helpers_1.cleanDailyData)(byPaymentMethodType[methodType].daily, 90);
    });
    // Calculate totals
    const totalIncome = Object.values(incomeMonthly).reduce((sum, val) => sum + (val || 0), 0);
    const totalExpense = Object.values(expenseMonthly).reduce((sum, val) => sum + (val || 0), 0);
    const netIncome = totalIncome - totalExpense;
    // Update analytics document
    await analyticsRef.set({
        source: constants_1.TRANSACTIONS_SOURCE_KEY,
        organizationId,
        financialYear,
        incomeDaily: cleanedIncomeDaily,
        expenseDaily: cleanedExpenseDaily,
        incomeWeekly,
        expenseWeekly,
        incomeMonthly,
        expenseMonthly,
        byType,
        byPaymentAccount,
        byPaymentMethodType,
        totalIncome,
        totalExpense,
        netIncome,
        transactionCount,
        completedTransactionCount,
        totalPayableToVendors,
        fuelPurchaseMonthly: { values: fuelPurchaseMonthly },
        fuelPurchaseYearly,
        fuelByVehicleMonthly,
        fuelByVehicleYearly,
        fuelAverageByVehicleMonthly,
        fuelAverageByVehicleYearly,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
/**
 * Cloud Function: Scheduled function to rebuild all client ledgers
 * Runs every 24 hours to recalculate ledger balances
 */
exports.rebuildClientLedgers = functions.pubsub
    .schedule('every 24 hours')
    .timeZone('UTC')
    .onRun(async () => {
    const now = new Date();
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(now);
    // Get all client ledger documents for current FY
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