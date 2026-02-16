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
exports.processProductionBatchWages = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const logger_1 = require("../shared/logger");
const db = (0, firestore_1.getFirestore)();
const BATCH_WRITE_LIMIT = 500; // Firestore batch write limit
/**
 * Compute attendance write payload from a read snapshot (no tx writes).
 * Firestore transactions require all reads before any writes.
 */
function computeAttendanceWrite(attendanceDoc, organizationId, employeeId, batchDate, batchId) {
    const financialYear = (0, financial_year_1.getFinancialContext)(batchDate).fyLabel;
    const yearMonth = (0, date_helpers_1.getYearMonth)(batchDate);
    const ledgerId = `${employeeId}_${financialYear}`;
    const normalizedDate = (0, date_helpers_1.normalizeDate)(batchDate);
    const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
    const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
    const attendanceData = attendanceDoc.data();
    let dailyRecords = [];
    let totalDaysPresent = 0;
    let totalBatchesWorked = 0;
    if (attendanceDoc.exists && attendanceData != null) {
        dailyRecords = Array.from(attendanceData.dailyRecords || []);
        const dateIndex = dailyRecords.findIndex((record) => {
            var _a, _b;
            let recordDate;
            if ((_a = record.date) === null || _a === void 0 ? void 0 : _a.toDate) {
                recordDate = record.date.toDate();
            }
            else if ((_b = record.date) === null || _b === void 0 ? void 0 : _b._seconds) {
                recordDate = new Date(record.date._seconds * 1000);
            }
            else if (record.date instanceof admin.firestore.Timestamp) {
                recordDate = record.date.toDate();
            }
            else {
                recordDate = new Date(record.date);
            }
            const normalizedRecordDate = (0, date_helpers_1.normalizeDate)(recordDate);
            return normalizedRecordDate.getTime() === normalizedDate.getTime();
        });
        if (dateIndex >= 0) {
            const existingRecord = dailyRecords[dateIndex];
            const batchIds = Array.from(existingRecord.batchIds || []);
            if (!batchIds.includes(batchId)) {
                batchIds.push(batchId);
                dailyRecords[dateIndex] = Object.assign(Object.assign({}, existingRecord), { numberOfBatches: batchIds.length, batchIds });
            }
        }
        else {
            dailyRecords.push({
                date: admin.firestore.Timestamp.fromDate(normalizedDate),
                isPresent: true,
                numberOfBatches: 1,
                batchIds: [batchId],
            });
        }
        totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
        totalBatchesWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfBatches || 0), 0);
    }
    else {
        dailyRecords = [
            {
                date: admin.firestore.Timestamp.fromDate(normalizedDate),
                isPresent: true,
                numberOfBatches: 1,
                batchIds: [batchId],
            },
        ];
        totalDaysPresent = 1;
        totalBatchesWorked = 1;
    }
    const attendanceJson = {
        yearMonth,
        employeeId,
        organizationId,
        financialYear,
        dailyRecords,
        totalDaysPresent,
        totalBatchesWorked,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (!attendanceDoc.exists) {
        attendanceJson.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }
    return {
        ref: attendanceRef,
        isCreate: !attendanceDoc.exists,
        data: attendanceJson,
    };
}
/**
 * Perform all attendance reads in the transaction, then all writes.
 * Firestore requires all reads before any writes in a transaction.
 */
async function recordAttendanceInTransaction(tx, organizationId, employeeIds, batchDate, batchId) {
    const yearMonth = (0, date_helpers_1.getYearMonth)(batchDate);
    // Phase 1: All reads
    const writes = [];
    for (const employeeId of employeeIds) {
        const financialYear = (0, financial_year_1.getFinancialContext)(batchDate).fyLabel;
        const ledgerId = `${employeeId}_${financialYear}`;
        const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
        const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
        const attendanceDoc = await tx.get(attendanceRef);
        const write = computeAttendanceWrite(attendanceDoc, organizationId, employeeId, batchDate, batchId);
        writes.push(write);
    }
    // Phase 2: All writes
    for (const w of writes) {
        if (w.isCreate) {
            tx.set(w.ref, w.data);
        }
        else {
            tx.update(w.ref, w.data);
        }
    }
}
/**
 * Cloud Function: Process production batch wages atomically
 * Creates all transactions, records attendance, and updates batch status
 */
