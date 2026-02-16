import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface RepairConfig {
  serviceAccount: string;
  projectId?: string;
  orgId: string;
  dryRun: boolean;
  batchSize: number;
}

interface ProductRecord {
  id: string;
  name: string;
  nameLc: string;
  status?: string;
}

const TARGET_PRODUCT_NAMES = ['Bricks', 'Tukda'];

function resolvePath(value?: string): string | undefined {
  if (!value) return undefined;
  return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
}

function parseBoolean(value: any, defaultValue: boolean): boolean {
  if (value === null || value === undefined || value === '') return defaultValue;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  const normalized = String(value).trim().toLowerCase();
  if (['true', 'yes', 'y', '1'].includes(normalized)) return true;
  if (['false', 'no', 'n', '0'].includes(normalized)) return false;
  return defaultValue;
}

function normalizeName(value?: string): string {
  return (value || '').trim().toLowerCase();
}

function resolveConfig(): RepairConfig {
  const serviceAccount =
    resolvePath(process.env.SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds', 'service-account.json');

  if (!fs.existsSync(serviceAccount)) {
    throw new Error(`Service account file not found: ${serviceAccount}`);
  }

  const orgId = String(process.env.ORG_ID || '').trim();
  if (!orgId) {
    throw new Error('Missing ORG_ID');
  }

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
    orgId,
    dryRun: parseBoolean(process.env.DRY_RUN, false),
    batchSize: Math.max(50, Number(process.env.BATCH_SIZE || 500)),
  };
}

function initApp(config: RepairConfig): admin.app.App {
  const serviceAccount = JSON.parse(fs.readFileSync(config.serviceAccount, 'utf8'));
  return admin.initializeApp(
    {
      credential: admin.credential.cert(serviceAccount),
      projectId: config.projectId || serviceAccount.project_id,
    },
    'repair-product-ids',
  );
}

function chooseProductByName(
  existing: ProductRecord | undefined,
  candidate: ProductRecord,
): ProductRecord {
  if (!existing) return candidate;
  const existingActive = existing.status === 'active';
  const candidateActive = candidate.status === 'active';
  if (!existingActive && candidateActive) return candidate;
  return existing;
}

async function loadProducts(
  db: FirebaseFirestore.Firestore,
  orgId: string,
): Promise<{
  byId: Map<string, ProductRecord>;
  byName: Map<string, ProductRecord>;
  targetByName: Map<string, ProductRecord>;
}> {
  const productsRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('PRODUCTS');

  const snapshot = await productsRef.get();
  const byId = new Map<string, ProductRecord>();
  const byName = new Map<string, ProductRecord>();
  const targetByName = new Map<string, ProductRecord>();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const name = String(data.name || data.productName || doc.id).trim();
    const nameLc = String(data.name_lc || normalizeName(name));
    const status = data.status ? String(data.status) : undefined;
    const record: ProductRecord = {
      id: doc.id,
      name: name || doc.id,
      nameLc,
      status,
    };
    byId.set(doc.id, record);

    if (record.nameLc) {
      const existing = byName.get(record.nameLc);
      byName.set(record.nameLc, chooseProductByName(existing, record));
    }
  }

  for (const targetName of TARGET_PRODUCT_NAMES) {
    const nameLc = normalizeName(targetName);
    const match = byName.get(nameLc);
    if (!match) {
      throw new Error(`Target product not found in PRODUCTS: ${targetName}`);
    }
    targetByName.set(nameLc, match);
  }

  return { byId, byName, targetByName };
}

function resolveTargetReplacement(
  productId: string | undefined,
  productName: string | undefined,
  productsById: Map<string, ProductRecord>,
  targetByName: Map<string, ProductRecord>,
): ProductRecord | null {
  const nameLc = normalizeName(productName);
  if (nameLc) {
    const directTarget = targetByName.get(nameLc);
    if (directTarget) return directTarget;
  }

  if (productId) {
    const existing = productsById.get(productId);
    if (existing && targetByName.has(existing.nameLc)) {
      return targetByName.get(existing.nameLc) ?? null;
    }
  }

  return null;
}

async function commitBatch(batch: FirebaseFirestore.WriteBatch, writes: number) {
  if (writes === 0) return;
  await batch.commit();
}

