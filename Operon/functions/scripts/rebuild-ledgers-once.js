/*
 * One-off ledger rebuild script (client/vendor/employee).
 *
 * Usage:
 *   node rebuild-ledgers-once.js --org=ORG_ID --fy=FY2526 --type=all --confirm
 *
 * Notes:
 *  - --fy can be: FYxxxx, current, or all
 *  - --type can be: client | vendor | employee | all
 *  - Requires service account credentials.
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
const typeArg = (getArgValue('--type=') || 'all').trim();

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

const { rebuildLedgerCore } = require('../lib/ledger-maintenance/rebuild/rebuild-ledger-core');
const { getLedgerConfig } = require('../lib/ledger-maintenance/ledger-types');

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

async function rebuildType(ledgerType, financialYear) {
  const config = getLedgerConfig(ledgerType);
  let query = db.collection(config.collectionName).where('organizationId', '==', organizationId);
  if (financialYear) {
    query = query.where('financialYear', '==', financialYear);
  }

  const snapshot = await query.get();
  console.log(`🔎 ${ledgerType} ledgers matched: ${snapshot.size}`);

  if (!shouldConfirm) {
    return { total: snapshot.size, success: 0, failed: 0 };
  }

  let success = 0;
  let failed = 0;
  let skipped = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const entityId = data[config.idField];
    const fy = data.financialYear || financialYear;

    if (!entityId || !fy) {
      failed += 1;
      console.warn('⚠️  Skipping ledger with missing fields', { ledgerId: doc.id, entityId, fy });
      continue;
    }

    try {
      const ledgerRef = db.collection(config.collectionName).doc(doc.id);
      const hasTransactions = !(await ledgerRef.collection('TRANSACTIONS').limit(1).get()).empty;

      if (!hasTransactions) {
        skipped += 1;
        continue;
      }

      await rebuildLedgerCore(ledgerType, entityId, organizationId, fy);
      success += 1;
    } catch (error) {
      failed += 1;
      console.error('❌ Rebuild failed', { ledgerType, ledgerId: doc.id, entityId, fy, error });
    }
  }

  return { total: snapshot.size, success, failed, skipped };
}

async function run() {
  const financialYear = normalizeFy(fyArg);
  const types = typeArg === 'all' ? ['client', 'vendor', 'employee'] : [typeArg];

  if (!shouldConfirm) {
    console.log('⚠️  Dry run only. Re-run with --confirm to execute rebuilds.');
  }

  const summary = {
    total: 0,
    success: 0,
    failed: 0,
    skipped: 0,
  };

  for (const ledgerType of types) {
    if (!['client', 'vendor', 'employee'].includes(ledgerType)) {
      console.warn(`⚠️  Skipping invalid ledger type: ${ledgerType}`);
      continue;
    }

    const result = await rebuildType(ledgerType, financialYear);
    summary.total += result.total;
    summary.success += result.success;
    summary.failed += result.failed;
    summary.skipped += result.skipped || 0;
  }

  console.log('✅ Rebuild summary', summary);
  console.log('✨ Done');
  process.exit(0);
}

run().catch((error) => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
