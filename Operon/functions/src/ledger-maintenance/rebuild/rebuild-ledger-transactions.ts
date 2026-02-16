import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from '../../shared/firestore-helpers';
import { SCHEDULED_FUNCTION_OPTS } from '../../shared/function-config';
import { getFinancialContext } from '../../shared/financial-year';
import { logInfo, logWarning, logError } from '../../shared/logger';
import { TRANSACTIONS_COLLECTION, EMPLOYEE_LEDGERS_COLLECTION } from '../../shared/constants';
import { getYearMonthCompact, getYearMonth, normalizeDate } from '../../shared/date-helpers';
import { removeUndefinedFields } from '../../shared/transaction-helpers';
import { getLedgerConfig } from '../ledger-types';

const db = getFirestore();

const LEDGER_TYPE_MAP = [
  { ledgerType: 'clientLedger', typeKey: 'client' as const },
  { ledgerType: 'vendorLedger', typeKey: 'vendor' as const },
  { ledgerType: 'employeeLedger', typeKey: 'employee' as const },
];

type LedgerTypeKey = 'client' | 'vendor' | 'employee';
type LedgerTransactionEntry = Record<string, unknown> & {
  type?: string;
  amount?: number;
};

function getTransactionDate(
  data: FirebaseFirestore.DocumentData,
  doc: FirebaseFirestore.QueryDocumentSnapshot,
): Date {
  const dateValue = data.transactionDate || data.createdAt;
  if (dateValue?.toDate) {
    return dateValue.toDate();
  }
  if (dateValue instanceof admin.firestore.Timestamp) {
    return dateValue.toDate();
  }
  if (doc.createTime) {
    return doc.createTime.toDate();
  }
  return new Date();
}

