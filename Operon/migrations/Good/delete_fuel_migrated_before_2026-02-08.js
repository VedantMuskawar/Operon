const admin = require('firebase-admin');

const newServiceAccount = require('../firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json');
const newApp = admin.initializeApp(
  {
    credential: admin.credential.cert(newServiceAccount),
    databaseURL: 'https://operonappsuite.firebaseio.com',
  },
  'new',
);

async function deleteMigratedFuelTransactionsBeforeCutoff() {
  const db = newApp.firestore();

  const organizationId = 'NlQgs9kADbZr4ddBRkhS';
  const cutoffDate = new Date('2026-02-08T23:59:59.999Z');
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);

  const snapshot = await db
    .collection('TRANSACTIONS')
    .where('organizationId', '==', organizationId)
    .where('ledgerType', '==', 'vendorLedger')
    .where('category', '==', 'vendorPurchase')
    .where('type', '==', 'credit')
    .where('createdBy', '==', 'Migrated')
    .get();

  let batch = db.batch();
  let batchCount = 0;
  let totalDeleted = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const metadata = (data.metadata && typeof data.metadata === 'object') ? data.metadata : {};
    const purchaseType = metadata.purchaseType || data.purchaseType;
    const transactionDate = data.transactionDate || data.createdAt;

    if (purchaseType !== 'fuel') {
      continue;
    }

    if (!transactionDate || transactionDate.toMillis() > cutoffTimestamp.toMillis()) {
      continue;
    }

    batch.delete(doc.ref);
    batchCount += 1;

    if (batchCount >= 400) {
      await batch.commit();
      totalDeleted += batchCount;
      console.log(`Committed batch of ${batchCount}. Total deleted: ${totalDeleted}`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    totalDeleted += batchCount;
    console.log(`Committed final batch of ${batchCount}. Total deleted: ${totalDeleted}`);
  }

  console.log(`Delete complete. Deleted ${totalDeleted} transactions.`);
}

deleteMigratedFuelTransactionsBeforeCutoff();
