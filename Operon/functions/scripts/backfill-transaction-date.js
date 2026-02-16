/*
 * Backfill transactionDate for transactions missing it.
 *
 * Usage:
 *   node backfill-transaction-date.js --org=ORG_ID --fy=FY2526 --confirm
 *
 * Notes:
 *  - --fy can be: FYxxxx, current, or all (default: all)
 *  - Runs in dry-run mode unless --confirm is provided
 *  - Sets transactionDate = paymentDate (if present) else createdAt
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
const fyArg = (getArgValue('--fy=') || 'all').trim();

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
const BATCH_SIZE = 400;

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
  if (normalized === 'all') return null;
  return value;
}

function pickTransactionDate(data) {
  const paymentDate = data.paymentDate;
  if (paymentDate) return paymentDate;
  const createdAt = data.createdAt;
  if (createdAt) return createdAt;
  return null;
}

async function backfillTransactions(financialYear) {
  let query = db.collection('TRANSACTIONS')
    .where('organizationId', '==', organizationId)
    .orderBy(admin.firestore.FieldPath.documentId());

  if (financialYear) {
    query = query.where('financialYear', '==', financialYear);
  }

  let lastDoc = null;
  let totalScanned = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;

  while (true) {
    let page = query.limit(BATCH_SIZE);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }

    const snapshot = await page.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let batchUpdates = 0;

    for (const doc of snapshot.docs) {
      totalScanned += 1;
      const data = doc.data();

      if (data.transactionDate) {
        totalSkipped += 1;
        continue;
      }

      const newDate = pickTransactionDate(data);
      if (!newDate) {
        totalSkipped += 1;
        continue;
      }

      if (shouldConfirm) {
        batch.update(doc.ref, {
          transactionDate: newDate,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batchUpdates += 1;
      }

      totalUpdated += 1;
    }

    if (shouldConfirm && batchUpdates > 0) {
      await batch.commit();
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < BATCH_SIZE) break;
  }

  return { totalScanned, totalUpdated, totalSkipped };
}

async function run() {
  try {
    if (!shouldConfirm) {
      console.log('⚠️  Dry run only. Re-run with --confirm to apply updates.');
    }

    const financialYear = normalizeFy(fyArg);
    const result = await backfillTransactions(financialYear);

    console.log('✅ Backfill summary', result);
    console.log('✨ Done');
    process.exit(0);
  } catch (error) {
    console.error('💥 Failed:', error);
    process.exit(1);
  }
}

run();
