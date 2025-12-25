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

const FALLBACK_LEGACY_ORG = 'K4Q6vPOuTcLPtlcEwdw0';
const FALLBACK_TARGET_ORG = 'unWyJiHDvYmrYNQ5G8lQ';

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

async function migrateClients() {
  const config = resolveConfig();
  const { legacy, target } = initApps(config);

  const legacyDb = legacy.firestore();
  const targetDb = target.firestore();

  const snapshot = await legacyDb
    .collection('CLIENTS')
    .where('orgID', '==', config.legacyOrgId)
    .get();

  if (snapshot.empty) {
    console.log('No legacy clients found for org', config.legacyOrgId);
    return;
  }

  let processed = 0;
  const batchSize = 400;
  let batch = targetDb.batch();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const transformed = transformClient(data, config.targetOrgId);

    const targetRef = targetDb.collection('CLIENTS').doc(doc.id);
    batch.set(targetRef, transformed, { merge: true });
    processed += 1;

    if (processed % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Committed ${processed} client docs...`);
    }
  }

  await batch.commit();
  console.log(`Migration complete. Total clients processed: ${processed}`);
}

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

function transformClient(
  data: firestore.DocumentData,
  targetOrgId: string,
): firestore.DocumentData {
  const name = (data.name as string | undefined) ?? 'Unnamed Client';
  const phoneList = (data.phoneList as string[] | undefined) ?? [];

  const normalizedPhones = phoneList
    .map((phone) => ({
      number: phone,
      normalized: normalizePhone(phone),
    }))
    .filter(
      (entry): entry is { number: string; normalized: string } =>
        Boolean(entry.normalized),
    );

  const fallbackPrimary =
    normalizedPhones.length > 0 ? normalizedPhones[0].number : undefined;
  const primaryPhone =
    (data.phoneNumber as string | undefined) ?? fallbackPrimary;

  const primaryNormalized = normalizePhone(primaryPhone);

  const tags =
    normalizedPhones.length <= 1 ? ['Individual'] : ['Distributor'];

  return {
    name,
    name_lowercase: name.toLowerCase(),
    organizationId: targetOrgId,
    primaryPhone: primaryPhone ?? primaryNormalized,
    primaryPhoneNormalized: primaryNormalized ?? primaryPhone,
    phones: normalizedPhones,
    phoneIndex: normalizedPhones.map((entry) => entry.normalized),
    contacts: [],
    tags,
    createdAt: data.registeredTime ?? admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

migrateClients().catch((error) => {
  console.error('Client migration failed:', error);
  process.exitCode = 1;
});
