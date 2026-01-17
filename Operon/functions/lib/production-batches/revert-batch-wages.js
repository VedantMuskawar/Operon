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
exports.revertProductionBatchWages = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const logger_1 = require("../shared/logger");
const db = (0, firestore_1.getFirestore)();
/**
 * Revert attendance for an employee in a batch
 * This is a helper function that updates attendance within a transaction
 */
async function revertAttendanceInTransaction(tx, organizationId, employeeId, batchDate, batchId) {
    const financialYear = (0, financial_year_1.getFinancialContext)(batchDate).fyLabel;
    const yearMonth = (0, date_helpers_1.getYearMonth)(batchDate);
    const ledgerId = `${employeeId}_${financialYear}`;
    const normalizedDate = (0, date_helpers_1.normalizeDate)(batchDate);
    const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
    const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
    // Read attendance document
    const attendanceDoc = await tx.get(attendanceRef);
    if (!attendanceDoc.exists) {
        // No attendance record exists, nothing to revert
        return;
    }
    const attendanceData = attendanceDoc.data();
    let dailyRecords = Array.from(attendanceData.dailyRecords || []);
    // Find and remove the batch from daily records
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
    if (dateIndex < 0) {
        // No record for this date, nothing to revert
        return;
    }
    const existingRecord = dailyRecords[dateIndex];
    // Remove batchId from the record
    const batchIds = Array.from(existingRecord.batchIds || []);
    const updatedBatchIds = batchIds.filter((id) => id !== batchId);
    if (updatedBatchIds.length === 0) {
        // No more batches for this day, remove the daily record
        dailyRecords = dailyRecords.filter((_, index) => index !== dateIndex);
    }
    else {
        // Update the record with remaining batches
        dailyRecords[dateIndex] = Object.assign(Object.assign({}, existingRecord), { numberOfBatches: updatedBatchIds.length, batchIds: updatedBatchIds });
    }
    // Recalculate totals
    const totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
    const totalBatchesWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfBatches || 0), 0);
    // If no daily records remain, delete the attendance document
    if (dailyRecords.length === 0) {
        tx.delete(attendanceRef);
    }
    else {
        // Update attendance document
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
        tx.update(attendanceRef, attendanceJson);
    }
}
/**
 * Cloud Function: Revert production batch wages atomically
 * Deletes all transactions and reverts attendance for a batch
 */
exports.revertProductionBatchWages = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a;
    const { batchId } = request.data;
    (0, logger_1.logInfo)('ProductionBatches', 'revertProductionBatchWages', 'Request received', {
        batchId,
    });
    // Validate input
    if (!batchId) {
        throw new Error('Missing required parameter: batchId');
    }
    try {
        // Read batch document
        const batchRef = db.collection(constants_1.PRODUCTION_BATCHES_COLLECTION).doc(batchId);
        const batchDoc = await batchRef.get();
        if (!batchDoc.exists) {
            throw new Error(`Batch not found: ${batchId}`);
        }
        const batchData = batchDoc.data();
        const wageTransactionIds = batchData.wageTransactionIds || [];
        const employeeIds = batchData.employeeIds || [];
        const organizationId = batchData.organizationId;
        const batchDate = ((_a = batchData.batchDate) === null || _a === void 0 ? void 0 : _a.toDate()) || new Date();
        const status = batchData.status;
        // Only revert if batch was processed
        if (status !== 'processed' || wageTransactionIds.length === 0) {
            (0, logger_1.logInfo)('ProductionBatches', 'revertProductionBatchWages', 'Batch not processed, skipping revert', {
                batchId,
                status,
                transactionCount: wageTransactionIds.length,
            });
            return {
                success: true,
                batchId,
                message: 'Batch not processed, no revert needed',
                transactionCount: 0,
            };
        }
        (0, logger_1.logInfo)('ProductionBatches', 'revertProductionBatchWages', 'Reverting batch', {
            batchId,
            employeeCount: employeeIds.length,
            transactionCount: wageTransactionIds.length,
        });
        // Delete all transactions in batches (to handle large numbers)
        const BATCH_SIZE = 500;
        const transactionBatches = [];
        for (let i = 0; i < wageTransactionIds.length; i += BATCH_SIZE) {
            transactionBatches.push(wageTransactionIds.slice(i, i + BATCH_SIZE));
        }
        // Delete transactions (each deletion will trigger onTransactionDeleted to revert ledger balances)
        for (let batchIndex = 0; batchIndex < transactionBatches.length; batchIndex++) {
            const transactionBatch = transactionBatches[batchIndex];
            const firestoreBatch = db.batch();
            for (const transactionId of transactionBatch) {
                const transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc(transactionId);
                firestoreBatch.delete(transactionRef);
            }
            await firestoreBatch.commit();
            (0, logger_1.logInfo)('ProductionBatches', 'revertProductionBatchWages', 'Deleted transaction batch', {
                batchIndex: batchIndex + 1,
                totalBatches: transactionBatches.length,
                transactionCount: transactionBatch.length,
            });
        }
        // Now revert attendance and delete batch atomically
        // Use a transaction to ensure both attendance revert and batch deletion succeed or fail together
        await db.runTransaction(async (tx) => {
            // Revert attendance for all employees
            for (const employeeId of employeeIds) {
                await revertAttendanceInTransaction(tx, organizationId, employeeId, batchDate, batchId);
            }
            // Delete batch document
            tx.delete(batchRef);
        });
        (0, logger_1.logInfo)('ProductionBatches', 'revertProductionBatchWages', 'Successfully reverted batch', {
            batchId,
            transactionCount: wageTransactionIds.length,
            employeeCount: employeeIds.length,
        });
        return {
            success: true,
            batchId,
            transactionCount: wageTransactionIds.length,
            employeeCount: employeeIds.length,
        };
    }
    catch (error) {
        (0, logger_1.logError)('ProductionBatches', 'revertProductionBatchWages', 'Error reverting batch', error instanceof Error ? error : String(error), { batchId });
        throw error;
    }
});
//# sourceMappingURL=revert-batch-wages.js.map