async function repairPendingOrders(
  db: FirebaseFirestore.Firestore,
  config: RepairConfig,
  productsById: Map<string, ProductRecord>,
  targetByName: Map<string, ProductRecord>,
) {
  console.log('\n=== Repairing PENDING_ORDERS ===');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let updated = 0;
  let unmatchedItems = 0;

  while (true) {
    let query = db
      .collection('PENDING_ORDERS')
      .where('organizationId', '==', config.orgId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    let batch = db.batch();
    let writes = 0;

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const items = Array.isArray(data.items) ? data.items : [];
      let changed = false;

      const newItems = items.map((item: any) => {
        if (!item || typeof item !== 'object') return item;
        const currentProductId = item.productId ? String(item.productId) : undefined;
        const currentProductName =
          item.productName ? String(item.productName) : item.name ? String(item.name) : undefined;

        const match = resolveTargetReplacement(
          currentProductId,
          currentProductName,
          productsById,
          targetByName,
        );

        if (!match) {
          unmatchedItems += 1;
          return item;
        }

        const nextItem = { ...item };
        if (currentProductId !== match.id) {
          nextItem.productId = match.id;
          changed = true;
        }
        if (!currentProductName || currentProductName.trim() !== match.name) {
          nextItem.productName = match.name;
          changed = true;
        }
        return nextItem;
      });

      if (changed) {
        updated += 1;
        if (!config.dryRun) {
          batch.update(doc.ref, {
            items: newItems,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          writes += 1;
        }
      }

      if (writes >= 400) {
        await commitBatch(batch, writes);
        batch = db.batch();
        writes = 0;
      }
    }

    await commitBatch(batch, writes);
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed ${processed} orders so far; updated: ${updated}`);
  }

  console.log(`PENDING_ORDERS complete. Updated: ${updated}, unmatched items: ${unmatchedItems}`);
  if (config.dryRun) {
    console.log('(Dry run: no writes performed)');
  }
}

async function repairScheduleTrips(
  db: FirebaseFirestore.Firestore,
  config: RepairConfig,
  productsById: Map<string, ProductRecord>,
  targetByName: Map<string, ProductRecord>,
) {
  console.log('\n=== Repairing SCHEDULE_TRIPS ===');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let updated = 0;
  let unmatchedTrips = 0;

  while (true) {
    let query = db
      .collection('SCHEDULE_TRIPS')
      .where('organizationId', '==', config.orgId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    let batch = db.batch();
    let writes = 0;

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const items = Array.isArray(data.items) ? data.items : [];
      let changed = false;
      let matchedProduct: ProductRecord | null = null;

      const newItems = items.map((item: any) => {
        if (!item || typeof item !== 'object') return item;
        const currentProductId = item.productId ? String(item.productId) : undefined;
        const currentProductName =
          item.productName ? String(item.productName) : item.name ? String(item.name) : undefined;

        const match = resolveTargetReplacement(
          currentProductId,
          currentProductName,
          productsById,
          targetByName,
        );

        if (!match) return item;
        matchedProduct = match;

        const nextItem = { ...item };
        if (currentProductId !== match.id) {
          nextItem.productId = match.id;
          changed = true;
        }
        if (!currentProductName || currentProductName.trim() !== match.name) {
          nextItem.productName = match.name;
          changed = true;
        }
        return nextItem;
      });

      const rootProductId = data.productId ? String(data.productId) : undefined;
      const rootProductName = items[0]?.productName ? String(items[0]?.productName) : undefined;
      const rootMatch = matchedProduct ||
        resolveTargetReplacement(rootProductId, rootProductName, productsById, targetByName);

      if (!rootMatch) {
        unmatchedTrips += 1;
      } else if (rootProductId !== rootMatch.id) {
        changed = true;
      }

      if (changed) {
        updated += 1;
        if (!config.dryRun) {
          const updatePayload: Record<string, any> = {
            items: newItems,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          if (rootMatch) {
            updatePayload.productId = rootMatch.id;
          }
          batch.update(doc.ref, updatePayload);
          writes += 1;
        }
      }

      if (writes >= 400) {
        await commitBatch(batch, writes);
        batch = db.batch();
        writes = 0;
      }
    }

    await commitBatch(batch, writes);
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed ${processed} trips so far; updated: ${updated}`);
  }

  console.log(`SCHEDULE_TRIPS complete. Updated: ${updated}, unmatched trips: ${unmatchedTrips}`);
  if (config.dryRun) {
    console.log('(Dry run: no writes performed)');
  }
}

async function repairDeliveryMemos(
  db: FirebaseFirestore.Firestore,
  config: RepairConfig,
  productsById: Map<string, ProductRecord>,
  targetByName: Map<string, ProductRecord>,
) {
  console.log('\n=== Repairing DELIVERY_MEMOS ===');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let updated = 0;
  let unmatchedItems = 0;

  while (true) {
    let query = db
      .collection('DELIVERY_MEMOS')
      .where('organizationId', '==', config.orgId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    let batch = db.batch();
    let writes = 0;

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const items = Array.isArray(data.items) ? data.items : [];
      let changed = false;

      const newItems = items.map((item: any) => {
        if (!item || typeof item !== 'object') return item;
        const currentProductId = item.productId ? String(item.productId) : undefined;
        const currentProductName =
          item.productName ? String(item.productName) : item.name ? String(item.name) : undefined;

        const match = resolveTargetReplacement(
          currentProductId,
          currentProductName,
          productsById,
          targetByName,
        );

        if (!match) {
          unmatchedItems += 1;
          return item;
        }

        const nextItem = { ...item };
        if (currentProductId !== match.id) {
          nextItem.productId = match.id;
          changed = true;
        }
        if (!currentProductName || currentProductName.trim() !== match.name) {
          nextItem.productName = match.name;
          changed = true;
        }
        return nextItem;
      });

      if (changed) {
        updated += 1;
        if (!config.dryRun) {
          batch.update(doc.ref, {
            items: newItems,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          writes += 1;
        }
      }

      if (writes >= 400) {
        await commitBatch(batch, writes);
        batch = db.batch();
        writes = 0;
      }
    }

    await commitBatch(batch, writes);
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed ${processed} memos so far; updated: ${updated}`);
  }

  console.log(`DELIVERY_MEMOS complete. Updated: ${updated}, unmatched items: ${unmatchedItems}`);
  if (config.dryRun) {
    console.log('(Dry run: no writes performed)');
  }
}

async function repairDeliveryZones(
  db: FirebaseFirestore.Firestore,
  config: RepairConfig,
  productsById: Map<string, ProductRecord>,
  targetByName: Map<string, ProductRecord>,
) {
  console.log('\n=== Repairing DELIVERY_ZONES ===');
  const zonesRef = db
    .collection('ORGANIZATIONS')
    .doc(config.orgId)
    .collection('DELIVERY_ZONES');

  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let updated = 0;
  let removedLegacy = 0;
  let remapped = 0;

  while (true) {
    let query = zonesRef
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    let batch = db.batch();
    let writes = 0;

    for (const doc of snapshot.docs) {
      processed += 1;
      const data = doc.data();
      const prices = data.prices && typeof data.prices === 'object' ? data.prices : {};
      const newPrices: Record<string, any> = {};
      let changed = false;

      for (const [legacyProductId, entry] of Object.entries(prices)) {
        const priceEntry = entry as Record<string, any>;
        const entryName = priceEntry.product_name
          ? String(priceEntry.product_name)
          : priceEntry.productName
            ? String(priceEntry.productName)
            : undefined;

        const match = resolveTargetReplacement(
          legacyProductId,
          entryName,
          productsById,
          targetByName,
        );

        if (!match) {
          removedLegacy += 1;
          changed = true;
          continue;
        }

        if (match.id !== legacyProductId) {
          remapped += 1;
          changed = true;
        }

        const nextEntry = { ...priceEntry };
        if (!entryName || entryName.trim() !== match.name) {
          nextEntry.product_name = match.name;
          changed = true;
        }

        if (!newPrices[match.id]) {
          newPrices[match.id] = nextEntry;
        }
      }

      const pricesChanged = JSON.stringify(prices) !== JSON.stringify(newPrices);
      if (pricesChanged || changed) {
        updated += 1;
        if (!config.dryRun) {
          batch.update(doc.ref, {
            prices: newPrices,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          writes += 1;
        }
      }

      if (writes >= 400) {
        await commitBatch(batch, writes);
        batch = db.batch();
        writes = 0;
      }
    }

    await commitBatch(batch, writes);
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed ${processed} zones so far; updated: ${updated}`);
  }

  console.log(
    `DELIVERY_ZONES complete. Updated: ${updated}, remapped entries: ${remapped}, removed legacy: ${removedLegacy}`,
  );
  if (config.dryRun) {
    console.log('(Dry run: no writes performed)');
  }
}

async function run(): Promise<void> {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();
  db.settings({ ignoreUndefinedProperties: true });

  console.log('=== Product ID Repair Script ===');
  console.log(`Org ID: ${config.orgId}`);
  console.log(`Dry Run: ${config.dryRun ? 'yes' : 'no'}`);
  console.log(`Batch Size: ${config.batchSize}`);

  const { byId, targetByName } = await loadProducts(db, config.orgId);
  console.log(`Loaded products: ${byId.size}`);
  console.log('Target products:');
  for (const targetName of TARGET_PRODUCT_NAMES) {
    const record = targetByName.get(normalizeName(targetName));
    if (record) {
      console.log(`- ${record.name}: ${record.id}`);
    }
  }

  await repairScheduleTrips(db, config, byId, targetByName);
  await repairDeliveryMemos(db, config, byId, targetByName);
  await repairPendingOrders(db, config, byId, targetByName);
  await repairDeliveryZones(db, config, byId, targetByName);

  console.log('\n=== Repair Complete ===');
}

run().catch((error) => {
  console.error('[repair-product-ids] Failed:', error);
  process.exit(1);
});
