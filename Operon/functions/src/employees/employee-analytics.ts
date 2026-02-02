import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  ANALYTICS_COLLECTION,
  EMPLOYEES_COLLECTION,
  TRANSACTIONS_COLLECTION,
  EMPLOYEES_SOURCE_KEY,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import {
  getCreationDate,
  getFirestore,
  seedEmployeeAnalyticsDoc,
} from '../shared/firestore-helpers';
import { getYearMonth } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Cloud Function: Triggered when an employee is created
 * Updates employee analytics for the organization
 */
export const onEmployeeCreated = functions.firestore
  .document(`${EMPLOYEES_COLLECTION}/{employeeId}`)
  .onCreate(async (snapshot) => {
    const employeeData = snapshot.data();
    const organizationId = employeeData?.organizationId as string | undefined;
    
    if (!organizationId) {
      console.warn('[Employee Analytics] Employee created without organizationId', {
        employeeId: snapshot.id,
      });
      return;
    }

    const createdAt = getCreationDate(snapshot);
    const { fyLabel } = getFinancialContext(createdAt);
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${EMPLOYEES_SOURCE_KEY}_${organizationId}_${fyLabel}`);

    await seedEmployeeAnalyticsDoc(analyticsRef, fyLabel, organizationId);

    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveEmployees':
          admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  });

/**
 * Core logic to rebuild employee analytics for all organizations.
 * Called by unified analytics scheduler.
 */
export async function rebuildEmployeeAnalyticsCore(fyLabel: string): Promise<void> {
  const employeesSnapshot = await db.collection(EMPLOYEES_COLLECTION).get();
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
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${EMPLOYEES_SOURCE_KEY}_${organizationId}_${fyLabel}`);

    const totalActiveEmployees = orgEmployees.length;

    const wageCreditsSnapshot = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'employeeLedger')
      .where('type', '==', 'credit')
      .where('category', '==', 'wageCredit')
      .get();

    const wagesByMonth: Record<string, number> = {};
    wageCreditsSnapshot.forEach((doc) => {
      const transactionData = doc.data();
      const transactionDate = transactionData.transactionDate as admin.firestore.Timestamp | undefined
        || transactionData.paymentDate as admin.firestore.Timestamp | undefined
        || transactionData.createdAt as admin.firestore.Timestamp | undefined;
      const amount = (transactionData.amount as number) || 0;
      if (transactionDate) {
        const dateObj = transactionDate.toDate();
        const monthKey = getYearMonth(dateObj);
        wagesByMonth[monthKey] = (wagesByMonth[monthKey] || 0) + amount;
      }
    });

    await seedEmployeeAnalyticsDoc(analyticsRef, fyLabel, organizationId);
    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveEmployees': totalActiveEmployees,
        'metrics.wagesCreditMonthly.values': wagesByMonth,
      },
      { merge: true },
    );
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Employee Analytics] Rebuilt analytics for ${Object.keys(employeesByOrg).length} organizations`);
}