async function ensureLedgerDoc(
  ledgerId: string,
  config: ReturnType<typeof getLedgerConfig>,
  organizationId: string,
  entityId: string,
  financialYear: string,
): Promise<FirebaseFirestore.DocumentReference> {
  const ledgerRef = db.collection(config.collectionName).doc(ledgerId);
  const ledgerDoc = await ledgerRef.get();
  if (ledgerDoc.exists) return ledgerRef;

  await ledgerRef.set(
    {
      ledgerId,
      organizationId,
      [config.idField]: entityId,
      financialYear,
      openingBalance: 0,
      currentBalance: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return ledgerRef;
}

async function deleteStaleMonthlyDocs(
  ledgerRef: FirebaseFirestore.DocumentReference,
  validMonthIds: Set<string>,
): Promise<number> {
  const existing = await ledgerRef.collection('TRANSACTIONS').get();
  const staleDocs = existing.docs.filter((doc) => !validMonthIds.has(doc.id));

  if (staleDocs.length === 0) return 0;

  const BATCH_SIZE = 400;
  let deleted = 0;

  for (let i = 0; i < staleDocs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = staleDocs.slice(i, i + BATCH_SIZE);
    chunk.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += chunk.length;
  }

  return deleted;
}

async function rebuildLedgerTypeTransactions(
  typeKey: LedgerTypeKey,
  ledgerTypeValue: string,
  financialYear: string,
): Promise<void> {
  const config = getLedgerConfig(typeKey);
  const ledgerMap = new Map<
    string,
    {
      organizationId: string;
      entityId: string;
      months: Map<string, LedgerTransactionEntry[]>;
    }
  >();

  const BATCH_SIZE = 500;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let processed = 0;

  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection(TRANSACTIONS_COLLECTION)
      .where('ledgerType', '==', ledgerTypeValue)
      .where('financialYear', '==', financialYear)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const entityId = data[config.idField] as string | undefined;
      const organizationId = data.organizationId as string | undefined;

      if (!entityId || !organizationId) {
        logWarning('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Missing entity/organization', {
          ledgerType: ledgerTypeValue,
          transactionId: doc.id,
        });
        continue;
      }

      const transactionDate = getTransactionDate(data, doc);
      const monthKey = getYearMonthCompact(transactionDate);
      const ledgerId = `${entityId}_${financialYear}`;

      const txData = removeUndefinedFields({
        transactionId: doc.id,
        organizationId,
        [config.idField]: entityId,
        ledgerType: data.ledgerType || ledgerTypeValue,
        type: data.type,
        category: data.category,
        amount: data.amount,
        financialYear: data.financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        createdAt: data.createdAt || admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: data.updatedAt || admin.firestore.Timestamp.fromDate(transactionDate),
        paymentAccountId: data.paymentAccountId,
        paymentAccountType: data.paymentAccountType,
        referenceNumber: data.referenceNumber,
        description: data.description,
        metadata: data.metadata,
        createdBy: data.createdBy,
        employeeName: data.employeeName,
        clientName: data.clientName,
        vendorName: data.vendorName,
      });

      if (!ledgerMap.has(ledgerId)) {
        ledgerMap.set(ledgerId, {
          organizationId,
          entityId,
          months: new Map(),
        });
      }

      const ledgerEntry = ledgerMap.get(ledgerId)!;
      if (!ledgerEntry.months.has(monthKey)) {
        ledgerEntry.months.set(monthKey, []);
      }
      ledgerEntry.months.get(monthKey)!.push(txData as LedgerTransactionEntry);
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  logInfo('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Collected transactions', {
    ledgerType: ledgerTypeValue,
    financialYear,
    processed,
    ledgers: ledgerMap.size,
  });

  let ledgersTouched = 0;
  let monthsWritten = 0;
  let monthsDeleted = 0;

  const ledgersSnapshot = await db
    .collection(config.collectionName)
    .where('financialYear', '==', financialYear)
    .get();

  for (const ledgerDoc of ledgersSnapshot.docs) {
    const ledgerData = ledgerDoc.data();
    const entityId = ledgerData[config.idField] as string | undefined;

    if (!entityId) {
      logWarning('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Ledger missing entityId', {
        ledgerType: ledgerTypeValue,
        ledgerId: ledgerDoc.id,
      });
      continue;
    }

    const ledgerId = ledgerDoc.id;
    const ledgerEntry = ledgerMap.get(ledgerId);
    const monthsMap = ledgerEntry?.months ?? new Map();
    const validMonthIds = new Set(monthsMap.keys());

    const deleted = await deleteStaleMonthlyDocs(ledgerDoc.ref, validMonthIds);
    monthsDeleted += deleted;

    if (monthsMap.size === 0) {
      ledgersTouched += 1;
      continue;
    }

    for (const [monthKey, transactions] of monthsMap.entries()) {
      const monthlyRef = ledgerDoc.ref.collection('TRANSACTIONS').doc(monthKey);
      const totalCredit = transactions
        .filter((t: LedgerTransactionEntry) => t.type === 'credit')
        .reduce((sum: number, t: LedgerTransactionEntry) => sum + (t.amount || 0), 0);
      const totalDebit = transactions
        .filter((t: LedgerTransactionEntry) => t.type === 'debit')
        .reduce((sum: number, t: LedgerTransactionEntry) => sum + (t.amount || 0), 0);

      await monthlyRef.set(
        {
          yearMonth: monthKey,
          transactions,
          transactionCount: transactions.length,
          totalCredit,
          totalDebit,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      monthsWritten += 1;
    }

    ledgersTouched += 1;
  }

  const ledgersWithoutDocs = Array.from(ledgerMap.keys()).filter(
    (ledgerId) => !ledgersSnapshot.docs.some((doc) => doc.id === ledgerId),
  );

  for (const ledgerId of ledgersWithoutDocs) {
    const entry = ledgerMap.get(ledgerId);
    if (!entry) continue;

    const ledgerRef = await ensureLedgerDoc(
      ledgerId,
      config,
      entry.organizationId,
      entry.entityId,
      financialYear,
    );

    const validMonthIds = new Set(entry.months.keys());
    monthsDeleted += await deleteStaleMonthlyDocs(ledgerRef, validMonthIds);

    for (const [monthKey, transactions] of entry.months.entries()) {
      const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(monthKey);
      const totalCredit = transactions
        .filter((t: LedgerTransactionEntry) => t.type === 'credit')
        .reduce((sum: number, t: LedgerTransactionEntry) => sum + (t.amount || 0), 0);
      const totalDebit = transactions
        .filter((t: LedgerTransactionEntry) => t.type === 'debit')
        .reduce((sum: number, t: LedgerTransactionEntry) => sum + (t.amount || 0), 0);

      await monthlyRef.set(
        {
          yearMonth: monthKey,
          transactions,
          transactionCount: transactions.length,
          totalCredit,
          totalDebit,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      monthsWritten += 1;
    }

    ledgersTouched += 1;
  }

  logInfo('LedgerMaintenance', 'rebuildLedgerTypeTransactions', 'Rebuilt ledger subcollections', {
    ledgerType: ledgerTypeValue,
    financialYear,
    ledgersTouched,
    monthsWritten,
    monthsDeleted,
  });
}

/**
 * Rebuild attendance subcollections from TRANSACTIONS
 */
async function rebuildAttendance(financialYear: string): Promise<void> {
  const attendanceMap = new Map<
    string,
    {
      organizationId: string;
      employeeId: string;
      months: Map<
        string,
        {
          date: Date;
          batchId?: string;
          tripWageId?: string;
        }[]
      >;
    }
  >();

  const BATCH_SIZE = 500;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let processed = 0;

  // Fetch all employee transactions with batchId or tripWageId
  while (true) {
    let query: FirebaseFirestore.Query = db
      .collection(TRANSACTIONS_COLLECTION)
      .where('ledgerType', '==', 'employeeLedger')
      .where('financialYear', '==', financialYear)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const employeeId = data.employeeId as string | undefined;
      const organizationId = data.organizationId as string | undefined;
      const metadata = data.metadata as any;
      const batchId = metadata?.batchId as string | undefined;
      const tripWageId = metadata?.tripWageId as string | undefined;

      if (!employeeId || !organizationId || (!batchId && !tripWageId)) {
        continue;
      }

      const transactionDate = getTransactionDate(data, doc);
      const monthKey = getYearMonth(transactionDate);
      const normalizedDate = normalizeDate(transactionDate);
      const ledgerId = `${employeeId}_${financialYear}`;

      if (!attendanceMap.has(ledgerId)) {
        attendanceMap.set(ledgerId, {
          organizationId,
          employeeId,
          months: new Map(),
        });
      }

      const ledgerEntry = attendanceMap.get(ledgerId)!;
      if (!ledgerEntry.months.has(monthKey)) {
        ledgerEntry.months.set(monthKey, []);
      }
      ledgerEntry.months.get(monthKey)!.push({
        date: normalizedDate,
        batchId,
        tripWageId,
      });
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  logInfo('LedgerMaintenance', 'rebuildAttendance', 'Collected attendance data', {
    financialYear,
    processed,
    ledgers: attendanceMap.size,
  });

  let ledgersTouched = 0;
  let monthsWritten = 0;
  let monthsDeleted = 0;

  // Fetch all employee ledgers for this FY to ensure we clean up empty attendance docs
  const ledgersSnapshot = await db
    .collection(EMPLOYEE_LEDGERS_COLLECTION)
    .where('financialYear', '==', financialYear)
    .get();

  for (const ledgerDoc of ledgersSnapshot.docs) {
    const ledgerId = ledgerDoc.id;
    const ledgerData = ledgerDoc.data();
    const employeeId = ledgerData.employeeId as string | undefined;
    const organizationId = ledgerData.organizationId as string | undefined;

    if (!employeeId || !organizationId) {
      logWarning('LedgerMaintenance', 'rebuildAttendance', 'Employee ledger missing data', {
        ledgerId,
      });
      continue;
    }

    const ledgerEntry = attendanceMap.get(ledgerId);
    const monthsMap = ledgerEntry?.months ?? new Map();
    const validMonthIds = new Set(monthsMap.keys());

    // Delete stale attendance docs
    const existingAttendance = await ledgerDoc.ref.collection('Attendance').get();
    const staleDocs = existingAttendance.docs.filter((doc) => !validMonthIds.has(doc.id));
    for (const doc of staleDocs) {
      await doc.ref.delete();
      monthsDeleted += 1;
    }

    if (monthsMap.size === 0) {
      ledgersTouched += 1;
      continue;
    }

    // Group attendance records by date and aggregate batch/trip IDs
    for (const [monthKey, records] of monthsMap.entries()) {
      const dailyMap = new Map<
        string,
        {
          date: Date;
          batchIds: string[];
          tripWageIds: string[];
        }
      >();

      for (const record of records) {
        const dateKey = record.date.toISOString().split('T')[0];
        if (!dailyMap.has(dateKey)) {
          dailyMap.set(dateKey, {
            date: record.date,
            batchIds: [],
            tripWageIds: [],
          });
        }
        const dailyEntry = dailyMap.get(dateKey)!;
        if (record.batchId && !dailyEntry.batchIds.includes(record.batchId)) {
          dailyEntry.batchIds.push(record.batchId);
        }
        if (record.tripWageId && !dailyEntry.tripWageIds.includes(record.tripWageId)) {
          dailyEntry.tripWageIds.push(record.tripWageId);
        }
      }

      const dailyRecords = Array.from(dailyMap.values()).map((entry) => {
        const record: any = {
          date: admin.firestore.Timestamp.fromDate(entry.date),
          isPresent: true,
        };

        if (entry.batchIds.length > 0) {
          record.batchIds = entry.batchIds;
          record.numberOfBatches = entry.batchIds.length;
        }
        if (entry.tripWageIds.length > 0) {
          record.tripWageIds = entry.tripWageIds;
          record.numberOfTrips = entry.tripWageIds.length;
        }

        return record;
      });

      const totalDaysPresent = dailyRecords.filter((r) => r.isPresent === true).length;
      const totalBatchesWorked = dailyRecords.reduce((sum, r) => sum + (r.numberOfBatches || 0), 0);
      const totalTripsWorked = dailyRecords.reduce((sum, r) => sum + (r.numberOfTrips || 0), 0);

      const attendanceRef = ledgerDoc.ref.collection('Attendance').doc(monthKey);
      const attendanceData: any = {
        yearMonth: monthKey,
        employeeId,
        organizationId,
        financialYear,
        dailyRecords,
        totalDaysPresent,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (totalBatchesWorked > 0) {
        attendanceData.totalBatchesWorked = totalBatchesWorked;
      }
      if (totalTripsWorked > 0) {
        attendanceData.totalTripsWorked = totalTripsWorked;
      }

      await attendanceRef.set(attendanceData, { merge: true });
      monthsWritten += 1;
    }

    ledgersTouched += 1;
  }

  logInfo('LedgerMaintenance', 'rebuildAttendance', 'Rebuilt attendance subcollections', {
    financialYear,
    ledgersTouched,
    monthsWritten,
    monthsDeleted,
  });
}

/**
 * Scheduled weekly rebuild of ledger TRANSACTIONS and Attendance subcollections
 * Uses source TRANSACTIONS to rebuild client/vendor/employee ledger monthly docs and attendance.
 */
export const rebuildLedgerTransactionsScheduled = onSchedule(
  {
    schedule: '0 3 * * 1',
    timeZone: 'UTC',
    ...SCHEDULED_FUNCTION_OPTS,
  },
  async () => {
    const now = new Date();
    const { fyLabel } = getFinancialContext(now);

    logInfo('LedgerMaintenance', 'rebuildLedgerTransactionsScheduled', 'Starting rebuild', {
      financialYear: fyLabel,
      timestamp: now.toISOString(),
    });

    try {
      for (const entry of LEDGER_TYPE_MAP) {
        await rebuildLedgerTypeTransactions(entry.typeKey, entry.ledgerType, fyLabel);
      }

      // Rebuild attendance subcollections
      await rebuildAttendance(fyLabel);

      logInfo('LedgerMaintenance', 'rebuildLedgerTransactionsScheduled', 'Rebuild completed', {
        financialYear: fyLabel,
      });
    } catch (error) {
      logError(
        'LedgerMaintenance',
        'rebuildLedgerTransactionsScheduled',
        'Rebuild failed',
        error instanceof Error ? error : String(error),
      );
      throw error;
    }
  },
);
