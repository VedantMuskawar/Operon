import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface CleanupConfig {
  serviceAccount: string;
  projectId?: string;
  targetOrgId: string;
  cutoffIso: string;
}

const FALLBACK_TARGET_ORG = 'unWyJiHDvYmrYNQ5G8lQ';
// FY 2024-2025 start: 1 April 2024 (midnight UTC)
const DEFAULT_CUTOFF_ISO = '2024-04-01T00:00:00.000Z';

function resolveConfig(): CleanupConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const serviceAccount =
    resolvePath(process.env.NEW_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/new-service-account.json');

  if (!fs.existsSync(serviceAccount)) {
    throw new Error(
      `New project service account not found at ${serviceAccount}.\n` +
        'Download the JSON for the NEW Firebase project and set NEW_SERVICE_ACCOUNT or place it at creds/new-service-account.json.',
    );
  }

  return {
    serviceAccount,
    projectId: process.env.NEW_PROJECT_ID,
    targetOrgId: process.env.NEW_ORG_ID ?? FALLBACK_TARGET_ORG,
    cutoffIso: process.env.CUTOFF_ISO ?? DEFAULT_CUTOFF_ISO,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

async function deleteOldClients() {
  const config = resolveConfig();

  const app = admin.initializeApp(
    {
      credential: admin.credential.cert(readServiceAccount(config.serviceAccount)),
      projectId: config.projectId,
    },
    'cleanup-target',
  );

  const db = app.firestore();
  const cutoff = new Date(config.cutoffIso);

  console.log(
    `Deleting clients in org ${config.targetOrgId} with createdAt < ${cutoff.toISOString()}`,
  );

  const query = db
    .collection('CLIENTS')
    .where('organizationId', '==', config.targetOrgId)
    .where('createdAt', '<', cutoff);

  const snapshot = await query.get();
  if (snapshot.empty) {
    console.log('No old clients found to delete.');
    return;
  }

  console.log(`Found ${snapshot.size} old client docs. Deleting in batches...`);

  const batchSize = 400;
  let processed = 0;
  let batch = db.batch();

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    processed += 1;

    if (processed % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`Deleted ${processed} client docs so far...`);
    }
  }

  await batch.commit();
  console.log(`Cleanup complete. Total clients deleted: ${processed}`);
}

deleteOldClients().catch((error) => {
  console.error('Client cleanup failed:', error);
  process.exitCode = 1;
});


