const admin = require('firebase-admin');

const newServiceAccount = require('../firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json');
const newApp = admin.initializeApp(
  {
    credential: admin.credential.cert(newServiceAccount),
    databaseURL: 'https://operonappsuite.firebaseio.com',
  },
  'new',
);

async function recalcFuelVendorBalances() {
  const db = newApp.firestore();

  const organizationId = 'NlQgs9kADbZr4ddBRkhS';
  const financialYear = 'FY2526';

  const vendorsSnapshot = await db
    .collection('VENDORS')
    .where('organizationId', '==', organizationId)
    .where('vendorType', '==', 'fuel')
    .get();

  let totalVendorsUpdated = 0;

  for (const vendorDoc of vendorsSnapshot.docs) {
    const vendorId = vendorDoc.id;

    const ledgerRef = db.collection('VENDOR_LEDGERS').doc(`${vendorId}_${financialYear}`);
    const ledgerDoc = await ledgerRef.get();
    const openingBalance = (ledgerDoc.data() && ledgerDoc.data().openingBalance) || 0;

    const txSnapshot = await db
      .collection('TRANSACTIONS')
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'vendorLedger')
      .where('vendorId', '==', vendorId)
      .where('financialYear', '==', financialYear)
      .get();

    let totalPayables = 0;
    let totalPayments = 0;
    let creditCount = 0;
    let debitCount = 0;
    let lastTransactionDate = null;
    let lastTransactionAmount = 0;

    for (const doc of txSnapshot.docs) {
      const data = doc.data();
      const amount = (data.amount !== undefined ? data.amount : 0) || 0;
      const type = data.type;
      const transactionDate = data.transactionDate || data.createdAt || doc.createTime;

      if (type === 'credit') {
        totalPayables += amount;
        creditCount += 1;
      } else if (type === 'debit') {
        totalPayments += amount;
        debitCount += 1;
      }

      if (transactionDate) {
        const txDate = transactionDate.toDate();
        if (!lastTransactionDate || txDate > lastTransactionDate.toDate()) {
          lastTransactionDate = admin.firestore.Timestamp.fromDate(txDate);
          lastTransactionAmount = amount;
        }
      }
    }

    const currentBalance = openingBalance + totalPayables - totalPayments;
    const transactionCount = creditCount + debitCount;

    const ledgerUpdates = {
      organizationId,
      vendorId,
      financialYear,
      openingBalance,
      currentBalance,
      totalPayables,
      totalPayments,
      transactionCount,
      creditCount,
      debitCount,
      lastTransactionDate: lastTransactionDate || admin.firestore.FieldValue.serverTimestamp(),
      lastTransactionAmount,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (ledgerDoc.exists) {
      await ledgerRef.update(ledgerUpdates);
    } else {
      await ledgerRef.set({
        ledgerId: `${vendorId}_${financialYear}`,
        ...ledgerUpdates,
      }, { merge: true });
    }

    await db.collection('VENDORS').doc(vendorId).update({
      currentBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    totalVendorsUpdated += 1;
    console.log(`[Vendor Balance] Updated ${vendorId}: ${currentBalance} (tx: ${transactionCount})`);
  }

  console.log(`Recalc complete. Updated ${totalVendorsUpdated} fuel vendors.`);
}

recalcFuelVendorBalances();
