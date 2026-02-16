/*
 * Deletes ALL documents from TRANSACTIONS, SCHEDULE_TRIPS, and DELIVERY_MEMO collections.
 *
 * Usage:
 *   node delete-transactions-schedule-delivery-memos.js --confirm
 *
 * By default, this runs in dry-run mode and prints counts only.
 */

const path = require('path');
const admin = require('firebase-admin');

const shouldConfirm = process.argv.includes('--confirm');

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH
  ? path.resolve(process.env.SERVICE_ACCOUNT_PATH)
  : path.resolve(__dirname, '../../creds/service-account.json');

if (!shouldConfirm) {
  console.log('⚠️  Dry run only. Re-run with --confirm to delete data.');
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();
const BATCH_SIZE = 500;

async function deleteCollection(collectionName) {
  let totalDeleted = 0;
  let lastDoc = null;

  while (true) {
    let query = db.collection(collectionName).orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    if (shouldConfirm) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    totalDeleted += snapshot.size;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < BATCH_SIZE) {
      break;
    }
  }

  return totalDeleted;
}

async function run() {
  try {
    const collections = ['TRANSACTIONS', 'SCHEDULE_TRIPS', 'DELIVERY_MEMOS'];
    for (const name of collections) {
      const deleted = await deleteCollection(name);
      console.log(`${shouldConfirm ? '✅ Deleted' : 'ℹ️  Would delete'} ${deleted} docs from ${name}`);
    }
    console.log('✨ Done');
    process.exit(0);
  } catch (error) {
    console.error('💥 Failed:', error);
    process.exit(1);
  }
}

run();
