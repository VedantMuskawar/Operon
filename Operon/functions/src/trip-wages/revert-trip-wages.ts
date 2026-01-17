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

const TRIP_WAGES_COLLECTION = 'TRIP_WAGES';

/**
 * Cloud Function: Revert trip wages atomically
 * Deletes all transactions and reverts attendance for a trip wage
 */
export const revertTripWages = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    const { tripWageId } = request.data;

    logInfo('TripWages', 'revertTripWages', 'Request received', {
      tripWageId,
    });

    // Validate input
    if (!tripWageId) {
      throw new Error('Missing required parameter: tripWageId');
    }

    try {
      // Read trip wage document
      const tripWageRef = db.collection(TRIP_WAGES_COLLECTION).doc(tripWageId);
      const tripWageDoc = await tripWageRef.get();

      if (!tripWageDoc.exists) {
        throw new Error(`Trip wage not found: ${tripWageId}`);
      }

      const tripWageData = tripWageDoc.data()!;

      const wageTransactionIds = (tripWageData.wageTransactionIds as string[]) || [];
      const loadingEmployeeIds = (tripWageData.loadingEmployeeIds as string[]) || [];
      const unloadingEmployeeIds = (tripWageData.unloadingEmployeeIds as string[]) || [];
      const organizationId = tripWageData.organizationId as string;
      const dmId = tripWageData.dmId as string;
      const status = tripWageData.status as string;

      // Combine all employee IDs (unique set for attendance)
      const allEmployeeIds = Array.from(new Set([...loadingEmployeeIds, ...unloadingEmployeeIds]));

      // Get scheduled date from DM or use current date as fallback
      let tripDate = new Date();
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
        logError('TripWages', 'revertTripWages', 'Error fetching DM date, using current date', error instanceof Error ? error : new Error(String(error)));
      }

      // Only revert if trip wage was processed
      if (status !== 'processed' || wageTransactionIds.length === 0) {
        logInfo('TripWages', 'revertTripWages', 'Trip wage not processed, skipping revert', {
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

      logInfo('TripWages', 'revertTripWages', 'Reverting trip wage', {
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
          const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc(transactionId);
          firestoreBatch.delete(transactionRef);
        }

        await firestoreBatch.commit();

        logInfo('TripWages', 'revertTripWages', 'Deleted transaction batch', {
          batchIndex: batchIndex + 1,
          totalBatches: transactionBatches.length,
          transactionCount: transactionBatch.length,
        });
      }

      // Now revert attendance and delete trip wage atomically
      // Use a transaction to ensure both attendance revert and trip wage deletion succeed or fail together
      // IMPORTANT: Firestore transactions require all reads before all writes
      await db.runTransaction(async (tx) => {
        const financialYear = getFinancialContext(tripDate).fyLabel;
        const yearMonth = getYearMonth(tripDate);
        const normalizedDate = normalizeDate(tripDate);

        // PHASE 1: Read all attendance documents FIRST (Firestore requirement: all reads before writes)
        const attendanceDocs = new Map<string, admin.firestore.DocumentSnapshot>();
        for (const employeeId of allEmployeeIds) {
          const ledgerId = `${employeeId}_${financialYear}`;
          const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
          const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
          const attendanceDoc = await tx.get(attendanceRef);
          attendanceDocs.set(employeeId, attendanceDoc);
        }

        // PHASE 2: Now perform all writes (revert attendance + delete trip wage)
        for (const employeeId of allEmployeeIds) {
          const ledgerId = `${employeeId}_${financialYear}`;
          const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
          const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
          const attendanceDoc = attendanceDocs.get(employeeId)!;

          if (!attendanceDoc.exists) {
            // No attendance record exists, nothing to revert
            continue;
          }

          const attendanceData = attendanceDoc.data()!;
          let dailyRecords = Array.from(attendanceData.dailyRecords || []);

          // Find and remove the trip wage from daily records
          const dateIndex = dailyRecords.findIndex((record: any) => {
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

          if (dateIndex < 0) {
            // No record for this date, nothing to revert
            continue;
          }

          const existingRecord: any = dailyRecords[dateIndex];

          // Remove tripWageId from the record
          const tripWageIds = Array.from(existingRecord.tripWageIds || []);
          const updatedTripWageIds = tripWageIds.filter((id: any) => id !== tripWageId);

          if (updatedTripWageIds.length === 0) {
            // No more trips for this day, remove the daily record
            dailyRecords = dailyRecords.filter((_, index) => index !== dateIndex);
          } else {
            // Update the record with remaining trips
            dailyRecords[dateIndex] = {
              ...existingRecord,
              numberOfTrips: updatedTripWageIds.length,
              tripWageIds: updatedTripWageIds,
            };
          }

          // Recalculate totals
          const totalDaysPresent = dailyRecords.filter((record: any) => record.isPresent === true).length;
          const totalTripsWorked = dailyRecords.reduce((sum: number, record: any) => sum + (record.numberOfTrips || 0), 0);

          // If no daily records remain, delete the attendance document
          if (dailyRecords.length === 0) {
            tx.delete(attendanceRef);
          } else {
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

      logInfo('TripWages', 'revertTripWages', 'Successfully reverted trip wage', {
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
    } catch (error) {
      logError(
        'TripWages',
        'revertTripWages',
        'Error reverting trip wage',
        error instanceof Error ? error : String(error),
        { tripWageId },
      );

      throw error;
    }
  },
);
