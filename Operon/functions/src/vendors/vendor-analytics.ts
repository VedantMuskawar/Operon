import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  ANALYTICS_COLLECTION,
  VENDORS_COLLECTION,
  TRANSACTIONS_COLLECTION,
  VENDORS_SOURCE_KEY,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import {
  getFirestore,
  seedVendorAnalyticsDoc,
} from '../shared/firestore-helpers';
import { getYearMonth } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Cloud Function: Scheduled function to rebuild vendor analytics
 * Runs every 24 hours to recalculate analytics for all organizations
 */
export const rebuildVendorAnalytics = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel } = getFinancialContext(now);

    // Get all vendors and group by organizationId
    const vendorsSnapshot = await db.collection(VENDORS_COLLECTION).get();
    
    // Group vendors by organizationId
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

    // Process analytics for each organization
    const analyticsUpdates = Object.entries(vendorsByOrg).map(async ([organizationId, orgVendors]) => {
      const analyticsRef = db
        .collection(ANALYTICS_COLLECTION)
        .doc(`${VENDORS_SOURCE_KEY}_${organizationId}_${fyLabel}`);

      // Calculate total payable (sum of currentBalance from all vendors, irrespective of time)
      let totalPayable = 0;
      orgVendors.forEach((doc) => {
        const currentBalance = (doc.data()?.currentBalance as number) || 0;
        totalPayable += currentBalance;
      });

      // Query all vendor purchase transactions (credit transactions = purchases)
      const purchaseTransactionsSnapshot = await db
        .collection(TRANSACTIONS_COLLECTION)
        .where('organizationId', '==', organizationId)
        .where('ledgerType', '==', 'vendorLedger')
        .where('type', '==', 'credit')
        .get();

      // Build vendor type lookup map from vendor documents
      const vendorTypeMap: Record<string, string> = {};
      orgVendors.forEach((doc) => {
        const vendorId = doc.id;
        const vendorType = doc.data()?.vendorType as string | undefined;
        if (vendorType) {
          vendorTypeMap[vendorId] = vendorType;
        }
      });

      // Group purchases by vendor type and month
      const purchasesByVendorType: Record<string, Record<string, number>> = {};
      
      purchaseTransactionsSnapshot.forEach((doc) => {
        const transactionData = doc.data();
        const vendorId = transactionData.vendorId as string | undefined;
        const vendorType = vendorId ? vendorTypeMap[vendorId] : undefined;
        
        if (!vendorId || !vendorType) {
          console.warn('[Vendor Analytics] Transaction missing vendorId or vendorType', {
            transactionId: doc.id,
            vendorId,
            vendorType,
          });
          return;
        }

        // Use transactionDate (primary) or paymentDate (fallback) or createdAt
        const transactionDate = transactionData.transactionDate as admin.firestore.Timestamp | undefined
          || transactionData.paymentDate as admin.firestore.Timestamp | undefined
          || transactionData.createdAt as admin.firestore.Timestamp | undefined;
        const amount = (transactionData.amount as number) || 0;
        
        if (transactionDate) {
          const dateObj = transactionDate.toDate();
          const monthKey = getYearMonth(dateObj);
          
          // Initialize vendor type if not exists
          if (!purchasesByVendorType[vendorType]) {
            purchasesByVendorType[vendorType] = {};
          }
          
          // Add amount to month
          purchasesByVendorType[vendorType][monthKey] = (purchasesByVendorType[vendorType][monthKey] || 0) + amount;
        }
      });

      await seedVendorAnalyticsDoc(analyticsRef, fyLabel, organizationId);
      
      // Build update data with nested structure
      const updateData: any = {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalPayable': totalPayable,
      };

      // Set purchases by vendor type - use dot notation for nested structure
      for (const [vendorType, monthlyData] of Object.entries(purchasesByVendorType)) {
        for (const [monthKey, amount] of Object.entries(monthlyData)) {
          updateData[`metrics.purchasesByVendorType.values.${vendorType}.${monthKey}`] = amount;
        }
      }

      await analyticsRef.set(updateData, { merge: true });
    });

    await Promise.all(analyticsUpdates);
    console.log(`[Vendor Analytics] Rebuilt analytics for ${Object.keys(vendorsByOrg).length} organizations`);
  });
