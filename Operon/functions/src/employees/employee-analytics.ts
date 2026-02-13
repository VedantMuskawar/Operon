import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import {
  ANALYTICS_COLLECTION,
  EMPLOYEES_COLLECTION,
  TRANSACTIONS_COLLECTION,
  EMPLOYEES_SOURCE_KEY,
} from '../shared/constants';
import {
  getCreationDate,
  getFirestore,
  seedEmployeeAnalyticsDoc,
} from '../shared/firestore-helpers';
import { getYearMonth, formatDate } from '../shared/date-helpers';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';

const db = getFirestore();

/**
 * Cloud Function: Triggered when an employee is created
 * Updates employee analytics for the organization
 */
export const onEmployeeCreated = onDocumentCreated(
  {
    document: `${EMPLOYEES_COLLECTION}/{employeeId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const employeeData = snapshot.data();
    const organizationId = employeeData?.organizationId as string | undefined;

    if (!organizationId) {
      console.warn('[Employee Analytics] Employee created without organizationId', {
        employeeId: snapshot.id,
      });
      return;
    }

    const createdAt = getCreationDate(snapshot);
    const monthKey = getYearMonth(createdAt);
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${EMPLOYEES_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedEmployeeAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveEmployees':
          admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  },
);

/**
 * Core logic to rebuild employee analytics for all organizations.
 * Now writes to monthly documents instead of yearly.
 * Called by unified analytics scheduler.
 */
export async function rebuildEmployeeAnalyticsCore(fyLabel: string): Promise<void> {
  const employeesSnapshot = await db
    .collection(EMPLOYEES_COLLECTION)
    .select('organizationId')
    .get();
  const employeesByOrg: Record<string, FirebaseFirestore.DocumentSnapshot[]> = {};

  employeesSnapshot.forEach((doc) => {
    const organizationId = doc.data()?.organizationId as string | undefined;
    if (organizationId) {
      if (!employeesByOrg[organizationId]) {
        employeesByOrg[organizationId] = [];
      }
      employeesByOrg[organizationId].push(doc);
    }
  });

  const analyticsUpdates = Object.entries(employeesByOrg).map(async ([organizationId, orgEmployees]) => {
    const totalActiveEmployees = orgEmployees.length;

    const wageCreditsSnapshot = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'employeeLedger')
      .where('type', '==', 'credit')
      .where('category', '==', 'wageCredit')
      .select('transactionDate', 'paymentDate', 'createdAt', 'amount')
      .get();

    // Group wages by month and by day (daily data only)
    const wagesByMonthDay: Record<string, Record<string, number>> = {};
    wageCreditsSnapshot.forEach((doc) => {
      const transactionData = doc.data();
      const transactionDate = transactionData.transactionDate as admin.firestore.Timestamp | undefined
        || transactionData.paymentDate as admin.firestore.Timestamp | undefined
        || transactionData.createdAt as admin.firestore.Timestamp | undefined;
      const amount = (transactionData.amount as number) || 0;
      if (transactionDate) {
        const dateObj = transactionDate.toDate();
        const monthKey = getYearMonth(dateObj);
        const dateString = formatDate(dateObj);
        if (!wagesByMonthDay[monthKey]) {
          wagesByMonthDay[monthKey] = {};
        }
        wagesByMonthDay[monthKey][dateString] = (wagesByMonthDay[monthKey][dateString] || 0) + amount;
      }
    });

    // Write to each month's document (daily data only)
    const monthPromises = Object.entries(wagesByMonthDay).map(async ([monthKey, dailyMap]) => {
      const analyticsRef = db
        .collection(ANALYTICS_COLLECTION)
        .doc(`${EMPLOYEES_SOURCE_KEY}_${organizationId}_${monthKey}`);

      await seedEmployeeAnalyticsDoc(analyticsRef, monthKey, organizationId);
      await analyticsRef.set(
        {
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'metrics.totalActiveEmployees': totalActiveEmployees,
          'metrics.wagesCreditDaily': dailyMap,
        },
        { merge: true },
      );
    });

    await Promise.all(monthPromises);
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Employee Analytics] Rebuilt analytics for ${Object.keys(employeesByOrg).length} organizations`);
}
