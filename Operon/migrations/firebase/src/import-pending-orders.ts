import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { v4 as uuidv4 } from 'uuid';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

interface ImportConfig {
  serviceAccount: string;
  projectId?: string;
  orgId: string;
  inputPath: string;
  sheetName: string;
  dryRun: boolean;
  allowUpdates: boolean;
  updateMode: 'replace' | 'merge';
}

interface RawRow {
  [key: string]: any;
}

interface OrderRow {
  orderId?: string;
  orderKey?: string;
  orderNumber?: string;
  organizationId?: string;
  clientId: string;
  clientName: string;
  clientPhone?: string;
  priority?: string;
  status?: string;
  createdBy?: string;
  createdAt?: string;
  updatedAt?: string;
  advanceAmount?: number;
  advancePaymentAccountId?: string;
  deliveryZoneId?: string;
  deliveryZoneCity?: string;
  deliveryZoneRegion?: string;
  productId: string;
  productName?: string;
  estimatedTrips: number;
  fixedQuantityPerTrip: number;
  unitPrice: number;
  gstPercent?: number;
  gstAmount?: number;
}

interface OrderAggregate {
  orderId?: string;
  orderKey: string;
  orderNumber?: string;
  organizationId: string;
  clientId: string;
  clientName: string;
  clientPhone?: string;
  priority: string;
  status: string;
  createdBy: string;
  createdAt?: admin.firestore.Timestamp;
  updatedAt?: admin.firestore.Timestamp;
  advanceAmount?: number;
  advancePaymentAccountId?: string;
  deliveryZoneId?: string;
  deliveryZoneCity: string;
  deliveryZoneRegion: string;
  items: Array<Record<string, any>>;
}

type PendingOrderDocument = Record<string, any>;

const HEADER_MAP: Record<string, keyof OrderRow> = {
  orderid: 'orderId',
  order_id: 'orderId',
  orderkey: 'orderKey',
  order_key: 'orderKey',
  external_order_ref: 'orderKey',
  ordernumber: 'orderNumber',
  order_number: 'orderNumber',
  organizationid: 'organizationId',
  organization_id: 'organizationId',
  clientid: 'clientId',
  client_id: 'clientId',
  clientname: 'clientName',
  client_name: 'clientName',
  clientphone: 'clientPhone',
  client_phone: 'clientPhone',
  priority: 'priority',
  status: 'status',
  createdby: 'createdBy',
  created_by: 'createdBy',
  createdat: 'createdAt',
  created_at: 'createdAt',
  updatedat: 'updatedAt',
  updated_at: 'updatedAt',
  advanceamount: 'advanceAmount',
  advance_amount: 'advanceAmount',
  advancepaymentaccountid: 'advancePaymentAccountId',
  advance_payment_account_id: 'advancePaymentAccountId',
  delivery_zone_id: 'deliveryZoneId',
  deliveryzoneid: 'deliveryZoneId',
  delivery_zone_city: 'deliveryZoneCity',
  delivery_zone_city_name: 'deliveryZoneCity',
  delivery_zone_region: 'deliveryZoneRegion',
  productid: 'productId',
  product_id: 'productId',
  productname: 'productName',
  product_name: 'productName',
  estimatedtrips: 'estimatedTrips',
  estimated_trips: 'estimatedTrips',
  fixedquantitypertrip: 'fixedQuantityPerTrip',
  fixed_quantity_per_trip: 'fixedQuantityPerTrip',
  unitprice: 'unitPrice',
  unit_price: 'unitPrice',
  gstpercent: 'gstPercent',
  gst_percent: 'gstPercent',
  gstamount: 'gstAmount',
  gst_amount: 'gstAmount',
};

