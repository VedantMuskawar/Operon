import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  VENDORS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  VENDORS_SOURCE_KEY,
} from '../shared/constants';
import {
  getFirestore,
  seedVendorAnalyticsDoc,
} from '../shared/firestore-helpers';
import { getYearMonth, formatDate } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Core logic to rebuild vendor analytics for all organizations.
 * Called by unified analytics scheduler.
 */
export async function rebuildVendorAnalyticsCore(fyLabel: string): Promise<void> {
  const vendorsSnapshot = await db.collection(VENDORS_COLLECTION).get();
  const vendorsByOrg: Record<string, FirebaseFirestore.DocumentSnapshot[]> = {};

  vendorsSnapshot.forEach((doc) => {
    const organizationId = doc.data()?.organizationId as string | undefined;
    if (organizationId) {
      if (!vendorsByOrg[organizationId]) {
        vendorsByOrg[organizationId] = [];
      }
      vendorsByOrg[organizationId].push(doc);
    }
  });

  // Calculate total payable (current balance across all vendors) - this is org-wide, not month-specific
  const totalPayableByOrg: Record<string, number> = {};
  Object.entries(vendorsByOrg).forEach(([organizationId, orgVendors]) => {
    let totalPayable = 0;
    orgVendors.forEach((doc) => {
      const currentBalance = (doc.data()?.currentBalance as number) || 0;
      totalPayable += currentBalance;
    });
    totalPayableByOrg[organizationId] = totalPayable;
  });

  const analyticsUpdates = Object.entries(vendorsByOrg).map(async ([organizationId, orgVendors]) => {
    const vendorTypeMap: Record<string, string> = {};
    orgVendors.forEach((doc) => {
      const vendorId = doc.id;
      const vendorType = doc.data()?.vendorType as string | undefined;
      if (vendorType) {
        vendorTypeMap[vendorId] = vendorType;
      }
    });

    const purchaseTransactionsSnapshot = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'vendorLedger')
      .where('type', '==', 'credit')
      .get();

    // Group purchases by month and by day (daily data only): month -> date -> vendorType -> amount
    const purchasesByMonthDay: Record<string, Record<string, Record<string, number>>> = {};

    purchaseTransactionsSnapshot.forEach((doc) => {
      const transactionData = doc.data();
      const vendorId = transactionData.vendorId as string | undefined;
      const vendorType = vendorId ? vendorTypeMap[vendorId] : undefined;
      if (!vendorId || !vendorType) {
        return;
      }
      const transactionDate = transactionData.transactionDate as admin.firestore.Timestamp | undefined
        || transactionData.paymentDate as admin.firestore.Timestamp | undefined
        || transactionData.createdAt as admin.firestore.Timestamp | undefined;
      const amount = (transactionData.amount as number) || 0;
      if (transactionDate) {
        const dateObj = transactionDate.toDate();
        const monthKey = getYearMonth(dateObj);
        const dateString = formatDate(dateObj);

        if (!purchasesByMonthDay[monthKey]) {
          purchasesByMonthDay[monthKey] = {};
        }
        if (!purchasesByMonthDay[monthKey][dateString]) {
          purchasesByMonthDay[monthKey][dateString] = {};
        }
        purchasesByMonthDay[monthKey][dateString][vendorType] =
          (purchasesByMonthDay[monthKey][dateString][vendorType] || 0) + amount;
      }
    });

    // Write to each month's document (daily data only)
    const monthPromises = Object.entries(purchasesByMonthDay).map(async ([monthKey, dailyMap]) => {
      const analyticsRef = db
        .collection(ANALYTICS_COLLECTION)
        .doc(`${VENDORS_SOURCE_KEY}_${organizationId}_${monthKey}`);

      await seedVendorAnalyticsDoc(analyticsRef, monthKey, organizationId);
      await analyticsRef.set(
        {
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'metrics.totalPayable': totalPayableByOrg[organizationId],
          'metrics.purchasesDaily': dailyMap,
        },
        { merge: true },
      );
    });

    await Promise.all(monthPromises);
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Vendor Analytics] Rebuilt analytics for ${Object.keys(vendorsByOrg).length} organizations`);
}
