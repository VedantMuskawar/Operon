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
exports.rebuildLedgerCore = rebuildLedgerCore;
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const ledger_types_1 = require("../ledger-types");
const ledger_helpers_1 = require("../ledger-helpers");
const db = (0, firestore_1.getFirestore)();
/**
 * Core rebuild logic (extracted for reuse)
 */
async function rebuildLedgerCore(ledgerType, entityId, organizationId, financialYear) {
    var _a, _b;
    const config = (0, ledger_types_1.getLedgerConfig)(ledgerType);
    const ledgerId = (0, ledger_types_1.getLedgerId)(entityId, financialYear);
    const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
    // Get existing ledger to track previous balance
    const ledgerDoc = await ledgerRef.get();
    const previousBalance = ledgerDoc.exists
        ? (((_a = ledgerDoc.data()) === null || _a === void 0 ? void 0 : _a.currentBalance) || 0)
        : 0;
    // Get opening balance from previous FY
    const openingBalance = await (0, ledger_helpers_1.getOpeningBalance)(ledgerType, entityId, financialYear);
    // Get FY date range
    const fyDates = (0, ledger_helpers_1.getFinancialYearDates)(financialYear);
    // Get all transactions from monthly subcollections
    const allTransactions = await (0, ledger_helpers_1.getAllTransactionsFromMonthlyDocs)(ledgerRef);
    // Recalculate balance and totals
    let currentBalance = openingBalance;
    let totalReceivables = 0;
    let totalIncome = 0;
    let totalPayables = 0;
    let totalPayments = 0;
    let totalCredited = 0;
    let transactionCount = 0;
    const transactionIds = [];
    let lastTransactionId = null;
    let lastTransactionDate = null;
    let lastTransactionAmount = null;
    let firstTransactionDate = null;
    for (const transaction of allTransactions) {
        const transactionId = transaction.transactionId;
        const ledgerTypeFromTx = transaction.ledgerType || `${ledgerType}Ledger`;
        const type = transaction.type;
        const amount = transaction.amount || 0;
        const transactionDate = (0, ledger_helpers_1.getTransactionDateFromData)(transaction);
        // Calculate delta
        const delta = (0, ledger_helpers_1.getLedgerDelta)(ledgerTypeFromTx, type, amount);
        currentBalance += delta;
        // Update totals based on ledger type
        if (ledgerType === 'client') {
            if (type === 'credit') {
                totalReceivables += amount;
            }
            else {
                totalIncome += amount;
            }
        }
        else if (ledgerType === 'vendor') {
            if (type === 'credit') {
                totalPayables += amount;
            }
            else {
                totalPayments += amount;
            }
        }
        else if (ledgerType === 'employee') {
            if (type === 'credit') {
                totalCredited += amount;
            }
        }
        transactionCount++;
        if (transactionId && !transactionIds.includes(transactionId)) {
            transactionIds.push(transactionId);
        }
        // Track first and last transaction
        if (!firstTransactionDate || transactionDate < firstTransactionDate.toDate()) {
            firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
        }
        if (!lastTransactionDate || transactionDate > lastTransactionDate.toDate()) {
            lastTransactionId = transactionId;
            lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
            lastTransactionAmount = amount;
        }
    }
    // Build ledger data (type-specific fields)
    const baseLedgerData = {
        ledgerId,
        organizationId,
        [config.idField]: entityId,
        financialYear,
        fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
        fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
        openingBalance,
        currentBalance,
        transactionCount,
        transactionIds,
        lastTransactionId: lastTransactionId || null,
        lastTransactionDate: lastTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
        lastTransactionAmount: lastTransactionAmount || null,
        firstTransactionDate: firstTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    // Add type-specific totals
    if (ledgerType === 'client') {
        baseLedgerData.totalReceivables = totalReceivables;
        baseLedgerData.totalIncome = totalIncome;
        baseLedgerData.netBalance = currentBalance;
    }
    else if (ledgerType === 'vendor') {
        baseLedgerData.totalPayables = totalPayables;
        baseLedgerData.totalPayments = totalPayments;
        baseLedgerData.lastUpdated = admin.firestore.Timestamp.now();
    }
    else if (ledgerType === 'employee') {
        baseLedgerData.totalCredited = totalCredited;
        baseLedgerData.totalTransactions = transactionCount;
        baseLedgerData.createdAt = ledgerDoc.exists
            ? (((_b = ledgerDoc.data()) === null || _b === void 0 ? void 0 : _b.createdAt) || admin.firestore.Timestamp.now())
            : admin.firestore.Timestamp.now();
        baseLedgerData.updatedAt = admin.firestore.Timestamp.now();
    }
    // Update or create ledger document
    if (ledgerDoc.exists) {
        await ledgerRef.update(baseLedgerData);
    }
    else {
        baseLedgerData.metadata = {};
        baseLedgerData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        await ledgerRef.set(baseLedgerData);
    }
    // Update entity.currentBalance to match ledger (skip if entity missing)
    const entityRef = db.collection(config.entityCollectionName).doc(entityId);
    const entityDoc = await entityRef.get();
    if (entityDoc.exists) {
        await entityRef.update({
            [config.balanceField]: currentBalance,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    else {
        console.warn('[Ledger Rebuild] Entity document missing; skipped entity balance update', {
            ledgerType,
            entityId,
            organizationId,
            financialYear,
        });
    }
    return {
        previousBalance,
        newBalance: currentBalance,
        transactionCount,
    };
}
//# sourceMappingURL=rebuild-ledger-core.js.map