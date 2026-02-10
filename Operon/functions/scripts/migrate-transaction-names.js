#!/usr/bin/env node
/**
 * Backfill missing client/vendor/employee names on TRANSACTIONS.
 *
 * Updates:
 * - clientName (top-level) and metadata.clientName
 * - metadata.vendorName
 * - metadata.employeeName
 *
 * Run: node functions/scripts/migrate-transaction-names.js
 *
 * Uses migrations/firebase/creds/operonappsuite-firebase-adminsdk-*.json if present,
 * else serviceAccountKey.json, else GOOGLE_APPLICATION_CREDENTIALS / ADC.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

if (!admin.apps.length) {
  try {
    const credsPath = fs.existsSync(
      path.join(
        __dirname,
        '../../migrations/firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json',
      ),
    )
      ? path.join(
          __dirname,
          '../../migrations/firebase/creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json',
        )
      : path.join(__dirname, '../serviceAccountKey.json');

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

const TRANSACTIONS = 'TRANSACTIONS';
const CLIENTS = 'CLIENTS';
const VENDORS = 'VENDORS';
const EMPLOYEES = 'EMPLOYEES';

const BATCH_SIZE = 400; // Keep under Firestore batch limit

function normalizeName(value) {
  if (!value || typeof value !== 'string') return '';
  return value.trim();
}

async function fetchName(cache, collection, id) {
  if (!id) return '';
  if (cache.has(id)) return cache.get(id);
  const doc = await db.collection(collection).doc(id).get();
  if (!doc.exists) {
    cache.set(id, '');
    return '';
  }
  const data = doc.data() || {};
  const name =
    normalizeName(data.name) ||
    normalizeName(data.clientName) ||
    normalizeName(data.vendorName) ||
    normalizeName(data.employeeName);
  cache.set(id, name || '');
  return name || '';
}

async function run() {
  console.log('Backfilling transaction names...');

  const clientCache = new Map();
  const vendorCache = new Map();
  const employeeCache = new Map();

  let total = 0;
  let updated = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection(TRANSACTIONS)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(BATCH_SIZE);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchUpdates = 0;

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const metadata = data.metadata || {};
      const updates = {};
      let hasUpdate = false;

      const currentClientName = normalizeName(data.clientName);
      if (data.clientId && !currentClientName) {
        const resolvedClientName = await fetchName(clientCache, CLIENTS, data.clientId);
        if (resolvedClientName) {
          updates.clientName = resolvedClientName;
          if (!normalizeName(metadata.clientName)) {
            updates['metadata.clientName'] = resolvedClientName;
          }
          hasUpdate = true;
        }
      }

      if (data.vendorId && !normalizeName(metadata.vendorName)) {
        const resolvedVendorName = await fetchName(vendorCache, VENDORS, data.vendorId);
        if (resolvedVendorName) {
          updates['metadata.vendorName'] = resolvedVendorName;
          hasUpdate = true;
        }
      }

      if (data.employeeId && !normalizeName(metadata.employeeName)) {
        const resolvedEmployeeName = await fetchName(employeeCache, EMPLOYEES, data.employeeId);
        if (resolvedEmployeeName) {
          updates['metadata.employeeName'] = resolvedEmployeeName;
          hasUpdate = true;
        }
      }

      if (hasUpdate) {
        batch.update(doc.ref, updates);
        batchUpdates += 1;
        updated += 1;
      }

      total += 1;
    }

    if (batchUpdates > 0) {
      await batch.commit();
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`Processed ${total} transactions, updated ${updated}...`);

    if (snap.size < BATCH_SIZE) break;
  }

  console.log(`Done. Total processed: ${total}, updated: ${updated}.`);
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
