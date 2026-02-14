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
exports.revertTripWages = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const date_helpers_1 = require("../shared/date-helpers");
const function_config_1 = require("../shared/function-config");
const logger_1 = require("../shared/logger");
const db = (0, firestore_1.getFirestore)();
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';
/**
 * Cloud Function: Revert trip wages atomically
 * Deletes all transactions and reverts attendance for a trip wage
 */
exports.revertTripWages = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a;
    const { tripWageId } = request.data;
    (0, logger_1.logInfo)('TripWages', 'revertTripWages', 'Request received', {
        tripWageId,
    });
    // Validate input
    if (!tripWageId || tripWageId.trim().length === 0) {
        throw new https_1.HttpsError('invalid-argument', 'Missing or empty required parameter: tripWageId');
    }
    try {
        // Read trip wage document
        const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
        const tripWageDoc = await tripWageRef.get();
        if (!tripWageDoc.exists) {
            throw new https_1.HttpsError('not-found', `Trip wage not found: ${tripWageId}`);
        }
        const tripWageData = tripWageDoc.data();
        const wageTransactionIds = tripWageData.wageTransactionIds || [];
        const loadingEmployeeIds = tripWageData.loadingEmployeeIds || [];
        const unloadingEmployeeIds = tripWageData.unloadingEmployeeIds || [];
        const organizationId = tripWageData.organizationId;
        const dmId = tripWageData.dmId;
        const status = tripWageData.status;
        // Combine all employee IDs (unique set for attendance)
        const allEmployeeIds = Array.from(new Set([...loadingEmployeeIds, ...unloadingEmployeeIds]));
        // Get scheduled date from DM or use current date as fallback
        let tripDate = new Date();
        try {
            const dmDoc = await db.collection('DELIVERY_MEMOS').doc(dmId).get();
            if (dmDoc.exists) {
                const dmData = dmDoc.data();
                const scheduledDate = dmData.scheduledDate;
                if (scheduledDate === null || scheduledDate === void 0 ? void 0 : scheduledDate.toDate) {
                    tripDate = scheduledDate.toDate();
                }
                else if (scheduledDate === null || scheduledDate === void 0 ? void 0 : scheduledDate._seconds) {
                    tripDate = new Date(scheduledDate._seconds * 1000);
                }
            }
        }
        catch (error) {
            (0, logger_1.logError)('TripWages', 'revertTripWages', 'Error fetching DM date, using current date', error instanceof Error ? error : new Error(String(error)));
        }
        // Only revert if trip wage was processed
        if (status !== 'processed' || wageTransactionIds.length === 0) {
            (0, logger_1.logInfo)('TripWages', 'revertTripWages', 'Trip wage not processed, skipping revert', {
                tripWageId,
                status,
                transactionCount: wageTransactionIds.length,
            });
            // Delete the trip wage document if not processed
            await tripWageRef.delete();
            return {
                success: true,
                tripWageId,
                message: 'Trip wage not processed, no revert needed',
                transactionCount: 0,
            };
        }
        (0, logger_1.logInfo)('TripWages', 'revertTripWages', 'Reverting trip wage', {
            tripWageId,
            loadingEmployeeCount: loadingEmployeeIds.length,
            unloadingEmployeeCount: unloadingEmployeeIds.length,
            totalEmployeeCount: allEmployeeIds.length,
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
            (0, logger_1.logInfo)('TripWages', 'revertTripWages', 'Deleted transaction batch', {
                batchIndex: batchIndex + 1,
                totalBatches: transactionBatches.length,
                transactionCount: transactionBatch.length,
            });
        }
        // Now revert attendance and delete trip wage atomically
        // Use a transaction to ensure both attendance revert and trip wage deletion succeed or fail together
        // IMPORTANT: Firestore transactions require all reads before all writes
        await db.runTransaction(async (tx) => {
            const financialYear = (0, financial_year_1.getFinancialContext)(tripDate).fyLabel;
            const yearMonth = (0, date_helpers_1.getYearMonth)(tripDate);
            const normalizedDate = (0, date_helpers_1.normalizeDate)(tripDate);
            // PHASE 1: Read all attendance documents FIRST (Firestore requirement: all reads before writes)
            const attendanceDocs = new Map();
            for (const employeeId of allEmployeeIds) {
                const ledgerId = `${employeeId}_${financialYear}`;
                const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
                const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
                const attendanceDoc = await tx.get(attendanceRef);
                attendanceDocs.set(employeeId, attendanceDoc);
            }
            // PHASE 2: Now perform all writes (revert attendance + delete trip wage)
            for (const employeeId of allEmployeeIds) {
                const ledgerId = `${employeeId}_${financialYear}`;
                const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
                const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
                const attendanceDoc = attendanceDocs.get(employeeId);
                if (!attendanceDoc.exists) {
                    // No attendance record exists, nothing to revert
                    continue;
                }
                const attendanceData = attendanceDoc.data();
                let dailyRecords = Array.from(attendanceData.dailyRecords || []);
                // Find and remove the trip wage from daily records
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
                    continue;
                }
                const existingRecord = dailyRecords[dateIndex];
                // Remove tripWageId from the record
                const tripWageIds = Array.from(existingRecord.tripWageIds || []);
                const updatedTripWageIds = tripWageIds.filter((id) => id !== tripWageId);
                if (updatedTripWageIds.length === 0) {
                    // No more trips for this day, remove the daily record
                    dailyRecords = dailyRecords.filter((_, index) => index !== dateIndex);
                }
                else {
                    // Update the record with remaining trips
                    dailyRecords[dateIndex] = Object.assign(Object.assign({}, existingRecord), { numberOfTrips: updatedTripWageIds.length, tripWageIds: updatedTripWageIds });
                }
                // Recalculate totals
                const totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
                const totalTripsWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfTrips || 0), 0);
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
                        totalTripsWorked,
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    };
                    tx.update(attendanceRef, attendanceJson);
                }
            }
            // Delete trip wage document (also a write, so must come after all reads)
            tx.delete(tripWageRef);
        });
        (0, logger_1.logInfo)('TripWages', 'revertTripWages', 'Successfully reverted trip wage', {
            tripWageId,
            transactionCount: wageTransactionIds.length,
            loadingEmployeeCount: loadingEmployeeIds.length,
            unloadingEmployeeCount: unloadingEmployeeIds.length,
            totalEmployeeCount: allEmployeeIds.length,
        });
        return {
            success: true,
            tripWageId,
            transactionCount: wageTransactionIds.length,
            loadingEmployeeCount: loadingEmployeeIds.length,
            unloadingEmployeeCount: unloadingEmployeeIds.length,
            totalEmployeeCount: allEmployeeIds.length,
        };
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        const errorStack = error instanceof Error ? error.stack : '';
        (0, logger_1.logError)('TripWages', 'revertTripWages', 'Error reverting trip wage', error instanceof Error ? error : String(error), { tripWageId });
        console.error('[revertTripWages] Full error details:', {
            errorMessage,
            errorStack,
            errorCode: error === null || error === void 0 ? void 0 : error.code,
            errorType: (_a = error === null || error === void 0 ? void 0 : error.constructor) === null || _a === void 0 ? void 0 : _a.name,
            tripWageId,
        });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        // Check for specific Firebase error codes
        if ((error === null || error === void 0 ? void 0 : error.code) === 'permission-denied') {
            throw new https_1.HttpsError('permission-denied', 'You do not have permission to revert this trip wage');
        }
        if ((error === null || error === void 0 ? void 0 : error.code) === 'not-found') {
            throw new https_1.HttpsError('not-found', 'Trip wage document not found');
        }
        throw new https_1.HttpsError('internal', errorMessage);
    }
});
//# sourceMappingURL=revert-trip-wages.js.map