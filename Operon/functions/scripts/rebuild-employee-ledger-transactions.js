/*
 * Rebuild EMPLOYEE_LEDGERS/{employeeId_fy}/TRANSACTIONS monthly subcollections
 * from TRANSACTIONS for a specific organization and financial year.
 *
 * Usage:
 *   node rebuild-employee-ledger-transactions.js --org=ORG_ID --fy=FY2526 --confirm
 *
 * Notes:
 *  - --fy can be: FYxxxx or current
 *  - Dry run unless --confirm is provided
 */

const path = require('path');
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const shouldConfirm = args.includes('--confirm');

function getArgValue(prefix) {
  const arg = args.find((a) => a.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : null;
}

const organizationId = getArgValue('--org=');
const fyArg = (getArgValue('--fy=') || 'current').trim();

if (!organizationId) {
  console.error('❌ Missing --org=ORG_ID');
  process.exit(1);
}

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH
  ? path.resolve(process.env.SERVICE_ACCOUNT_PATH)
  : path.resolve(__dirname, '../../creds/service-account.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

function getCurrentFinancialYear() {
  const now = new Date();
  const month = now.getMonth() + 1;
  const year = now.getFullYear();
  const fyStartYear = month >= 4 ? year : year - 1;
  const fyEndYear = fyStartYear + 1;
  const startStr = (fyStartYear % 100).toString().padStart(2, '0');
  const endStr = (fyEndYear % 100).toString().padStart(2, '0');
  return `FY${startStr}${endStr}`;
}

function normalizeFy(value) {
  const normalized = value.toLowerCase();
  if (normalized === 'current') return getCurrentFinancialYear();
  return value;
}

function getYearMonthCompact(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  return `${year}${month}`;
}

function toDate(value) {
  if (!value) return new Date(0);
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  return new Date(value);
}

function removeUndefined(obj) {
  return Object.fromEntries(Object.entries(obj).filter(([, v]) => v !== undefined));
}

async function ensureLedgerDoc(employeeId, financialYear) {
  const ledgerId = `${employeeId}_${financialYear}`;
  const ledgerRef = db.collection('EMPLOYEE_LEDGERS').doc(ledgerId);
  const ledgerDoc = await ledgerRef.get();
  if (ledgerDoc.exists) return ledgerRef;

  if (shouldConfirm) {
    await ledgerRef.set({
      ledgerId,
      employeeId,
      organizationId,
      financialYear,
      openingBalance: 0,
      currentBalance: 0,
      totalCredited: 0,
      totalTransactions: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return ledgerRef;
}

async function deleteStaleMonthlyDocs(ledgerRef, validMonthIds) {
  const existing = await ledgerRef.collection('TRANSACTIONS').get();
  const staleDocs = existing.docs.filter((doc) => !validMonthIds.has(doc.id));

  if (!shouldConfirm || staleDocs.length === 0) return;

  const BATCH_SIZE = 400;
  for (let i = 0; i < staleDocs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = staleDocs.slice(i, i + BATCH_SIZE);
    chunk.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function run() {
  const financialYear = normalizeFy(fyArg);
  console.log(`ℹ️  Rebuilding employee ledger subcollections for ${organizationId} (${financialYear})`);

  if (!shouldConfirm) {
    console.log('⚠️  Dry run only. Re-run with --confirm to apply changes.');
  }

  const transactionsByEmployeeMonth = new Map();

  let lastDoc = null;
  const BATCH_SIZE = 500;

  while (true) {
    let query = db
      .collection('TRANSACTIONS')
      .where('organizationId', '==', organizationId)
      .where('ledgerType', '==', 'employeeLedger')
      .where('financialYear', '==', financialYear)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const employeeId = data.employeeId;
      if (!employeeId) continue;

      const transactionDate = toDate(data.transactionDate || data.createdAt || doc.createTime?.toDate());
      const monthKey = getYearMonthCompact(transactionDate);
      const key = `${employeeId}_${monthKey}`;

      const txData = removeUndefined({
        transactionId: doc.id,
        organizationId: data.organizationId,
        employeeId,
        employeeName: data.employeeName,
        ledgerType: data.ledgerType || 'employeeLedger',
        type: data.type,
        category: data.category,
        amount: data.amount,
        financialYear: data.financialYear,
        transactionDate: admin.firestore.Timestamp.fromDate(transactionDate),
        createdAt: data.createdAt || admin.firestore.Timestamp.fromDate(transactionDate),
        updatedAt: data.updatedAt || admin.firestore.Timestamp.fromDate(transactionDate),
        paymentAccountId: data.paymentAccountId,
        paymentAccountType: data.paymentAccountType,
        referenceNumber: data.referenceNumber,
        description: data.description,
        metadata: data.metadata,
        createdBy: data.createdBy,
      });

      if (!transactionsByEmployeeMonth.has(key)) {
        transactionsByEmployeeMonth.set(key, { employeeId, monthKey, transactions: [] });
      }
      transactionsByEmployeeMonth.get(key).transactions.push(txData);
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < BATCH_SIZE) break;
  }

  const groupedByEmployee = new Map();
  for (const { employeeId, monthKey, transactions } of transactionsByEmployeeMonth.values()) {
    if (!groupedByEmployee.has(employeeId)) groupedByEmployee.set(employeeId, new Map());
    groupedByEmployee.get(employeeId).set(monthKey, transactions);
  }

  let totalMonths = 0;
  let totalEmployees = groupedByEmployee.size;

  for (const [employeeId, monthsMap] of groupedByEmployee.entries()) {
    const ledgerRef = await ensureLedgerDoc(employeeId, financialYear);
    const monthIds = new Set(monthsMap.keys());

    await deleteStaleMonthlyDocs(ledgerRef, monthIds);

    for (const [monthKey, transactions] of monthsMap.entries()) {
      totalMonths += 1;
      if (!shouldConfirm) continue;

      const monthlyRef = ledgerRef.collection('TRANSACTIONS').doc(monthKey);
      const totalCredit = transactions
        .filter((t) => t.type === 'credit')
        .reduce((sum, t) => sum + (t.amount || 0), 0);
      const totalDebit = transactions
        .filter((t) => t.type === 'debit')
        .reduce((sum, t) => sum + (t.amount || 0), 0);

      await monthlyRef.set({
        yearMonth: monthKey,
        transactions,
        transactionCount: transactions.length,
        totalCredit,
        totalDebit,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  console.log('✅ Rebuild summary', {
    employees: totalEmployees,
    months: totalMonths,
    dryRun: !shouldConfirm,
  });
  console.log('✨ Done');
  process.exit(0);
}

run().catch((error) => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
