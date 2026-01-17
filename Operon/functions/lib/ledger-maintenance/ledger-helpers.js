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
exports.getFinancialYearDates = getFinancialYearDates;
exports.getLedgerDelta = getLedgerDelta;
exports.getOpeningBalance = getOpeningBalance;
exports.getLedgerId = getLedgerId;
exports.getAllTransactionsFromMonthlyDocs = getAllTransactionsFromMonthlyDocs;
exports.getTransactionDateFromData = getTransactionDateFromData;
exports.getYearMonthFromDate = getYearMonthFromDate;
const admin = __importStar(require("firebase-admin"));
const firestore_helpers_1 = require("../shared/firestore-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const ledger_types_1 = require("./ledger-types");
const logger_1 = require("../shared/logger");
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
 */
function getLedgerDelta(ledgerType, type, amount) {
    // All ledger types use the same logic: credit increases balance, debit decreases
    // For clients: credit = receivable (client owes), debit = payment (client paid)
    // For vendors: credit = payable (we owe), debit = payment (we paid)
    // For employees: credit = payable (we owe), debit = payment (we paid)
    return type === 'credit' ? amount : -amount;
}
/**
 * Get opening balance from previous financial year (generic for all ledger types)
 */
async function getOpeningBalance(ledgerType, entityId, currentFY) {
    const config = (0, ledger_types_1.getLedgerConfig)(ledgerType);
    try {
        const previousFY = getPreviousFinancialYear(currentFY);
        const previousLedgerId = `${entityId}_${previousFY}`;
        const previousLedgerRef = db.collection(config.collectionName).doc(previousLedgerId);
        const previousLedgerDoc = await previousLedgerRef.get();
        if (previousLedgerDoc.exists) {
            const previousLedgerData = previousLedgerDoc.data();
            return previousLedgerData.currentBalance || 0;
        }
    }
    catch (error) {
        (0, logger_1.logWarning)('LedgerMaintenance', 'getOpeningBalance', 'Error fetching previous FY balance, defaulting to 0', {
            ledgerType,
            entityId,
            currentFY,
            error: error instanceof Error ? error.message : String(error),
        });
    }
    return 0;
}
/**
 * Get ledger document ID from entity ID and financial year
 */
function getLedgerId(entityId, financialYear) {
    return `${entityId}_${financialYear}`;
}
/**
 * Get all transactions from monthly subcollection documents
 */
async function getAllTransactionsFromMonthlyDocs(ledgerRef) {
    const transactionsSubRef = ledgerRef.collection('TRANSACTIONS');
    const monthlyDocsSnapshot = await transactionsSubRef.get();
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
    return allTransactions;
}
/**
 * Get transaction date from transaction object
 */
function getTransactionDateFromData(transaction) {
    var _a, _b;
    if ((_a = transaction.transactionDate) === null || _a === void 0 ? void 0 : _a.toDate) {
        return transaction.transactionDate.toDate();
    }
    else if ((_b = transaction.transactionDate) === null || _b === void 0 ? void 0 : _b._seconds) {
        return new Date(transaction.transactionDate._seconds * 1000);
    }
    else if (transaction.transactionDate instanceof admin.firestore.Timestamp) {
        return transaction.transactionDate.toDate();
    }
    else {
        return new Date(transaction.transactionDate || Date.now());
    }
}
/**
 * Calculate year-month string from date (YYYYMM format for document IDs)
 */
function getYearMonthFromDate(date) {
    return (0, date_helpers_1.getYearMonthCompact)(date);
}
//# sourceMappingURL=ledger-helpers.js.map