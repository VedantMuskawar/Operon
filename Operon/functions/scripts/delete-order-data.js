#!/usr/bin/env node
/**
 * Delete order-related documents while preserving CLIENT_LEDGERS.
 *
 * DELETES:
 * - DELIVERY_MEMOS (all)
 * - TRANSACTIONS (root collection only)
 * - PENDING_ORDERS (all)
 * - SCHEDULE_TRIPS (all)
 *
 * KEEPS:
 * - CLIENT_LEDGERS (including CLIENT_LEDGERS/{id}/TRANSACTIONS subcollection)
 *
 * Run: node scripts/delete-order-data.js
 *
 * Uses migrations/firebase/creds/operonappsuite-firebase-adminsdk-*.json if present,
 * else serviceAccountKey.json, else GOOGLE_APPLICATION_CREDENTIALS / ADC.
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin (uses GOOGLE_APPLICATION_CREDENTIALS if set)
if (!admin.apps.length) {
  try {
    const credsPath = require('fs').existsSync(path.join(__dirname, '../../migrations/firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json'))
      ? path.join(__dirname, '../../migrations/firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json')
      : path.join(__dirname, '../serviceAccountKey.json');
    if (require('fs').existsSync(credsPath)) {
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

const DELIVERY_MEMOS = 'DELIVERY_MEMOS';
const TRANSACTIONS = 'TRANSACTIONS';
const PENDING_ORDERS = 'PENDING_ORDERS';
const SCHEDULE_TRIPS = 'SCHEDULE_TRIPS';

const BATCH_SIZE = 400; // Firestore limit 500; stay safe
const MAX_ITERATIONS = 2000;

async function deleteInBatches(collectionName) {
  const colRef = db.collection(collectionName);
  let total = 0;
  let it = 0;

  while (it < MAX_ITERATIONS) {
    const snap = await colRef.limit(BATCH_SIZE).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    total += snap.size;
    console.log(`  [${collectionName}] deleted batch ${snap.size} (total: ${total})`);

    if (snap.size < BATCH_SIZE) break;
    it++;
  }

  return total;
}

async function run() {
  console.log('Deleting order data (keeping CLIENT_LEDGERS)...\n');

  const results = {
    deliveryMemos: 0,
    transactions: 0,
    pendingOrders: 0,
    scheduleTrips: 0,
    errors: [],
  };

  const steps = [
    [DELIVERY_MEMOS, 'deliveryMemos'],
    [TRANSACTIONS, 'transactions'],
    [PENDING_ORDERS, 'pendingOrders'],
    [SCHEDULE_TRIPS, 'scheduleTrips'],
  ];

  for (const [col, key] of steps) {
    try {
      console.log(`Deleting ${col}...`);
      results[key] = await deleteInBatches(col);
      console.log(`  Done: ${results[key]} documents\n`);
    } catch (e) {
      const msg = `Failed ${col}: ${e.message}`;
      console.error('  ' + msg);
      results.errors.push(msg);
    }
  }

  console.log('Summary:', JSON.stringify(results, null, 2));
  if (results.errors.length) process.exit(1);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
