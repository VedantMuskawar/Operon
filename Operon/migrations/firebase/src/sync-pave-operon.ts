import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface SyncConfig {
  legacyServiceAccount: string;
  targetServiceAccount: string;
  legacyProjectId?: string;
  targetProjectId?: string;
  legacyOrgId: string;
  targetOrgId: string;
  dryRun: boolean;
  updateMode: 'skip' | 'merge' | 'replace';
  batchSize: number;
  skipClients: boolean;
  skipOrders: boolean;
}

interface SyncStats {
  createdCities: number;
  createdZones: number;
}

type ClientDocument = Record<string, any>;

type PendingOrderDocument = Record<string, any>;

// Product name mapping: legacy name -> target name
const PRODUCT_NAME_MAPPING: Record<string, string> = {
  'BRICKS': 'Bricks',
  'TUKDA': 'Tukda',
};

const LEGACY_APP_NAME = 'pave-legacy-sync';
const TARGET_APP_NAME = 'operon-target-sync';

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

function resolveUpdateMode(value?: string): 'skip' | 'merge' | 'replace' {
  const normalized = (value || 'merge').toLowerCase();
  if (normalized === 'skip' || normalized === 'merge' || normalized === 'replace') {
    return normalized;
  }
  return 'merge';
}

function readServiceAccount(pathname: string): admin.ServiceAccount {
  return JSON.parse(fs.readFileSync(pathname, 'utf8')) as admin.ServiceAccount;
}

