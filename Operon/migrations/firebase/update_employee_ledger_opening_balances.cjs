const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('../../creds/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

const LEDGER_DOC_ID = 'GVFJbpyYDiyf3p1dpxnV_FY2526';
const LEDGER_COLLECTION = 'EMPLOYEE_LEDGER'; // Adjust if your collection name differs

async function updateLedgerOpeningBalances() {
  // 1. Get all employees and their openingBalance
  const employeesSnap = await db.collection('EMPLOYEES').get();
  const openingBalances = {};
  employeesSnap.forEach(doc => {
    const data = doc.data();
    if (data && data.openingBalance !== undefined) {
      openingBalances[doc.id] = { openingBalance: data.openingBalance };
    }
  });

  // 2. Get the ledger doc
  const ledgerRef = db.collection(LEDGER_COLLECTION).doc(LEDGER_DOC_ID);
  const ledgerSnap = await ledgerRef.get();
  if (!ledgerSnap.exists) {
    console.error('Ledger document not found:', LEDGER_DOC_ID);
    return;
  }
  const ledgerData = ledgerSnap.data() || {};
  const employeeLedgers = ledgerData.employeeLedgers || {};

  // 3. Update openingBalance for each employee
  for (const [empId, { openingBalance }] of Object.entries(openingBalances)) {
    if (!employeeLedgers[empId]) employeeLedgers[empId] = {};
    employeeLedgers[empId].openingBalance = openingBalance;
  }

  // 4. Write back
  await ledgerRef.update({ employeeLedgers });
  console.log('Updated openingBalance for all employees in EMPLOYEE LEDGER:', LEDGER_DOC_ID);
}

updateLedgerOpeningBalances().catch(console.error);
