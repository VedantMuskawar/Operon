import { onCall } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {
  TRANSACTIONS_COLLECTION,
  EMPLOYEE_LEDGERS_COLLECTION,
  PRODUCTION_BATCHES_COLLECTION,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { getYearMonth, normalizeDate } from '../shared/date-helpers';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import { logInfo, logError } from '../shared/logger';

const db = getFirestore();

/**
 * Revert attendance for an employee in a batch
 * This is a helper function that updates attendance within a transaction
 */
async function revertAttendanceInTransaction(
  tx: admin.firestore.Transaction,
  organizationId: string,
  employeeId: string,
  batchDate: Date,
  batchId: string,
): Promise<void> {
  const financialYear = getFinancialContext(batchDate).fyLabel;
  const yearMonth = getYearMonth(batchDate);
  const ledgerId = `${employeeId}_${financialYear}`;
  const normalizedDate = normalizeDate(batchDate);

  const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
  const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);

  // Read attendance document
  const attendanceDoc = await tx.get(attendanceRef);

  if (!attendanceDoc.exists) {
    // No attendance record exists, nothing to revert
    return;
  }

  const attendanceData = attendanceDoc.data()!;
  let dailyRecords = Array.from(attendanceData.dailyRecords || []);

  // Find and remove the batch from daily records
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
    return;
  }

  const existingRecord: any = dailyRecords[dateIndex];

  // Remove batchId from the record
  const batchIds = Array.from(existingRecord.batchIds || []);
  const updatedBatchIds = batchIds.filter((id: any) => id !== batchId);

  if (updatedBatchIds.length === 0) {
    // No more batches for this day, remove the daily record
    dailyRecords = dailyRecords.filter((_, index) => index !== dateIndex);
  } else {
    // Update the record with remaining batches
    dailyRecords[dateIndex] = {
      ...existingRecord,
      numberOfBatches: updatedBatchIds.length,
      batchIds: updatedBatchIds,
    };
  }

  // Recalculate totals
  const totalDaysPresent = dailyRecords.filter((record: any) => record.isPresent === true).length;
  const totalBatchesWorked = dailyRecords.reduce((sum: number, record: any) => sum + (record.numberOfBatches || 0), 0);

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
export const revertProductionBatchWages = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    const { batchId } = request.data;

    logInfo('ProductionBatches', 'revertProductionBatchWages', 'Request received', {
      batchId,
    });

    // Validate input
    if (!batchId) {
      throw new Error('Missing required parameter: batchId');
    }

    try {
      // Read batch document
      const batchRef = db.collection(PRODUCTION_BATCHES_COLLECTION).doc(batchId);
      const batchDoc = await batchRef.get();

      if (!batchDoc.exists) {
        throw new Error(`Batch not found: ${batchId}`);
      }

      const batchData = batchDoc.data()!;

      const wageTransactionIds = (batchData.wageTransactionIds as string[]) || [];
      const employeeIds = (batchData.employeeIds as string[]) || [];
      const organizationId = batchData.organizationId as string;
      const batchDate = (batchData.batchDate as admin.firestore.Timestamp)?.toDate() || new Date();
      const status = batchData.status as string;

      // Only revert if batch was processed
      if (status !== 'processed' || wageTransactionIds.length === 0) {
        logInfo('ProductionBatches', 'revertProductionBatchWages', 'Batch not processed, skipping revert', {
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

      logInfo('ProductionBatches', 'revertProductionBatchWages', 'Reverting batch', {
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
          const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc(transactionId);
          firestoreBatch.delete(transactionRef);
        }

        await firestoreBatch.commit();

        logInfo('ProductionBatches', 'revertProductionBatchWages', 'Deleted transaction batch', {
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
          await revertAttendanceInTransaction(
            tx,
            organizationId,
            employeeId,
            batchDate,
            batchId,
          );
        }

        // Delete batch document
        tx.delete(batchRef);
      });

      logInfo('ProductionBatches', 'revertProductionBatchWages', 'Successfully reverted batch', {
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
    } catch (error) {
      logError(
        'ProductionBatches',
        'revertProductionBatchWages',
        'Error reverting batch',
        error instanceof Error ? error : String(error),
        { batchId },
      );

      throw error;
    }
  },
);
