import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import {
  CLIENTS_COLLECTION,
  PENDING_ORDERS_COLLECTION,
} from '../shared/constants';
import { LIGHT_TRIGGER_OPTS } from '../shared/function-config';

interface SyncConfig {
  enabled: boolean;
  legacyOrgId?: string;
  targetOrgId?: string;
  legacyClientsCollection: string;
  legacyDefOrdersCollection: string;
  clientMapCollection: string;
  updateMode: 'skip' | 'merge' | 'replace';
  deleteOnLegacyDelete: boolean;
  targetProjectId?: string;
  targetServiceAccount?: admin.ServiceAccount;
}

const TARGET_APP_NAME = 'pave-operon-sync-target';

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

function readServiceAccountFromEnv(): admin.ServiceAccount | undefined {
  const jsonRaw = process.env.SYNC_TARGET_SERVICE_ACCOUNT_JSON;
  if (jsonRaw) {
    try {
      return JSON.parse(jsonRaw);
    } catch (error) {
      console.error('[Sync] Failed to parse SYNC_TARGET_SERVICE_ACCOUNT_JSON', error);
    }
  }

  const base64 = process.env.SYNC_TARGET_SERVICE_ACCOUNT_JSON_BASE64;
  if (base64) {
    try {
      const decoded = Buffer.from(base64, 'base64').toString('utf8');
      return JSON.parse(decoded);
    } catch (error) {
      console.error('[Sync] Failed to parse SYNC_TARGET_SERVICE_ACCOUNT_JSON_BASE64', error);
    }
  }

  return undefined;
}

function resolveSyncConfig(): SyncConfig {
  const updateMode = resolveUpdateMode(process.env.SYNC_UPDATE_MODE);

  return {
    enabled: parseBoolean(process.env.SYNC_ENABLED, false),
    legacyOrgId: process.env.SYNC_LEGACY_ORG_ID,
    targetOrgId: process.env.SYNC_TARGET_ORG_ID,
    legacyClientsCollection: process.env.SYNC_LEGACY_CLIENTS_COLLECTION || 'CLIENTS',
    legacyDefOrdersCollection: process.env.SYNC_LEGACY_DEF_ORDERS_COLLECTION || 'DEF_ORDERS',
    clientMapCollection: process.env.SYNC_CLIENT_MAP_COLLECTION || 'CLIENT_ID_MAP',
    updateMode,
    deleteOnLegacyDelete: parseBoolean(process.env.SYNC_DELETE_ON_LEGACY_DELETE, false),
    targetProjectId: process.env.SYNC_TARGET_PROJECT_ID,
    targetServiceAccount: readServiceAccountFromEnv(),
  };
}

function getTargetFirestore(config: SyncConfig): FirebaseFirestore.Firestore | null {
  try {
    const existingApp = admin.apps.find((app) => app?.name === TARGET_APP_NAME);
    if (existingApp) {
      return existingApp.firestore();
    }

    if (config.targetServiceAccount || config.targetProjectId) {
      const app = admin.initializeApp(
        {
          credential: config.targetServiceAccount
            ? admin.credential.cert(config.targetServiceAccount)
            : undefined,
          projectId:
            config.targetProjectId ||
            (config.targetServiceAccount as any)?.project_id ||
            config.targetServiceAccount?.projectId,
        },
        TARGET_APP_NAME,
      );
      return app.firestore();
    }

    console.warn('[Sync] Target project credentials not provided; defaulting to current app.');
    return admin.firestore();
  } catch (error) {
    console.error('[Sync] Failed to initialize target Firestore', error);
    return null;
  }
}

function normalizePhone(input?: string): string {
  if (!input) return '';
  return input.replace(/[^0-9+]/g, '');
}

function normalizeName(name?: string): string {
  return (name || '').trim().toLowerCase();
}

function slugify(value?: string): string {
  return (value || 'product')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '') || 'product';
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

