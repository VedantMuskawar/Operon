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
exports.generateAccountsLedger = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const function_config_1 = require("../shared/function-config");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const ledger_helpers_1 = require("./ledger-helpers");
const date_helpers_1 = require("../shared/date-helpers");
const transaction_helpers_1 = require("../shared/transaction-helpers");
const logger_1 = require("../shared/logger");
const db = (0, firestore_helpers_1.getFirestore)();
const ledgerTypeMap = {
    client: 'clientLedger',
    vendor: 'vendorLedger',
    employee: 'employeeLedger',
};
const ledgerCollectionMap = {
    client: constants_1.CLIENT_LEDGERS_COLLECTION,
    vendor: constants_1.VENDOR_LEDGERS_COLLECTION,
    employee: constants_1.EMPLOYEE_LEDGERS_COLLECTION,
};
const idFieldMap = {
    client: 'clientId',
    vendor: 'vendorId',
    employee: 'employeeId',
};
function chunkIds(ids, size) {
    const chunks = [];
    for (let i = 0; i < ids.length; i += size) {
        chunks.push(ids.slice(i, i + size));
    }
    return chunks;
}
async function getCombinedOpeningBalance(accounts, financialYear) {
    if (!accounts || accounts.length === 0)
        return 0;
    const balances = await Promise.all(accounts.map(async (account) => {
        const collection = ledgerCollectionMap[account.type];
        if (!collection || !account.id)
            return 0;
        const ledgerId = `${account.id}_${financialYear}`;
        const ledgerDoc = await db.collection(collection).doc(ledgerId).get();
        if (!ledgerDoc.exists)
            return 0;
        return ledgerDoc.get('openingBalance') || 0;
    }));
    return balances.reduce((sum, value) => sum + value, 0);
}
async function fetchTransactionsForAccounts(organizationId, financialYear, type, ids) {
    if (ids.length === 0)
        return [];
    const chunks = chunkIds(ids, 10);
    const snapshots = [];
    for (const chunk of chunks) {
        const query = db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('financialYear', '==', financialYear)
            .where('ledgerType', '==', ledgerTypeMap[type])
            .where(idFieldMap[type], 'in', chunk);
        const result = await query.get();
        result.docs.forEach((doc) => snapshots.push(doc));
    }
    return snapshots;
}
exports.generateAccountsLedger = (0, https_1.onCall)(function_config_1.CALLABLE_OPTS, async (request) => {
    const data = request.data;
    try {
        const { organizationId, financialYear, accountsLedgerId, ledgerName, accounts, clearMissingMonths = true, } = data;
        if (!organizationId || !financialYear || !accountsLedgerId) {
            throw new Error('Missing required parameters: organizationId, financialYear, accountsLedgerId');
        }
        if (!accounts || accounts.length < 2) {
            throw new Error('At least two accounts are required to generate a combined ledger');
        }
        (0, logger_1.logInfo)('AccountsLedger', 'generateAccountsLedger', 'Generating accounts ledger', {
            organizationId,
            financialYear,
            accountsLedgerId,
            accountCount: accounts.length,
        });
        const accountsByType = {
            client: [],
            vendor: [],
            employee: [],
        };
        accounts.forEach((account) => {
            if (accountsByType[account.type]) {
                accountsByType[account.type].push(account.id);
            }
        });
        const snapshots = (await Promise.all([
            fetchTransactionsForAccounts(organizationId, financialYear, 'client', accountsByType.client),
            fetchTransactionsForAccounts(organizationId, financialYear, 'vendor', accountsByType.vendor),
            fetchTransactionsForAccounts(organizationId, financialYear, 'employee', accountsByType.employee),
        ])).flat();
        const transactionMap = new Map();
        snapshots.forEach((doc) => {
            const transactionId = doc.get('transactionId') || doc.id;
            transactionMap.set(transactionId, doc);
        });
        const transactions = Array.from(transactionMap.values());
        transactions.sort((a, b) => {
            const dateA = (0, transaction_helpers_1.getTransactionDate)(a).getTime();
            const dateB = (0, transaction_helpers_1.getTransactionDate)(b).getTime();
            if (dateA !== dateB)
                return dateA - dateB;
            return a.id.localeCompare(b.id);
        });
        const ledgerId = `${accountsLedgerId}_${financialYear}`;
        const ledgerRef = db.collection(constants_1.ACCOUNTS_LEDGERS_COLLECTION).doc(ledgerId);
        const fyDates = (0, ledger_helpers_1.getFinancialYearDates)(financialYear);
        const openingBalance = await getCombinedOpeningBalance(accounts, financialYear);
        let currentBalance = openingBalance;
        const monthlyBuckets = new Map();
        const transactionIds = [];
        let firstTransactionDate = null;
        let lastTransactionDate = null;
        let lastTransactionId = null;
        let lastTransactionAmount = null;
        transactions.forEach((snapshot) => {
            var _a, _b;
            const transactionId = snapshot.get('transactionId') || snapshot.id;
            const data = snapshot.data();
            const transactionDate = (0, transaction_helpers_1.getTransactionDate)(snapshot);
            const yearMonth = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
            const amount = data.amount || 0;
            const type = data.type || 'debit';
            const ledgerType = data.ledgerType || 'organizationLedger';
            const ledgerDelta = (0, ledger_helpers_1.getLedgerDelta)(ledgerType, type, amount);
            const balanceBefore = currentBalance;
            currentBalance += ledgerDelta;
            const balanceAfter = currentBalance;
            const transactionData = {
                transactionId,
                organizationId,
                ledgerType,
                type,
                category: data.category,
                amount,
                financialYear,
                transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                updatedAt: admin.firestore.Timestamp.now(),
                balanceBefore,
                balanceAfter,
            };
            if (data.clientId)
                transactionData.clientId = data.clientId;
            if (data.vendorId)
                transactionData.vendorId = data.vendorId;
            if (data.employeeId)
                transactionData.employeeId = data.employeeId;
            if (data.createdAt) {
                transactionData.createdAt = data.createdAt;
            }
            else {
                transactionData.createdAt = admin.firestore.Timestamp.now();
            }
            if (data.paymentAccountId)
                transactionData.paymentAccountId = data.paymentAccountId;
            if (data.paymentAccountType)
                transactionData.paymentAccountType = data.paymentAccountType;
            if (data.referenceNumber)
                transactionData.referenceNumber = data.referenceNumber;
            if (data.tripId || data.orderId)
                transactionData.tripId = (_a = data.tripId) !== null && _a !== void 0 ? _a : data.orderId;
            if (data.description)
                transactionData.description = data.description;
            if (data.metadata)
                transactionData.metadata = data.metadata;
            if (data.createdBy)
                transactionData.createdBy = data.createdBy;
            const cleanData = (0, transaction_helpers_1.removeUndefinedFields)(transactionData);
            const bucket = (_b = monthlyBuckets.get(yearMonth)) !== null && _b !== void 0 ? _b : [];
            bucket.push(cleanData);
            monthlyBuckets.set(yearMonth, bucket);
            transactionIds.push(transactionId);
            if (!firstTransactionDate) {
                firstTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
            }
            lastTransactionDate = admin.firestore.Timestamp.fromDate(transactionDate);
            lastTransactionId = transactionId;
            lastTransactionAmount = amount;
        });
        const batch = db.batch();
        if (clearMissingMonths) {
            const existingDocs = await ledgerRef.collection('TRANSACTIONS').get();
            existingDocs.forEach((doc) => {
                if (!monthlyBuckets.has(doc.id)) {
                    batch.delete(doc.ref);
                }
            });
        }
        monthlyBuckets.forEach((bucket, yearMonth) => {
            const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(yearMonth);
            batch.set(monthlyRef, {
                yearMonth,
                transactions: bucket,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        const totals = transactions.reduce((acc, snapshot) => {
            const amount = snapshot.get('amount') || 0;
            const type = snapshot.get('type') || 'debit';
            if (type === 'credit') {
                acc.totalCredits += amount;
            }
            else {
                acc.totalDebits += amount;
            }
            return acc;
        }, { totalCredits: 0, totalDebits: 0 });
        batch.set(ledgerRef, {
            ledgerId,
            accountsLedgerId,
            organizationId,
            financialYear,
            ledgerType: 'accountsLedger',
            ledgerName: ledgerName !== null && ledgerName !== void 0 ? ledgerName : 'Combined Ledger',
            accounts,
            fyStartDate: admin.firestore.Timestamp.fromDate(fyDates.start),
            fyEndDate: admin.firestore.Timestamp.fromDate(fyDates.end),
            openingBalance,
            currentBalance,
            totalCredits: totals.totalCredits,
            totalDebits: totals.totalDebits,
            transactionCount: transactionIds.length,
            transactionIds,
            lastTransactionId: lastTransactionId !== null && lastTransactionId !== void 0 ? lastTransactionId : null,
            lastTransactionDate: lastTransactionDate !== null && lastTransactionDate !== void 0 ? lastTransactionDate : null,
            lastTransactionAmount: lastTransactionAmount !== null && lastTransactionAmount !== void 0 ? lastTransactionAmount : null,
            firstTransactionDate: firstTransactionDate !== null && firstTransactionDate !== void 0 ? firstTransactionDate : null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await batch.commit();
        (0, logger_1.logInfo)('AccountsLedger', 'generateAccountsLedger', 'Accounts ledger generated', {
            ledgerId,
            transactionCount: transactionIds.length,
        });
        return {
            success: true,
            ledgerId,
            transactionCount: transactionIds.length,
        };
    }
    catch (error) {
        (0, logger_1.logError)('AccountsLedger', 'generateAccountsLedger', 'Failed to generate accounts ledger', error instanceof Error ? error : String(error), data);
        throw error;
    }
});
//# sourceMappingURL=accounts-ledger.js.map