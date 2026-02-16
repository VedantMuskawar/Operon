const admin = require('firebase-admin');

const newServiceAccount = require('../firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json');
const newApp = admin.initializeApp(
  {
    credential: admin.credential.cert(newServiceAccount),
    databaseURL: 'https://operonappsuite.firebaseio.com',
  },
  'new',
);

async function backfillFuelTransactions() {
  const newDb = newApp.firestore();

  const snapshot = await newDb
    .collection('TRANSACTIONS')
    .where('organizationId', '==', 'NlQgs9kADbZr4ddBRkhS')
    .where('ledgerType', '==', 'vendorLedger')
    .where('category', '==', 'vendorPurchase')
    .where('type', '==', 'credit')
    .get();

  let batch = newDb.batch();
  let batchCount = 0;
  let totalUpdated = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const metadata = (data.metadata && typeof data.metadata === 'object') ? { ...data.metadata } : {};

    const hasPurchaseType = metadata.purchaseType === 'fuel';
    const hasCreatedAt = !!data.createdAt;
    const hasVehicleNumber = !!metadata.vehicleNumber;
    const hasVoucherNumber = !!metadata.voucherNumber;

    if (hasPurchaseType && hasCreatedAt && hasVehicleNumber && hasVoucherNumber) {
      continue;
    }

    const transactionDate = data.transactionDate || data.createdAt || admin.firestore.Timestamp.now();
    const vehicleNumber = (data.vehicleNumber || metadata.vehicleNumber || '').toString().replace(/\s+/g, '');
    const voucherNumber = data.voucherNumber || metadata.voucherNumber || metadata.invoiceNumber || '';

    metadata.purchaseType = 'fuel';
    if (vehicleNumber) metadata.vehicleNumber = vehicleNumber;
    if (voucherNumber) metadata.voucherNumber = voucherNumber;
    if (!metadata.recordedVia) metadata.recordedVia = data.recordedVia || 'purchase-page';
    if (!metadata.linkedTrips) metadata.linkedTrips = data.linkedTrips || [];

    const updatePayload = {
      metadata,
      createdAt: data.createdAt || transactionDate,
      updatedAt: admin.firestore.Timestamp.now(),
      transactionDate: data.transactionDate || transactionDate,
    };

    batch.update(doc.ref, updatePayload);
    batchCount += 1;

    if (batchCount >= 400) {
      await batch.commit();
      totalUpdated += batchCount;
      console.log(`Committed batch of ${batchCount}. Total updated: ${totalUpdated}`);
      batch = newDb.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    totalUpdated += batchCount;
    console.log(`Committed final batch of ${batchCount}. Total updated: ${totalUpdated}`);
  }

  console.log(`Backfill complete. Updated ${totalUpdated} transactions.`);
}

backfillFuelTransactions();
