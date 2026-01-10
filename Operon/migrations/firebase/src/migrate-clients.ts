/**
 * CLIENTS Migration Script - From Pave
 * 
 * Migrates client data from Pave (legacy Firebase project) to the new Operon Firebase project.
 * Only migrates data up to December 31, 2025 (31.12.25).
 * 
 * Before running:
 * 1. Review and fill in CLIENTS_MIGRATION_MAPPING.md with field mappings
 * 2. Update field names in this script based on the mapping document
 * 3. Ensure Firestore indexes are created for the query (orgID + date field)
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface MigrationConfig {
  legacyServiceAccount: string;
  newServiceAccount: string;
  legacyProjectId?: string;
  newProjectId?: string;
  legacyOrgId: string;
  targetOrgId: string;
}

const FALLBACK_LEGACY_ORG = 'K4Q6vPOuTcLPtlcEwdw0'; // Filter data from old database
const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS'; // Assign this OrgID in target database

function resolveConfig(): MigrationConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const legacyServiceAccount =
    resolvePath(process.env.LEGACY_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/legacy-service-account.json');
  const newServiceAccount =
    resolvePath(process.env.NEW_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/new-service-account.json');

  if (!fs.existsSync(legacyServiceAccount) || !fs.existsSync(newServiceAccount)) {
    const missing = [];
    if (!fs.existsSync(legacyServiceAccount)) {
      missing.push(`Legacy: ${legacyServiceAccount}`);
    }
    if (!fs.existsSync(newServiceAccount)) {
      missing.push(`New: ${newServiceAccount}`);
    }
    throw new Error(
      `Service account files not found:\n${missing.join('\n')}\n\n` +
        'Please download service account JSON files from Google Cloud Console and place them in:\n' +
        `  - ${path.join(process.cwd(), 'creds/legacy-service-account.json')}\n` +
        `  - ${path.join(process.cwd(), 'creds/new-service-account.json')}\n\n` +
        'Or set LEGACY_SERVICE_ACCOUNT and NEW_SERVICE_ACCOUNT environment variables with full paths.',
    );
  }

  return {
    legacyServiceAccount,
    newServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    newProjectId: process.env.NEW_PROJECT_ID,
    legacyOrgId: process.env.LEGACY_ORG_ID ?? FALLBACK_LEGACY_ORG,
    targetOrgId: process.env.NEW_ORG_ID ?? FALLBACK_TARGET_ORG,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApps(
  config: MigrationConfig,
): { legacy: admin.app.App; target: admin.app.App } {
  const legacy = admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.legacyServiceAccount),
      ),
      projectId: config.legacyProjectId,
    },
    'legacy',
  );

  const target = admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.newServiceAccount),
      ),
      projectId: config.newProjectId,
    },
    'target',
  );

  return { legacy, target };
}

async function deleteExistingClients(targetDb: admin.firestore.Firestore, targetOrgId: string) {
  console.log('\n=== Deleting existing CLIENTS data ===');
  console.log('Target Org ID:', targetOrgId);

  // Delete all clients for the target organization
  const snapshot = await targetDb
    .collection('CLIENTS')
    .where('organizationId', '==', targetOrgId)
    .get();

  if (snapshot.empty) {
    console.log('No existing clients found to delete.');
    return;
  }

  console.log(`Found ${snapshot.size} existing client documents to delete`);

  const batchSize = 400;
  let deleted = 0;
  let batch = targetDb.batch();

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    deleted += 1;

    if (deleted % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Deleted ${deleted} client docs...`);
    }
  }

  if (deleted % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`Cleanup complete. Total clients deleted: ${deleted}\n`);
}

async function migrateClients() {
  const config = resolveConfig();
  const { legacy, target } = initApps(config);

  const legacyDb = legacy.firestore();
  const targetDb = target.firestore();

  // Delete existing clients before migration
  await deleteExistingClients(targetDb, config.targetOrgId);

  // Date cutoff: December 31, 2025, 23:59:59 UTC
  const cutoffDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-12-31T23:59:59.999Z')
  );

  console.log('=== Migrating CLIENTS from Pave ===');
  console.log('Cutoff date:', cutoffDate.toDate().toISOString());
  console.log('Legacy Org ID:', config.legacyOrgId);
  console.log('Target Org ID:', config.targetOrgId);
  console.log('Preserving Pave document IDs\n');

  // Query by orgID only (avoids need for composite index)
  // Date filtering will be done in memory after fetching
  // Field names based on CLIENTS_MIGRATION_MAPPING.md:
  // - orgID: organization field in Pave (configured via LEGACY_ORG_ID env var)
  // - registeredTime: creation date field in Pave (filtered in memory)
  console.log('Fetching clients from Pave (this may take a while for large datasets)...');
  const snapshot = await legacyDb
    .collection('CLIENTS')
    .where('orgID', '==', config.legacyOrgId)
    .get();
  
  console.log(`Fetched ${snapshot.size} total clients from Pave`);

  if (snapshot.empty) {
    console.log('No legacy clients found for org', config.legacyOrgId);
    return;
  }

  // Filter by date in memory (to avoid needing composite index)
  const cutoffMillis = cutoffDate.toMillis();
  const docsToMigrate = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const docDate = data.registeredTime as admin.firestore.Timestamp | undefined;
    if (!docDate) return true; // Include if no date (migrate anyway)
    return docDate.toMillis() <= cutoffMillis;
  });

  console.log(`After date filtering (<= ${cutoffDate.toDate().toISOString()}): ${docsToMigrate.length} documents to migrate`);

  if (docsToMigrate.length === 0) {
    console.log('No clients found matching the date filter');
    return;
  }

  let processed = 0;
  let skipped = snapshot.size - docsToMigrate.length;
  const batchSize = 400;
  let batch = targetDb.batch();

  for (const doc of docsToMigrate) {
    const data = doc.data();

    const transformed = transformClient(data, config.targetOrgId);

    // Preserve Pave's document ID
    const targetRef = targetDb.collection('CLIENTS').doc(doc.id);
    // Set clientId to match document ID (as per schema requirement)
    transformed.clientId = doc.id;
    batch.set(targetRef, transformed, { merge: true });
    processed += 1;

    if (processed % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Committed ${processed} client docs...`);
    }
  }

  if (processed % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`\n=== Migration Complete ===`);
  console.log(`Total clients processed: ${processed}`);
  if (skipped > 0) {
    console.log(`Skipped ${skipped} clients (date after cutoff)`);
  }
}

/**
 * Normalize phone number to E.164 format
 * Format: +[country code][number] (e.g., +919876543210)
 */
