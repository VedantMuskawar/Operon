#!/usr/bin/env node
/**
 * One-time backfill for PENDING_ORDERS.hasAvailableTrips and missing status.
 *
 * Usage:
 *   node scripts/backfill-has-available-trips.js
 *   node scripts/backfill-has-available-trips.js --dry-run
 *   node scripts/backfill-has-available-trips.js --org=ORG_ID
 *   node scripts/backfill-has-available-trips.js --limit=5000
 *
 * Uses migrations/firebase/creds/operonappsuite-firebase-adminsdk-*.json if present,
 * else serviceAccountKey.json, else GOOGLE_APPLICATION_CREDENTIALS / ADC.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin (uses GOOGLE_APPLICATION_CREDENTIALS if set)
if (!admin.apps.length) {
  try {
    const migrationsCreds = path.join(
      __dirname,
      '../../migrations/firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json',
    );
    const fallbackCreds = path.join(__dirname, '../serviceAccountKey.json');
    const credsPath = fs.existsSync(migrationsCreds) ? migrationsCreds : fallbackCreds;

    if (fs.existsSync(credsPath)) {
      admin.initializeApp({ credential: admin.credential.cert(require(credsPath)) });
    } else {
      admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'operonappsuite' });
    }
  } catch (e) {
    console.error('Init failed. Set GOOGLE_APPLICATION_CREDENTIALS or add migrations/firebase/creds/ service account file');
    process.exit(1);
  }
}

const db = admin.firestore();
const PENDING_ORDERS = 'PENDING_ORDERS';
const BATCH_SIZE = 400; // Firestore limit 500; stay safe

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const orgArg = args.find((arg) => arg.startsWith('--org='));
const limitArg = args.find((arg) => arg.startsWith('--limit='));
const orgId = orgArg ? orgArg.split('=')[1] : null;
const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : null;

function computeHasAvailableTrips(items) {
  if (!Array.isArray(items)) return false;
  for (const item of items) {
    if (!item || typeof item !== 'object') continue;
    const estimatedTrips = Math.max(0, Math.floor(Number(item.estimatedTrips)) || 0);
    const scheduledTrips = Math.max(0, Math.floor(Number(item.scheduledTrips)) || 0);
    if (estimatedTrips > scheduledTrips) return true;
  }
  return false;
}

async function run() {
  console.log('Backfilling PENDING_ORDERS.hasAvailableTrips and missing status');
  if (dryRun) console.log('Mode: DRY RUN');
  if (orgId) console.log(`Filter: organizationId == ${orgId}`);
  if (limit) console.log(`Limit: ${limit}`);

  let totalScanned = 0;
  let totalUpdated = 0;
  let lastDoc = null;

  while (true) {
    let query = db.collection(PENDING_ORDERS).orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);

    if (orgId) {
      query = query.where('organizationId', '==', orgId);
    }

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    let batchUpdates = 0;

    snapshot.docs.forEach((doc) => {
      if (limit && totalScanned >= limit) return;
      totalScanned += 1;

      const data = doc.data() || {};
      const items = data.items || [];
      const computedHasAvailableTrips = computeHasAvailableTrips(items);
      const existingHasAvailableTrips = data.hasAvailableTrips;
      const status = (data.status || '').toString().trim();
      const resolvedStatus = status ? status : 'pending';

      const shouldUpdateHasAvailableTrips = existingHasAvailableTrips !== computedHasAvailableTrips;
      const shouldUpdateStatus = !status;

      if (shouldUpdateHasAvailableTrips || shouldUpdateStatus) {
        batchUpdates += 1;
        if (!dryRun) {
          const updateData = {
            hasAvailableTrips: computedHasAvailableTrips,
            ...(shouldUpdateStatus ? { status: resolvedStatus } : {}),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          batch.update(doc.ref, updateData);
        }
      }
    });

    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    if (batchUpdates > 0) {
      if (!dryRun) {
        await batch.commit();
      }
      totalUpdated += batchUpdates;
    }

    console.log(`Processed batch: ${snapshot.size} docs (total scanned: ${totalScanned}, updated: ${totalUpdated})`);

    if (limit && totalScanned >= limit) break;
    if (snapshot.size < BATCH_SIZE) break;
  }

  console.log('Backfill complete:', JSON.stringify({ scanned: totalScanned, updated: totalUpdated, dryRun }, null, 2));
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
