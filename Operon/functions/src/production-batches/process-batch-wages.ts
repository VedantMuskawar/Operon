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

const BATCH_WRITE_LIMIT = 500; // Firestore batch write limit

/**
 * Record attendance for an employee in a batch
 * This is a helper function that updates attendance within a transaction
 */
async function recordAttendanceInTransaction(
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
  const attendanceData = attendanceDoc.data();

  let dailyRecords: any[] = [];
  let totalDaysPresent: number = 0;
  let totalBatchesWorked: number = 0;

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
      // Update existing record - increment batch count
      const existingRecord = dailyRecords[dateIndex];
      const batchIds = Array.from(existingRecord.batchIds || []);
      
      if (!batchIds.includes(batchId)) {
        batchIds.push(batchId);
        dailyRecords[dateIndex] = {
          ...existingRecord,
          numberOfBatches: batchIds.length,
          batchIds,
        };
      }
    } else {
      // Create new daily record
      dailyRecords.push({
        date: admin.firestore.Timestamp.fromDate(normalizedDate),
        isPresent: true,
        numberOfBatches: 1,
        batchIds: [batchId],
      });
    }

    // Recalculate totals
    totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
    totalBatchesWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfBatches || 0), 0);
  } else {
    // Create new attendance document
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

  // Prepare attendance data
  const attendanceJson: any = {
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
    tx.set(attendanceRef, attendanceJson);
  } else {
    tx.update(attendanceRef, attendanceJson);
  }
}

/**
 * Cloud Function: Process production batch wages atomically
 * Creates all transactions, records attendance, and updates batch status
 */
export const processProductionBatchWages = onCall(
  CALLABLE_FUNCTION_CONFIG,
  async (request) => {
    const { batchId, paymentDate, createdBy } = request.data;

    logInfo('ProductionBatches', 'processProductionBatchWages', 'Request received', {
      batchId,
      paymentDate: paymentDate?.toString(),
      createdBy,
    });

    // Validate input
    if (!batchId || !paymentDate || !createdBy) {
      throw new Error('Missing required parameters: batchId, paymentDate, createdBy');
    }

    try {
      // Parse payment date
      let parsedPaymentDate: Date;
      if (typeof paymentDate === 'string') {
        parsedPaymentDate = new Date(paymentDate);
      } else if (paymentDate?.toDate) {
        parsedPaymentDate = paymentDate.toDate();
      } else if (paymentDate?._seconds) {
        parsedPaymentDate = new Date((paymentDate as any)._seconds * 1000);
      } else {
        throw new Error('Invalid paymentDate format');
      }

      // Read batch document
      const batchRef = db.collection(PRODUCTION_BATCHES_COLLECTION).doc(batchId);
      const batchDoc = await batchRef.get();

      if (!batchDoc.exists) {
        throw new Error(`Batch not found: ${batchId}`);
      }

      const batchData = batchDoc.data()!;

      // Validate batch has calculated wages
      const totalWages = batchData.totalWages as number | undefined;
      const wagePerEmployee = batchData.wagePerEmployee as number | undefined;
      const employeeIds = (batchData.employeeIds as string[]) || [];
      const organizationId = batchData.organizationId as string;
      const batchDate = (batchData.batchDate as admin.firestore.Timestamp)?.toDate() || parsedPaymentDate;
      const status = batchData.status as string;

      if (!totalWages || !wagePerEmployee || employeeIds.length === 0) {
        throw new Error('Batch does not have calculated wages or is invalid');
      }

      if (status === 'processed') {
        throw new Error('Batch has already been processed');
      }

      const financialYear = getFinancialContext(parsedPaymentDate).fyLabel;
      const transactionIds: string[] = [];

      logInfo('ProductionBatches', 'processProductionBatchWages', 'Processing batch', {
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
          const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
          const transactionId = transactionRef.id;

          const transactionData = {
            transactionId,
            organizationId,
            employeeId,
            ledgerType: 'employeeLedger',
            type: 'credit',
            category: 'wageCredit',
            amount: wagePerEmployee,
            financialYear,
            paymentDate: admin.firestore.Timestamp.fromDate(parsedPaymentDate),
            description: `Production Batch #${batchId}`,
            metadata: {
              sourceType: 'productionBatch',
              sourceId: batchId,
              batchId,
            },
            createdBy,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          firestoreBatch.set(transactionRef, transactionData);
          transactionIds.push(transactionId);
        }

        // Commit this batch of transactions
        await firestoreBatch.commit();

        logInfo('ProductionBatches', 'processProductionBatchWages', 'Created transaction batch', {
          batchIndex: batchIndex + 1,
          totalBatches: employeeBatches.length,
          transactionCount: employeeBatch.length,
        });
      }

      // Now record attendance and update batch status atomically
      // Use a transaction to ensure both attendance and batch update succeed or fail together
      await db.runTransaction(async (tx) => {
        // Record attendance for all employees
        for (const employeeId of employeeIds) {
          await recordAttendanceInTransaction(
            tx,
            organizationId,
            employeeId,
            batchDate,
            batchId,
          );
        }

        // Update batch status
        tx.update(batchRef, {
          wageTransactionIds: transactionIds,
          status: 'processed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      logInfo('ProductionBatches', 'processProductionBatchWages', 'Successfully processed batch', {
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
    } catch (error) {
      logError(
        'ProductionBatches',
        'processProductionBatchWages',
        'Error processing batch',
        error instanceof Error ? error : String(error),
        { batchId },
      );

      throw error;
    }
  },
);
