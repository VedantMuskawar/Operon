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
exports.onTransactionUpdated = exports.onTransactionCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("./shared/constants");
const firestore_helpers_1 = require("./shared/firestore-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Get ISO week number for a date
 * ISO week starts on Monday and week 1 is the first week with at least 4 days in the new year
 * Returns format: YYYY-Www (e.g., "2024-W14")
 */
function getISOWeek(date) {
    const d = new Date(date);
    d.setUTCHours(0, 0, 0, 0);
    // Find the Thursday of the week (ISO week starts on Monday)
    const dayOfWeek = d.getUTCDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
    const thursdayOffset = dayOfWeek === 0 ? -3 : 4 - dayOfWeek;
    const thursday = new Date(d);
    thursday.setUTCDate(d.getUTCDate() + thursdayOffset);
    // January 4th is always in week 1
    const jan4 = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 4));
    const jan4DayOfWeek = jan4.getUTCDay();
    const jan4ThursdayOffset = jan4DayOfWeek === 0 ? -3 : 4 - jan4DayOfWeek;
    const jan4Thursday = new Date(jan4);
    jan4Thursday.setUTCDate(jan4.getUTCDate() + jan4ThursdayOffset);
    // Calculate week number
    const daysDiff = Math.floor((thursday.getTime() - jan4Thursday.getTime()) / (1000 * 60 * 60 * 24));
    const weekNumber = Math.floor(daysDiff / 7) + 1;
    return `${thursday.getUTCFullYear()}-W${String(weekNumber).padStart(2, '0')}`;
}
/**
 * Format date as YYYY-MM-DD
 */
