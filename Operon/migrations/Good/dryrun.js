const admin = require('firebase-admin');

// Initialize old DB
const oldServiceAccount = require('../firebase/creds/legacy-service-account.json');
const oldApp = admin.initializeApp({
  credential: admin.credential.cert(oldServiceAccount),
  databaseURL: 'https://apex-21cd0.firebaseio.com'
}, 'old');

// Initialize new DB
const newServiceAccount = require('../firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json');
const newApp = admin.initializeApp({
  credential: admin.credential.cert(newServiceAccount),
  databaseURL: 'https://operonappsuite.firebaseio.com'
}, 'new');

async function migrateDieselVouchers() {
  const oldDb = oldApp.firestore();
  const newDb = newApp.firestore();

  // Filter: paid == false
  const snapshot = await oldDb.collection('DIESEL_VOUCHERS').where('paid', '==', false).get();
  let batch = newDb.batch();
  let batchCount = 0;
  let totalWritten = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();

    const transactionDate = data.date || admin.firestore.Timestamp.now();
    const mapped = {
      amount: data.amount,
      category: "vendorPurchase",
      clientId: "",
      createdBy: "Migrated",
      createdAt: transactionDate,
      updatedAt: transactionDate,
      currency: "INR",
      financialYear: "FY2526",
      ledgerType: "vendorLedger",
      metadata: {
        invoiceNumber: data.voucherNo,
        purchaseType: "fuel",
        vehicleNumber: (data.vehicleNo || "").replace(/\s+/g, ""),
        voucherNumber: data.voucherNo,
        recordedVia: "purchase-page",
        linkedTrips: data.linkedTrips || [],
      },
      linkedTrips: data.linkedTrips || [],
      purchaseType: "fuel",
      recordedVia: "purchase-page",
      totals: {
        chargesGst: 0,
        chargesSubtotal: 0,
        chargesTotal: 0,
        grandTotal: data.amount,
        materialsGst: 0,
        materialsSubtotal: 0,
        materialsTotal: 0
      },
      vehicleNumber: (data.vehicleNo || "").replace(/\s+/g, ""),
      vendorName: "H K Petroleum",
      voucherNumber: data.voucherNo,
      organizationId: "NlQgs9kADbZr4ddBRkhS",
      referenceNumber: data.voucherNo,
      transactionDate: transactionDate,
      type: "credit",
      vendorId: "CkZ04yUPZkoR2g7OM1XZ",
      verified: false
    };

    const ref = newDb.collection('TRANSACTIONS').doc();
    batch.set(ref, mapped);
    batchCount += 1;

    if (batchCount >= 400) {
      await batch.commit();
      totalWritten += batchCount;
      console.log(`Committed batch of ${batchCount}. Total written: ${totalWritten}`);
      batch = newDb.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    totalWritten += batchCount;
    console.log(`Committed final batch of ${batchCount}. Total written: ${totalWritten}`);
  }
}

migrateDieselVouchers();