async function ensureDeliveryZone(
  targetDb: FirebaseFirestore.Firestore,
  organizationId: string,
  cityName: string,
  regionName: string,
  product: { productId: string; productName: string },
  unitPrice: number,
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

async function ensureProduct(
  targetDb: FirebaseFirestore.Firestore,
  organizationId: string,
  productName: string,
): Promise<{ productId: string; productName: string }> {
  const normalizedName = productName.trim() || 'Product';
  const productsRef = targetDb
    .collection('ORGANIZATIONS')
    .doc(organizationId)
    .collection('PRODUCTS');
  const nameLc = normalizeName(normalizedName);

  const nameMatch = await productsRef.where('name_lc', '==', nameLc).limit(1).get();
  if (!nameMatch.empty) {
    const existingDoc = nameMatch.docs[0];
    return {
      productId: existingDoc.id,
      productName: String(existingDoc.data().name || normalizedName),
    };
  }

  const productId = `legacy-${slugify(normalizedName)}`;
  const productRef = productsRef.doc(productId);

  const snapshot = await productRef.get();
  if (!snapshot.exists) {
    await productRef.set({
      name: normalizedName,
      name_lc: nameLc,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'legacy',
    });
  }

  return { productId, productName: normalizedName };
}

async function resolveTargetClientId(
  legacyClientId: string,
  targetDb: FirebaseFirestore.Firestore,
  config: SyncConfig,
): Promise<string | null> {
  try {
    const mapRef = targetDb.collection(config.clientMapCollection).doc(legacyClientId);
    const mapSnap = await mapRef.get();

    const mappedId = mapSnap.exists
      ? (mapSnap.data()?.operonClientId || mapSnap.data()?.clientId || mapSnap.data()?.targetClientId)
      : undefined;

    if (mappedId) {
      return String(mappedId);
    }

    const newClientRef = targetDb.collection(CLIENTS_COLLECTION).doc();
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
  } catch (error) {
    console.error('[Sync] Failed to resolve target client mapping', {
      legacyClientId,
      error,
    });
    return null;
  }
}

function buildOperonClientPayload(data: FirebaseFirestore.DocumentData, targetClientId: string, config: SyncConfig) {
  const phoneList = Array.isArray(data.phoneList) ? data.phoneList : [];
  const primaryPhone = normalizePhone(data.phoneNumber || phoneList[0]);
  const phoneIndex = [primaryPhone, ...phoneList.map((phone: any) => normalizePhone(phone))]
    .filter((phone) => phone)
    .filter((phone, index, arr) => arr.indexOf(phone) === index);

  const phones = phoneIndex.map((phone, index) => ({
    e164: phone,
    label: index === 0 ? 'main' : `phone_${index + 1}`,
  }));

  const createdAt = data.registeredTime || data.createdAt || admin.firestore.FieldValue.serverTimestamp();

  return {
    clientId: targetClientId,
    name: String(data.name || '').trim(),
    name_lc: normalizeName(data.name),
    organizationId: config.targetOrgId || data.orgID || data.organizationId,
    contacts: Array.isArray(data.contacts) ? data.contacts : [],
    phones,
    phoneIndex,
    primaryPhone,
    primaryPhoneNormalized: primaryPhone,
    currentBalance: Number(data.totalBalance ?? data.currentBalance ?? 0),
    stats: {
      lifetimeAmount: Number(data.totalRevenue ?? data.lifetimeAmount ?? 0),
      orders: Number(data.totalOrders ?? 0),
    },
    status: String(data.status || 'active').toLowerCase(),
    tags: Array.isArray(data.tags)
      ? data.tags
      : [data.orgName ? String(data.orgName) : 'Legacy'],
    createdAt,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    syncMetadata: {
      source: 'pave',
      legacyClientId: data.id || undefined,
      syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

function formatDateOnly(value: any): string | undefined {
  if (!value) return undefined;
  const date = value.toDate ? value.toDate() : new Date(value);
  if (Number.isNaN(date.getTime())) return undefined;
  const yyyy = date.getFullYear();
  const mm = `${date.getMonth() + 1}`.padStart(2, '0');
  const dd = `${date.getDate()}`.padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function buildOperonPendingOrderPayload(
  data: FirebaseFirestore.DocumentData,
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
  const productName = resolved.productName;
  const orderCount = Math.max(1, Math.floor(Number(data.orderCount ?? 0)) || 1);
  const productQuant = Number(data.productQuant ?? 0) || 0;
  const unitPrice = Number(data.productUnitPrice ?? 0) || 0;
  const fixedQuantityPerTrip = productQuant;
  const subtotal = fixedQuantityPerTrip * unitPrice * orderCount;

  const estimatedStartDate = formatDateOnly(data.expectedDeliveyDate || data.expectedDeliveryDate);

  return {
    orderId,
    orderKey: data.orderId || data.id || orderId,
    organizationId: config.targetOrgId || data.orgID || data.organizationId,
    clientId: targetClientId,
    clientName: String(data.clientName || '').trim(),
    clientPhone: normalizePhone(data.clientPhoneNumber || data.clientPhone || ''),
    name_lc: normalizeName(data.clientName),
    priority: String(data.priority || 'normal').toLowerCase(),
    status: String(data.status || 'pending').toLowerCase(),
    createdBy: 'sync',
    createdAt: data.createdTime || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    advanceAmount: Number(data.advanceAmount ?? 0),
    deliveryZone: {
      city_name: resolved.cityName,
      region_name: resolved.regionName,
      region: resolved.regionName,
      zone_id: resolved.zoneId,
    },
    edd: estimatedStartDate
      ? {
          calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
          estimatedStartDate,
          estimatedCompletionDate: estimatedStartDate,
        }
      : undefined,
    items: [
      {
        itemIndex: 0,
        productId: resolved.productId,
        productName,
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

async function upsertTargetDoc(
  docRef: FirebaseFirestore.DocumentReference,
  payload: Record<string, unknown>,
  updateMode: SyncConfig['updateMode'],
): Promise<void> {
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

const syncConfig = resolveSyncConfig();

export const onPaveClientWritten = onDocumentWritten(
  {
    document: `${syncConfig.legacyClientsCollection}/{legacyClientId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    if (!syncConfig.enabled) return;

    const targetDb = getTargetFirestore(syncConfig);
    if (!targetDb) return;

    const legacyClientId = event.params.legacyClientId as string;
    const after = event.data?.after;

    if (!after || !after.exists) {
      if (!syncConfig.deleteOnLegacyDelete) return;
      try {
        const mapRef = targetDb.collection(syncConfig.clientMapCollection).doc(legacyClientId);
        const mapSnap = await mapRef.get();
        const targetId = mapSnap.data()?.operonClientId;
        if (targetId) {
          await targetDb.collection(CLIENTS_COLLECTION).doc(String(targetId)).delete();
          await mapRef.delete();
        }
      } catch (error) {
        console.error('[Sync] Failed to delete target client on legacy delete', error);
      }
      return;
    }

    const data = after.data();
    if (!data) {
      return;
    }
    if (syncConfig.legacyOrgId && data?.orgID && data.orgID !== syncConfig.legacyOrgId) {
      return;
    }

    try {
      const targetClientId = await resolveTargetClientId(legacyClientId, targetDb, syncConfig);
      if (!targetClientId) return;

      const payload = buildOperonClientPayload({ ...data, id: legacyClientId }, targetClientId, syncConfig);
      const targetRef = targetDb.collection(CLIENTS_COLLECTION).doc(targetClientId);

      await upsertTargetDoc(targetRef, payload, syncConfig.updateMode);
    } catch (error) {
      console.error('[Sync] Failed to sync legacy client', {
        legacyClientId,
        error,
      });
    }
  },
);

export const onPaveDefOrderWritten = onDocumentWritten(
  {
    document: `${syncConfig.legacyDefOrdersCollection}/{legacyOrderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    if (!syncConfig.enabled) return;

    const targetDb = getTargetFirestore(syncConfig);
    if (!targetDb) return;

    const legacyOrderId = event.params.legacyOrderId as string;
    const after = event.data?.after;

    if (!after || !after.exists) {
      if (!syncConfig.deleteOnLegacyDelete) return;
      try {
        const targetId = `pave_${legacyOrderId}`;
        await targetDb.collection(PENDING_ORDERS_COLLECTION).doc(targetId).delete();
      } catch (error) {
        console.error('[Sync] Failed to delete target order on legacy delete', error);
      }
      return;
    }

    const data = after.data();
    if (!data) {
      return;
    }

    if (syncConfig.legacyOrgId && data?.orgID && data.orgID !== syncConfig.legacyOrgId) {
      return;
    }

    const orderCount = Number(data?.orderCount ?? 0);
    if (!Number.isFinite(orderCount) || orderCount <= 0) {
      return;
    }

    try {
      const legacyClientId = String(data.clientID || '').trim();
      if (!legacyClientId) {
        console.warn('[Sync] Missing legacy clientID in DEF_ORDERS', { legacyOrderId });
        return;
      }

      const targetClientId = await resolveTargetClientId(legacyClientId, targetDb, syncConfig);
      if (!targetClientId) return;

      const organizationId = String(syncConfig.targetOrgId || data.orgID || data.organizationId || '').trim();
      if (!organizationId) {
        console.warn('[Sync] Missing organizationId for DEF_ORDERS sync', { legacyOrderId });
        return;
      }

      const productName = String(data.productName || 'Product').trim();
      const product = await ensureProduct(targetDb, organizationId, productName);
      const unitPrice = Number(data.productUnitPrice ?? 0) || 0;

      const cityName = titleCase(String(data.regionName || data.city || '').trim());
      const regionName = titleCase(String(data.address || data.region || '').trim());
      const deliveryZone = await ensureDeliveryZone(
        targetDb,
        organizationId,
        cityName,
        regionName,
        product,
        unitPrice,
      );

      const targetOrderId = `pave_${legacyOrderId}`;
      const payload = buildOperonPendingOrderPayload(
        { ...data, id: legacyOrderId },
        targetOrderId,
        targetClientId,
        syncConfig,
        {
          zoneId: deliveryZone?.zoneId,
          cityName: deliveryZone?.cityName || cityName,
          regionName: deliveryZone?.regionName || regionName,
          productId: product.productId,
          productName: product.productName,
        },
      );
      const targetRef = targetDb.collection(PENDING_ORDERS_COLLECTION).doc(targetOrderId);

      await upsertTargetDoc(targetRef, payload, syncConfig.updateMode);
    } catch (error) {
      console.error('[Sync] Failed to sync DEF_ORDERS order', {
        legacyOrderId,
        error,
      });
    }
  },
);
