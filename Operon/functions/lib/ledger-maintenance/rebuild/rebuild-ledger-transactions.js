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
exports.rebuildLedgerTransactionsScheduled = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_helpers_1 = require("../../shared/firestore-helpers");
const function_config_1 = require("../../shared/function-config");
const financial_year_1 = require("../../shared/financial-year");
const logger_1 = require("../../shared/logger");
const constants_1 = require("../../shared/constants");
const date_helpers_1 = require("../../shared/date-helpers");
const transaction_helpers_1 = require("../../shared/transaction-helpers");
const ledger_types_1 = require("../ledger-types");
const db = (0, firestore_helpers_1.getFirestore)();
const LEDGER_TYPE_MAP = [
    { ledgerType: 'clientLedger', typeKey: 'client' },
    { ledgerType: 'vendorLedger', typeKey: 'vendor' },
    { ledgerType: 'employeeLedger', typeKey: 'employee' },
];
function getTransactionDate(data, doc) {
    const dateValue = data.transactionDate || data.createdAt;
    if (dateValue === null || dateValue === void 0 ? void 0 : dateValue.toDate) {
        return dateValue.toDate();
    }
    if (dateValue instanceof admin.firestore.Timestamp) {
        return dateValue.toDate();
    }
    if (doc.createTime) {
        return doc.createTime.toDate();
    }
    return new Date();
}
async function ensureLedgerDoc(ledgerId, config, organizationId, entityId, financialYear) {
    const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
    const ledgerDoc = await ledgerRef.get();
    if (ledgerDoc.exists)
        return ledgerRef;
    await ledgerRef.set({
        ledgerId,
        organizationId,
        [config.idField]: entityId,
        financialYear,
        openingBalance: 0,
        currentBalance: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return ledgerRef;
}
async function deleteStaleMonthlyDocs(ledgerRef, validMonthIds) {
    const existing = await ledgerRef.collection('TRANSACTIONS').get();
    const staleDocs = existing.docs.filter((doc) => !validMonthIds.has(doc.id));
    if (staleDocs.length === 0)
        return 0;
    const BATCH_SIZE = 400;
    let deleted = 0;
    for (let i = 0; i < staleDocs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        const chunk = staleDocs.slice(i, i + BATCH_SIZE);
        chunk.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        deleted += chunk.length;
    }
    return deleted;
}
async function rebuildLedgerTypeTransactions(typeKey, ledgerTypeValue, financialYear) {
    var _a;
    const config = (0, ledger_types_1.getLedgerConfig)(typeKey);
    const ledgerMap = new Map();
    const BATCH_SIZE = 500;
    let lastDoc = null;
    let processed = 0;
    while (true) {
        let query = db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('ledgerType', '==', ledgerTypeValue)
            .where('financialYear', '==', financialYear)
            .orderBy(admin.firestore.FieldPath.documentId())
            .limit(BATCH_SIZE);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }
        const snapshot = await query.get();
        if (snapshot.empty) {
            break;
        }
        for (const doc of snapshot.docs) {
            processed += 1;
            const data = doc.data();
            const entityId = data[config.idField];
            const organizationId = data.organizationId;
            if (!entityId || !organizationId) {
                (0, logger_1.logWarning)('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Missing entity/organization', {
                    ledgerType: ledgerTypeValue,
                    transactionId: doc.id,
                });
                continue;
            }
            const transactionDate = getTransactionDate(data, doc);
            const monthKey = (0, date_helpers_1.getYearMonthCompact)(transactionDate);
            const ledgerId = `${entityId}_${financialYear}`;
            const txData = (0, transaction_helpers_1.removeUndefinedFields)({
                transactionId: doc.id,
                organizationId,
                [config.idField]: entityId,
                ledgerType: data.ledgerType || ledgerTypeValue,
                type: data.type,
                category: data.category,
                amount: data.amount,
                financialYear: data.financialYear,
                transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
                createdAt: data.createdAt || admin.firestore.Timestamp.fromDate(transactionDate),
                updatedAt: data.updatedAt || admin.firestore.Timestamp.fromDate(transactionDate),
                paymentAccountId: data.paymentAccountId,
                paymentAccountType: data.paymentAccountType,
                referenceNumber: data.referenceNumber,
                description: data.description,
                metadata: data.metadata,
                createdBy: data.createdBy,
                employeeName: data.employeeName,
                clientName: data.clientName,
                vendorName: data.vendorName,
            });
            if (!ledgerMap.has(ledgerId)) {
                ledgerMap.set(ledgerId, {
                    organizationId,
                    entityId,
                    months: new Map(),
                });
            }
            const ledgerEntry = ledgerMap.get(ledgerId);
            if (!ledgerEntry.months.has(monthKey)) {
                ledgerEntry.months.set(monthKey, []);
            }
            ledgerEntry.months.get(monthKey).push(txData);
        }
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < BATCH_SIZE) {
            break;
        }
    }
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Collected transactions', {
        ledgerType: ledgerTypeValue,
        financialYear,
        processed,
        ledgers: ledgerMap.size,
    });
    let ledgersTouched = 0;
    let monthsWritten = 0;
    let monthsDeleted = 0;
    const ledgersSnapshot = await db
        .collection(config.collectionName)
        .where('financialYear', '==', financialYear)
        .get();
    for (const ledgerDoc of ledgersSnapshot.docs) {
        const ledgerData = ledgerDoc.data();
        const entityId = ledgerData[config.idField];
        if (!entityId) {
            (0, logger_1.logWarning)('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Ledger missing entityId', {
                ledgerType: ledgerTypeValue,
                ledgerId: ledgerDoc.id,
            });
            continue;
        }
        const ledgerId = ledgerDoc.id;
        const ledgerEntry = ledgerMap.get(ledgerId);
        const monthsMap = (_a = ledgerEntry === null || ledgerEntry === void 0 ? void 0 : ledgerEntry.months) !== null && _a !== void 0 ? _a : new Map();
        const validMonthIds = new Set(monthsMap.keys());
        const deleted = await deleteStaleMonthlyDocs(ledgerDoc.ref, validMonthIds);
        monthsDeleted += deleted;
        if (monthsMap.size === 0) {
            ledgersTouched += 1;
            continue;
        }
        for (const [monthKey, transactions] of monthsMap.entries()) {
            const monthlyRef = ledgerDoc.ref.collection('TRANSACTIONS').doc(monthKey);
            const totalCredit = transactions
                .filter((t) => t.type === 'credit')
                .reduce((sum, t) => sum + (t.amount || 0), 0);
            const totalDebit = transactions
                .filter((t) => t.type === 'debit')
                .reduce((sum, t) => sum + (t.amount || 0), 0);
            await monthlyRef.set({
                yearMonth: monthKey,
                transactions,
                transactionCount: transactions.length,
                totalCredit,
                totalDebit,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            monthsWritten += 1;
        }
        ledgersTouched += 1;
    }
    const ledgersWithoutDocs = Array.from(ledgerMap.keys()).filter((ledgerId) => !ledgersSnapshot.docs.some((doc) => doc.id === ledgerId));
    for (const ledgerId of ledgersWithoutDocs) {
        const entry = ledgerMap.get(ledgerId);
        if (!entry)
            continue;
        const ledgerRef = await ensureLedgerDoc(ledgerId, config, entry.organizationId, entry.entityId, financialYear);
        const validMonthIds = new Set(entry.months.keys());
        monthsDeleted += await deleteStaleMonthlyDocs(ledgerRef, validMonthIds);
        for (const [monthKey, transactions] of entry.months.entries()) {
            const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(monthKey);
            const totalCredit = transactions
                .filter((t) => t.type === 'credit')
                .reduce((sum, t) => sum + (t.amount || 0), 0);
            const totalDebit = transactions
                .filter((t) => t.type === 'debit')
                .reduce((sum, t) => sum + (t.amount || 0), 0);
            await monthlyRef.set({
                yearMonth: monthKey,
                transactions,
                transactionCount: transactions.length,
                totalCredit,
                totalDebit,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            monthsWritten += 1;
        }
        ledgersTouched += 1;
    }
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Rebuilt ledger subcollections', {
        ledgerType: ledgerTypeValue,
        financialYear,
        ledgersTouched,
        monthsWritten,
        monthsDeleted,
    });
}
/**
 * Rebuild attendance subcollections from TRANSACTIONS
 */
async function rebuildAttendance(financialYear) {
    var _a;
    const attendanceMap = new Map();
    const BATCH_SIZE = 500;
    let lastDoc = null;
    let processed = 0;
    // Fetch all employee transactions with batchId or tripWageId
    while (true) {
        let query = db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('ledgerType', '==', 'employeeLedger')
            .where('financialYear', '==', financialYear)
            .orderBy(admin.firestore.FieldPath.documentId())
            .limit(BATCH_SIZE);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }
        const snapshot = await query.get();
        if (snapshot.empty) {
            break;
        }
        for (const doc of snapshot.docs) {
            processed += 1;
            const data = doc.data();
            const employeeId = data.employeeId;
            const organizationId = data.organizationId;
            const metadata = data.metadata;
            const batchId = metadata === null || metadata === void 0 ? void 0 : metadata.batchId;
            const tripWageId = metadata === null || metadata === void 0 ? void 0 : metadata.tripWageId;
            if (!employeeId || !organizationId || (!batchId && !tripWageId)) {
                continue;
            }
            const transactionDate = getTransactionDate(data, doc);
            const monthKey = (0, date_helpers_1.getYearMonth)(transactionDate);
            const normalizedDate = (0, date_helpers_1.normalizeDate)(transactionDate);
            const ledgerId = `${employeeId}_${financialYear}`;
            if (!attendanceMap.has(ledgerId)) {
                attendanceMap.set(ledgerId, {
                    organizationId,
                    employeeId,
                    months: new Map(),
                });
            }
            const ledgerEntry = attendanceMap.get(ledgerId);
            if (!ledgerEntry.months.has(monthKey)) {
                ledgerEntry.months.set(monthKey, []);
            }
            ledgerEntry.months.get(monthKey).push({
                date: normalizedDate,
                batchId,
                tripWageId,
            });
        }
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        if (snapshot.size < BATCH_SIZE) {
            break;
        }
    }
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAttendance', 'Collected attendance data', {
        financialYear,
        processed,
        ledgers: attendanceMap.size,
    });
    let ledgersTouched = 0;
    let monthsWritten = 0;
    let monthsDeleted = 0;
    // Fetch all employee ledgers for this FY to ensure we clean up empty attendance docs
    const ledgersSnapshot = await db
        .collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION)
        .where('financialYear', '==', financialYear)
        .get();
    for (const ledgerDoc of ledgersSnapshot.docs) {
        const ledgerId = ledgerDoc.id;
        const ledgerData = ledgerDoc.data();
        const employeeId = ledgerData.employeeId;
        const organizationId = ledgerData.organizationId;
        if (!employeeId || !organizationId) {
            (0, logger_1.logWarning)('LedgerMaintenance', 'rebuildAttendance', 'Employee ledger missing data', {
                ledgerId,
            });
            continue;
        }
        const ledgerEntry = attendanceMap.get(ledgerId);
        const monthsMap = (_a = ledgerEntry === null || ledgerEntry === void 0 ? void 0 : ledgerEntry.months) !== null && _a !== void 0 ? _a : new Map();
        const validMonthIds = new Set(monthsMap.keys());
        // Delete stale attendance docs
        const existingAttendance = await ledgerDoc.ref.collection('Attendance').get();
        const staleDocs = existingAttendance.docs.filter((doc) => !validMonthIds.has(doc.id));
        for (const doc of staleDocs) {
            await doc.ref.delete();
            monthsDeleted += 1;
        }
        if (monthsMap.size === 0) {
            ledgersTouched += 1;
            continue;
        }
        // Group attendance records by date and aggregate batch/trip IDs
        for (const [monthKey, records] of monthsMap.entries()) {
            const dailyMap = new Map();
            for (const record of records) {
                const dateKey = record.date.toISOString().split('T')[0];
                if (!dailyMap.has(dateKey)) {
                    dailyMap.set(dateKey, {
                        date: record.date,
                        batchIds: [],
                        tripWageIds: [],
                    });
                }
                const dailyEntry = dailyMap.get(dateKey);
                if (record.batchId && !dailyEntry.batchIds.includes(record.batchId)) {
                    dailyEntry.batchIds.push(record.batchId);
                }
                if (record.tripWageId && !dailyEntry.tripWageIds.includes(record.tripWageId)) {
                    dailyEntry.tripWageIds.push(record.tripWageId);
                }
            }
            const dailyRecords = Array.from(dailyMap.values()).map((entry) => {
                const record = {
                    date: admin.firestore.Timestamp.fromDate(entry.date),
                    isPresent: true,
                };
                if (entry.batchIds.length > 0) {
                    record.batchIds = entry.batchIds;
                    record.numberOfBatches = entry.batchIds.length;
                }
                if (entry.tripWageIds.length > 0) {
                    record.tripWageIds = entry.tripWageIds;
                    record.numberOfTrips = entry.tripWageIds.length;
                }
                return record;
            });
            const totalDaysPresent = dailyRecords.filter((r) => r.isPresent === true).length;
            const totalBatchesWorked = dailyRecords.reduce((sum, r) => sum + (r.numberOfBatches || 0), 0);
            const totalTripsWorked = dailyRecords.reduce((sum, r) => sum + (r.numberOfTrips || 0), 0);
            const attendanceRef = ledgerDoc.ref.collection('Attendance').doc(monthKey);
            const attendanceData = {
                yearMonth: monthKey,
                employeeId,
                organizationId,
                financialYear,
                dailyRecords,
                totalDaysPresent,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (totalBatchesWorked > 0) {
                attendanceData.totalBatchesWorked = totalBatchesWorked;
            }
            if (totalTripsWorked > 0) {
                attendanceData.totalTripsWorked = totalTripsWorked;
            }
            await attendanceRef.set(attendanceData, { merge: true });
            monthsWritten += 1;
        }
        ledgersTouched += 1;
    }
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildAttendance', 'Rebuilt attendance subcollections', {
        financialYear,
        ledgersTouched,
        monthsWritten,
        monthsDeleted,
    });
}
/**
 * Scheduled weekly rebuild of ledger TRANSACTIONS and Attendance subcollections
 * Uses source TRANSACTIONS to rebuild client/vendor/employee ledger monthly docs and attendance.
 */
exports.rebuildLedgerTransactionsScheduled = (0, scheduler_1.onSchedule)(Object.assign({ schedule: '0 3 * * 1', timeZone: 'UTC' }, function_config_1.SCHEDULED_FUNCTION_OPTS), async () => {
    const now = new Date();
    const { fyLabel } = (0, financial_year_1.getFinancialContext)(now);
    (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedgerTransactionsScheduled', 'Starting rebuild', {
        financialYear: fyLabel,
        timestamp: now.toISOString(),
    });
    try {
        for (const entry of LEDGER_TYPE_MAP) {
            await rebuildLedgerTypeTransactions(entry.typeKey, entry.ledgerType, fyLabel);
        }
        // Rebuild attendance subcollections
        await rebuildAttendance(fyLabel);
        (0, logger_1.logInfo)('LedgerMaintenance', 'rebuildLedgerTransactionsScheduled', 'Rebuild completed', {
            financialYear: fyLabel,
        });
    }
    catch (error) {
        (0, logger_1.logError)('LedgerMaintenance', 'rebuildLedgerTransactionsScheduled', 'Rebuild failed', error instanceof Error ? error : String(error));
        throw error;
    }
});
//# sourceMappingURL=rebuild-ledger-transactions.js.map