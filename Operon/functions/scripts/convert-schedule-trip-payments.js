/*
 * Convert Schedule Trip Detail manual payments from clientPayment to tripPayment.
 *
 * Criteria:
 *  - category == 'clientPayment'
 *  - metadata.manualPayment == true
 *  - metadata.tripId exists (non-empty)
 *
 * Usage:
 *   node convert-schedule-trip-payments.js          (dry run)
 *   node convert-schedule-trip-payments.js --confirm
 */

const path = require('path');
const admin = require('firebase-admin');

const shouldConfirm = process.argv.includes('--confirm');

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

async function run() {
  try {
    if (!shouldConfirm) {
      console.log('⚠️  Dry run only. Re-run with --confirm to update records.');
    }

    let totalMatched = 0;
    let totalUpdated = 0;
    let lastDoc = null;

    while (true) {
      let query = db
        .collection('TRANSACTIONS')
        .where('category', '==', 'clientPayment')
        .where('metadata.manualPayment', '==', true)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(BATCH_SIZE);

      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      const batch = db.batch();
      let batchUpdates = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data() || {};
        const metadata = data.metadata || {};
        const tripId = (metadata.tripId || '').toString().trim();

        totalMatched += 1;

        if (!tripId) {
          continue;
        }

        if (shouldConfirm) {
          batch.update(doc.ref, {
            category: 'tripPayment',
          });
          batchUpdates += 1;
        }
      }

      if (shouldConfirm && batchUpdates > 0) {
        await batch.commit();
        totalUpdated += batchUpdates;
      }

      lastDoc = snapshot.docs[snapshot.docs.length - 1];

      if (snapshot.size < BATCH_SIZE) {
        break;
      }
    }

    if (shouldConfirm) {
      console.log(`✅ Updated ${totalUpdated} transactions (matched ${totalMatched})`);
    } else {
      console.log(`ℹ️  Would update ${totalMatched} transactions`);
    }

    console.log('✨ Done');
    process.exit(0);
  } catch (error) {
    console.error('💥 Failed:', error);
    process.exit(1);
  }
}

run();