function resolveConfig(): SyncConfig {
  const legacyServiceAccount =
    resolvePath(process.env.LEGACY_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds', 'legacy-service-account.json');
  const targetServiceAccount =
    resolvePath(process.env.TARGET_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds', 'new-service-account.json');

  if (!fs.existsSync(legacyServiceAccount)) {
    throw new Error(`Legacy service account file not found: ${legacyServiceAccount}`);
  }
  if (!fs.existsSync(targetServiceAccount)) {
    throw new Error(`Target service account file not found: ${targetServiceAccount}`);
  }

  const legacyOrgId = String(process.env.LEGACY_ORG_ID || '').trim();
  const targetOrgId = String(process.env.TARGET_ORG_ID || '').trim();
  if (!legacyOrgId) throw new Error('Missing LEGACY_ORG_ID');
  if (!targetOrgId) throw new Error('Missing TARGET_ORG_ID');

  return {
    legacyServiceAccount,
    targetServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    targetProjectId: process.env.TARGET_PROJECT_ID,
    legacyOrgId,
    targetOrgId,
    dryRun: parseBoolean(process.env.DRY_RUN, false),
    updateMode: resolveUpdateMode(process.env.UPDATE_MODE),
    batchSize: Math.max(50, Number(process.env.BATCH_SIZE || 500)),
    skipClients: parseBoolean(process.env.SKIP_CLIENTS, false),
    skipOrders: parseBoolean(process.env.SKIP_ORDERS, false),
  };
}

function initApps(config: SyncConfig) {
  const legacyCred = readServiceAccount(config.legacyServiceAccount);
  const targetCred = readServiceAccount(config.targetServiceAccount);

  const legacyApp = admin.initializeApp(
    {
      credential: admin.credential.cert(legacyCred),
      projectId: config.legacyProjectId || (legacyCred as any).project_id,
    },
    LEGACY_APP_NAME,
  );

  const targetApp = admin.initializeApp(
    {
      credential: admin.credential.cert(targetCred),
      projectId: config.targetProjectId || (targetCred as any).project_id,
    },
    TARGET_APP_NAME,
  );

  return {
    legacyDb: legacyApp.firestore(),
    targetDb: targetApp.firestore(),
  };
}

function normalizePhone(input?: string): string {
  if (!input) return '';
  return input.replace(/[^0-9+]/g, '');
}

function normalizeName(name?: string): string {
  return (name || '').trim().toLowerCase();
}

function titleCase(value?: string): string {
  if (!value) return '';
  return value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map((word) => (word ? word[0].toUpperCase() + word.slice(1) : ''))
    .join(' ')
    .trim();
}

function slugify(value?: string): string {
  return (value || 'product')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '') || 'product';
}

function pickTimestamp(value: any): admin.firestore.Timestamp | admin.firestore.FieldValue {
  if (!value) return admin.firestore.FieldValue.serverTimestamp();
  if (value instanceof admin.firestore.Timestamp) return value;
  if (value.toDate) {
    return admin.firestore.Timestamp.fromDate(value.toDate());
  }
  const parsed = Date.parse(String(value));
  if (Number.isNaN(parsed)) return admin.firestore.FieldValue.serverTimestamp();
  return admin.firestore.Timestamp.fromDate(new Date(parsed));
}

async function resolveTargetClientId(
  legacyClientId: string,
  targetDb: FirebaseFirestore.Firestore,
): Promise<string> {
  const mapRef = targetDb.collection('CLIENT_ID_MAP').doc(legacyClientId);
  const mapSnap = await mapRef.get();
  const mappedId = mapSnap.exists
    ? (mapSnap.data()?.operonClientId || mapSnap.data()?.clientId || mapSnap.data()?.targetClientId)
    : undefined;

  if (mappedId) return String(mappedId);

  const newClientRef = targetDb.collection('CLIENTS').doc();
  await mapRef.set(
    {
      legacyClientId,
      operonClientId: newClientRef.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return newClientRef.id;
}

async function getExistingTargetClientId(
  legacyClientId: string,
  targetDb: FirebaseFirestore.Firestore,
): Promise<string | null> {
  const mapRef = targetDb.collection('CLIENT_ID_MAP').doc(legacyClientId);
  const mapSnap = await mapRef.get();
  if (!mapSnap.exists) return null;
  const mappedId = mapSnap.data()?.operonClientId || mapSnap.data()?.clientId || mapSnap.data()?.targetClientId;
  return mappedId ? String(mappedId) : null;
}

async function ensureProduct(
  targetDb: FirebaseFirestore.Firestore,
  organizationId: string,
  productName: string,
): Promise<{ productId: string; productName: string } | null> {
  const normalizedName = productName.trim() || 'Product';
  const productsRef = targetDb
    .collection('ORGANIZATIONS')
    .doc(organizationId)
    .collection('PRODUCTS');
  const nameLc = normalizeName(normalizedName);

  // First try to find by name_lc field (for products that have it)
  const nameMatch = await productsRef.where('name_lc', '==', nameLc).limit(1).get();
  if (!nameMatch.empty) {
    const existingDoc = nameMatch.docs[0];
    return {
      productId: existingDoc.id,
      productName: String(existingDoc.data().name || normalizedName),
    };
  }

  // If not found by name_lc, fetch all products and match by name (case-insensitive)
  const allProducts = await productsRef.get();
  for (const doc of allProducts.docs) {
    const docName = String(doc.data().name || '').trim();
    if (docName.toLowerCase() === nameLc) {
      return {
        productId: doc.id,
        productName: docName,
      };
    }
  }

  // Product not found
  return null;
}

async function ensureDeliveryZone(
  targetDb: FirebaseFirestore.Firestore,
  organizationId: string,
  cityName: string,
  regionName: string,
  product: { productId: string; productName: string },
  unitPrice: number,
  stats: SyncStats,
): Promise<{ cityId: string; zoneId: string; cityName: string; regionName: string } | null> {
  if (!cityName || !regionName) return null;

  const citiesRef = targetDb
    .collection('ORGANIZATIONS')
    .doc(organizationId)
    .collection('DELIVERY_CITIES');
  const zonesRef = targetDb
    .collection('ORGANIZATIONS')
    .doc(organizationId)
    .collection('DELIVERY_ZONES');

  const cityNameLc = normalizeName(cityName);
  let citySnapshot = await citiesRef.where('name', '==', cityName).limit(1).get();
  if (citySnapshot.empty) {
    citySnapshot = await citiesRef.where('name_lc', '==', cityNameLc).limit(1).get();
  }
  let cityId = citySnapshot.empty ? null : citySnapshot.docs[0].id;

  if (!cityId) {
    const newCityRef = citiesRef.doc();
    await newCityRef.set({
      name: cityName,
      name_lc: cityNameLc,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    cityId = newCityRef.id;
    stats.createdCities += 1;
  }

  const zoneKey = `${cityId}::${regionName.toLowerCase()}`;
  const zoneSnapshot = await zonesRef.where('key', '==', zoneKey).limit(1).get();
  let zoneId = zoneSnapshot.empty ? null : zoneSnapshot.docs[0].id;

  if (!zoneId) {
    const newZoneRef = zonesRef.doc();
    await newZoneRef.set({
      key: zoneKey,
      city_id: cityId,
      region: regionName,
      region_name: regionName,
      prices: {
        [product.productId]: {
          deliverable: true,
          product_name: product.productName,
          unit_price: unitPrice,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    zoneId = newZoneRef.id;
    stats.createdZones += 1;
  } else {
    const zoneRef = zonesRef.doc(zoneId);
    const zoneDoc = await zoneRef.get();
    const prices = (zoneDoc.data()?.prices || {}) as Record<string, any>;
    if (!prices[product.productId]) {
      await zoneRef.set(
        {
          prices: {
            [product.productId]: {
              deliverable: true,
              product_name: product.productName,
              unit_price: unitPrice,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
          },
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  }

  return { cityId, zoneId, cityName, regionName };
}

function buildClientPayload(data: ClientDocument, targetClientId: string, config: SyncConfig) {
  const phoneList = Array.isArray(data.phoneList) ? data.phoneList : [];
  const primaryPhone = normalizePhone(data.phoneNumber || phoneList[0]);
  const phoneIndex = [primaryPhone, ...phoneList.map((phone: any) => normalizePhone(phone))]
    .filter((phone) => phone)
    .filter((phone, index, arr) => arr.indexOf(phone) === index);

  const phones = phoneIndex.map((phone, index) => ({
    e164: phone,
    label: index === 0 ? 'main' : `phone_${index + 1}`,
  }));

  return {
    clientId: targetClientId,
    name: String(data.name || '').trim(),
    name_lc: normalizeName(data.name),
    organizationId: config.targetOrgId,
    phones,
    phoneIndex,
    primaryPhone,
    primaryPhoneNormalized: primaryPhone,
    createdAt: pickTimestamp(data.registeredTime || data.createdAt),
    currentBalance: Number(data.totalBalance ?? 0),
    stats: {
      lifetimeAmount: Number(data.totalRevenue ?? 0),
      orders: Number(data.totalOrders ?? 0),
    },
    status: 'active',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    syncMetadata: {
      source: 'pave',
      legacyClientId: data.id || undefined,
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

function buildPendingOrderPayload(
  data: PendingOrderDocument,
  orderId: string,
  targetClientId: string,
  config: SyncConfig,
  resolved: {
    zoneId?: string;
    cityName?: string;
    regionName?: string;
    productId: string;
    productName: string;
  },
) {
  const orderCount = Math.max(1, Math.floor(Number(data.orderCount ?? 0)) || 1);
  const fixedQuantityPerTrip = Number(data.productQuant ?? 0) || 0;
  const unitPrice = Number(data.productUnitPrice ?? 0) || 0;
  const subtotal = fixedQuantityPerTrip * unitPrice * orderCount;

  return {
    orderId,
    orderKey: data.orderId || data.id || orderId,
    organizationId: config.targetOrgId,
    clientId: targetClientId,
    clientName: String(data.clientName || '').trim(),
    clientPhone: normalizePhone(data.clientPhoneNumber || data.clientPhone || ''),
    name_lc: normalizeName(data.clientName),
    priority: 'normal',
    status: 'pending',
    createdBy: 'migration-script',
    createdAt: pickTimestamp(data.createdTime),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    advanceAmount: Number(data.advanceAmount ?? 0),
    deliveryZone: {
      city_name: resolved.cityName,
      region_name: resolved.regionName,
      region: resolved.regionName,
      zone_id: resolved.zoneId,
    },
    items: [
      {
        itemIndex: 0,
        productId: resolved.productId,
        productName: resolved.productName,
        estimatedTrips: orderCount,
        scheduledTrips: 0,
        fixedQuantityPerTrip,
        unitPrice,
        subtotal,
        total: subtotal,
      },
    ],
    tripIds: [],
    totalScheduledTrips: 0,
    pricing: {
      subtotal,
      totalAmount: subtotal,
    },
    hasAvailableTrips: orderCount > 0,
    syncMetadata: {
      source: 'pave',
      legacyOrderId: data.id || undefined,
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

async function upsertDoc(
  docRef: FirebaseFirestore.DocumentReference,
  payload: Record<string, unknown>,
  updateMode: SyncConfig['updateMode'],
  dryRun: boolean,
): Promise<void> {
  if (dryRun) return;

  if (updateMode === 'replace') {
    await docRef.set(payload);
    return;
  }

  if (updateMode === 'merge') {
    await docRef.set(payload, { merge: true });
    return;
  }

  const existing = await docRef.get();
  if (!existing.exists) {
    await docRef.set(payload);
  }
}

async function processClients(config: SyncConfig, legacyDb: FirebaseFirestore.Firestore, targetDb: FirebaseFirestore.Firestore) {
  console.log('=== Syncing Legacy CLIENTS ===');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let skippedExisting = 0;
  const samplePayloads: Array<Record<string, unknown>> = [];

  while (true) {
    let query = legacyDb
      .collection('CLIENTS')
      .where('orgID', '==', config.legacyOrgId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const existingTargetId = await getExistingTargetClientId(doc.id, targetDb);
      if (existingTargetId) {
        skippedExisting += 1;
        continue;
      }

      const targetClientId = await resolveTargetClientId(doc.id, targetDb);
      const payload = buildClientPayload({ ...data, id: doc.id }, targetClientId, config);
      const targetRef = targetDb.collection('CLIENTS').doc(targetClientId);
      await upsertDoc(targetRef, payload, config.updateMode, config.dryRun);
      processed += 1;

      if (config.dryRun && samplePayloads.length < 3) {
        samplePayloads.push({ id: targetClientId, ...payload });
      }
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed new clients: ${processed}, skipped existing: ${skippedExisting}`);
  }

  console.log(`Finished CLIENTS sync. New: ${processed}, skipped existing: ${skippedExisting}`);
  if (config.dryRun && samplePayloads.length > 0) {
    console.log('Sample client payloads (dry run):');
    console.log(JSON.stringify(samplePayloads, null, 2));
  }
}

async function processOrders(config: SyncConfig, legacyDb: FirebaseFirestore.Firestore, targetDb: FirebaseFirestore.Firestore) {
  console.log('=== Syncing Legacy DEF_ORDERS ===');
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let processed = 0;
  let skipped = 0;
  const stats: SyncStats = { createdCities: 0, createdZones: 0 };

  while (true) {
    let query = legacyDb
      .collection('DEF_ORDERS')
      .where('orgID', '==', config.legacyOrgId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(config.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const orderCount = Number(data?.orderCount ?? 0);
      if (!Number.isFinite(orderCount) || orderCount <= 0) {
        skipped += 1;
        continue;
      }

      const legacyClientId = String(data.clientID || '').trim();
      if (!legacyClientId) {
        skipped += 1;
        continue;
      }

      const targetClientId = await resolveTargetClientId(legacyClientId, targetDb);
      const legacyProductName = String(data.productName || 'Product').trim();
      const mappedProductName = PRODUCT_NAME_MAPPING[legacyProductName] || legacyProductName;
      const product = await ensureProduct(targetDb, config.targetOrgId, mappedProductName);
      
      // Skip order if product doesn't exist
      if (!product) {
        skipped += 1;
        continue;
      }
      
      const unitPrice = Number(data.productUnitPrice ?? 0) || 0;

      const cityName = titleCase(String(data.regionName || data.city || '').trim());
      const regionName = titleCase(String(data.address || data.region || '').trim());
      const deliveryZone = await ensureDeliveryZone(
        targetDb,
        config.targetOrgId,
        cityName,
        regionName,
        product,
        unitPrice,
        stats,
      );

      const targetOrderId = `pave_${doc.id}`;
      const payload = buildPendingOrderPayload(
        { ...data, id: doc.id },
        targetOrderId,
        targetClientId,
        config,
        {
          zoneId: deliveryZone?.zoneId,
          cityName: deliveryZone?.cityName || cityName,
          regionName: deliveryZone?.regionName || regionName,
          productId: product.productId,
          productName: product.productName,
        },
      );

      const targetRef = targetDb.collection('PENDING_ORDERS').doc(targetOrderId);
      await upsertDoc(targetRef, payload, config.updateMode, config.dryRun);
      processed += 1;
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    console.log(`Processed orders: ${processed}, skipped: ${skipped}`);
  }

  console.log(`Finished DEF_ORDERS sync. Total: ${processed}, skipped: ${skipped}`);
  console.log(`Delivery cities created: ${stats.createdCities}`);
  console.log(`Delivery zones created: ${stats.createdZones}`);
}

async function cleanupExistingOrdersForProducts(
  targetDb: FirebaseFirestore.Firestore,
  organizationId: string,
  productNames: string[],
  dryRun: boolean,
): Promise<number> {
  console.log(`\n=== Cleaning up existing PENDING_ORDERS for products: ${productNames.join(', ')} ===`);
  
  let deletedCount = 0;
  const productNameSet = new Set(productNames.map(p => p.toLowerCase()));
  
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  const batchSize = 500;
  
  while (true) {
    let query = targetDb
      .collection('PENDING_ORDERS')
      .where('organizationId', '==', organizationId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(batchSize);
    
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    
    const snapshot = await query.get();
    if (snapshot.empty) break;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const items = Array.isArray(data.items) ? data.items : [];
      
      // Check if any item matches the products to clean
      const hasProductToClean = items.some((item: any) => 
        productNameSet.has((item.productName || '').toLowerCase())
      );
      
      if (hasProductToClean) {
        if (!dryRun) {
          await doc.ref.delete();
        }
        deletedCount += 1;
      }
    }
    
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }
  
  console.log(`Total PENDING_ORDERS deleted for specified products: ${deletedCount}`);
  if (dryRun) {
    console.log('(Dry run: no actual deletions performed)');
  }
  return deletedCount;
}

async function run(): Promise<void> {
  const config = resolveConfig();
  const { legacyDb, targetDb } = initApps(config);

  legacyDb.settings({ ignoreUndefinedProperties: true });
  targetDb.settings({ ignoreUndefinedProperties: true });

  console.log('=== Pave → Operon Sync (Script) ===');
  console.log(`Legacy Org: ${config.legacyOrgId}`);
  console.log(`Target Org: ${config.targetOrgId}`);
  console.log(`Dry Run: ${config.dryRun ? 'yes' : 'no'}`);
  console.log(`Update Mode: ${config.updateMode}`);
  if (config.skipClients) console.log('⊘ SKIP_CLIENTS: enabled');
  if (config.skipOrders) console.log('⊘ SKIP_ORDERS: enabled');

  // Clean up existing orders for specific products before migration
  const productsToClean = ['Bricks', 'Tukda'];
  await cleanupExistingOrdersForProducts(targetDb, config.targetOrgId, productsToClean, config.dryRun);

  if (!config.skipClients) {
    await processClients(config, legacyDb, targetDb);
  } else {
    console.log('\n=== Skipping CLIENTS sync (SKIP_CLIENTS=true) ===');
  }
  
  if (!config.skipOrders) {
    await processOrders(config, legacyDb, targetDb);
  } else {
    console.log('\n=== Skipping ORDERS sync (SKIP_ORDERS=true) ===');
  }
}

run().catch((error) => {
  console.error('[Sync] Failed:', error);
  process.exit(1);
});
