import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {
  TRANSACTIONS_COLLECTION,
  EMPLOYEE_LEDGERS_COLLECTION,
  EMPLOYEES_COLLECTION,
  PRODUCTION_BATCHES_COLLECTION,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import { getYearMonth, normalizeDate } from '../shared/date-helpers';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import { logInfo, logError, toHttpsError } from '../shared/logger';

const db = getFirestore();

const BATCH_WRITE_LIMIT = 500; // Firestore batch write limit

/** Result of reading attendance: either create (set) or update */
interface AttendanceWrite {
  ref: admin.firestore.DocumentReference;
  isCreate: boolean;
  data: Record<string, any>;
}

/**
 * Compute attendance write payload from a read snapshot (no tx writes).
 * Firestore transactions require all reads before any writes.
 */
function computeAttendanceWrite(
  attendanceDoc: admin.firestore.DocumentSnapshot,
  organizationId: string,
  employeeId: string,
  batchDate: Date,
  batchId: string,
): { ref: admin.firestore.DocumentReference; isCreate: boolean; data: Record<string, any> } {
  const financialYear = getFinancialContext(batchDate).fyLabel;
  const yearMonth = getYearMonth(batchDate);
  const ledgerId = `${employeeId}_${financialYear}`;
  const normalizedDate = normalizeDate(batchDate);

  const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
  const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
  const attendanceData = attendanceDoc.data();

  let dailyRecords: any[] = [];
  let totalDaysPresent: number = 0;
  let totalBatchesWorked: number = 0;

  if (attendanceDoc.exists && attendanceData != null) {
    dailyRecords = Array.from(attendanceData.dailyRecords || []);

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
      dailyRecords.push({
        date: admin.firestore.Timestamp.fromDate(normalizedDate),
        isPresent: true,
        numberOfBatches: 1,
        batchIds: [batchId],
      });
    }

    totalDaysPresent = dailyRecords.filter((record) => record.isPresent === true).length;
    totalBatchesWorked = dailyRecords.reduce((sum, record) => sum + (record.numberOfBatches || 0), 0);
  } else {
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
async function recordAttendanceInTransaction(
  tx: admin.firestore.Transaction,
  organizationId: string,
  employeeIds: string[],
  batchDate: Date,
  batchId: string,
): Promise<void> {
  const yearMonth = getYearMonth(batchDate);

  // Phase 1: All reads
  const writes: AttendanceWrite[] = [];
  for (const employeeId of employeeIds) {
    const financialYear = getFinancialContext(batchDate).fyLabel;
    const ledgerId = `${employeeId}_${financialYear}`;
    const ledgerRef = db.collection(EMPLOYEE_LEDGERS_COLLECTION).doc(ledgerId);
    const attendanceRef = ledgerRef.collection('Attendance').doc(yearMonth);
    const attendanceDoc = await tx.get(attendanceRef);
    const write = computeAttendanceWrite(
      attendanceDoc,
      organizationId,
      employeeId,
      batchDate,
      batchId,
    );
    writes.push(write);
  }

  // Phase 2: All writes
  for (const w of writes) {
    if (w.isCreate) {
      tx.set(w.ref, w.data);
    } else {
      tx.update(w.ref, w.data);
    }
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
    if (!batchId || typeof batchId !== 'string' || batchId.trim() === '') {
      throw new HttpsError('invalid-argument', 'Missing or invalid batchId');
    }
    if (!paymentDate) {
      throw new HttpsError('invalid-argument', 'Missing paymentDate');
    }
    if (!createdBy || typeof createdBy !== 'string' || createdBy.trim() === '') {
      throw new HttpsError('invalid-argument', 'Missing or invalid createdBy');
    }

    try {
      // Parse payment date (accept ISO string or Firestore timestamp shape)
      let parsedPaymentDate: Date;
      if (typeof paymentDate === 'string') {
        parsedPaymentDate = new Date(paymentDate);
      } else if (typeof paymentDate === 'object' && paymentDate !== null) {
        const anyDate = paymentDate as any;
        if (typeof anyDate.toDate === 'function') {
          parsedPaymentDate = anyDate.toDate();
        } else if (typeof anyDate._seconds === 'number') {
          parsedPaymentDate = new Date(anyDate._seconds * 1000);
        } else {
          throw new HttpsError('invalid-argument', 'Invalid paymentDate format: expected string or timestamp');
        }
      } else {
        throw new HttpsError('invalid-argument', 'Invalid paymentDate format');
      }
      if (Number.isNaN(parsedPaymentDate.getTime())) {
        throw new HttpsError('invalid-argument', 'Invalid paymentDate: date is not valid');
      }

      // Read batch document
      const batchRef = db.collection(PRODUCTION_BATCHES_COLLECTION).doc(batchId);
      const batchDoc = await batchRef.get();

      if (!batchDoc.exists) {
        throw new HttpsError('not-found', `Batch not found: ${batchId}`);
      }

      const batchData = batchDoc.data()!;

      // Validate batch has calculated wages
      const totalWages = batchData.totalWages as number | undefined;
      const wagePerEmployee = batchData.wagePerEmployee as number | undefined;
      const employeeIds = (batchData.employeeIds as string[]) || [];
      const organizationId = (batchData.organizationId as string) ?? '';
      const batchDateRaw = batchData.batchDate;
      const batchDate =
        batchDateRaw && typeof (batchDateRaw as any).toDate === 'function'
          ? (batchDateRaw as admin.firestore.Timestamp).toDate()
          : batchDateRaw && typeof (batchDateRaw as any)._seconds === 'number'
            ? new Date((batchDateRaw as any)._seconds * 1000)
            : parsedPaymentDate;
      const status = (batchData.status as string) ?? '';
      
      // Get batch details for ledger metadata
      const productName = batchData.productName as string | undefined;
      const productId = batchData.productId as string | undefined;
      const totalBricksProduced = batchData.totalBricksProduced as number | undefined;
      const totalBricksStacked = batchData.totalBricksStacked as number | undefined;

      if (!organizationId || organizationId.trim() === '') {
        throw new HttpsError('failed-precondition', 'Batch is missing organizationId');
      }

      if (!totalWages || !wagePerEmployee || employeeIds.length === 0) {
        throw new HttpsError('failed-precondition', 'Batch does not have calculated wages or is invalid');
      }

      if (status === 'processed') {
        throw new HttpsError('failed-precondition', 'Batch has already been processed');
      }

      const financialYear = getFinancialContext(parsedPaymentDate).fyLabel;
      const transactionIds: string[] = [];
      const employeeNameMap: Record<string, string> = {};

      if (employeeIds.length > 0) {
        const nameBatches: string[][] = [];
        for (let i = 0; i < employeeIds.length; i += BATCH_WRITE_LIMIT) {
          nameBatches.push(employeeIds.slice(i, i + BATCH_WRITE_LIMIT));
        }

        for (const batch of nameBatches) {
          const refs = batch.map((employeeId) =>
            db.collection(EMPLOYEES_COLLECTION).doc(employeeId)
          );
          const docs = await db.getAll(...refs);
          docs.forEach((doc) => {
            if (!doc.exists) return;
            const data = doc.data() || {};
            const name =
              (data.name as string | undefined) ||
              (data.employeeName as string | undefined);
            if (name && name.trim().length > 0) {
              employeeNameMap[doc.id] = name.trim();
            }
          });
        }
      }

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
          const employeeName = employeeNameMap[employeeId];

          const transactionData: any = {
            transactionId,
            organizationId,
            employeeId,
            ...(employeeName ? { employeeName } : {}),
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
              ...(employeeName ? { employeeName } : {}),
            },
            createdBy,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          
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

        logInfo('ProductionBatches', 'processProductionBatchWages', 'Created transaction batch', {
          batchIndex: batchIndex + 1,
          totalBatches: employeeBatches.length,
          transactionCount: employeeBatch.length,
        });
      }

      // Now record attendance and update batch status atomically
      // Transaction: all reads first, then all writes (Firestore requirement)
      await db.runTransaction(async (tx) => {
        await recordAttendanceInTransaction(
          tx,
          organizationId,
          employeeIds,
          batchDate,
          batchId,
        );

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

      if (error instanceof HttpsError) throw error;
      throw toHttpsError(error, 'internal');
    }
  },
);
