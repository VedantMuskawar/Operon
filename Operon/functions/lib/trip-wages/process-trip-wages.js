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
exports.processTripWages = void 0;
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
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';
/**
 * Cloud Function: Process trip wages atomically
 * Creates all transactions for loading and unloading employees, records attendance, and updates trip wage status
 */
exports.processTripWages = (0, https_1.onCall)(function_config_1.CALLABLE_FUNCTION_CONFIG, async (request) => {
    var _a, _b;
    const { tripWageId, paymentDate, createdBy } = request.data;
    // #region agent log
    console.log('[DEBUG] processTripWages ENTRY', JSON.stringify({ location: 'process-trip-wages.ts:132', message: 'Function entry - request received', data: { tripWageId, tripWageIdType: typeof tripWageId, tripWageIdLength: tripWageId === null || tripWageId === void 0 ? void 0 : tripWageId.length, paymentDate, paymentDateType: typeof paymentDate, createdBy }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B,C' }));
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:132', message: 'Function entry - request received', data: { tripWageId, tripWageIdType: typeof tripWageId, tripWageIdLength: tripWageId === null || tripWageId === void 0 ? void 0 : tripWageId.length, paymentDate, paymentDateType: typeof paymentDate, createdBy }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B,C' }) }).catch(() => { });
    // #endregion
    (0, logger_1.logInfo)('TripWages', 'processTripWages', 'Request received', {
        tripWageId,
        paymentDate: paymentDate === null || paymentDate === void 0 ? void 0 : paymentDate.toString(),
        createdBy,
    });
    // Validate input
    if (!tripWageId || !paymentDate || !createdBy) {
        // #region agent log
        console.log('[DEBUG] processTripWages VALIDATION_FAILED', JSON.stringify({ location: 'process-trip-wages.ts:141', message: 'Validation failed - missing parameters', data: { hasTripWageId: !!tripWageId, hasPaymentDate: !!paymentDate, hasCreatedBy: !!createdBy }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,C' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:141', message: 'Validation failed - missing parameters', data: { hasTripWageId: !!tripWageId, hasPaymentDate: !!paymentDate, hasCreatedBy: !!createdBy }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,C' }) }).catch(() => { });
        // #endregion
        throw new https_1.HttpsError('invalid-argument', 'Missing required parameters: tripWageId, paymentDate, createdBy');
    }
    try {
        // Parse payment date - support multiple formats
        let parsedPaymentDate;
        // #region agent log
        console.log('[DEBUG] processTripWages BEFORE_PARSE_DATE', JSON.stringify({ location: 'process-trip-wages.ts:148', message: 'Before parsing paymentDate', data: { paymentDate, paymentDateType: typeof paymentDate, paymentDateString: JSON.stringify(paymentDate) }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:148', message: 'Before parsing paymentDate', data: { paymentDate, paymentDateType: typeof paymentDate, paymentDateString: JSON.stringify(paymentDate) }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        if (typeof paymentDate === 'string') {
            // Handle ISO string format
            parsedPaymentDate = new Date(paymentDate);
            if (isNaN(parsedPaymentDate.getTime())) {
                // #region agent log
                console.log('[DEBUG] processTripWages INVALID_DATE_FORMAT', JSON.stringify({ location: 'process-trip-wages.ts:151', message: 'Invalid paymentDate string format', data: { paymentDate }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }));
                fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:151', message: 'Invalid paymentDate string format', data: { paymentDate }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }) }).catch(() => { });
                // #endregion
                throw new https_1.HttpsError('invalid-argument', 'Invalid paymentDate string format');
            }
        }
        else if ((paymentDate === null || paymentDate === void 0 ? void 0 : paymentDate.toDate) && typeof paymentDate.toDate === 'function') {
            parsedPaymentDate = paymentDate.toDate();
        }
        else if ((paymentDate === null || paymentDate === void 0 ? void 0 : paymentDate._seconds) || (paymentDate === null || paymentDate === void 0 ? void 0 : paymentDate.seconds)) {
            const seconds = paymentDate._seconds || paymentDate.seconds;
            const nanoseconds = paymentDate._nanoseconds || paymentDate.nanoseconds || 0;
            parsedPaymentDate = new Date(seconds * 1000 + nanoseconds / 1000000);
        }
        else {
            // #region agent log
            console.log('[DEBUG] processTripWages UNKNOWN_DATE_FORMAT', JSON.stringify({ location: 'process-trip-wages.ts:161', message: 'Unknown paymentDate format', data: { paymentDate: JSON.stringify(paymentDate) }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }));
            fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:161', message: 'Unknown paymentDate format', data: { paymentDate: JSON.stringify(paymentDate) }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }) }).catch(() => { });
            // #endregion
            throw new https_1.HttpsError('invalid-argument', `Invalid paymentDate format: ${JSON.stringify(paymentDate)}`);
        }
        // #region agent log
        console.log('[DEBUG] processTripWages AFTER_PARSE_DATE', JSON.stringify({ location: 'process-trip-wages.ts:164', message: 'After parsing paymentDate', data: { parsedPaymentDate: parsedPaymentDate.toISOString() }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:164', message: 'After parsing paymentDate', data: { parsedPaymentDate: parsedPaymentDate.toISOString() }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'C' }) }).catch(() => { });
        // #endregion
        // Read trip wage document
        // #region agent log
        console.log('[DEBUG] processTripWages BEFORE_READ_DOC', JSON.stringify({ location: 'process-trip-wages.ts:167', message: 'Before reading trip wage document', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:167', message: 'Before reading trip wage document', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B' }) }).catch(() => { });
        // #endregion
        const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
        const tripWageDoc = await tripWageRef.get();
        if (!tripWageDoc.exists) {
            // #region agent log
            console.log('[DEBUG] processTripWages DOC_NOT_FOUND', JSON.stringify({ location: 'process-trip-wages.ts:171', message: 'Trip wage document not found', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B' }));
            fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:171', message: 'Trip wage document not found', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B' }) }).catch(() => { });
            // #endregion
            throw new https_1.HttpsError('not-found', `Trip wage not found: ${tripWageId}`);
        }
        const tripWageData = tripWageDoc.data();
        // #region agent log
        console.log('[DEBUG] processTripWages AFTER_READ_DOC', JSON.stringify({ location: 'process-trip-wages.ts:175', message: 'After reading trip wage document', data: { hasLoadingWages: tripWageData.loadingWages != null, hasUnloadingWages: tripWageData.unloadingWages != null, hasLoadingWagePerEmployee: tripWageData.loadingWagePerEmployee != null, hasUnloadingWagePerEmployee: tripWageData.unloadingWagePerEmployee != null, organizationId: tripWageData.organizationId, dmId: tripWageData.dmId, loadingEmployeeIdsLength: (tripWageData.loadingEmployeeIds || []).length, unloadingEmployeeIdsLength: (tripWageData.unloadingEmployeeIds || []).length }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'B,D' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:175', message: 'After reading trip wage document', data: { hasLoadingWages: tripWageData.loadingWages != null, hasUnloadingWages: tripWageData.unloadingWages != null, hasLoadingWagePerEmployee: tripWageData.loadingWagePerEmployee != null, hasUnloadingWagePerEmployee: tripWageData.unloadingWagePerEmployee != null, organizationId: tripWageData.organizationId, dmId: tripWageData.dmId, loadingEmployeeIdsLength: (tripWageData.loadingEmployeeIds || []).length, unloadingEmployeeIdsLength: (tripWageData.unloadingEmployeeIds || []).length }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'B,D' }) }).catch(() => { });
        // #endregion
        // Validate trip wage has calculated wages
        const loadingWages = tripWageData.loadingWages;
        const unloadingWages = tripWageData.unloadingWages;
        const loadingWagePerEmployee = tripWageData.loadingWagePerEmployee;
        const unloadingWagePerEmployee = tripWageData.unloadingWagePerEmployee;
        const loadingEmployeeIds = tripWageData.loadingEmployeeIds || [];
        const unloadingEmployeeIds = tripWageData.unloadingEmployeeIds || [];
        const organizationId = tripWageData.organizationId;
        const dmId = tripWageData.dmId;
        const status = tripWageData.status;
        // Validate required fields
        if (!organizationId) {
            throw new https_1.HttpsError('invalid-argument', 'Trip wage is missing organizationId');
        }
        if (!dmId) {
            throw new https_1.HttpsError('invalid-argument', 'Trip wage is missing dmId');
        }
        if (loadingEmployeeIds.length === 0 && unloadingEmployeeIds.length === 0) {
            throw new https_1.HttpsError('invalid-argument', 'Trip wage must have at least one employee (loading or unloading)');
        }
        if (loadingWages == null ||
            unloadingWages == null ||
            loadingWagePerEmployee == null ||
            unloadingWagePerEmployee == null) {
            (0, logger_1.logError)('TripWages', 'processTripWages', 'Trip wage missing calculated wages', new Error('Missing calculated wages'), {
                tripWageId,
                loadingWages,
                unloadingWages,
                loadingWagePerEmployee,
                unloadingWagePerEmployee,
            });
            throw new Error('Trip wage does not have calculated wages or is invalid');
        }
        if (status === 'processed') {
            throw new https_1.HttpsError('failed-precondition', 'Trip wage has already been processed');
        }
        // Get scheduled date and vehicle number from DM or use payment date as fallback
        let tripDate = parsedPaymentDate;
        let vehicleNumber;
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
                // Get vehicle number for ledger metadata
                vehicleNumber = dmData.vehicleNumber;
            }
        }
        catch (error) {
            (0, logger_1.logError)('TripWages', 'processTripWages', 'Error fetching DM date, using payment date', error instanceof Error ? error : new Error(String(error)));
        }
        const financialYear = (0, financial_year_1.getFinancialContext)(parsedPaymentDate).fyLabel;
        const transactionIds = [];
        // Combine all employee IDs (unique set for attendance)
        const allEmployeeIds = Array.from(new Set([...loadingEmployeeIds, ...unloadingEmployeeIds]));
        const employeeNameMap = {};
        if (allEmployeeIds.length > 0) {
            const nameBatches = [];
            for (let i = 0; i < allEmployeeIds.length; i += BATCH_WRITE_LIMIT) {
                nameBatches.push(allEmployeeIds.slice(i, i + BATCH_WRITE_LIMIT));
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
        (0, logger_1.logInfo)('TripWages', 'processTripWages', 'Processing trip wage', {
            tripWageId,
            loadingEmployeeCount: loadingEmployeeIds.length,
            unloadingEmployeeCount: unloadingEmployeeIds.length,
            totalEmployeeCount: allEmployeeIds.length,
            loadingWages,
            unloadingWages,
            financialYear,
        });
        // Handle employees with >500 by splitting into multiple batch writes
        // Process loading employees
        if (loadingEmployeeIds.length > 0) {
            const loadingBatches = [];
            for (let i = 0; i < loadingEmployeeIds.length; i += BATCH_WRITE_LIMIT) {
                loadingBatches.push(loadingEmployeeIds.slice(i, i + BATCH_WRITE_LIMIT));
            }
            for (let batchIndex = 0; batchIndex < loadingBatches.length; batchIndex++) {
                const employeeBatch = loadingBatches[batchIndex];
                const firestoreBatch = db.batch();
                for (const employeeId of employeeBatch) {
                    const transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc();
                    const transactionId = transactionRef.id;
                    const employeeName = employeeNameMap[employeeId];
                    const transactionData = Object.assign(Object.assign({ transactionId,
                        organizationId,
                        employeeId }, (employeeName ? { employeeName } : {})), { ledgerType: 'employeeLedger', type: 'credit', category: 'wageCredit', amount: loadingWagePerEmployee, financialYear, paymentDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate), description: `Trip Wage - Loading (DM: ${dmId})`, metadata: Object.assign({ sourceType: 'tripWage', sourceId: tripWageId, tripWageId,
                            dmId, taskType: 'loading' }, (employeeName ? { employeeName } : {})), createdBy, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                    // Add vehicle number to metadata if available
                    if (vehicleNumber) {
                        transactionData.metadata.vehicleNumber = vehicleNumber;
                    }
                    firestoreBatch.set(transactionRef, transactionData);
                    transactionIds.push(transactionId);
                }
                await firestoreBatch.commit();
                (0, logger_1.logInfo)('TripWages', 'processTripWages', 'Created loading transaction batch', {
                    batchIndex: batchIndex + 1,
                    totalBatches: loadingBatches.length,
                    transactionCount: employeeBatch.length,
                });
            }
        }
        // Process unloading employees
        if (unloadingEmployeeIds.length > 0) {
            const unloadingBatches = [];
            for (let i = 0; i < unloadingEmployeeIds.length; i += BATCH_WRITE_LIMIT) {
                unloadingBatches.push(unloadingEmployeeIds.slice(i, i + BATCH_WRITE_LIMIT));
            }
            for (let batchIndex = 0; batchIndex < unloadingBatches.length; batchIndex++) {
                const employeeBatch = unloadingBatches[batchIndex];
                const firestoreBatch = db.batch();
                for (const employeeId of employeeBatch) {
                    const transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc();
                    const transactionId = transactionRef.id;
                    const employeeName = employeeNameMap[employeeId];
                    const transactionData = Object.assign(Object.assign({ transactionId,
                        organizationId,
                        employeeId }, (employeeName ? { employeeName } : {})), { ledgerType: 'employeeLedger', type: 'credit', category: 'wageCredit', amount: unloadingWagePerEmployee, financialYear, paymentDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate), description: `Trip Wage - Unloading (DM: ${dmId})`, metadata: Object.assign({ sourceType: 'tripWage', sourceId: tripWageId, tripWageId,
                            dmId, taskType: 'unloading' }, (employeeName ? { employeeName } : {})), createdBy, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
                    // Add vehicle number to metadata if available
                    if (vehicleNumber) {
                        transactionData.metadata.vehicleNumber = vehicleNumber;
                    }
                    firestoreBatch.set(transactionRef, transactionData);
                    transactionIds.push(transactionId);
                }
                await firestoreBatch.commit();
                (0, logger_1.logInfo)('TripWages', 'processTripWages', 'Created unloading transaction batch', {
                    batchIndex: batchIndex + 1,
                    totalBatches: unloadingBatches.length,
                    transactionCount: employeeBatch.length,
                });
            }
        }
        // Now record attendance and update trip wage status atomically
        // Use a transaction to ensure both attendance and trip wage update succeed or fail together
        // IMPORTANT: Firestore transactions require all reads before all writes
        // #region agent log
        console.log('[DEBUG] processTripWages BEFORE_TRANSACTION', JSON.stringify({ location: 'process-trip-wages.ts:340', message: 'Before Firestore transaction', data: { transactionIdsCount: transactionIds.length, allEmployeeIdsCount: allEmployeeIds.length, organizationId, dmId, tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'D,E' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:340', message: 'Before Firestore transaction', data: { transactionIdsCount: transactionIds.length, allEmployeeIdsCount: allEmployeeIds.length, organizationId, dmId, tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'D,E' }) }).catch(() => { });
        // #endregion
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
            // PHASE 2: Now perform all writes (updates/creates)
            for (const employeeId of allEmployeeIds) {
                const ledgerId = `${employeeId}_${financialYear}`;
                const ledgerRef = db.collection(constants_1.EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
                const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
                const attendanceDoc = attendanceDocs.get(employeeId);
                const attendanceData = attendanceDoc.data();
                let dailyRecords = [];
                let totalDaysPresent = 0;
                let totalTripsWorked = 0;
                if (attendanceDoc.exists && attendanceData != null) {
                    // Existing attendance document
                    dailyRecords = Array.from(attendanceData.dailyRecords || []);
                    // Check if record exists for this date
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
                        // Update existing record - increment trip count
                        const existingRecord = dailyRecords[dateIndex];
                        const tripWageIds = Array.from(existingRecord.tripWageIds || []);
                        if (!tripWageIds.includes(tripWageId)) {
                            tripWageIds.push(tripWageId);
                            dailyRecords[dateIndex] = Object.assign(Object.assign({}, existingRecord), { numberOfTrips: tripWageIds.length, tripWageIds });
                        }
                    }
                    else {
                        // Create new daily record
                        dailyRecords.push({
                            date: admin.firestore.Timestamp.fromDate(normalizedDate),
                            isPresent: true,
                            numberOfTrips: 1,
                            tripWageIds: [tripWageId],
                        });
                    }
                    // Recalculate totals
                    totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
                    totalTripsWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfTrips || 0), 0);
                }
                else {
                    // Create new attendance document
                    dailyRecords = [
                        {
                            date: admin.firestore.Timestamp.fromDate(normalizedDate),
                            isPresent: true,
                            numberOfTrips: 1,
                            tripWageIds: [tripWageId],
                        },
                    ];
                    totalDaysPresent = 1;
                    totalTripsWorked = 1;
                }
                // Prepare attendance data
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
                if (!attendanceDoc.exists) {
                    attendanceJson.createdAt = admin.firestore.FieldValue.serverTimestamp();
                    tx.set(attendanceRef, attendanceJson);
                }
                else {
                    tx.update(attendanceRef, attendanceJson);
                }
            }
            // Update trip wage status (also a write, so must come after all reads)
            tx.update(tripWageRef, {
                wageTransactionIds: transactionIds,
                status: 'processed',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
        // #region agent log
        console.log('[DEBUG] processTripWages AFTER_TRANSACTION_SUCCESS', JSON.stringify({ location: 'process-trip-wages.ts:357', message: 'After Firestore transaction - success', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'D,E' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:357', message: 'After Firestore transaction - success', data: { tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'D,E' }) }).catch(() => { });
        // #endregion
        (0, logger_1.logInfo)('TripWages', 'processTripWages', 'Successfully processed trip wage', {
            tripWageId,
            transactionCount: transactionIds.length,
            loadingEmployeeCount: loadingEmployeeIds.length,
            unloadingEmployeeCount: unloadingEmployeeIds.length,
            totalEmployeeCount: allEmployeeIds.length,
        });
        return {
            success: true,
            tripWageId,
            transactionIds,
            transactionCount: transactionIds.length,
        };
    }
    catch (error) {
        // #region agent log
        console.log('[DEBUG] processTripWages ERROR_CATCH', JSON.stringify({ location: 'process-trip-wages.ts:381', message: 'Error in processTripWages catch block', data: { errorMessage: error instanceof Error ? error.message : String(error), errorStack: error instanceof Error ? error.stack : undefined, errorType: (_a = error === null || error === void 0 ? void 0 : error.constructor) === null || _a === void 0 ? void 0 : _a.name, tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B,C,D,E,F' }));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ location: 'process-trip-wages.ts:381', message: 'Error in processTripWages catch block', data: { errorMessage: error instanceof Error ? error.message : String(error), errorStack: error instanceof Error ? error.stack : undefined, errorType: (_b = error === null || error === void 0 ? void 0 : error.constructor) === null || _b === void 0 ? void 0 : _b.name, tripWageId }, timestamp: Date.now(), sessionId: 'debug-session', runId: 'initial', hypothesisId: 'A,B,C,D,E,F' }) }).catch(() => { });
        // #endregion
        (0, logger_1.logError)('TripWages', 'processTripWages', 'Error processing trip wage', error instanceof Error ? error : String(error), { tripWageId });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError('internal', error instanceof Error ? error.message : String(error));
    }
});
//# sourceMappingURL=process-trip-wages.js.map