function normalizePhone(raw?: string | null): string | undefined {
  if (!raw) return undefined;
  const digits = raw.replace(/[^0-9+]/g, '');
  if (/^[0-9]{10}$/.test(digits)) {
    return `+91${digits}`;
  }
  if (/^91[0-9]{10}$/.test(digits) && !digits.startsWith('+')) {
    return `+${digits}`;
  }
  return digits.startsWith('+') ? digits : digits;
}

/**
 * Transform Pave client data to Operon CLIENTS schema
 * Field mappings based on CLIENTS_MIGRATION_MAPPING.md:
 * - name → name
 * - phoneNumber → primaryPhone
 * - phoneList → phones array
 * - registeredTime → createdAt
 */
function transformClient(
  data: firestore.DocumentData,
  targetOrgId: string,
): firestore.DocumentData {
  // Extract fields from Pave schema
  const name = (data.name as string | undefined) ?? 'Unnamed Client';
  const phoneList = (data.phoneList as string[] | undefined) ?? [];
  const primaryPhoneRaw = (data.phoneNumber as string | undefined);

  // Normalize all phone numbers to E.164 format
  const phoneEntries: Array<{ e164: string; label: string }> = [];
  const seenPhones = new Set<string>();

  // Add primary phone first with 'main' label
  if (primaryPhoneRaw) {
    const normalizedPrimary = normalizePhone(primaryPhoneRaw);
    if (normalizedPrimary && !seenPhones.has(normalizedPrimary)) {
      phoneEntries.push({ e164: normalizedPrimary, label: 'main' });
      seenPhones.add(normalizedPrimary);
    }
  }

  // Add other phones from phoneList with 'alt' label
  for (const phone of phoneList) {
    const normalized = normalizePhone(phone);
    if (normalized && !seenPhones.has(normalized)) {
      phoneEntries.push({ e164: normalized, label: 'alt' });
      seenPhones.add(normalized);
    }
  }

  // Use primary phone or first phone from list as primary
  const primaryPhone = primaryPhoneRaw ?? (phoneList.length > 0 ? phoneList[0] : undefined);
  const primaryPhoneNormalized = normalizePhone(primaryPhone);

  // Generate phoneIndex array (all normalized phone numbers for search)
  const phoneIndex = phoneEntries.map((entry) => entry.e164);

  // Determine tags (default based on phone count if not provided)
  const tags: string[] = phoneEntries.length <= 1 ? ['Individual'] : ['Distributor'];

  // Build the transformed document matching Operon CLIENTS schema
  return {
    name: name.trim(),
    name_lc: name.trim().toLowerCase(), // Use name_lc (not name_lowercase) based on actual schema
    clientId: '', // Will be set to document ID after migration
    organizationId: targetOrgId,
    primaryPhone: primaryPhoneNormalized ?? primaryPhone ?? '',
    primaryPhoneNormalized: primaryPhoneNormalized ?? '',
    phones: phoneEntries, // Format: [{e164: string, label: string}]
    phoneIndex: phoneIndex,
    tags: tags,
    contacts: [], // Not mapped from Pave
    status: 'active', // Default status
    stats: {
      orders: 0,
      lifetimeAmount: 0,
    },
    createdAt: data.registeredTime ?? admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

migrateClients().catch((error) => {
  console.error('Client migration failed:', error);
  process.exitCode = 1;
});
