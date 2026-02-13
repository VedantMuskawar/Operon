const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('../../creds/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

async function fixEmployeesBalances() {
  const employeesSnap = await db.collection('EMPLOYEES').get();
  let fixed = 0;
  for (const doc of employeesSnap.docs) {
    const data = doc.data();
    let update = {};
    let changed = false;
    if (data.openingBalance !== undefined && typeof data.openingBalance !== 'number') {
      update.openingBalance = Number(data.openingBalance) || 0;
      changed = true;
    }
    if (data.currentBalance !== undefined && typeof data.currentBalance !== 'number') {
      update.currentBalance = Number(data.currentBalance) || 0;
      changed = true;
    }
    if (changed) {
      await doc.ref.update(update);
      fixed++;
    }
  }
  console.log(`Fixed EMPLOYEES: ${fixed} docs updated.`);
}

async function fixEmployeeLedgerBalances() {
  const ledgersSnap = await db.collection('EMPLOYEE_LEDGER').get();
  let fixed = 0;
  for (const doc of ledgersSnap.docs) {
    const data = doc.data();
    if (!data.employeeLedgers) continue;
    let changed = false;
    for (const [empId, ledger] of Object.entries(data.employeeLedgers)) {
      if (!ledger) continue;
      let update = {};
      if (ledger.openingBalance !== undefined && typeof ledger.openingBalance !== 'number') {
        update.openingBalance = Number(ledger.openingBalance) || 0;
        changed = true;
      }
      if (ledger.currentBalance !== undefined && typeof ledger.currentBalance !== 'number') {
        update.currentBalance = Number(ledger.currentBalance) || 0;
        changed = true;
      }
      if (Object.keys(update).length > 0) {
        data.employeeLedgers[empId] = { ...ledger, ...update };
      }
    }
    if (changed) {
      await doc.ref.update({ employeeLedgers: data.employeeLedgers });
      fixed++;
    }
  }
  console.log(`Fixed EMPLOYEE_LEDGER: ${fixed} docs updated.`);
}

async function main() {
  await fixEmployeesBalances();
  await fixEmployeeLedgerBalances();
  console.log('Balance type correction complete.');
}

main().catch(console.error);
