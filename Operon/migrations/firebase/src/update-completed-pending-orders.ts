/**
 * Update or delete fully completed PENDING_ORDERS so they don't appear in the UI.
 *
 * The UI shows an order only when:
 *   (status == null || status == 'pending') && hasAvailableTrips
 * where hasAvailableTrips = at least one item has estimatedTrips > scheduledTrips.
 *
 * This script finds orders that have no available trips (all items have
 * estimatedTrips <= scheduledTrips) and either:
 *   --update (default): Sets status to 'completed' so they are hidden from the UI.
 *   --delete: Deletes the document; Cloud Function onOrderDeleted will run
 *             (cleans up transactions, marks trips with orderDeleted).
 *
 * Usage:
 *   npx ts-node src/update-completed-pending-orders.ts [--dry-run] [--update|--delete]
 *   npm run update-completed-pending-orders -- [--dry-run] [--update|--delete]
 *
 * Requires: Credentials for TARGET (Operon) project only. Default:
 *           creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json
 *           Or set TARGET_SERVICE_ACCOUNT.
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

const PENDING_ORDERS_COLLECTION = 'PENDING_ORDERS';
const BATCH_SIZE = 100;

interface Config {
  targetServiceAccount: string;
  targetProjectId?: string;
  dryRun: boolean;
  mode: 'update' | 'delete';
}

function resolveConfig(): Config {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const targetServiceAccount =
    resolvePath(process.env.TARGET_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds', 'operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json');

  if (!fs.existsSync(targetServiceAccount)) {
    throw new Error(
      `Target project service account file not found: ${targetServiceAccount}\n\n` +
        'Place your TARGET (Operon) service account at creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json\n' +
        'Or set TARGET_SERVICE_ACCOUNT environment variable with full path.',
    );
  }

  const argv = process.argv.slice(2);
  const dryRun = argv.includes('--dry-run');
  const deleteFlag = argv.includes('--delete');
  const updateFlag = argv.includes('--update');
  let mode: 'update' | 'delete' = 'update';
  if (deleteFlag && !updateFlag) mode = 'delete';
  if (updateFlag && !deleteFlag) mode = 'update';

  return {
    targetServiceAccount,
    targetProjectId: process.env.TARGET_PROJECT_ID,
    dryRun,
    mode,
  };
}

function readServiceAccount(pathname: string): admin.ServiceAccount {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

/**
 * Returns true if the order has at least one item with estimatedTrips > scheduledTrips
 * (i.e. it would be shown in the Pending Orders UI).
 */
function hasAvailableTrips(data: admin.firestore.DocumentData): boolean {
  const items = (data.items as any[]) ?? [];
  for (const item of items) {
    const estimatedTrips = (item?.estimatedTrips as number) ?? 0;
    const scheduledTrips = (item?.scheduledTrips as number) ?? 0;
    if (estimatedTrips > scheduledTrips) return true;
  }
  return false;
}

/**
 * Returns true if the order is considered "fully completed" (no trips left to schedule),
 * so it should be hidden from the UI.
 */
function isFullyCompleted(data: admin.firestore.DocumentData): boolean {
  return !hasAvailableTrips(data);
}

function initTargetApp(config: Config): admin.app.App {
  const serviceAccount = readServiceAccount(config.targetServiceAccount);
  return admin.initializeApp(
    {
      credential: admin.credential.cert(serviceAccount),
      projectId: config.targetProjectId ?? serviceAccount.project_id,
    },
    'target',
  );
}

async function main() {
  const config = resolveConfig();

  let app: admin.app.App;
  try {
    app = admin.app('target');
  } catch {
    app = initTargetApp(config);
  }
  const db = app.firestore();
  const ordersRef = db.collection(PENDING_ORDERS_COLLECTION);

  const projectId = db.projectId;
  console.log('[update-completed-pending-orders] Target service account:', config.targetServiceAccount);
  console.log('[update-completed-pending-orders] Config:', {
    projectId,
    dryRun: config.dryRun,
    mode: config.mode,
  });
  console.log('[update-completed-pending-orders] Updating TARGET database only:', projectId);

  let totalProcessed = 0;
  let totalFullyCompleted = 0;
  let totalUpdatedOrDeleted = 0;
  let lastDoc: admin.firestore.DocumentSnapshot | null = null;

  // Process in batches (no single query for "all orders" with a filter we can't express in Firestore)
  while (true) {
    let query = ordersRef.orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
    if (lastDoc) {
      query = query.startAfter(lastDoc) as any;
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      totalProcessed++;
      const data = doc.data();
      if (!isFullyCompleted(data)) continue;

      totalFullyCompleted++;
      const orderId = doc.id;
      const status = (data.status as string) ?? '(none)';
      const orgId = (data.organizationId as string) ?? '';

      if (config.dryRun) {
        console.log(`  [dry-run] Would ${config.mode}: ${orderId} (org: ${orgId}, status: ${status})`);
        totalUpdatedOrDeleted++;
        continue;
      }

      try {
        if (config.mode === 'update') {
          await doc.ref.update({
            status: 'completed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`  Updated ${orderId} -> status: completed`);
        } else {
          await doc.ref.delete();
          console.log(`  Deleted ${orderId} (onOrderDeleted will run)`);
        }
        totalUpdatedOrDeleted++;
      } catch (err) {
        console.error(`  Failed to ${config.mode} ${orderId}:`, err);
      }
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.docs.length < BATCH_SIZE) break;
  }

  console.log('[update-completed-pending-orders] Done:', {
    totalProcessed,
    totalFullyCompleted,
    totalUpdatedOrDeleted,
    dryRun: config.dryRun,
    mode: config.mode,
  });

  if (totalProcessed === 0) {
    console.log(
      '[update-completed-pending-orders] No orders found. Check: (1) creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json is your TARGET (Operon) project. (2) PENDING_ORDERS exists and has documents there.',
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
