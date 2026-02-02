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
import { getYearMonth } from '../shared/date-helpers';

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

  const analyticsUpdates = Object.entries(vendorsByOrg).map(async ([organizationId, orgVendors]) => {
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${VENDORS_SOURCE_KEY}_${organizationId}_${fyLabel}`);

    let totalPayable = 0;
    orgVendors.forEach((doc) => {
      const currentBalance = (doc.data()?.currentBalance as number) || 0;
      totalPayable += currentBalance;
    });

    const purchaseTransactionsSnapshot = await db
      .collection(TRANSACTIONS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'vendorLedger')
      .where('type', '==', 'credit')
      .get();

    const vendorTypeMap: Record<string, string> = {};
    orgVendors.forEach((doc) => {
      const vendorId = doc.id;
      const vendorType = doc.data()?.vendorType as string | undefined;
      if (vendorType) {
        vendorTypeMap[vendorId] = vendorType;
      }
    });

    const purchasesByVendorType: Record<string, Record<string, number>> = {};
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
        if (!purchasesByVendorType[vendorType]) {
          purchasesByVendorType[vendorType] = {};
        }
        purchasesByVendorType[vendorType][monthKey] = (purchasesByVendorType[vendorType][monthKey] || 0) + amount;
      }
    });

    await seedVendorAnalyticsDoc(analyticsRef, fyLabel, organizationId);
    const updateData: Record<string, unknown> = {
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.totalPayable': totalPayable,
    };
    for (const [vendorType, monthlyData] of Object.entries(purchasesByVendorType)) {
      for (const [monthKey, amount] of Object.entries(monthlyData)) {
        updateData[`metrics.purchasesByVendorType.values.${vendorType}.${monthKey}`] = amount;
      }
    }
    await analyticsRef.set(updateData, { merge: true });
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Vendor Analytics] Rebuilt analytics for ${Object.keys(vendorsByOrg).length} organizations`);
}
