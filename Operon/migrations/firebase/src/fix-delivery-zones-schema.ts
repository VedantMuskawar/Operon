import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface FixConfig {
  serviceAccount: string;
  projectId?: string;
  orgId?: string;
  dryRun: boolean;
  batchSize: number;
}

interface PriceNormalizeResult {
  entry: Record<string, any>;
  changed: boolean;
}

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

function resolveConfig(): FixConfig {
  const serviceAccount =
    resolvePath(process.env.SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds', 'service-account.json');

  if (!fs.existsSync(serviceAccount)) {
    throw new Error(`Service account file not found: ${serviceAccount}`);
  }

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
    orgId: process.env.ORG_ID ? String(process.env.ORG_ID).trim() : undefined,
    dryRun: parseBoolean(process.env.DRY_RUN, true),
    batchSize: Math.max(50, Number(process.env.BATCH_SIZE || 500)),
  };
}

function initApp(config: FixConfig): admin.app.App {
  const serviceAccount = JSON.parse(fs.readFileSync(config.serviceAccount, 'utf8'));
  return admin.initializeApp(
    {
      credential: admin.credential.cert(serviceAccount),
      projectId: config.projectId || serviceAccount.project_id,
    },
    'fix-delivery-zones-schema',
  );
}

function normalizePriceEntry(entry: Record<string, any>): PriceNormalizeResult {
  let changed = false;
  const normalized: Record<string, any> = { ...entry };

  if (normalized.unit_price === undefined && normalized.unitPrice !== undefined) {
    normalized.unit_price = normalized.unitPrice;
    delete normalized.unitPrice;
    changed = true;
  }

  if (normalized.product_name === undefined && normalized.productName !== undefined) {
    normalized.product_name = normalized.productName;
    delete normalized.productName;
    changed = true;
  }

  if (normalized.deliverable === undefined && entry.deliverable !== undefined) {
    normalized.deliverable = entry.deliverable;
  }

  return { entry: normalized, changed };
}

function normalizePrices(pricesRaw: any): { prices: Record<string, any>; changed: boolean } {
  let changed = false;
  const prices: Record<string, any> = {};

  if (Array.isArray(pricesRaw)) {
    for (const item of pricesRaw) {
      if (!item || typeof item !== 'object') continue;
      const productId =
        item.product_id ? String(item.product_id) : item.productId ? String(item.productId) : undefined;
      if (!productId) continue;
      const normalized = normalizePriceEntry(item);
      prices[productId] = normalized.entry;
      if (normalized.changed) changed = true;
    }
    if (pricesRaw.length > 0) changed = true;
    return { prices, changed };
  }

  if (pricesRaw && typeof pricesRaw === 'object') {
    for (const [key, value] of Object.entries(pricesRaw)) {
      if (!value || typeof value !== 'object') continue;
      const normalized = normalizePriceEntry(value as Record<string, any>);
      prices[key] = normalized.entry;
      if (normalized.changed) changed = true;
    }
    return { prices, changed };
  }

  return { prices: {}, changed: false };
}

async function commitBatch(batch: FirebaseFirestore.WriteBatch, writes: number) {
  if (writes === 0) return;
  await batch.commit();
}

async function fixZonesForOrg(
  db: FirebaseFirestore.Firestore,
  orgId: string,
  config: FixConfig,
) {
  console.log(`\n=== Fixing DELIVERY_ZONES for org: ${orgId} ===`);
  const zonesRef = db.collection('ORGANIZATIONS').doc(orgId).collection('DELIVERY_ZONES');

  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let updated = 0;
  let pricesFixed = 0;

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
      const updates: Record<string, any> = {};

      if (!data.organization_id && data.organizationId) {
        updates.organization_id = data.organizationId;
      } else if (!data.organization_id) {
        updates.organization_id = orgId;
      }

      if (!data.city_id && data.cityId) updates.city_id = data.cityId;
      if (!data.city_name && (data.cityName || data.city)) {
        updates.city_name = data.cityName || data.city;
      }
      if (!data.region && (data.region_name || data.regionName)) {
        updates.region = data.region_name || data.regionName;
      }
      if (data.is_active === undefined && data.isActive !== undefined) {
        updates.is_active = data.isActive;
      }
      if (data.roundtrip_km === undefined && data.roundtripKm !== undefined) {
        updates.roundtrip_km = data.roundtripKm;
      }

      const pricesRaw = data.prices;
      const normalizedPrices = normalizePrices(pricesRaw);
      if (normalizedPrices.changed) {
        updates.prices = normalizedPrices.prices;
        pricesFixed += 1;
      }

      if (Object.keys(updates).length > 0) {
        updated += 1;
        if (!config.dryRun) {
          updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
          batch.update(doc.ref, updates);
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
    `DELIVERY_ZONES org ${orgId} complete. Updated: ${updated}, prices normalized: ${pricesFixed}`,
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

  console.log('=== Fix Delivery Zones Schema ===');
  console.log(`Dry Run: ${config.dryRun ? 'yes' : 'no'}`);
  console.log(`Batch Size: ${config.batchSize}`);

  let orgIds: string[] = [];
  if (config.orgId) {
    orgIds = [config.orgId];
  } else {
    const snapshot = await db.collection('ORGANIZATIONS').get();
    orgIds = snapshot.docs.map((doc) => doc.id);
  }

  if (orgIds.length === 0) {
    console.log('No organizations found.');
    return;
  }

  for (const orgId of orgIds) {
    await fixZonesForOrg(db, orgId, config);
  }

  console.log('\n=== Delivery Zones Schema Fix Complete ===');
}

run().catch((error) => {
  console.error('[fix-delivery-zones-schema] Failed:', error);
  process.exit(1);
});
