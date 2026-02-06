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
exports.onTransactionDeleted = exports.onTransactionCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const financial_year_1 = require("../shared/financial-year");
const date_helpers_1 = require("../shared/date-helpers");
const transaction_helpers_1 = require("../shared/transaction-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Get previous financial year label
 */
function getPreviousFinancialYear(currentFY) {
    // Extract years from FY label (e.g., "FY2425" -> 2024, 2025)
    const match = currentFY.match(/FY(\d{2})(\d{2})/);
    if (!match) {
        throw new Error(`Invalid financial year format: ${currentFY}`);
    }
    const startYear = parseInt(match[1], 10);
    const endYear = parseInt(match[2], 10);
    // Calculate previous FY
    const prevStartYear = startYear - 1;
    const prevEndYear = endYear - 1;
    return `FY${String(prevStartYear).padStart(2, '0')}${String(prevEndYear).padStart(2, '0')}`;
}
/**
 * Get opening balance from previous financial year (for clients)
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
        console.warn('[Ledger] Error fetching previous FY balance, defaulting to 0', {
            organizationId,
            clientId,
            currentFY,
            error,
        });
    }
    return 0;
}
/**
 * Get opening balance from previous financial year (for vendors)
 */
async function getVendorOpeningBalance(organizationId, vendorId, currentFY) {
    try {
        const previousFY = getPreviousFinancialYear(currentFY);
        const previousLedgerId = `${vendorId}_${previousFY}`;
        const previousLedgerRef = db.collection(constants_1.VENDOR_LEDGERS_COLLECTION).doc(previousLedgerId);
        const previousLedgerDoc = await previousLedgerRef.get();
        if (previousLedgerDoc.exists) {
            const previousLedgerData = previousLedgerDoc.data();
            return previousLedgerData.currentBalance || 0;
        }
    }
    catch (error) {
        console.warn('[Vendor Ledger] Error fetching previous FY balance, defaulting to 0', {
            organizationId,
            vendorId,
            currentFY,
            error,
        });
    }
    return 0;
}
/**
 * Get opening balance from previous financial year (for employees)
 */
async function getEmployeeOpeningBalance(organizationId, employeeId, currentFY) {
    try {
        const previousFY = getPreviousFinancialYear(currentFY);
        const previousLedgerId = `${employeeId}_${previousFY}`;
        const previousLedgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(previousLedgerId);
        const previousLedgerDoc = await previousLedgerRef.get();
        if (previousLedgerDoc.exists) {
            const previousLedgerData = previousLedgerDoc.data();
            return previousLedgerData.currentBalance || 0;
        }
    }
    catch (error) {
        console.warn('[Employee Ledger] Error fetching previous FY balance, defaulting to 0', {
            organizationId,
            employeeId,
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
    // FY starts in April (month 3, 0-indexed)
    const start = new Date(Date.UTC(startYear, 3, 1, 0, 0, 0));
    const end = new Date(Date.UTC(endYear, 3, 1, 0, 0, 0));
    return { start, end };
}
/**
 * Calculate ledger delta based on ledgerType and transaction type
 * @param ledgerType - The ledger type (e.g., 'clientLedger')
 * @param type - Transaction type ('credit' or 'debit')
 * @param amount - Transaction amount
 * @returns The balance change amount (positive for increment, negative for decrement)
 */
function getLedgerDelta(ledgerType, type, amount) {
    if (ledgerType === 'clientLedger') {
        // For ClientLedger: Credit = increment receivable, Debit = decrement receivable
        // Credit means client owes us (increases receivable/balance)
        // Debit means client paid us (decreases receivable/balance)
        const delta = type === 'credit' ? amount : -amount;
        console.log('[Transaction] getLedgerDelta calculation', {
            ledgerType,
            type,
            amount,
            delta,
            explanation: type === 'credit' ? 'Credit: client owes us (+amount)' : 'Debit: client paid us (-amount)',
        });
        return delta;
    }
    if (ledgerType === 'vendorLedger') {
        // For VendorLedger: Credit = increment payable (we owe vendor), Debit = decrement payable (we paid vendor)
        // Credit means purchase from vendor (increases payable/balance)
        // Debit means payment to vendor (decreases payable/balance)
        const delta = type === 'credit' ? amount : -amount;
        console.log('[Transaction] getLedgerDelta calculation (vendorLedger)', {
            ledgerType,
            type,
            amount,
            delta,
            explanation: type === 'credit' ? 'Credit: purchase from vendor (+amount, we owe them)' : 'Debit: payment to vendor (-amount, we paid them)',
        });
        return delta;
    }
    if (ledgerType === 'employeeLedger') {
        // For EmployeeLedger: Credit = increment payable (we owe employee), Debit = decrement payable (we paid employee)
        // Credit means salary/bonus credited (increases payable/balance - we owe more)
        // Debit means payment/advance to employee (decreases payable/balance - we paid/owe less)
        const delta = type === 'credit' ? amount : -amount;
        console.log('[Transaction] getLedgerDelta calculation (employeeLedger)', {
            ledgerType,
            type,
            amount,
            delta,
            explanation: type === 'credit' ? 'Credit: salary/bonus credited (+amount, we owe employee)' : 'Debit: payment/advance to employee (-amount, we paid employee)',
        });
        return delta;
    }
    if (ledgerType === 'organizationLedger') {
        // For OrganizationLedger: Credit = refund/adjustment (decreases expense total), Debit = expense (increases expense total)
        // Credit means refund/adjustment (decreases expense total/balance)
        // Debit means expense (increases expense total/balance - we spent more)
        const delta = type === 'credit' ? -amount : amount;
        console.log('[Transaction] getLedgerDelta calculation (organizationLedger)', {
            ledgerType,
            type,
            amount,
            delta,
            explanation: type === 'credit' ? 'Credit: refund/adjustment (-amount, decreases expense)' : 'Debit: expense (+amount, increases expense)',
        });
        return delta;
    }
    // Default: assume same semantics as ClientLedger
    const delta = type === 'credit' ? amount : -amount;
    console.log('[Transaction] getLedgerDelta (default)', {
        ledgerType,
        type,
        amount,
        delta,
    });
    return delta;
}
// removeUndefinedFields now imported from shared/transaction-helpers
/**
 * Update client ledger when transaction is created or cancelled
 * Returns the balanceBefore and balanceAfter values for the transaction
 */
async function updateClientLedger(organizationId, clientId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    var _a, _b;
    const ledgerId = `${clientId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.CLIENT_LEDGERS_COLLECTION).doc(ledgerId);
    const amount = transaction.amount;
    const ledgerType = transaction.ledgerType || 'clientLedger';
    const type = transaction.type;
    const multiplier = isCancellation ? -1 : 1;
    const dmNumber = (_a = transaction.metadata) === null || _a === void 0 ? void 0 : _a.dmNumber;
    // Calculate ledger delta
    const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
    console.log('[Ledger] updateClientLedger called', {
        transactionId,
        ledgerId,
        ledgerType,
        type,
        amount,
        ledgerDelta,
        multiplier,
        isCancellation,
    });
    const fyDates = getFinancialYearDates(financialYear);
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const yearMonth = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
    const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
    let balanceBefore = 0;
    let balanceAfter = 0;
    // Build transaction data for monthly subcollection - NO undefined values
    // NOTE: Cannot use FieldValue.serverTimestamp() in arrays - must use actual Timestamp
    const now = admin.firestore.Timestamp.now();
    const transactionData = {
        transactionId,
        organizationId,
        clientId,
        ledgerType: ledgerType || 'clientLedger',
        type,
        category: transaction.category,
        amount,
        financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: now, // Use actual timestamp, not FieldValue (arrays don't support FieldValue)
    };
    // Add optional fields only if they exist
    if (transaction.createdAt) {
        transactionData.createdAt = transaction.createdAt;
    }
    else {
        transactionData.createdAt = now; // Use actual timestamp, not FieldValue
    }
    if (transaction.paymentAccountId) {
        transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
        transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
        transactionData.referenceNumber = transaction.referenceNumber;
    }
    const tripIdVal = (_b = transaction.tripId) !== null && _b !== void 0 ? _b : transaction.orderId;
    if (tripIdVal) {
        transactionData.tripId = tripIdVal;
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
    // Update ledger and monthly subcollection atomically
    await db.runTransaction(async (tx) => {
        // Read all documents FIRST (Firestore requirement: all reads before writes)
        const ledgerDoc = await tx.get(ledgerRef);
        const monthlyDoc = await tx.get(monthlyRef);
        if (!ledgerDoc.exists && !isCancellation) {
            // Create new ledger
            const openingBalance = await getOpeningBalance(organizationId, clientId, financialYear);
            balanceBefore = openingBalance;
            const currentBalance = openingBalance + (ledgerDelta * multiplier);
            balanceAfter = currentBalance;
            // Add balance values to transaction data
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            console.log('[Ledger] Creating new ledger', {
                transactionId,
                openingBalance,
                ledgerDelta,
                currentBalance,
                balanceBefore,
                balanceAfter,
            });
            // Calculate totalReceivables (only for credit transactions)
            // Credit = receivables created (what client owes)
            const totalReceivables = type === 'credit' ? (amount * multiplier) : 0;
            const totalIncome = type === 'debit' ? (amount * multiplier) : 0;
            // Build ledger document - NO undefined values allowed
            const ledgerData = {
                ledgerId,
                organizationId,
                clientId,
                financialYear,
                fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
                fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
                openingBalance,
                currentBalance,
                totalReceivables, // Total receivables created (credit transactions)
                totalIncome, // Total payments received (debit transactions)
                netBalance: currentBalance, // Same as currentBalance for clients
                transactionCount: 1,
                transactionIds: [transactionId],
                lastTransactionId: transactionId,
                lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                lastTransactionAmount: amount,
                firstTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                metadata: {},
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            // Only add dmNumbers if defined
            if (dmNumber !== undefined) {
                ledgerData.dmNumbers = [dmNumber];
            }
            tx.set(ledgerRef, ledgerData);
            // Create monthly transaction document atomically
            const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
            tx.set(monthlyRef, {
                yearMonth,
                transactions: [cleanData],
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log('[Ledger] Created ledger and monthly transaction atomically', {
                transactionId,
                yearMonth,
            });
        }
        else if (ledgerDoc.exists) {
            // Update existing ledger
            const ledgerData = ledgerDoc.data();
            const currentBalance = ledgerData.currentBalance || 0;
            const transactionIds = ledgerData.transactionIds || [];
            balanceBefore = currentBalance;
            const newBalance = currentBalance + (ledgerDelta * multiplier);
            balanceAfter = newBalance;
            // Add balance values to transaction data
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            // Get current totals
            const currentTotalReceivables = ledgerData.totalReceivables || 0;
            const currentTotalIncome = ledgerData.totalIncome || 0;
            // Update totals based on transaction type
            // Credit = receivables created, Debit = income received
            const receivablesChange = type === 'credit' ? (amount * multiplier) : 0;
            const incomeChange = type === 'debit' ? (amount * multiplier) : 0;
            const newTotalReceivables = currentTotalReceivables + receivablesChange;
            const newTotalIncome = currentTotalIncome + incomeChange;
            console.log('[Ledger] Updating ledger', {
                transactionId,
                currentBalance,
                ledgerDelta,
                newBalance,
                balanceBefore,
                balanceAfter,
                type,
                receivablesChange,
                incomeChange,
                newTotalReceivables,
                newTotalIncome,
            });
            // Build updates object - NO undefined values
            const updates = {
                currentBalance: newBalance,
                totalReceivables: newTotalReceivables,
                totalIncome: newTotalIncome,
                netBalance: newBalance, // Same as currentBalance for clients
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (isCancellation) {
                updates.transactionCount = Math.max(0, (ledgerData.transactionCount || 0) - 1);
                updates.transactionIds = admin.firestore.FieldValue.arrayRemove(transactionId);
            }
            else {
                updates.transactionCount = (ledgerData.transactionCount || 0) + 1;
                if (!transactionIds.includes(transactionId)) {
                    updates.transactionIds = admin.firestore.FieldValue.arrayUnion(transactionId);
                }
                if (dmNumber !== undefined) {
                    updates.dmNumbers = admin.firestore.FieldValue.arrayUnion(dmNumber);
                }
                updates.lastTransactionId = transactionId;
                updates.lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
                updates.lastTransactionAmount = amount;
                if (!ledgerData.firstTransactionDate) {
                    updates.firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
                }
            }
            tx.update(ledgerRef, updates);
            // Update monthly transaction document atomically (monthlyDoc already read above)
            const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
            if (isCancellation) {
                // Remove from monthly array
                if (monthlyDoc.exists) {
                    const data = monthlyDoc.data();
                    const transactions = data.transactions || [];
                    const filtered = transactions.filter((t) => t.transactionId !== transactionId);
                    if (filtered.length === 0) {
                        tx.delete(monthlyRef);
                        console.log('[Ledger] Deleted empty monthly document', {
                            transactionId,
                            yearMonth,
                        });
                    }
                    else {
                        tx.update(monthlyRef, {
                            transactions: filtered,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                        console.log('[Ledger] Removed transaction from monthly array', {
                            transactionId,
                            yearMonth,
                            remainingCount: filtered.length,
                        });
                    }
                }
            }
            else {
                // Add to monthly array
                if (!monthlyDoc.exists) {
                    tx.set(monthlyRef, {
                        yearMonth,
                        transactions: [cleanData],
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    console.log('[Ledger] Created new monthly document', {
                        transactionId,
                        yearMonth,
                    });
                }
                else {
                    const data = monthlyDoc.data();
                    const transactions = data.transactions || [];
                    const index = transactions.findIndex((t) => t.transactionId === transactionId);
                    if (index >= 0) {
                        transactions[index] = cleanData;
                        console.log('[Ledger] Updated existing transaction in monthly array', {
                            transactionId,
                            yearMonth,
                            index,
                        });
                    }
                    else {
                        transactions.push(cleanData);
                        console.log('[Ledger] Added transaction to monthly array', {
                            transactionId,
                            yearMonth,
                            arrayLength: transactions.length,
                        });
                    }
                    tx.update(monthlyRef, {
                        transactions,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
        }
        else {
            // Cancellation but ledger doesn't exist
            console.warn('[Ledger] Cancellation but ledger does not exist', { transactionId, ledgerId });
            balanceBefore = 0;
            balanceAfter = 0;
        }
    });
    console.log('[Ledger] Successfully updated ledger and monthly subcollection atomically', {
        transactionId,
        balanceBefore,
        balanceAfter,
        yearMonth,
    });
    return { balanceBefore, balanceAfter };
}
/**
 * Update vendor ledger when transaction is created or cancelled
 * Returns the balanceBefore and balanceAfter values for the transaction
 */
async function updateVendorLedger(organizationId, vendorId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    const ledgerId = `${vendorId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.VENDOR_LEDGERS_COLLECTION).doc(ledgerId);
    const amount = transaction.amount;
    const ledgerType = transaction.ledgerType || 'vendorLedger';
    const type = transaction.type;
    const multiplier = isCancellation ? -1 : 1;
    // Calculate ledger delta
    const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
    console.log('[Vendor Ledger] updateVendorLedger called', {
        transactionId,
        ledgerId,
        ledgerType,
        type,
        amount,
        ledgerDelta,
        multiplier,
        isCancellation,
    });
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const yearMonth = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
    const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
    let balanceBefore = 0;
    let balanceAfter = 0;
    // Build transaction data for monthly subcollection - NO undefined values
    const now = admin.firestore.Timestamp.now();
    const transactionData = {
        transactionId,
        organizationId,
        vendorId,
        ledgerType: ledgerType || 'vendorLedger',
        type,
        category: transaction.category,
        amount,
        financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: now,
    };
    // Add optional fields only if they exist
    if (transaction.createdAt) {
        transactionData.createdAt = transaction.createdAt;
    }
    else {
        transactionData.createdAt = now;
    }
    if (transaction.paymentAccountId) {
        transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
        transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
        transactionData.referenceNumber = transaction.referenceNumber;
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
    // Update ledger and monthly subcollection atomically
    await db.runTransaction(async (tx) => {
        // Read all documents FIRST (Firestore requirement: all reads before writes)
        const ledgerDoc = await tx.get(ledgerRef);
        const monthlyDoc = await tx.get(monthlyRef);
        if (!ledgerDoc.exists && !isCancellation) {
            // Create new ledger
            const openingBalance = await getVendorOpeningBalance(organizationId, vendorId, financialYear);
            balanceBefore = openingBalance;
            const currentBalance = openingBalance + (ledgerDelta * multiplier);
            balanceAfter = currentBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            console.log('[Vendor Ledger] Creating new ledger', {
                transactionId,
                openingBalance,
                ledgerDelta,
                currentBalance,
                balanceBefore,
                balanceAfter,
            });
            // Calculate totalPayables (only for credit transactions = purchases)
            const totalPayables = type === 'credit' ? (amount * multiplier) : 0;
            const totalPayments = type === 'debit' ? (amount * multiplier) : 0;
            const ledgerData = {
                ledgerId,
                vendorId,
                organizationId,
                financialYear,
                openingBalance,
                currentBalance,
                totalPayables,
                totalPayments,
                transactionCount: 1,
                creditCount: type === 'credit' ? 1 : 0,
                debitCount: type === 'debit' ? 1 : 0,
                transactionIds: [transactionId],
                lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                lastUpdated: now,
            };
            tx.set(ledgerRef, ledgerData);
            // Create monthly document
            const monthlyData = {
                yearMonth,
                transactions: [transactionData],
                transactionCount: 1,
                totalCredit: type === 'credit' ? amount : 0,
                totalDebit: type === 'debit' ? amount : 0,
            };
            tx.set(monthlyRef, monthlyData);
        }
        else if (ledgerDoc.exists) {
            // Update existing ledger
            const ledgerData = ledgerDoc.data();
            balanceBefore = ledgerData.currentBalance || 0;
            const newBalance = balanceBefore + (ledgerDelta * multiplier);
            balanceAfter = newBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            const currentTotalPayables = ledgerData.totalPayables || 0;
            const currentTotalPayments = ledgerData.totalPayments || 0;
            const totalPayables = type === 'credit'
                ? currentTotalPayables + (amount * multiplier)
                : currentTotalPayables;
            const totalPayments = type === 'debit'
                ? currentTotalPayments + (amount * multiplier)
                : currentTotalPayments;
            const transactionCount = (ledgerData.transactionCount || 0) + multiplier;
            const creditCount = type === 'credit'
                ? (ledgerData.creditCount || 0) + multiplier
                : ledgerData.creditCount || 0;
            const debitCount = type === 'debit'
                ? (ledgerData.debitCount || 0) + multiplier
                : ledgerData.debitCount || 0;
            const transactionIds = ledgerData.transactionIds || [];
            const updatedTransactionIds = isCancellation
                ? transactionIds.filter(id => id !== transactionId)
                : [...transactionIds, transactionId];
            tx.update(ledgerRef, {
                currentBalance: newBalance,
                totalPayables,
                totalPayments,
                transactionCount: Math.max(0, transactionCount),
                creditCount: Math.max(0, creditCount),
                debitCount: Math.max(0, debitCount),
                transactionIds: updatedTransactionIds,
                lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                lastUpdated: now,
            });
            // Update monthly document
            if (monthlyDoc.exists) {
                const monthlyData = monthlyDoc.data();
                const transactions = monthlyData.transactions || [];
                const updatedTransactions = isCancellation
                    ? transactions.filter((t) => t.transactionId !== transactionId)
                    : [...transactions, transactionData];
                const transactionCount = updatedTransactions.length;
                const totalCredit = updatedTransactions
                    .filter((t) => t.type === 'credit')
                    .reduce((sum, t) => sum + (t.amount || 0), 0);
                const totalDebit = updatedTransactions
                    .filter((t) => t.type === 'debit')
                    .reduce((sum, t) => sum + (t.amount || 0), 0);
                tx.update(monthlyRef, {
                    transactions: updatedTransactions,
                    transactionCount,
                    totalCredit,
                    totalDebit,
                });
            }
            else {
                // Create monthly document if it doesn't exist
                const monthlyData = {
                    yearMonth,
                    transactions: [transactionData],
                    transactionCount: 1,
                    totalCredit: type === 'credit' ? amount : 0,
                    totalDebit: type === 'debit' ? amount : 0,
                };
                tx.set(monthlyRef, monthlyData);
            }
            // Update vendor document currentBalance
            const vendorRef = db.collection(constants_1.VENDORS_COLLECTION).doc(vendorId);
            tx.update(vendorRef, {
                currentBalance: newBalance,
                lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                updatedAt: now,
            });
        }
        else {
            // Cancellation but ledger doesn't exist
            console.warn('[Vendor Ledger] Cancellation but ledger does not exist', { transactionId, ledgerId });
            balanceBefore = 0;
            balanceAfter = 0;
        }
    });
    console.log('[Vendor Ledger] Successfully updated ledger and monthly subcollection atomically', {
        transactionId,
        balanceBefore,
        balanceAfter,
        yearMonth,
    });
    return { balanceBefore, balanceAfter };
}
/**
 * Update employee ledger when transaction is created or cancelled
 * Returns the balanceBefore and balanceAfter values for the transaction
 */
async function updateEmployeeLedger(organizationId, employeeId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    const ledgerId = `${employeeId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
    const amount = transaction.amount;
    const ledgerType = transaction.ledgerType || 'employeeLedger';
    const type = transaction.type;
    const multiplier = isCancellation ? -1 : 1;
    // Calculate ledger delta
    const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
    console.log('[Employee Ledger] updateEmployeeLedger called', {
        transactionId,
        ledgerId,
        ledgerType,
        type,
        amount,
        ledgerDelta,
        multiplier,
        isCancellation,
    });
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const yearMonth = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
    const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
    let balanceBefore = 0;
    let balanceAfter = 0;
    // Build transaction data for monthly subcollection - NO undefined values
    const now = admin.firestore.Timestamp.now();
    const transactionData = {
        transactionId,
        organizationId,
        employeeId,
        ledgerType: ledgerType || 'employeeLedger',
        type,
        category: transaction.category,
        amount,
        financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: now,
    };
    // Add optional fields only if they exist
    if (transaction.createdAt) {
        transactionData.createdAt = transaction.createdAt;
    }
    else {
        transactionData.createdAt = now;
    }
    if (transaction.paymentAccountId) {
        transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
        transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
        transactionData.referenceNumber = transaction.referenceNumber;
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
    // Update ledger and monthly subcollection atomically
    await db.runTransaction(async (tx) => {
        // Read all documents FIRST (Firestore requirement: all reads before writes)
        const ledgerDoc = await tx.get(ledgerRef);
        const monthlyDoc = await tx.get(monthlyRef);
        if (!ledgerDoc.exists && !isCancellation) {
            // Create new ledger
            const openingBalance = await getEmployeeOpeningBalance(organizationId, employeeId, financialYear);
            balanceBefore = openingBalance;
            const currentBalance = openingBalance + (ledgerDelta * multiplier);
            balanceAfter = currentBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            console.log('[Employee Ledger] Creating new ledger', {
                transactionId,
                openingBalance,
                ledgerDelta,
                currentBalance,
                balanceBefore,
                balanceAfter,
            });
            // Calculate totalCredited (only for credit transactions = salary/bonus)
            const totalCredited = type === 'credit' ? (amount * multiplier) : 0;
            const totalTransactions = 1;
            const ledgerData = {
                ledgerId,
                employeeId,
                organizationId,
                financialYear,
                openingBalance,
                currentBalance,
                totalCredited,
                totalTransactions,
                createdAt: now,
                updatedAt: now,
            };
            tx.set(ledgerRef, ledgerData);
            // Create monthly document
            const monthlyData = {
                yearMonth,
                transactions: [transactionData],
                transactionCount: 1,
                totalCredit: type === 'credit' ? amount : 0,
                totalDebit: type === 'debit' ? amount : 0,
            };
            tx.set(monthlyRef, monthlyData);
        }
        else if (ledgerDoc.exists) {
            // Update existing ledger
            const ledgerData = ledgerDoc.data();
            balanceBefore = ledgerData.currentBalance || 0;
            const newBalance = balanceBefore + (ledgerDelta * multiplier);
            balanceAfter = newBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            const currentTotalCredited = ledgerData.totalCredited || 0;
            const totalCredited = type === 'credit'
                ? currentTotalCredited + (amount * multiplier)
                : currentTotalCredited;
            const currentTotalTransactions = ledgerData.totalTransactions || 0;
            const totalTransactions = Math.max(0, currentTotalTransactions + multiplier);
            tx.update(ledgerRef, {
                currentBalance: newBalance,
                totalCredited,
                totalTransactions: Math.max(0, totalTransactions),
                updatedAt: now,
            });
            // Update monthly document
            if (monthlyDoc.exists) {
                const monthlyData = monthlyDoc.data();
                const transactions = monthlyData.transactions || [];
                // Clean transaction data
                const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
                const index = transactions.findIndex((t) => t.transactionId === transactionId);
                if (index >= 0) {
                    transactions[index] = cleanData;
                    console.log('[Employee Ledger] Updated existing transaction in monthly array', {
                        transactionId,
                        yearMonth,
                        index,
                    });
                }
                else {
                    transactions.push(cleanData);
                    console.log('[Employee Ledger] Added transaction to monthly array', {
                        transactionId,
                        yearMonth,
                        arrayLength: transactions.length,
                    });
                }
                const transactionCount = transactions.length;
                const totalCredit = transactions
                    .filter((t) => t.type === 'credit')
                    .reduce((sum, t) => sum + (t.amount || 0), 0);
                const totalDebit = transactions
                    .filter((t) => t.type === 'debit')
                    .reduce((sum, t) => sum + (t.amount || 0), 0);
                tx.update(monthlyRef, {
                    transactions,
                    transactionCount,
                    totalCredit,
                    totalDebit,
                });
            }
            else {
                // Create monthly document if it doesn't exist
                const monthlyData = {
                    yearMonth,
                    transactions: [transactionData],
                    transactionCount: 1,
                    totalCredit: type === 'credit' ? amount : 0,
                    totalDebit: type === 'debit' ? amount : 0,
                };
                tx.set(monthlyRef, monthlyData);
            }
            // Update employee document currentBalance
            const employeeRef = db.collection(constants_1.EMPLOYEES_COLLECTION).doc(employeeId);
            tx.update(employeeRef, {
                currentBalance: newBalance,
                updatedAt: now,
            });
        }
        else {
            // Cancellation but ledger doesn't exist
            console.warn('[Employee Ledger] Cancellation but ledger does not exist', { transactionId, ledgerId });
            balanceBefore = 0;
            balanceAfter = 0;
        }
    });
    console.log('[Employee Ledger] Successfully updated ledger and monthly subcollection atomically', {
        transactionId,
        balanceBefore,
        balanceAfter,
        yearMonth,
    });
    return { balanceBefore, balanceAfter };
}
/**
 * Update organization ledger when transaction is created or cancelled
 * Returns the balanceBefore and balanceAfter values for the transaction
 */
async function updateOrganizationLedger(organizationId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    const ledgerId = `${organizationId}_${financialYear}`;
    const ledgerRef = db.collection(constants_1.ORGANIZATION_LEDGERS_COLLECTION).doc(ledgerId);
    const amount = transaction.amount;
    const ledgerType = transaction.ledgerType || 'organizationLedger';
    const type = transaction.type;
    const multiplier = isCancellation ? -1 : 1;
    // Calculate ledger delta
    const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
    console.log('[Organization Ledger] updateOrganizationLedger called', {
        transactionId,
        ledgerId,
        ledgerType,
        type,
        amount,
        ledgerDelta,
        multiplier,
        isCancellation,
    });
    const fyDates = getFinancialYearDates(financialYear);
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const yearMonth = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
    const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
    let balanceBefore = 0;
    let balanceAfter = 0;
    // Build transaction data for monthly subcollection
    const now = admin.firestore.Timestamp.now();
    const transactionData = {
        transactionId,
        organizationId,
        ledgerType: ledgerType || 'organizationLedger',
        type,
        category: transaction.category,
        amount,
        financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: now,
    };
    // Add optional fields only if they exist
    if (transaction.createdAt) {
        transactionData.createdAt = transaction.createdAt;
    }
    else {
        transactionData.createdAt = now;
    }
    if (transaction.paymentAccountId) {
        transactionData.paymentAccountId = transaction.paymentAccountId;
    }
    if (transaction.paymentAccountType) {
        transactionData.paymentAccountType = transaction.paymentAccountType;
    }
    if (transaction.referenceNumber) {
        transactionData.referenceNumber = transaction.referenceNumber;
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
    // Update ledger and monthly subcollection atomically
    await db.runTransaction(async (tx) => {
        // Read all documents FIRST
        const ledgerDoc = await tx.get(ledgerRef);
        const monthlyDoc = await tx.get(monthlyRef);
        if (!ledgerDoc.exists && !isCancellation) {
            // Create new ledger
            balanceBefore = 0;
            const currentBalance = balanceBefore + (ledgerDelta * multiplier);
            balanceAfter = currentBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            const totalExpenses = type === 'debit' ? (amount * multiplier) : 0;
            const totalRefunds = type === 'credit' ? (amount * multiplier) : 0;
            const ledgerData = {
                ledgerId,
                organizationId,
                financialYear,
                fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
                fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
                openingBalance: 0,
                currentBalance,
                totalExpenses,
                totalRefunds,
                transactionCount: 1,
                transactionIds: [transactionId],
                lastTransactionId: transactionId,
                lastTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                lastTransactionAmount: amount,
                firstTransactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                metadata: {},
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            tx.set(ledgerRef, ledgerData);
            // Create monthly transaction document
            const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
            tx.set(monthlyRef, {
                yearMonth,
                transactions: [cleanData],
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else if (ledgerDoc.exists) {
            // Update existing ledger
            const ledgerData = ledgerDoc.data();
            const currentBalance = ledgerData.currentBalance || 0;
            balanceBefore = currentBalance;
            const newBalance = currentBalance + (ledgerDelta * multiplier);
            balanceAfter = newBalance;
            transactionData.balanceBefore = balanceBefore;
            transactionData.balanceAfter = balanceAfter;
            // Get current totals
            const currentTotalExpenses = ledgerData.totalExpenses || 0;
            const currentTotalRefunds = ledgerData.totalRefunds || 0;
            // Update totals based on transaction type
            const expensesChange = type === 'debit' ? (amount * multiplier) : 0;
            const refundsChange = type === 'credit' ? (amount * multiplier) : 0;
            const newTotalExpenses = currentTotalExpenses + expensesChange;
            const newTotalRefunds = currentTotalRefunds + refundsChange;
            const updates = {
                currentBalance: newBalance,
                totalExpenses: newTotalExpenses,
                totalRefunds: newTotalRefunds,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (isCancellation) {
                updates.transactionCount = Math.max(0, (ledgerData.transactionCount || 0) - 1);
                updates.transactionIds = admin.firestore.FieldValue.arrayRemove(transactionId);
            }
            else {
                updates.transactionCount = (ledgerData.transactionCount || 0) + 1;
                const transactionIds = ledgerData.transactionIds || [];
                if (!transactionIds.includes(transactionId)) {
                    updates.transactionIds = admin.firestore.FieldValue.arrayUnion(transactionId);
                }
                updates.lastTransactionId = transactionId;
                updates.lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
                updates.lastTransactionAmount = amount;
            }
            tx.update(ledgerRef, updates);
            // Update monthly transaction document
            const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
            if (isCancellation) {
                if (monthlyDoc.exists) {
                    const monthlyData = monthlyDoc.data();
                    const transactions = monthlyData.transactions || [];
                    const filtered = transactions.filter((t) => t.transactionId !== transactionId);
                    if (filtered.length === 0) {
                        tx.delete(monthlyRef);
                    }
                    else {
                        tx.update(monthlyRef, {
                            transactions: filtered,
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                    }
                }
            }
            else {
                if (!monthlyDoc.exists) {
                    tx.set(monthlyRef, {
                        yearMonth,
                        transactions: [cleanData],
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
                else {
                    const monthlyData = monthlyDoc.data();
                    const transactions = monthlyData.transactions || [];
                    const index = transactions.findIndex((t) => t.transactionId === transactionId);
                    if (index >= 0) {
                        transactions[index] = cleanData;
                    }
                    else {
                        transactions.push(cleanData);
                    }
                    tx.update(monthlyRef, {
                        transactions,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
        }
        else {
            // Cancellation but ledger doesn't exist
            console.warn('[Organization Ledger] Cancellation but ledger does not exist', { transactionId, ledgerId });
            balanceBefore = 0;
            balanceAfter = 0;
        }
    });
    console.log('[Organization Ledger] Successfully updated ledger and monthly subcollection atomically', {
        transactionId,
        balanceBefore,
        balanceAfter,
        yearMonth,
    });
    return { balanceBefore, balanceAfter };
}
/**
 * Update expense sub-category analytics when transaction is created or cancelled
 */
async function updateExpenseSubCategoryAnalytics(organizationId, subCategoryId, amount, transactionDate, isCancellation = false) {
    if (!subCategoryId)
        return;
    const subCategoryRef = db
        .collection(constants_1.ORGANIZATIONS_COLLECTION)
        .doc(organizationId)
        .collection(constants_1.EXPENSE_SUB_CATEGORIES_COLLECTION)
        .doc(subCategoryId);
    const multiplier = isCancellation ? -1 : 1;
    await db.runTransaction(async (tx) => {
        const subCategoryDoc = await tx.get(subCategoryRef);
        if (!subCategoryDoc.exists) {
            console.warn('[Sub-Category Analytics] Sub-category not found', { subCategoryId });
            return;
        }
        const subCategoryData = subCategoryDoc.data();
        const currentTransactionCount = subCategoryData.transactionCount || 0;
        const currentTotalAmount = subCategoryData.totalAmount || 0;
        const updates = {
            transactionCount: Math.max(0, currentTransactionCount + multiplier),
            totalAmount: Math.max(0, currentTotalAmount + (amount * multiplier)),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (!isCancellation) {
            updates.lastUsedAt = admin.firestore.Timestamp.fromDate(transactionDate);
        }
        tx.update(subCategoryRef, updates);
    });
    console.log('[Sub-Category Analytics] Updated analytics', {
        subCategoryId,
        amount,
        isCancellation,
    });
}
/**
 * Update employee analytics when wages credit transaction is created or cancelled
 */
async function updateEmployeeAnalytics(organizationId, financialYear, transactionDate, amount, isCancellation = false) {
    const multiplier = isCancellation ? -1 : 1;
    const { monthKey } = (0, financial_year_1.getFinancialContext)(transactionDate);
    const analyticsRef = db
        .collection(constants_1.ANALYTICS_COLLECTION)
        .doc(`${constants_1.EMPLOYEES_SOURCE_KEY}_${organizationId}_${financialYear}`);
    try {
        await (0, firestore_helpers_1.seedEmployeeAnalyticsDoc)(analyticsRef, financialYear, organizationId);
        await analyticsRef.set({
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            [`metrics.wagesCreditMonthly.values.${monthKey}`]: admin.firestore.FieldValue.increment(amount * multiplier),
        }, { merge: true });
    }
    catch (error) {
        console.warn('[Employee Analytics] Error updating wages credit analytics', {
            organizationId,
            financialYear,
            monthKey,
            error,
        });
    }
}
/**
 * Update analytics when transaction is created or cancelled
 * Now stores data in monthly documents instead of yearly
 */
async function updateTransactionAnalytics(organizationId, financialYear, transaction, transactionDate, isCancellation = false) {
    // Use monthly document ID based on transaction date
    const monthKey = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
    const analyticsDocId = `${constants_1.TRANSACTIONS_SOURCE_KEY}_${organizationId}_${monthKey}`;
    const analyticsRef = db.collection(constants_1.ANALYTICS_COLLECTION).doc(analyticsDocId);
    const amount = transaction.amount;
    const ledgerType = transaction.ledgerType || 'clientLedger';
    const type = transaction.type; // 'credit' or 'debit'
    const category = transaction.category;
    const paymentAccountId = transaction.paymentAccountId;
    const paymentAccountType = transaction.paymentAccountType;
    const multiplier = isCancellation ? -1 : 1;
    const dateString = (0, date_helpers_1.formatDate)(transactionDate);
    const weekString = (0, date_helpers_1.getISOWeek)(transactionDate);
    // Get current analytics data for this month
    const analyticsDoc = await analyticsRef.get();
    const analyticsData = analyticsDoc.exists ? analyticsDoc.data() : {};
    // For ClientLedger: Only Type: Debit counts as income (actual money received)
    // Type: Credit counts as receivables (what client owes, not yet received)
    const isDebit = type === 'debit';
    const isCredit = type === 'credit';
    // Clean daily data (keep only last 90 days)
    const incomeDaily = (0, date_helpers_1.cleanDailyData)(analyticsData.incomeDaily || {}, 90);
    const receivablesDaily = (0, date_helpers_1.cleanDailyData)(analyticsData.receivablesDaily || {}, 90);
    // Update daily breakdown
    if (isDebit && ledgerType === 'clientLedger') {
        // Debit = actual money received = income
        incomeDaily[dateString] = (incomeDaily[dateString] || 0) + (amount * multiplier);
    }
    else if (isCredit && ledgerType === 'clientLedger') {
        // Credit = receivable created = not income yet
        receivablesDaily[dateString] = (receivablesDaily[dateString] || 0) + (amount * multiplier);
    }
    // Update weekly breakdown
    const incomeWeekly = analyticsData.incomeWeekly || {};
    const receivablesWeekly = analyticsData.receivablesWeekly || {};
    if (isDebit && ledgerType === 'clientLedger') {
        incomeWeekly[weekString] = (incomeWeekly[weekString] || 0) + (amount * multiplier);
    }
    else if (isCredit && ledgerType === 'clientLedger') {
        receivablesWeekly[weekString] = (receivablesWeekly[weekString] || 0) + (amount * multiplier);
    }
    // Update income by category (only for Debit transactions = actual income)
    const incomeByCategory = analyticsData.incomeByCategory || {};
    if (isDebit && ledgerType === 'clientLedger') {
        if (!incomeByCategory[category]) {
            incomeByCategory[category] = 0;
        }
        incomeByCategory[category] = (incomeByCategory[category] || 0) + (amount * multiplier);
    }
    // Update receivables by category (only for Credit transactions = receivables)
    const receivablesByCategory = analyticsData.receivablesByCategory || {};
    if (isCredit && ledgerType === 'clientLedger') {
        if (!receivablesByCategory[category]) {
            receivablesByCategory[category] = 0;
        }
        receivablesByCategory[category] = (receivablesByCategory[category] || 0) + (amount * multiplier);
    }
    // Update by type breakdown (for both credit and debit)
    const byType = analyticsData.byType || {};
    if (!byType[type]) {
        byType[type] = { count: 0, total: 0, daily: {}, weekly: {} };
    }
    byType[type].count += multiplier;
    byType[type].total += (amount * multiplier);
    // Update type daily/weekly (no monthly maps needed - document is month-specific)
    if (!byType[type].daily)
        byType[type].daily = {};
    if (!byType[type].weekly)
        byType[type].weekly = {};
    byType[type].daily[dateString] = (byType[type].daily[dateString] || 0) + (amount * multiplier);
    byType[type].weekly[weekString] = (byType[type].weekly[weekString] || 0) + (amount * multiplier);
    // Clean type daily data
    byType[type].daily = (0, date_helpers_1.cleanDailyData)(byType[type].daily, 90);
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
            };
        }
        byPaymentAccount[accountId].count += multiplier;
        byPaymentAccount[accountId].total += (amount * multiplier);
        if (!byPaymentAccount[accountId].daily)
            byPaymentAccount[accountId].daily = {};
        if (!byPaymentAccount[accountId].weekly)
            byPaymentAccount[accountId].weekly = {};
        byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].daily = (0, date_helpers_1.cleanDailyData)(byPaymentAccount[accountId].daily, 90);
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
            };
        }
        byPaymentAccount[accountId].count += multiplier;
        byPaymentAccount[accountId].total += (amount * multiplier);
        if (!byPaymentAccount[accountId].daily)
            byPaymentAccount[accountId].daily = {};
        if (!byPaymentAccount[accountId].weekly)
            byPaymentAccount[accountId].weekly = {};
        byPaymentAccount[accountId].daily[dateString] = (byPaymentAccount[accountId].daily[dateString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].weekly[weekString] = (byPaymentAccount[accountId].weekly[weekString] || 0) + (amount * multiplier);
        byPaymentAccount[accountId].daily = (0, date_helpers_1.cleanDailyData)(byPaymentAccount[accountId].daily, 90);
    }
    // Update by payment method type breakdown
    const byPaymentMethodType = analyticsData.byPaymentMethodType || {};
    const methodType = paymentAccountType || 'cash';
    if (!byPaymentMethodType[methodType]) {
        byPaymentMethodType[methodType] = { count: 0, total: 0, daily: {}, weekly: {} };
    }
    byPaymentMethodType[methodType].count += multiplier;
    byPaymentMethodType[methodType].total += (amount * multiplier);
    if (!byPaymentMethodType[methodType].daily)
        byPaymentMethodType[methodType].daily = {};
    if (!byPaymentMethodType[methodType].weekly)
        byPaymentMethodType[methodType].weekly = {};
    byPaymentMethodType[methodType].daily[dateString] = (byPaymentMethodType[methodType].daily[dateString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].weekly[weekString] = (byPaymentMethodType[methodType].weekly[weekString] || 0) + (amount * multiplier);
    byPaymentMethodType[methodType].daily = (0, date_helpers_1.cleanDailyData)(byPaymentMethodType[methodType].daily, 90);
    // Calculate totals for this month (sum of daily values)
    const totalIncome = Object.values(incomeDaily).reduce((sum, val) => sum + (val || 0), 0);
    const totalReceivables = Object.values(receivablesDaily).reduce((sum, val) => sum + (val || 0), 0);
    const netReceivables = totalReceivables - totalIncome; // What's still owed
    const transactionCount = (analyticsData.transactionCount || 0) + multiplier;
    // Calculate receivable aging (for Credit transactions)
    let receivableAging = analyticsData.receivableAging || {
        current: 0, // 0-30 days
        days31to60: 0, // 31-60 days
        days61to90: 0, // 61-90 days
        over90: 0, // >90 days
    };
    if (isCredit && ledgerType === 'clientLedger' && !isCancellation) {
        // Add to current bucket (0-30 days) - this is a simplified calculation
        // In production, you'd calculate based on transaction date vs current date
        receivableAging.current = (receivableAging.current || 0) + (amount * multiplier);
    }
    else if (isCredit && ledgerType === 'clientLedger' && isCancellation) {
        // When cancelling, reduce receivables (simplified - should calculate actual aging)
        receivableAging.current = Math.max(0, (receivableAging.current || 0) - amount);
    }
    // Update analytics document (month-specific, no monthly maps)
    await analyticsRef.set({
        source: constants_1.TRANSACTIONS_SOURCE_KEY,
        organizationId,
        month: monthKey, // Store month for reference
        financialYear, // Keep for backward compatibility during migration
        incomeDaily,
        receivablesDaily,
        incomeWeekly,
        receivablesWeekly,
        incomeByCategory,
        receivablesByCategory,
        byType,
        byPaymentAccount,
        byPaymentMethodType,
        totalIncome,
        totalReceivables,
        netReceivables,
        receivableAging,
        transactionCount: Math.max(0, transactionCount),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
/**
 * Mark vendor invoices as paid when a payment transaction is created
 */
async function markInvoicesAsPaid(organizationId, paymentTransactionId, paymentAmount, linkedInvoiceIds) {
    if (!linkedInvoiceIds || linkedInvoiceIds.length === 0) {
        return; // No invoices to mark as paid
    }
    console.log('[Invoice Payment] Marking invoices as paid', {
        paymentTransactionId,
        paymentAmount,
        linkedInvoiceIds,
        invoiceCount: linkedInvoiceIds.length,
    });
    // Get all invoice transactions
    const invoiceTransactions = await Promise.all(linkedInvoiceIds.map(async (invoiceId) => {
        const invoiceDoc = await db.collection(constants_1.TRANSACTIONS_COLLECTION).doc(invoiceId).get();
        if (!invoiceDoc.exists) {
            console.warn('[Invoice Payment] Invoice not found', { invoiceId });
            return null;
        }
        return { id: invoiceId, data: invoiceDoc.data(), ref: invoiceDoc.ref };
    }));
    const validInvoices = invoiceTransactions.filter((inv) => inv !== null);
    if (validInvoices.length === 0) {
        console.warn('[Invoice Payment] No valid invoices found');
        return;
    }
    // Calculate total invoice amount and distribute payment proportionally
    let totalInvoiceAmount = 0;
    for (const invoice of validInvoices) {
        totalInvoiceAmount += invoice.data.amount || 0;
    }
    // Process each invoice
    for (const invoice of validInvoices) {
        const invoiceAmount = invoice.data.amount || 0;
        const metadata = invoice.data.metadata || {};
        const currentPaidAmount = metadata.paidAmount || 0;
        const currentPaymentIds = metadata.paymentIds || [];
        // Calculate payment allocation for this invoice (proportional)
        const paymentAllocation = totalInvoiceAmount > 0
            ? (paymentAmount * invoiceAmount) / totalInvoiceAmount
            : paymentAmount / validInvoices.length;
        const newPaidAmount = currentPaidAmount + paymentAllocation;
        const newPaymentIds = [...currentPaymentIds, paymentTransactionId];
        // Determine new paid status
        let newPaidStatus;
        if (newPaidAmount >= invoiceAmount) {
            newPaidStatus = 'paid';
        }
        else if (newPaidAmount > 0) {
            newPaidStatus = 'partial';
        }
        else {
            newPaidStatus = 'unpaid';
        }
        // Update invoice transaction metadata
        await invoice.ref.update({
            'metadata.paidStatus': newPaidStatus,
            'metadata.paidAmount': newPaidAmount,
            'metadata.paymentIds': newPaymentIds,
            'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[Invoice Payment] Updated invoice', {
            invoiceId: invoice.id,
            invoiceAmount,
            paymentAllocation,
            previousPaidAmount: currentPaidAmount,
            newPaidAmount,
            newPaidStatus,
        });
    }
}
/**
 * Revert invoice payment status when a payment transaction is deleted
 */
async function revertInvoicePayment(paymentTransactionId, paymentAmount, linkedInvoiceIds) {
    if (!linkedInvoiceIds || linkedInvoiceIds.length === 0) {
        return; // No invoices to revert
    }
    console.log('[Invoice Payment] Reverting invoice payment', {
        paymentTransactionId,
        paymentAmount,
        linkedInvoiceIds,
        invoiceCount: linkedInvoiceIds.length,
    });
    // Get all invoice transactions
    const invoiceTransactions = await Promise.all(linkedInvoiceIds.map(async (invoiceId) => {
        const invoiceDoc = await db.collection(constants_1.TRANSACTIONS_COLLECTION).doc(invoiceId).get();
        if (!invoiceDoc.exists) {
            console.warn('[Invoice Payment] Invoice not found for revert', { invoiceId });
            return null;
        }
        return { id: invoiceId, data: invoiceDoc.data(), ref: invoiceDoc.ref };
    }));
    const validInvoices = invoiceTransactions.filter((inv) => inv !== null);
    // Calculate total invoice amount for proportional distribution
    let totalInvoiceAmount = 0;
    for (const invoice of validInvoices) {
        totalInvoiceAmount += invoice.data.amount || 0;
    }
    // Revert each invoice
    for (const invoice of validInvoices) {
        const invoiceAmount = invoice.data.amount || 0;
        const metadata = invoice.data.metadata || {};
        const currentPaidAmount = metadata.paidAmount || 0;
        const currentPaymentIds = metadata.paymentIds || [];
        // Calculate payment allocation that was applied (proportional)
        const paymentAllocation = totalInvoiceAmount > 0
            ? (paymentAmount * invoiceAmount) / totalInvoiceAmount
            : paymentAmount / validInvoices.length;
        const newPaidAmount = Math.max(0, currentPaidAmount - paymentAllocation);
        const newPaymentIds = currentPaymentIds.filter((id) => id !== paymentTransactionId);
        // Determine new paid status
        let newPaidStatus;
        if (newPaidAmount >= invoiceAmount) {
            newPaidStatus = 'paid';
        }
        else if (newPaidAmount > 0) {
            newPaidStatus = 'partial';
        }
        else {
            newPaidStatus = 'unpaid';
        }
        // Update invoice transaction metadata
        await invoice.ref.update({
            'metadata.paidStatus': newPaidStatus,
            'metadata.paidAmount': newPaidAmount,
            'metadata.paymentIds': newPaymentIds,
            'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[Invoice Payment] Reverted invoice', {
            invoiceId: invoice.id,
            invoiceAmount,
            paymentAllocation,
            previousPaidAmount: currentPaidAmount,
            newPaidAmount,
            newPaidStatus,
        });
    }
}
/**
 * Cloud Function: Triggered when a transaction is created
 */
exports.onTransactionCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}` }, function_config_1.CRITICAL_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const transaction = snapshot.data();
    const transactionId = event.params.transactionId;
    // Idempotency: skip if already processed (balanceBefore/balanceAfter set)
    if (transaction.balanceBefore !== undefined && transaction.balanceAfter !== undefined) {
        console.log('[Transaction] Already processed, skipping', { transactionId });
        return;
    }
    const organizationId = transaction === null || transaction === void 0 ? void 0 : transaction.organizationId;
    const financialYear = transaction === null || transaction === void 0 ? void 0 : transaction.financialYear;
    const ledgerType = transaction.ledgerType || 'clientLedger';
    if (!organizationId || !financialYear) {
        console.error('[Transaction] Missing required fields', {
            transactionId,
            organizationId,
            financialYear,
        });
        return;
    }
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const amount = transaction.amount;
    const type = transaction.type;
    try {
        let balanceBefore = 0;
        let balanceAfter = 0;
        // Route to appropriate ledger handler based on ledgerType
        if (ledgerType === 'vendorLedger') {
            const vendorId = transaction === null || transaction === void 0 ? void 0 : transaction.vendorId;
            if (!vendorId) {
                console.error('[Transaction] Missing vendorId for vendorLedger transaction', {
                    transactionId,
                    organizationId,
                    vendorId,
                });
                return;
            }
            // Update vendor ledger and get balances
            const result = await updateVendorLedger(organizationId, vendorId, financialYear, transaction, transactionId, snapshot, false);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // If this is a vendor payment with linked invoices, mark invoices as paid
            const category = transaction.category;
            if (category === 'vendorPayment') {
                const metadata = transaction.metadata;
                const linkedInvoiceIds = metadata === null || metadata === void 0 ? void 0 : metadata.linkedInvoiceIds;
                if (linkedInvoiceIds && linkedInvoiceIds.length > 0) {
                    await markInvoicesAsPaid(organizationId, transactionId, amount, linkedInvoiceIds);
                }
            }
        }
        else if (ledgerType === 'employeeLedger') {
            const employeeId = transaction === null || transaction === void 0 ? void 0 : transaction.employeeId;
            if (!employeeId) {
                console.error('[Transaction] Missing employeeId for employeeLedger transaction', {
                    transactionId,
                    organizationId,
                    employeeId,
                });
                return;
            }
            // Update employee ledger and get balances
            const result = await updateEmployeeLedger(organizationId, employeeId, financialYear, transaction, transactionId, snapshot, false);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // Update employee analytics for wage credits
            const category = transaction.category;
            if (type === 'credit' && category === 'wageCredit') {
                await updateEmployeeAnalytics(organizationId, financialYear, transactionDate, amount, false);
            }
        }
        else if (ledgerType === 'organizationLedger') {
            // Update organization ledger and get balances
            const result = await updateOrganizationLedger(organizationId, financialYear, transaction, transactionId, snapshot, false);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // Update expense sub-category analytics if this is a general expense
            const category = transaction.category;
            if (category === 'generalExpense') {
                const metadata = transaction.metadata;
                const subCategoryId = metadata === null || metadata === void 0 ? void 0 : metadata.subCategoryId;
                if (subCategoryId) {
                    await updateExpenseSubCategoryAnalytics(organizationId, subCategoryId, amount, transactionDate, false);
                }
            }
        }
        else {
            // Default to clientLedger
            const clientId = transaction === null || transaction === void 0 ? void 0 : transaction.clientId;
            if (!clientId) {
                console.error('[Transaction] Missing clientId for clientLedger transaction', {
                    transactionId,
                    organizationId,
                    clientId,
                });
                return;
            }
            // Update client ledger and get balances
            const result = await updateClientLedger(organizationId, clientId, financialYear, transaction, transactionId, snapshot, false);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
        }
        const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
        console.log('[Transaction] Created', {
            transactionId,
            amount,
            type,
            ledgerType,
            ledgerDelta,
            balanceBefore,
            balanceAfter,
            calculation: `${balanceBefore} + ${ledgerDelta} = ${balanceAfter}`,
        });
        // Update transaction document with balances
        await snapshot.ref.update({
            balanceBefore,
            balanceAfter,
        });
        // Update analytics
        await updateTransactionAnalytics(organizationId, financialYear, Object.assign(Object.assign({}, transaction), { balanceBefore, balanceAfter }), transactionDate, false);
        console.log('[Transaction] Successfully processed', {
            transactionId,
            balanceBefore,
            balanceAfter,
        });
    }
    catch (error) {
        console.error('[Transaction] Error', {
            transactionId,
            error: error instanceof Error ? error.message : String(error),
            stack: error instanceof Error ? error.stack : undefined,
        });
        throw error;
    }
});
/**
 * Cloud Function: Triggered when a transaction is deleted (for cancellations)
 */
exports.onTransactionDeleted = (0, firestore_1.onDocumentDeleted)(Object.assign({ document: `${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const transaction = snapshot.data();
    const transactionId = event.params.transactionId;
    if (!transaction) {
        console.error('[Transaction] No data for deletion', { transactionId });
        return;
    }
    const organizationId = transaction.organizationId;
    const financialYear = transaction.financialYear;
    const ledgerType = transaction.ledgerType || 'clientLedger';
    if (!organizationId || !financialYear) {
        console.error('[Transaction] Missing fields for deletion', {
            transactionId,
            organizationId,
            financialYear,
        });
        return;
    }
    const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
    const amount = transaction.amount;
    const type = transaction.type;
    const originalBalanceBefore = transaction.balanceBefore;
    try {
        let balanceBefore = 0;
        let balanceAfter = 0;
        // Route to appropriate ledger handler based on ledgerType
        if (ledgerType === 'vendorLedger') {
            const vendorId = transaction === null || transaction === void 0 ? void 0 : transaction.vendorId;
            if (!vendorId) {
                console.error('[Transaction] Missing vendorId for vendorLedger transaction deletion', {
                    transactionId,
                    organizationId,
                    vendorId,
                });
                return;
            }
            // Reverse in vendor ledger
            const result = await updateVendorLedger(organizationId, vendorId, financialYear, transaction, transactionId, snapshot, true);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // If this was a vendor payment with linked invoices, revert invoice payment status
            const category = transaction.category;
            if (category === 'vendorPayment') {
                const metadata = transaction.metadata;
                const linkedInvoiceIds = metadata === null || metadata === void 0 ? void 0 : metadata.linkedInvoiceIds;
                if (linkedInvoiceIds && linkedInvoiceIds.length > 0) {
                    await revertInvoicePayment(transactionId, amount, linkedInvoiceIds);
                }
            }
        }
        else if (ledgerType === 'employeeLedger') {
            const employeeId = transaction === null || transaction === void 0 ? void 0 : transaction.employeeId;
            if (!employeeId) {
                console.error('[Transaction] Missing employeeId for employeeLedger transaction deletion', {
                    transactionId,
                    organizationId,
                    employeeId,
                });
                return;
            }
            // Reverse in employee ledger
            const result = await updateEmployeeLedger(organizationId, employeeId, financialYear, transaction, transactionId, snapshot, true);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // Update employee analytics for wage credits (revert)
            const category = transaction.category;
            if (type === 'credit' && category === 'wageCredit') {
                await updateEmployeeAnalytics(organizationId, financialYear, transactionDate, amount, true);
            }
        }
        else if (ledgerType === 'organizationLedger') {
            // Reverse in organization ledger
            const result = await updateOrganizationLedger(organizationId, financialYear, transaction, transactionId, snapshot, true);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
            // Update expense sub-category analytics if this is a general expense
            const category = transaction.category;
            if (category === 'generalExpense') {
                const metadata = transaction.metadata;
                const subCategoryId = metadata === null || metadata === void 0 ? void 0 : metadata.subCategoryId;
                if (subCategoryId) {
                    await updateExpenseSubCategoryAnalytics(organizationId, subCategoryId, amount, transactionDate, true);
                }
            }
        }
        else {
            // Default to clientLedger
            const clientId = transaction.clientId;
            if (!clientId) {
                console.error('[Transaction] Missing clientId for clientLedger transaction deletion', {
                    transactionId,
                    organizationId,
                    clientId,
                });
                return;
            }
            // Reverse in client ledger
            const result = await updateClientLedger(organizationId, clientId, financialYear, transaction, transactionId, snapshot, true);
            balanceBefore = result.balanceBefore;
            balanceAfter = result.balanceAfter;
        }
        // Verify reversal
        if (originalBalanceBefore !== undefined && Math.abs(balanceAfter - originalBalanceBefore) > 0.01) {
            console.warn('[Transaction] Reversal mismatch', {
                transactionId,
                originalBalanceBefore,
                balanceAfter,
                difference: balanceAfter - originalBalanceBefore,
            });
        }
        const ledgerDelta = getLedgerDelta(ledgerType, type, amount);
        console.log('[Transaction] Deleted', {
            transactionId,
            amount,
            type,
            ledgerType,
            ledgerDelta,
            originalBalanceBefore,
            balanceBefore,
            balanceAfter,
        });
        // Reverse in analytics
        await updateTransactionAnalytics(organizationId, financialYear, transaction, transactionDate, true);
        console.log('[Transaction] Successfully processed deletion', {
            transactionId,
            balanceAfter,
        });
    }
    catch (error) {
        console.error('[Transaction] Error processing deletion', {
            transactionId,
            error: error instanceof Error ? error.message : String(error),
            stack: error instanceof Error ? error.stack : undefined,
        });
        throw error;
    }
});
//# sourceMappingURL=transaction-handlers.js.map