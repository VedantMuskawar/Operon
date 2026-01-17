import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {
  TRANSACTIONS_COLLECTION,
  EMPLOYEE_LEDGERS_COLLECTION,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { getYearMonth, normalizeDate } from '../shared/date-helpers';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import { logInfo, logError } from '../shared/logger';

const db = getFirestore();

const BATCH_WRITE_LIMIT = 500; // Firestore batch write limit
const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';

/**
 * Cloud Function: Process trip wages atomically
 * Creates all transactions for loading and unloading employees, records attendance, and updates trip wage status
 */
export const processTripWages = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    const { tripWageId, paymentDate, createdBy } = request.data;

    // #region agent log
    console.log('[DEBUG] processTripWages ENTRY', JSON.stringify({location:'process-trip-wages.ts:132',message:'Function entry - request received',data:{tripWageId,tripWageIdType:typeof tripWageId,tripWageIdLength:tripWageId?.length,paymentDate,paymentDateType:typeof paymentDate,createdBy},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B,C'}));
    fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:132',message:'Function entry - request received',data:{tripWageId,tripWageIdType:typeof tripWageId,tripWageIdLength:tripWageId?.length,paymentDate,paymentDateType:typeof paymentDate,createdBy},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B,C'})}).catch(()=>{});
    // #endregion

    logInfo('TripWages', 'processTripWages', 'Request received', {
      tripWageId,
      paymentDate: paymentDate?.toString(),
      createdBy,
    });

      // Validate input
      if (!tripWageId || !paymentDate || !createdBy) {
        // #region agent log
        console.log('[DEBUG] processTripWages VALIDATION_FAILED', JSON.stringify({location:'process-trip-wages.ts:141',message:'Validation failed - missing parameters',data:{hasTripWageId:!!tripWageId,hasPaymentDate:!!paymentDate,hasCreatedBy:!!createdBy},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,C'}));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:141',message:'Validation failed - missing parameters',data:{hasTripWageId:!!tripWageId,hasPaymentDate:!!paymentDate,hasCreatedBy:!!createdBy},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,C'})}).catch(()=>{});
        // #endregion
        throw new Error('Missing required parameters: tripWageId, paymentDate, createdBy');
      }

      try {
        // Parse payment date - support multiple formats
        let parsedPaymentDate: Date;
        // #region agent log
        console.log('[DEBUG] processTripWages BEFORE_PARSE_DATE', JSON.stringify({location:'process-trip-wages.ts:148',message:'Before parsing paymentDate',data:{paymentDate,paymentDateType:typeof paymentDate,paymentDateString:JSON.stringify(paymentDate)},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'}));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:148',message:'Before parsing paymentDate',data:{paymentDate,paymentDateType:typeof paymentDate,paymentDateString:JSON.stringify(paymentDate)},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'})}).catch(()=>{});
        // #endregion
        if (typeof paymentDate === 'string') {
          // Handle ISO string format
          parsedPaymentDate = new Date(paymentDate);
          if (isNaN(parsedPaymentDate.getTime())) {
            // #region agent log
            console.log('[DEBUG] processTripWages INVALID_DATE_FORMAT', JSON.stringify({location:'process-trip-wages.ts:151',message:'Invalid paymentDate string format',data:{paymentDate},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'}));
            fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:151',message:'Invalid paymentDate string format',data:{paymentDate},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'})}).catch(()=>{});
            // #endregion
            throw new Error('Invalid paymentDate string format');
          }
        } else if (paymentDate?.toDate && typeof paymentDate.toDate === 'function') {
          parsedPaymentDate = paymentDate.toDate();
        } else if (paymentDate?._seconds || (paymentDate as any)?.seconds) {
          const seconds = (paymentDate as any)._seconds || (paymentDate as any).seconds;
          const nanoseconds = (paymentDate as any)._nanoseconds || (paymentDate as any).nanoseconds || 0;
          parsedPaymentDate = new Date(seconds * 1000 + nanoseconds / 1000000);
        } else {
          // #region agent log
          console.log('[DEBUG] processTripWages UNKNOWN_DATE_FORMAT', JSON.stringify({location:'process-trip-wages.ts:161',message:'Unknown paymentDate format',data:{paymentDate:JSON.stringify(paymentDate)},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'}));
          fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:161',message:'Unknown paymentDate format',data:{paymentDate:JSON.stringify(paymentDate)},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'})}).catch(()=>{});
          // #endregion
          throw new Error(`Invalid paymentDate format: ${JSON.stringify(paymentDate)}`);
        }
        // #region agent log
        console.log('[DEBUG] processTripWages AFTER_PARSE_DATE', JSON.stringify({location:'process-trip-wages.ts:164',message:'After parsing paymentDate',data:{parsedPaymentDate:parsedPaymentDate.toISOString()},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'}));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:164',message:'After parsing paymentDate',data:{parsedPaymentDate:parsedPaymentDate.toISOString()},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'C'})}).catch(()=>{});
        // #endregion

      // Read trip wage document
      // #region agent log
      console.log('[DEBUG] processTripWages BEFORE_READ_DOC', JSON.stringify({location:'process-trip-wages.ts:167',message:'Before reading trip wage document',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B'}));
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:167',message:'Before reading trip wage document',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B'})}).catch(()=>{});
      // #endregion
      const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
      const tripWageDoc = await tripWageRef.get();

      if (!tripWageDoc.exists) {
        // #region agent log
        console.log('[DEBUG] processTripWages DOC_NOT_FOUND', JSON.stringify({location:'process-trip-wages.ts:171',message:'Trip wage document not found',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B'}));
        fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:171',message:'Trip wage document not found',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B'})}).catch(()=>{});
        // #endregion
        throw new Error(`Trip wage not found: ${tripWageId}`);
      }

      const tripWageData = tripWageDoc.data()!;
      // #region agent log
      console.log('[DEBUG] processTripWages AFTER_READ_DOC', JSON.stringify({location:'process-trip-wages.ts:175',message:'After reading trip wage document',data:{hasLoadingWages:tripWageData.loadingWages!=null,hasUnloadingWages:tripWageData.unloadingWages!=null,hasLoadingWagePerEmployee:tripWageData.loadingWagePerEmployee!=null,hasUnloadingWagePerEmployee:tripWageData.unloadingWagePerEmployee!=null,organizationId:tripWageData.organizationId,dmId:tripWageData.dmId,loadingEmployeeIdsLength:(tripWageData.loadingEmployeeIds||[]).length,unloadingEmployeeIdsLength:(tripWageData.unloadingEmployeeIds||[]).length},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'B,D'}));
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:175',message:'After reading trip wage document',data:{hasLoadingWages:tripWageData.loadingWages!=null,hasUnloadingWages:tripWageData.unloadingWages!=null,hasLoadingWagePerEmployee:tripWageData.loadingWagePerEmployee!=null,hasUnloadingWagePerEmployee:tripWageData.unloadingWagePerEmployee!=null,organizationId:tripWageData.organizationId,dmId:tripWageData.dmId,loadingEmployeeIdsLength:(tripWageData.loadingEmployeeIds||[]).length,unloadingEmployeeIdsLength:(tripWageData.unloadingEmployeeIds||[]).length},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'B,D'})}).catch(()=>{});
      // #endregion

      // Validate trip wage has calculated wages
      const loadingWages = tripWageData.loadingWages as number | undefined;
      const unloadingWages = tripWageData.unloadingWages as number | undefined;
      const loadingWagePerEmployee = tripWageData.loadingWagePerEmployee as number | undefined;
      const unloadingWagePerEmployee = tripWageData.unloadingWagePerEmployee as number | undefined;
      const loadingEmployeeIds = (tripWageData.loadingEmployeeIds as string[]) || [];
      const unloadingEmployeeIds = (tripWageData.unloadingEmployeeIds as string[]) || [];
      const organizationId = tripWageData.organizationId as string;
      const dmId = tripWageData.dmId as string;
      const status = tripWageData.status as string;

      // Validate required fields
      if (!organizationId) {
        throw new Error('Trip wage is missing organizationId');
      }
      if (!dmId) {
        throw new Error('Trip wage is missing dmId');
      }
      if (loadingEmployeeIds.length === 0 && unloadingEmployeeIds.length === 0) {
        throw new Error('Trip wage must have at least one employee (loading or unloading)');
      }

      if (
        loadingWages == null ||
        unloadingWages == null ||
        loadingWagePerEmployee == null ||
        unloadingWagePerEmployee == null
      ) {
        logError('TripWages', 'processTripWages', 'Trip wage missing calculated wages', new Error('Missing calculated wages'), {
          tripWageId,
          loadingWages,
          unloadingWages,
          loadingWagePerEmployee,
          unloadingWagePerEmployee,
        });
        throw new Error('Trip wage does not have calculated wages or is invalid');
      }

      if (status === 'processed') {
        throw new Error('Trip wage has already been processed');
      }

      // Get scheduled date from DM or use payment date as fallback
      let tripDate = parsedPaymentDate;
      try {
        const dmDoc = await db.collection('DELIVERY_MEMOS').doc(dmId).get();
        if (dmDoc.exists) {
          const dmData = dmDoc.data()!;
          const scheduledDate = dmData.scheduledDate;
          if (scheduledDate?.toDate) {
            tripDate = scheduledDate.toDate();
          } else if (scheduledDate?._seconds) {
            tripDate = new Date((scheduledDate as any)._seconds * 1000);
          }
        }
      } catch (error) {
        logError('TripWages', 'processTripWages', 'Error fetching DM date, using payment date', error instanceof Error ? error : new Error(String(error)));
      }

      const financialYear = getFinancialContext(parsedPaymentDate).fyLabel;
      const transactionIds: string[] = [];

      // Combine all employee IDs (unique set for attendance)
      const allEmployeeIds = Array.from(new Set([...loadingEmployeeIds, ...unloadingEmployeeIds]));

      logInfo('TripWages', 'processTripWages', 'Processing trip wage', {
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
            const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
            const transactionId = transactionRef.id;

            const transactionData = {
              transactionId,
              organizationId,
              employeeId,
              ledgerType: 'employeeLedger',
              type: 'credit',
              category: 'wageCredit',
              amount: loadingWagePerEmployee,
              financialYear,
              paymentDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate),
              description: `Trip Wage - Loading (DM: ${dmId})`,
              metadata: {
                sourceType: 'tripWage',
                sourceId: tripWageId,
                tripWageId,
                dmId,
                taskType: 'loading',
              },
              createdBy,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            firestoreBatch.set(transactionRef, transactionData);
            transactionIds.push(transactionId);
          }

          await firestoreBatch.commit();

          logInfo('TripWages', 'processTripWages', 'Created loading transaction batch', {
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
            const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
            const transactionId = transactionRef.id;

            const transactionData = {
              transactionId,
              organizationId,
              employeeId,
              ledgerType: 'employeeLedger',
              type: 'credit',
              category: 'wageCredit',
              amount: unloadingWagePerEmployee,
              financialYear,
              paymentDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate),
              description: `Trip Wage - Unloading (DM: ${dmId})`,
              metadata: {
                sourceType: 'tripWage',
                sourceId: tripWageId,
                tripWageId,
                dmId,
                taskType: 'unloading',
              },
              createdBy,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            firestoreBatch.set(transactionRef, transactionData);
            transactionIds.push(transactionId);
          }

          await firestoreBatch.commit();

          logInfo('TripWages', 'processTripWages', 'Created unloading transaction batch', {
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
      console.log('[DEBUG] processTripWages BEFORE_TRANSACTION', JSON.stringify({location:'process-trip-wages.ts:340',message:'Before Firestore transaction',data:{transactionIdsCount:transactionIds.length,allEmployeeIdsCount:allEmployeeIds.length,organizationId,dmId,tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'D,E'}));
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:340',message:'Before Firestore transaction',data:{transactionIdsCount:transactionIds.length,allEmployeeIdsCount:allEmployeeIds.length,organizationId,dmId,tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'D,E'})}).catch(()=>{});
      // #endregion
      await db.runTransaction(async (tx) => {
        const financialYear = getFinancialContext(tripDate).fyLabel;
        const yearMonth = getYearMonth(tripDate);
        const normalizedDate = normalizeDate(tripDate);

        // PHASE 1: Read all attendance documents FIRST (Firestore requirement: all reads before writes)
        const attendanceDocs = new Map<string, FirebaseFirestore.DocumentSnapshot>();
        for (const employeeId of allEmployeeIds) {
          const ledgerId = `${employeeId}_${financialYear}`;
          const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
          const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
          const attendanceDoc = await tx.get(attendanceRef);
          attendanceDocs.set(employeeId, attendanceDoc);
        }

        // PHASE 2: Now perform all writes (updates/creates)
        for (const employeeId of allEmployeeIds) {
          const ledgerId = `${employeeId}_${financialYear}`;
          const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
          const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
          const attendanceDoc = attendanceDocs.get(employeeId)!;
          const attendanceData = attendanceDoc.data();

          let dailyRecords: any[] = [];
          let totalDaysPresent: number = 0;
          let totalTripsWorked: number = 0;

          if (attendanceDoc.exists && attendanceData != null) {
            // Existing attendance document
            dailyRecords = Array.from(attendanceData.dailyRecords || []);

            // Check if record exists for this date
            const dateIndex = dailyRecords.findIndex((record) => {
              let recordDate: Date;
              if (record.date?.toDate) {
                recordDate = record.date.toDate();
              } else if (record.date?._seconds) {
                recordDate = new Date((record.date as any)._seconds * 1000);
              } else if (record.date instanceof admin.firestore.Timestamp) {
                recordDate = record.date.toDate();
              } else {
                recordDate = new Date(record.date);
              }
              const normalizedRecordDate = normalizeDate(recordDate);
              return normalizedRecordDate.getTime() === normalizedDate.getTime();
            });

            if (dateIndex >= 0) {
              // Update existing record - increment trip count
              const existingRecord = dailyRecords[dateIndex];
              const tripWageIds = Array.from(existingRecord.tripWageIds || []);
              
              if (!tripWageIds.includes(tripWageId)) {
                tripWageIds.push(tripWageId);
                dailyRecords[dateIndex] = {
                  ...existingRecord,
                  numberOfTrips: tripWageIds.length,
                  tripWageIds,
                };
              }
            } else {
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
          } else {
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
          const attendanceJson: any = {
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
          } else {
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
      console.log('[DEBUG] processTripWages AFTER_TRANSACTION_SUCCESS', JSON.stringify({location:'process-trip-wages.ts:357',message:'After Firestore transaction - success',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'D,E'}));
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:357',message:'After Firestore transaction - success',data:{tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'D,E'})}).catch(()=>{});
      // #endregion

      logInfo('TripWages', 'processTripWages', 'Successfully processed trip wage', {
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
    } catch (error) {
      // #region agent log
      console.log('[DEBUG] processTripWages ERROR_CATCH', JSON.stringify({location:'process-trip-wages.ts:381',message:'Error in processTripWages catch block',data:{errorMessage:error instanceof Error ? error.message : String(error),errorStack:error instanceof Error ? error.stack : undefined,errorType:error?.constructor?.name,tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B,C,D,E,F'}));
      fetch('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'process-trip-wages.ts:381',message:'Error in processTripWages catch block',data:{errorMessage:error instanceof Error ? error.message : String(error),errorStack:error instanceof Error ? error.stack : undefined,errorType:error?.constructor?.name,tripWageId},timestamp:Date.now(),sessionId:'debug-session',runId:'initial',hypothesisId:'A,B,C,D,E,F'})}).catch(()=>{});
      // #endregion
      logError(
        'TripWages',
        'processTripWages',
        'Error processing trip wage',
        error instanceof Error ? error : String(error),
        { tripWageId },
      );

      throw error;
    }
  },
);