function resolveConfig(): ImportConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const serviceAccount =
    resolvePath(process.env.SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/service-account.json');

  if (!fs.existsSync(serviceAccount)) {
    throw new Error(
      `Service account file not found: ${serviceAccount}\n\n` +
        'Please download service account JSON file from Google Cloud Console and place it in:\n' +
        `  - ${path.join(process.cwd(), 'creds/service-account.json')}\n\n` +
        'Or set SERVICE_ACCOUNT environment variable with full path.',
    );
  }

  const orgId = process.env.ORG_ID ?? '';
  if (!orgId) {
    throw new Error('Missing ORG_ID environment variable.');
  }

  const inputPath =
    resolvePath(process.env.INPUT_PATH) ??
    path.join(process.cwd(), 'data', 'pending-orders-import.xlsx');

  if (!fs.existsSync(inputPath)) {
    throw new Error(
      `Input file not found: ${inputPath}\n` +
        'Set INPUT_PATH to the Excel file you want to import.',
    );
  }

  const updateMode = (process.env.UPDATE_MODE || 'replace').toLowerCase();
  if (updateMode !== 'replace' && updateMode !== 'merge') {
    throw new Error('UPDATE_MODE must be either "replace" or "merge".');
  }

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
    orgId,
    inputPath,
    sheetName: process.env.SHEET_NAME || 'PENDING ORDERS',
    dryRun: parseBoolean(process.env.DRY_RUN, false),
    allowUpdates: parseBoolean(process.env.ALLOW_UPDATES, true),
    updateMode: updateMode as 'replace' | 'merge',
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: ImportConfig): admin.app.App {
  const serviceAccount = readServiceAccount(config.serviceAccount);

  return admin.initializeApp(
    {
      credential: admin.credential.cert(serviceAccount),
      projectId: config.projectId || serviceAccount.project_id,
    },
    'import-pending-orders',
  );
}

