import { onCall, HttpsError } from 'firebase-functions/v2/https';
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
import { logInfo, logError, toHttpsError } from '../shared/logger';

const db = getFirestore();

/** Revert write: either delete the doc or update with new data */
interface RevertWrite {
  ref: admin.firestore.DocumentReference;
  delete: boolean;
  data?: Record<string, any>;
}

/**
 * Compute revert write from a read snapshot (no tx writes).
 * Firestore transactions require all reads before any writes.
 */
function computeRevertWrite(
  attendanceDoc: admin.firestore.DocumentSnapshot,
  organizationId: string,
  employeeId: string,
  batchDate: Date,
  batchId: string,
): RevertWrite | null {
  const financialYear = getFinancialContext(batchDate).fyLabel;
  const yearMonth = getYearMonth(batchDate);
  const ledgerId = `${employeeId}_${financialYear}`;
  const normalizedDate = normalizeDate(batchDate);

  const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
  const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);

  if (!attendanceDoc.exists) {
    return null;
  }

  const attendanceData = attendanceDoc.data()!;
  let dailyRecords = Array.from(attendanceData.dailyRecords || []);

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
    return null;
  }

  const existingRecord: any = dailyRecords[dateIndex];
  const batchIds = Array.from(existingRecord.batchIds || []);
  const updatedBatchIds = batchIds.filter((id: any) => id !== batchId);

  if (updatedBatchIds.length === 0) {
    dailyRecords = dailyRecords.filter((_, index) => index !== dateIndex);
  } else {
    dailyRecords[dateIndex] = {
      ...existingRecord,
      numberOfBatches: updatedBatchIds.length,
      batchIds: updatedBatchIds,
    };
  }

  const totalDaysPresent = dailyRecords.filter((record: any) => record.isPresent === true).length;
  const totalBatchesWorked = dailyRecords.reduce((sum: number, record: any) => sum + (record.numberOfBatches || 0), 0);

  if (dailyRecords.length === 0) {
    return { ref: attendanceRef, delete: true };
  }

  return {
    ref: attendanceRef,
    delete: false,
    data: {
      yearMonth,
      employeeId,
      organizationId,
      financialYear,
      dailyRecords,
      totalDaysPresent,
      totalBatchesWorked,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

/**
 * Revert attendance for all employees: all reads first, then all writes.
 */
async function revertAttendanceInTransaction(
  tx: admin.firestore.Transaction,
  organizationId: string,
  employeeIds: string[],
  batchDate: Date,
  batchId: string,
): Promise<void> {
  const yearMonth = getYearMonth(batchDate);

  // Phase 1: All reads
  const writes: RevertWrite[] = [];
  for (const employeeId of employeeIds) {
    const financialYear = getFinancialContext(batchDate).fyLabel;
    const ledgerId = `${employeeId}_${financialYear}`;
    const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
    const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
    const attendanceDoc = await tx.get(attendanceRef);
    const write = computeRevertWrite(
      attendanceDoc,
      organizationId,
      employeeId,
      batchDate,
      batchId,
    );
    if (write) {
      writes.push(write);
    }
  }

  // Phase 2: All writes
  for (const w of writes) {
    if (w.delete) {
      tx.delete(w.ref);
    } else if (w.data) {
      tx.update(w.ref, w.data);
    }
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
    if (!batchId || typeof batchId !== 'string' || batchId.trim() === '') {
      throw new HttpsError('invalid-argument', 'Missing or invalid batchId');
    }

    try {
      // Read batch document
      const batchRef = db.collection(PRODUCTION_BATCHES_COLLECTION).doc(batchId);
      const batchDoc = await batchRef.get();

      if (!batchDoc.exists) {
        throw new HttpsError('not-found', `Batch not found: ${batchId}`);
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

      // Revert attendance and delete batch atomically (all reads before all writes)
      await db.runTransaction(async (tx) => {
        await revertAttendanceInTransaction(
          tx,
          organizationId,
          employeeIds,
          batchDate,
          batchId,
        );
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

      if (error instanceof HttpsError) throw error;
      throw toHttpsError(error, 'internal');
    }
  },
);
