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
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const db = (0, firestore_helpers_1.getFirestore)();
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
 * Get year-month string in format YYYYMM for document IDs
 * @param date - The date to format
 * @returns Year-month string (e.g., "202401" for January 2024)
 */
function getYearMonth(date) {
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    return `${year}${month}`;
}
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
/**
 * Remove all undefined values from an object (recursive cleanup for nested objects)
 * Also explicitly excludes the 'status' field which is no longer part of the transaction model
 * @param obj - The object to clean
 * @returns A cleaned object without undefined values and without 'status' field
 */
function removeUndefinedFields(obj) {
    if (obj === null || obj === undefined) {
        return obj;
    }
    if (Array.isArray(obj)) {
        return obj.map(item => removeUndefinedFields(item));
    }
    if (typeof obj !== 'object') {
        return obj;
    }
    const cleaned = {};
    const excludeFields = ['status']; // Fields to explicitly exclude
    for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
            // Skip excluded fields (like status)
            if (excludeFields.includes(key)) {
                continue;
            }
            const value = obj[key];
            // Skip undefined values
            if (value !== undefined) {
                if (typeof value === 'object' && value !== null && !(value instanceof admin.firestore.Timestamp) && !(value instanceof admin.firestore.FieldValue)) {
                    cleaned[key] = removeUndefinedFields(value);
                }
                else {
                    cleaned[key] = value;
                }
            }
        }
    }
    return cleaned;
}
/**
 * Update client ledger when transaction is created or cancelled
 * Returns the balanceBefore and balanceAfter values for the transaction
 */
async function updateClientLedger(organizationId, clientId, financialYear, transaction, transactionId, snapshot, isCancellation = false) {
    var _a;
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
    const transactionDate = getTransactionDate(snapshot);
    const yearMonth = getYearMonth(transactionDate);
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
            const cleanData = removeUndefinedFields(transactionData);
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
            const cleanData = removeUndefinedFields(transactionData);
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
    const transactionDate = getTransactionDate(snapshot);
    const yearMonth = getYearMonth(transactionDate);
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
    const transactionDate = getTransactionDate(snapshot);
    const yearMonth = getYearMonth(transactionDate);
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
                const cleanData = removeUndefinedFields(transactionData);
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
 * Update analytics when transaction is created or cancelled
 */
async function updateTransactionAnalytics(organizationId, financialYear, transaction, transactionDate, isCancellation = false) {
    const analyticsDocId = `${constants_1.TRANSACTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
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
    const monthString = (0, date_helpers_1.formatMonth)(transactionDate);
    // Get current analytics data
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
    // Update monthly breakdown
    const incomeMonthly = analyticsData.incomeMonthly || {};
    const receivablesMonthly = analyticsData.receivablesMonthly || {};
    if (isDebit && ledgerType === 'clientLedger') {
        incomeMonthly[monthString] = (incomeMonthly[monthString] || 0) + (amount * multiplier);
    }
    else if (isCredit && ledgerType === 'clientLedger') {
        receivablesMonthly[monthString] = (receivablesMonthly[monthString] || 0) + (amount * multiplier);
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
        byPaymentAccount[accountId].daily = (0, date_helpers_1.cleanDailyData)(byPaymentAccount[accountId].daily, 90);
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
    byPaymentMethodType[methodType].daily = (0, date_helpers_1.cleanDailyData)(byPaymentMethodType[methodType].daily, 90);
    // Calculate totals
    const totalIncome = Object.values(incomeMonthly).reduce((sum, val) => sum + (val || 0), 0);
    const totalReceivables = Object.values(receivablesMonthly).reduce((sum, val) => sum + (val || 0), 0);
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
    // Update analytics document
    await analyticsRef.set({
        source: constants_1.TRANSACTIONS_SOURCE_KEY,
        organizationId,
        financialYear,
        incomeDaily,
        receivablesDaily,
        incomeWeekly,
        receivablesWeekly,
        incomeMonthly,
        receivablesMonthly,
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
 * Cloud Function: Triggered when a transaction is created
 */
exports.onTransactionCreated = functions.firestore
    .document(`${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}`)
    .onCreate(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;
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
    const transactionDate = getTransactionDate(snapshot);
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
exports.onTransactionDeleted = functions.firestore
    .document(`${constants_1.TRANSACTIONS_COLLECTION}/{transactionId}`)
    .onDelete(async (snapshot, context) => {
    const transaction = snapshot.data();
    const transactionId = context.params.transactionId;
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
    const transactionDate = getTransactionDate(snapshot);
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