exports.processProductionBatchWages = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    const { batchId, paymentDate, createdBy } = request.data;
    (0, logger_1.logInfo)('ProductionBatches', 'processProductionBatchWages', 'Request received', {
        batchId,
        paymentDate: paymentDate === null || paymentDate === void 0 ? void 0 : paymentDate.toString(),
        createdBy,
    });
    // Validate input
    if (!batchId || typeof batchId !== 'string' || batchId.trim() === '') {
        throw new https_1.HttpsError('invalid-argument', 'Missing or invalid batchId');
    }
    if (!paymentDate) {
        throw new https_1.HttpsError('invalid-argument', 'Missing paymentDate');
    }
    if (!createdBy || typeof createdBy !== 'string' || createdBy.trim() === '') {
        throw new https_1.HttpsError('invalid-argument', 'Missing or invalid createdBy');
    }
    try {
        // Parse payment date (accept ISO string or Firestore timestamp shape)
        let parsedPaymentDate;
        if (typeof paymentDate === 'string') {
            parsedPaymentDate = new Date(paymentDate);
        }
        else if (typeof paymentDate === 'object' && paymentDate !== null) {
            const anyDate = paymentDate;
            if (typeof anyDate.toDate === 'function') {
                parsedPaymentDate = anyDate.toDate();
            }
            else if (typeof anyDate._seconds === 'number') {
                parsedPaymentDate = new Date(anyDate._seconds * 1000);
            }
            else {
                throw new https_1.HttpsError('invalid-argument', 'Invalid paymentDate format: expected string or timestamp');
            }
        }
        else {
            throw new https_1.HttpsError('invalid-argument', 'Invalid paymentDate format');
        }
        if (Number.isNaN(parsedPaymentDate.getTime())) {
            throw new https_1.HttpsError('invalid-argument', 'Invalid paymentDate: date is not valid');
        }
        // Read batch document
        const batchRef = db.collection(constants_1.PRODUCTION_BATCHES_COLLECTION).doc(batchId);
        const batchDoc = await batchRef.get();
        if (!batchDoc.exists) {
            throw new https_1.HttpsError('not-found', `Batch not found: ${batchId}`);
        }
        const batchData = batchDoc.data();
        // Validate batch has calculated wages
        const totalWages = batchData.totalWages;
        const wagePerEmployee = batchData.wagePerEmployee;
        const employeeIds = batchData.employeeIds || [];
        const organizationId = (_a = batchData.organizationId) !== null && _a !== void 0 ? _a : '';
        const batchDateRaw = batchData.batchDate;
        const batchDate = batchDateRaw && typeof batchDateRaw.toDate === 'function'
            ? batchDateRaw.toDate()
            : batchDateRaw && typeof batchDateRaw._seconds === 'number'
                ? new Date(batchDateRaw._seconds * 1000)
                : parsedPaymentDate;
        const status = (_b = batchData.status) !== null && _b !== void 0 ? _b : '';
        // Get batch details for ledger metadata
        const productName = batchData.productName;
        const productId = batchData.productId;
        const totalBricksProduced = batchData.totalBricksProduced;
        const totalBricksStacked = batchData.totalBricksStacked;
        if (!organizationId || organizationId.trim() === '') {
            throw new https_1.HttpsError('failed-precondition', 'Batch is missing organizationId');
        }
        if (!totalWages || !wagePerEmployee || employeeIds.length === 0) {
            throw new https_1.HttpsError('failed-precondition', 'Batch does not have calculated wages or is invalid');
        }
        if (status === 'processed') {
            throw new https_1.HttpsError('failed-precondition', 'Batch has already been processed');
        }
        const financialYear = (0, financial_year_1.getFinancialContext)(parsedPaymentDate).fyLabel;
        const transactionIds = [];
        const employeeNameMap = {};
        if (employeeIds.length > 0) {
            const nameBatches = [];
            for (let i = 0; i < employeeIds.length; i += BATCH_WRITE_LIMIT) {
                nameBatches.push(employeeIds.slice(i, i + BATCH_WRITE_LIMIT));
            }
            for (const batch of nameBatches) {
                const refs = batch.map((employeeId) => db.collection(constants_1.EMPLOYEES_COLLECTION).doc(employeeId));
                const docs = await db.getAll(...refs);
                docs.forEach((doc) => {
                    if (!doc.exists)
                        return;
                    const data = doc.data() || {};
                    const name = data.name ||
                        data.employeeName;
                    if (name && name.trim().length > 0) {
                        employeeNameMap[doc.id] = name.trim();
                    }
                });
            }
        }
        (0, logger_1.logInfo)('ProductionBatches', 'processProductionBatchWages', 'Processing batch', {
            batchId,
            employeeCount: employeeIds.length,
            totalWages,
            wagePerEmployee,
            financialYear,
        });
        // Handle batches with >500 employees by splitting into multiple batch writes
        const employeeBatches = [];
        for (let i = 0; i < employeeIds.length; i += BATCH_WRITE_LIMIT) {
            employeeBatches.push(employeeIds.slice(i, i + BATCH_WRITE_LIMIT));
        }
        // Process each batch of employees
        for (let batchIndex = 0; batchIndex < employeeBatches.length; batchIndex++) {
            const employeeBatch = employeeBatches[batchIndex];
            const firestoreBatch = db.batch();
            // Create transactions for this batch of employees
            for (const employeeId of employeeBatch) {
                const transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc();
                const transactionId = transactionRef.id;
                const employeeName = employeeNameMap[employeeId];
                const transactionData = Object.assign(Object.assign({ transactionId,
                    organizationId,
                    employeeId }, (employeeName ? { employeeName } : {})), { ledgerType: 'employeeLedger', type: 'credit', category: 'wageCredit', amount: wagePerEmployee, financialYear, transactionDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate), description: `Production Batch #${batchId}`, metadata: Object.assign({ sourceType: 'productionBatch', sourceId: batchId, batchId }, (employeeName ? { employeeName } : {})), createdBy, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                // Add batch details to metadata if available
                if (productName) {
                    transactionData.metadata.productName = productName;
                }
                if (productId) {
                    transactionData.metadata.productId = productId;
                }
                if (totalBricksProduced !== undefined) {
                    transactionData.metadata.totalBricksProduced = totalBricksProduced;
                }
                if (totalBricksStacked !== undefined) {
                    transactionData.metadata.totalBricksStacked = totalBricksStacked;
                }
                firestoreBatch.set(transactionRef, transactionData);
                transactionIds.push(transactionId);
            }
            // Commit this batch of transactions
            await firestoreBatch.commit();
            (0, logger_1.logInfo)('ProductionBatches', 'processProductionBatchWages', 'Created transaction batch', {
                batchIndex: batchIndex + 1,
                totalBatches: employeeBatches.length,
                transactionCount: employeeBatch.length,
            });
        }
        // Now record attendance and update batch status atomically
        // Transaction: all reads first, then all writes (Firestore requirement)
        await db.runTransaction(async (tx) => {
            await recordAttendanceInTransaction(tx, organizationId, employeeIds, batchDate, batchId);
            tx.update(batchRef, {
                wageTransactionIds: transactionIds,
                status: 'processed',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
        (0, logger_1.logInfo)('ProductionBatches', 'processProductionBatchWages', 'Successfully processed batch', {
            batchId,
            transactionCount: transactionIds.length,
            employeeCount: employeeIds.length,
        });
        return {
            success: true,
            batchId,
            transactionIds,
            transactionCount: transactionIds.length,
        };
    }
    catch (error) {
        (0, logger_1.logError)('ProductionBatches', 'processProductionBatchWages', 'Error processing batch', error instanceof Error ? error : String(error), { batchId });
        if (error instanceof https_1.HttpsError)
            throw error;
        throw (0, logger_1.toHttpsError)(error, 'internal');
    }
});
//# sourceMappingURL=process-batch-wages.js.map