function normalizeHeader(value: string): string {
  return value
    .toLowerCase()
    .replace(/[\s\-]+/g, '_')
    .replace(/[^a-z0-9_]/g, '');
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

function parseNumber(value: any): number | undefined {
  if (value === null || value === undefined || value === '') return undefined;
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  const parsed = Number(String(value).trim());
  return Number.isFinite(parsed) ? parsed : undefined;
}

function parseDate(value: any): admin.firestore.Timestamp | undefined {
  if (!value) return undefined;
  if (value instanceof Date) {
    return admin.firestore.Timestamp.fromDate(value);
  }
  const parsed = Date.parse(String(value));
  if (Number.isNaN(parsed)) return undefined;
  return admin.firestore.Timestamp.fromDate(new Date(parsed));
}

function toOrderRow(row: RawRow): OrderRow | null {
  const parsed: Partial<OrderRow> = {};

  for (const [key, value] of Object.entries(row)) {
    const normalized = normalizeHeader(key);
    const mapped = HEADER_MAP[normalized];
    if (!mapped) continue;
    (parsed as any)[mapped] = value;
  }

  const clientName = String(parsed.clientName ?? '').trim();
  const clientId = String(parsed.clientId ?? '').trim();
  const productId = String(parsed.productId ?? '').trim();

  if (!clientId && !clientName && !productId) {
    return null;
  }

  return {
    orderId: parsed.orderId ? String(parsed.orderId).trim() : undefined,
    orderKey: parsed.orderKey ? String(parsed.orderKey).trim() : undefined,
    orderNumber: parsed.orderNumber ? String(parsed.orderNumber).trim() : undefined,
    organizationId: parsed.organizationId ? String(parsed.organizationId).trim() : undefined,
    clientId,
    clientName,
    clientPhone: parsed.clientPhone ? String(parsed.clientPhone).trim() : undefined,
    priority: parsed.priority ? String(parsed.priority).trim().toLowerCase() : undefined,
    status: parsed.status ? String(parsed.status).trim().toLowerCase() : undefined,
    createdBy: parsed.createdBy ? String(parsed.createdBy).trim() : undefined,
    createdAt: parsed.createdAt ? String(parsed.createdAt).trim() : undefined,
    updatedAt: parsed.updatedAt ? String(parsed.updatedAt).trim() : undefined,
    advanceAmount: parseNumber(parsed.advanceAmount),
    advancePaymentAccountId: parsed.advancePaymentAccountId
      ? String(parsed.advancePaymentAccountId).trim()
      : undefined,
    deliveryZoneId: parsed.deliveryZoneId ? String(parsed.deliveryZoneId).trim() : undefined,
    deliveryZoneCity: parsed.deliveryZoneCity ? String(parsed.deliveryZoneCity).trim() : undefined,
    deliveryZoneRegion: parsed.deliveryZoneRegion ? String(parsed.deliveryZoneRegion).trim() : undefined,
    productId,
    productName: parsed.productName ? String(parsed.productName).trim() : undefined,
    estimatedTrips: parseNumber(parsed.estimatedTrips) ?? 0,
    fixedQuantityPerTrip: parseNumber(parsed.fixedQuantityPerTrip) ?? 0,
    unitPrice: parseNumber(parsed.unitPrice) ?? 0,
    gstPercent: parseNumber(parsed.gstPercent),
    gstAmount: parseNumber(parsed.gstAmount),
  };
}

function normalizePhone(input: string | undefined): string {
  if (!input) return '';
  return input.replace(/[^0-9+]/g, '');
}

function buildPendingOrderDocument(order: OrderRow, config: ImportConfig): PendingOrderDocument {
  const normalizedPhone = normalizePhone(order.clientPhone);
  const nameLc = (order.clientName || '').trim().toLowerCase();

  const estimatedTrips = order.estimatedTrips ?? 0;
  const fixedQty = order.fixedQuantityPerTrip ?? 0;
  const unitPrice = order.unitPrice ?? 0;
  const subtotal = estimatedTrips * fixedQty * unitPrice;

  const hasGst = order.gstPercent !== undefined && order.gstPercent > 0;
  const gstAmount = hasGst
    ? subtotal * (order.gstPercent! / 100)
    : order.gstAmount ?? 0;
  const total = subtotal + (hasGst ? gstAmount : 0);

  const item: Record<string, any> = {
    productId: order.productId,
    productName: order.productName,
    estimatedTrips,
    scheduledTrips: 0,
    fixedQuantityPerTrip: fixedQty,
    unitPrice,
    subtotal,
    total,
  };

  if (hasGst) {
    item.gstPercent = order.gstPercent;
    item.gstAmount = gstAmount;
  }

  const createdAt = parseDate(order.createdAt) ?? admin.firestore.FieldValue.serverTimestamp();
  const updatedAt = parseDate(order.updatedAt) ?? admin.firestore.FieldValue.serverTimestamp();

  const pricing: Record<string, any> = {
    subtotal,
    totalAmount: total,
  };
  if (hasGst) {
    pricing.totalGst = gstAmount;
  }

  return {
    orderId: order.orderId,
    orderKey: order.orderKey,
    orderNumber: order.orderNumber,
    organizationId: config.orgId,
    clientId: order.clientId,
    clientName: order.clientName,
    clientPhone: normalizedPhone || order.clientPhone,
    name_lc: nameLc,
    priority: order.priority || 'normal',
    status: order.status || 'pending',
    createdBy: order.createdBy || 'migration',
    createdAt,
    updatedAt,
    advanceAmount: order.advanceAmount ?? 0,
    advancePaymentAccountId: order.advancePaymentAccountId,
    deliveryZone: {
      zone_id: order.deliveryZoneId,
      city_name: order.deliveryZoneCity,
      region: order.deliveryZoneRegion,
    },
    items: [item],
    tripIds: [],
    totalScheduledTrips: 0,
    pricing,
  };
}

async function ensureCityAndRegion(cityName: string, regionName: string, db: FirebaseFirestore.Firestore, config: ImportConfig): Promise<{ cityId: string; regionId: string }> {
  const citiesRef = db.collection('ORGANIZATIONS').doc(config.orgId).collection('DELIVERY_CITIES');
  const zonesRef = db.collection('ORGANIZATIONS').doc(config.orgId).collection('DELIVERY_ZONES');

  const citySnapshot = await citiesRef.where('name', '==', cityName).limit(1).get();
  let cityId = citySnapshot.empty ? null : citySnapshot.docs[0].id;

  if (!cityId) {
    if (config.dryRun) {
      console.log(`[Dry Run] Would create city: ${cityName}`);
      cityId = `dry-run-city-${cityName.toLowerCase().replace(/\s+/g, '-')}`;
    } else {
      const newCityRef = citiesRef.doc();
      await newCityRef.set({
        name: cityName,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      cityId = newCityRef.id;
    }
  }

  const zoneKey = `${cityId}::${regionName.toLowerCase()}`;
  const zoneSnapshot = await zonesRef.where('key', '==', zoneKey).limit(1).get();
  let regionId = zoneSnapshot.empty ? null : zoneSnapshot.docs[0].id;

  if (!regionId) {
    if (config.dryRun) {
      console.log(`[Dry Run] Would create region: ${regionName} in city: ${cityName}`);
      regionId = `dry-run-region-${regionName.toLowerCase().replace(/\s+/g, '-')}`;
    } else {
      const newZoneRef = zonesRef.doc();
      await newZoneRef.set({
        key: zoneKey,
        city_id: cityId,
        region: regionName,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      regionId = newZoneRef.id;
    }
  }

  return { cityId, regionId };
}

async function processOrderRow(row: RawRow, db: FirebaseFirestore.Firestore, config: ImportConfig): Promise<OrderRow | null> {
  const order = toOrderRow(row);
  if (!order) return null;

  if (order.deliveryZoneCity && order.deliveryZoneRegion) {
    const { cityId, regionId } = await ensureCityAndRegion(order.deliveryZoneCity, order.deliveryZoneRegion, db, config);
    order.deliveryZoneId = regionId;
    order.organizationId = config.orgId;
  }

  return order;
}

async function importPendingOrders(config: ImportConfig, appInstance: admin.app.App): Promise<void> {
  const db = appInstance.firestore();
  db.settings({ ignoreUndefinedProperties: true });
  const workbook = XLSX.readFile(config.inputPath);
  const sheetNames = workbook.SheetNames || [];
  console.log(`Input file: ${config.inputPath}`);
  console.log(`Requested sheet: ${config.sheetName}`);
  console.log(`Available sheets: ${sheetNames.join(', ') || '(none)'}`);

  let sheetNameToUse = config.sheetName;
  if (!process.env.SHEET_NAME && sheetNames.length > 0 && !workbook.Sheets[sheetNameToUse]) {
    sheetNameToUse = sheetNames[0];
    console.log(`Falling back to first sheet: ${sheetNameToUse}`);
  }

  const sheet = workbook.Sheets[sheetNameToUse];
  if (!sheet) {
    throw new Error(
      `Sheet not found: ${sheetNameToUse}. ` +
        `Available sheets: ${sheetNames.join(', ') || '(none)'}`,
    );
  }
  const rows = XLSX.utils.sheet_to_json(sheet) as RawRow[];

  if (!config.dryRun) {
    console.log('Deleting existing pending orders for org before import...');
    await deleteExistingPendingOrders(db, config.orgId);
  } else {
    console.log('[Dry Run] Would delete existing pending orders for org before import.');
  }

  // Add logging for processed rows, skipped rows, and successful writes
  console.log(`Starting import of pending orders...`);

  let processedCount = 0;
  let skippedCount = 0;

  for (const rawRow of rows) {
    const order = await processOrderRow(rawRow, db, config);
    if (!order) {
      skippedCount++;
      console.log(`Skipped row: ${JSON.stringify(rawRow)}`);
      continue;
    }

    const orderDocId = order.orderId || uuidv4();
    if (!order.orderId) {
      order.orderId = orderDocId;
      console.log(`Missing orderId; generated: ${orderDocId}`);
    }

    const orderDocument = buildPendingOrderDocument(order, config);

    if (config.dryRun) {
      processedCount++;
      console.log(`[Dry Run] Would import order: ${order.orderId}`);
      continue;
    }

    const orderRef = db.collection('PENDING_ORDERS').doc(orderDocId);
    await orderRef.set(orderDocument, { merge: config.updateMode === 'merge' });
    processedCount++;
    console.log(`Successfully imported order: ${order.orderId}`);
  }

  console.log(`Import completed. Processed: ${processedCount}, Skipped: ${skippedCount}`);
}

async function deleteExistingPendingOrders(
  db: FirebaseFirestore.Firestore,
  orgId: string,
): Promise<void> {
  const batchSize = 400;
  let deletedTotal = 0;

  while (true) {
    const snapshot = await db
      .collection('PENDING_ORDERS')
      .where('organizationId', '==', orgId)
      .limit(batchSize)
      .get();

    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();
    deletedTotal += snapshot.size;
    console.log(`Deleted ${deletedTotal} pending orders so far...`);
  }

  console.log(`Deleted ${deletedTotal} pending orders total.`);
}

// Initialize Firebase app at the top of the script
const config = resolveConfig();
const app = initApp(config);

// Ensure initApp() is used consistently

importPendingOrders(config, app).catch((error) => {
  console.error('Error importing pending orders:', error);
});