function formatDate(date) {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`;
}
/**
 * Format date as YYYY-MM (for monthly breakdown)
 */
function formatMonth(date) {
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}
/**
 * Clean up daily data older than specified days
 */
function cleanDailyData(dailyData, keepDays) {
    const cutoffDate = new Date();
    cutoffDate.setUTCDate(cutoffDate.getUTCDate() - keepDays);
    const cleaned = {};
    for (const [dateString, value] of Object.entries(dailyData)) {
        try {
            const parts = dateString.split('-');
            if (parts.length === 3) {
                const date = new Date(Date.UTC(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10)));
                if (date >= cutoffDate) {
                    cleaned[dateString] = value;
                }
            }
        }
        catch (e) {
            // Skip invalid date strings
        }
    }
    return cleaned;
}
/**
 * Get transaction date from transaction document
 */
function getTransactionDate(snapshot) {
    var _a, _b;
    const createdAt = snapshot.get('createdAt');
    if (createdAt) {
        return createdAt.toDate();
    }
    return (_b = (_a = snapshot.createTime) === null || _a === void 0 ? void 0 : _a.toDate()) !== null && _b !== void 0 ? _b : new Date();
}
/**
 * Update client ledger when transaction is created or cancelled
 */
async function updateClientLedger(organizationId, clientId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    const ledgerId = `${clientId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
    const amount = transaction.amount;
    const category = transaction.category; // 'income' or 'expense'
    const status = transaction.status;
    const isIncome = category === 'income';
    const multiplier = isCancellation ? -1 : 1;
    await db.runTransaction(async (tx) => {
        const ledgerDoc = await tx.get(ledgerRef);
        if (!ledgerDoc.exists && !isCancellation) {
            // Create new ledger document
            const balanceChange = isIncome ? amount : -amount;
            tx.set(ledgerRef, {
                ledgerId,
                organizationId,
                clientId,
                financialYear,
                openingBalance: 0,
                currentBalance: balanceChange * multiplier,
                totalIncome: isIncome ? amount * multiplier : 0,
                totalExpense: !isIncome ? amount * multiplier : 0,
                netBalance: balanceChange * multiplier,
                transactionCount: 1,
                completedTransactionCount: status === 'completed' ? 1 : 0,
                cancelledTransactionCount: 0,
                transactionIds: [transactionId],
                lastTransactionId: transactionId,
                lastTransactionDate: admin.firestore.FieldValue.serverTimestamp(),
                lastTransactionAmount: amount,
                metadata: {},
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else if (ledgerDoc.exists) {
            // Update existing ledger
            const ledgerData = ledgerDoc.data();
            const currentBalance = ledgerData.currentBalance || 0;
            const totalIncome = ledgerData.totalIncome || 0;
            const totalExpense = ledgerData.totalExpense || 0;
            const transactionIds = ledgerData.transactionIds || [];
            const balanceChange = isIncome ? amount : -amount;
            const newBalance = currentBalance + (balanceChange * multiplier);
            const updates = {
                currentBalance: newBalance,
                netBalance: newBalance,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (isIncome) {
                updates.totalIncome = totalIncome + (amount * multiplier);
            }
            else {
                updates.totalExpense = totalExpense + (amount * multiplier);
            }
            if (isCancellation) {
                updates.cancelledTransactionCount = (ledgerData.cancelledTransactionCount || 0) + 1;
                if (status === 'completed') {
                    updates.completedTransactionCount = Math.max(0, (ledgerData.completedTransactionCount || 0) - 1);
                }
            }
            else {
                updates.transactionCount = (ledgerData.transactionCount || 0) + 1;
                if (status === 'completed') {
                    updates.completedTransactionCount = (ledgerData.completedTransactionCount || 0) + 1;
                }
                if (!transactionIds.includes(transactionId)) {
                    updates.transactionIds = admin.firestore.FieldValue.arrayUnion(transactionId);
                }
                updates.lastTransactionId = transactionId;
                updates.lastTransactionDate = admin.firestore.FieldValue.serverTimestamp();
                updates.lastTransactionAmount = amount;
            }
            tx.update(ledgerRef, updates);
        }
    });
    // Create/update transaction in subcollection
    const transactionSubRef = ledgerRef.collection('TRANSACTIONS').doc(transactionId);
    const transactionDate = getTransactionDate(snapshot);
    const transactionData = {
        transactionId,
        organizationId,
        clientId,
        type: transaction.type,
        category: transaction.category,
        amount: transaction.amount,
        status: transaction.status,
        financialYear: transaction.financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        transactionType: transaction.type,
        createdAt: transaction.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (transaction.paymentAccountId) {
        transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
        transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
        transactionData.referenceNumber = transaction.referenceNumber;
    }
    if (transaction.orderId) {
        transactionData.orderId = transaction.orderId;
    }
    if (transaction.description) {
        transactionData.description = transaction.description;
    }
    if (transaction.metadata) {
        transactionData.metadata = transaction.metadata;
    }
    if (transaction.createdBy) {
        transactionData.createdBy = transaction.createdBy;
    }
    if (transaction.balanceBefore !== undefined) {
        transactionData.balanceBefore = transaction.balanceBefore;
    }
    if (transaction.balanceAfter !== undefined) {
        transactionData.balanceAfter = transaction.balanceAfter;
    }
    if (isCancellation) {
        transactionData.cancelledAt = transaction.cancelledAt || admin.firestore.FieldValue.serverTimestamp();
        if (transaction.cancelledBy) {
            transactionData.cancelledBy = transaction.cancelledBy;
        }
        if (transaction.cancellationReason) {
            transactionData.cancellationReason = transaction.cancellationReason;
        }
    }
    await transactionSubRef.set(transactionData, { merge: true });
}
/**
 * Update analytics when transaction is created or cancelled
 */
async function updateTransactionAnalytics(organizationId, financialYear, transaction, transactionDate, isCancellation = false) {
    const analyticsDocId = `${constants_1.TRANSACTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
    const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
    const amount = transaction.amount;
    const category = transaction.category;
    const type = transaction.type;
    const status = transaction.status;
    const paymentAccountId = transaction.paymentAccountId;
    const paymentAccountType = transaction.paymentAccountType;
    const multiplier = isCancellation ? -1 : 1;
    const isIncome = category === 'income';
    const dateString = formatDate(transactionDate);
    const weekString = getISOWeek(transactionDate);
    const monthString = formatMonth(transactionDate);
    // Get current analytics data
    const analyticsDoc = await analyticsRef.get();
    const analyticsData = analyticsDoc.exists ? analyticsDoc.data() : {};
    // Clean daily data (keep only last 90 days)
    const incomeDaily = cleanDailyData(analyticsData.incomeDaily || {}, 90);
    const expenseDaily = cleanDailyData(analyticsData.expenseDaily || {}, 90);
    // Update daily breakdown
    if (isIncome) {
        incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
    }
    else {
        expenseDaily[dateString] = (expenseDaily[dateString] || 0) + (amount * multiplier);
    }
    // Update weekly breakdown
    const incomeWeekly = analyticsData.incomeWeekly || {};
    const expenseWeekly = analyticsData.expenseWeekly || {};
    if (isIncome) {
        incomeWeekly[weekString] = (incomeWeekly[weekString] || 0) + (amount * multiplier);
    }
    else {
        expenseWeekly[weekString] = (expenseWeekly[weekString] || 0) + (amount * multiplier);
    }
    // Update monthly breakdown
    const incomeMonthly = analyticsData.incomeMonthly || {};
    const expenseMonthly = analyticsData.expenseMonthly || {};
    if (isIncome) {
        incomeMonthly[monthString] = (incomeMonthly[monthString] || 0) + (amount * multiplier);
    }
    else {
        expenseMonthly[monthString] = (expenseMonthly[monthString] || 0) + (amount * multiplier);
    }
    // Update by type breakdown
    const byType = analyticsData.byType || {};
    if (!byType[type]) {
        byType[type] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
    }
    byType[type].count += multiplier;
    byType[type].total += (amount * multiplier);
    // Update type daily/weekly/monthly
    if (!byType[type].daily)
        byType[type].daily = {};
    if (!byType[type].weekly)
        byType[type].weekly = {};
    if (!byType[type].monthly)
        byType[type].monthly = {};
    byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
    byType[type].weekly[weekString] = (byType[type].weekly[weekString] || 0) + (amount * multiplier);
    byType[type].monthly[monthString] = (byType[type].monthly[monthString] || 0) + (amount * multiplier);
    // Clean type daily data
    byType[type].daily = cleanDailyData(byType[type].daily, 90);
    // Update by payment account breakdown
    const byPaymentAccount = analyticsData.byPaymentAccount || {};
    const accountId = paymentAccountId || 'cash';
    if (paymentAccountId && paymentAccountId !== 'cash') {
        if (!byPaymentAccount[accountId]) {
            byPaymentAccount[accountId] = {
                accountId,
                accountName: accountId,
                accountType: paymentAccountType || 'other',
                count: 0,
                total: 0,
                daily: {},
                weekly: {},
                monthly: {},
            };
        }
        byPaymentAccount[accountId].count += multiplier;
        byPaymentAccount[accountId].total += (amount * multiplier);
        if (!byPaymentAccount[accountId].daily)
            byPaymentAccount[accountId].daily = {};
        if (!byPaymentAccount[accountId].weekly)
            byPaymentAccount[accountId].weekly = {};
        if (!byPaymentAccount[accountId].monthly)
            byPaymentAccount[accountId].monthly = {};
        byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
    }
    else if (accountId === 'cash') {
        if (!byPaymentAccount[accountId]) {
            byPaymentAccount[accountId] = {
                accountId: 'cash',
                accountName: 'Cash',
                accountType: 'cash',
                count: 0,
                total: 0,
                daily: {},
                weekly: {},
                monthly: {},
            };
        }
        byPaymentAccount[accountId].count += multiplier;
        byPaymentAccount[accountId].total += (amount * multiplier);
        if (!byPaymentAccount[accountId].daily)
            byPaymentAccount[accountId].daily = {};
        if (!byPaymentAccount[accountId].weekly)
            byPaymentAccount[accountId].weekly = {};
        if (!byPaymentAccount[accountId].monthly)
            byPaymentAccount[accountId].monthly = {};
        byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].monthly[monthString] = (byPaymentAccount[accountId].monthly[monthString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].daily = cleanDailyData(byPaymentAccount[accountId].daily, 90);
    }
    // Update by payment method type breakdown
    const byPaymentMethodType = analyticsData.byPaymentMethodType || {};
    const methodType = paymentAccountType || 'cash';
    if (!byPaymentMethodType[methodType]) {
        byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {}, weekly: {}, monthly: {} };
    }
    byPaymentMethodType[methodType].count += multiplier;
    byPaymentMethodType[methodType].total += (amount * multiplier);
    if (!byPaymentMethodType[methodType].daily)
        byPaymentMethodType[methodType].daily = {};
    if (!byPaymentMethodType[methodType].weekly)
        byPaymentMethodType[methodType].weekly = {};
    if (!byPaymentMethodType[methodType].monthly)
        byPaymentMethodType[methodType].monthly = {};
    byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].weekly[weekString] = (byPaymentMethodType[methodType].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].monthly[monthString] = (byPaymentMethodType[methodType].monthly[monthString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].daily = cleanDailyData(byPaymentMethodType[methodType].daily, 90);
    // Calculate totals
    const totalIncome = Object.values(incomeMonthly).reduce((sum, val) => sum + (val || 0), 0);
    const totalExpense = Object.values(expenseMonthly).reduce((sum, val) => sum + (val || 0), 0);
    const netIncome = totalIncome - totalExpense;
    const transactionCount = (analyticsData.transactionCount || 0) + multiplier;
    const completedTransactionCount = status === 'completed'
        ? ((analyticsData.completedTransactionCount || 0) + multiplier)
        : (analyticsData.completedTransactionCount || 0);
    const cancelledTransactionCount = isCancellation
        ? ((analyticsData.cancelledTransactionCount || 0) + multiplier)
        : (analyticsData.cancelledTransactionCount || 0);
    // Update analytics document
    await analyticsRef.set({
        source: constants_1.TRANSACTIONS_SOURCE_KEY,
        organizationId,
        financialYear,
        incomeDaily,
        expenseDaily,
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
        transactionCount: Math.max(0, transactionCount),
        completedTransactionCount: Math.max(0, completedTransactionCount),
        cancelledTransactionCount: Math.max(0, cancelledTransactionCount),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
/**
 * Cloud Function: Triggered when a transaction is created
 */
exports.onTransactionCreated = functions.firestore
    .document(`${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}`)
    .onCreate(async (snapshot, context) => {
    var _a;
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;
    const organizationId = transaction.organizationId;
    const clientId = transaction.clientId;
    const financialYear = transaction.financialYear;
    if (!organizationId || !clientId || !financialYear) {
        console.error('[Transaction] Missing required fields', {
            transactionId,
            organizationId,
            clientId,
            financialYear,
        });
        return;
    }
    const transactionDate = getTransactionDate(snapshot);
    try {
        // Get current balance from ledger to set balanceBefore and balanceAfter
        const ledgerId = `${clientId}_${financialYear}`;
        const ledgerRef = db.collection(constants_1.CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
        const ledgerDoc = await ledgerRef.get();
        const balanceBefore = ledgerDoc.exists
            ? (((_a = ledgerDoc.data()) === null || _a === void 0 ? void 0 : _a.currentBalance) || 0)
            : 0;
        const amount = transaction.amount;
        const category = transaction.category;
        const balanceChange = category === 'income' ? amount : -amount;
        const balanceAfter = balanceBefore + balanceChange;
        // Update transaction with balance information
        await snapshot.ref.update({
            balanceBefore,
            balanceAfter,
        });
        // Update client ledger
        await updateClientLedger(organizationId, clientId, financialYear, Object.assign(Object.assign({}, transaction), { balanceBefore, balanceAfter }), transactionId, snapshot, false);
        // Update analytics
        await updateTransactionAnalytics(organizationId, financialYear, Object.assign(Object.assign({}, transaction), { balanceBefore, balanceAfter }), transactionDate, false);
        console.log('[Transaction] Successfully processed transaction creation', {
            transactionId,
            organizationId,
            clientId,
            financialYear,
        });
    }
    catch (error) {
        console.error('[Transaction] Error processing transaction creation', {
            transactionId,
            error,
        });
        throw error;
    }
});
/**
 * Cloud Function: Triggered when a transaction is updated (for cancellations)
 */
exports.onTransactionUpdated = functions.firestore
    .document(`${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}`)
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const transactionId = context.params.transactionId;
    // Only process if status changed to cancelled
    const beforeStatus = before.status;
    const afterStatus = after.status;
    if (beforeStatus !== 'cancelled' && afterStatus === 'cancelled') {
        const organizationId = after.organizationId;
        const clientId = after.clientId;
        const financialYear = after.financialYear;
        if (!organizationId || !clientId || !financialYear) {
            console.error('[Transaction] Missing required fields for cancellation', {
                transactionId,
                organizationId,
                clientId,
                financialYear,
            });
            return;
        }
        const transactionDate = getTransactionDate(change.after);
        try {
            // Reverse the transaction in ledger
            await updateClientLedger(organizationId, clientId, financialYear, after, transactionId, change.after, true // isCancellation
            );
            // Reverse in analytics
            await updateTransactionAnalytics(organizationId, financialYear, after, transactionDate, true // isCancellation
            );
            console.log('[Transaction] Successfully processed transaction cancellation', {
                transactionId,
                organizationId,
                clientId,
                financialYear,
            });
        }
        catch (error) {
            console.error('[Transaction] Error processing transaction cancellation', {
                transactionId,
                error,
            });
            throw error;
        }
    }
});
//# sourceMappingURL=transactions.js.map