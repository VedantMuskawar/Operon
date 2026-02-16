/*
 * Re-open clientCredit transactions cancelled due to dispatch revert.
 *
 * Usage:
 *   node reopen-cancelled-clientcredit.js --org=ORG_ID --fy=FY2526 --confirm
 *
 * Notes:
 *  - --fy can be: FYxxxx, current, or all (default: current)
 *  - Runs in dry-run mode unless --confirm is provided
 *  - Will only reopen if an active DELIVERY_MEMO exists for the trip
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
  if (normalized === 'all') return null;
  return value;
}

async function hasActiveDeliveryMemo(tripId) {
  if (!tripId) return false;
  const snapshot = await db
    .collection('DELIVERY_MEMOS')
    .where('tripId', '==', tripId)
    .where('status', '==', 'active')
    .limit(1)
    .get();
  return !snapshot.empty;
}

async function reopenTransactions(financialYear) {
  let query = db.collection('TRANSACTIONS')
    .where('organizationId', '==', organizationId)
    .where('category', '==', 'clientCredit')
    .where('status', '==', 'cancelled')
    .where('cancellationReason', '==', 'Trip dispatch reverted');

  if (financialYear) {
    query = query.where('financialYear', '==', financialYear);
  }

  query = query.orderBy(admin.firestore.FieldPath.documentId());

  const batchSize = 200;
  let lastDoc = null;
  let totalMatched = 0;
  let totalReopened = 0;
  let totalSkipped = 0;

  while (true) {
    let page = query.limit(batchSize);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }

    const snapshot = await page.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      totalMatched += 1;
      const data = doc.data();
      const tripId = data.tripId || data.metadata?.tripId;

      const hasActiveDm = await hasActiveDeliveryMemo(tripId);
      if (!hasActiveDm) {
        totalSkipped += 1;
        continue;
      }

      if (shouldConfirm) {
        await doc.ref.update({
          status: admin.firestore.FieldValue.delete(),
          cancelledAt: admin.firestore.FieldValue.delete(),
          cancelledBy: admin.firestore.FieldValue.delete(),
          cancellationReason: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      totalReopened += 1;
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < batchSize) break;
  }

  return { totalMatched, totalReopened, totalSkipped };
}

async function run() {
  try {
    if (!shouldConfirm) {
      console.log('⚠️  Dry run only. Re-run with --confirm to apply updates.');
    }

    const financialYear = normalizeFy(fyArg);
    const result = await reopenTransactions(financialYear);

    console.log('✅ Reopen summary', result);
    console.log('✨ Done');
    process.exit(0);
  } catch (error) {
    console.error('💥 Failed:', error);
    process.exit(1);
  }
}

run();
