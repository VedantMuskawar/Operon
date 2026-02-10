import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

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
    sheetName: process.env.SHEET_NAME || 'PENDING_ORDERS',
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

async function importPendingOrders() {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  console.log('=== Importing Pending Orders ===');
  console.log('Org ID:', config.orgId);
  console.log('Input:', config.inputPath);
  console.log('Sheet:', config.sheetName);
  console.log('Dry run:', config.dryRun);
  console.log('Allow updates:', config.allowUpdates);
  console.log('Update mode:', config.updateMode);
  console.log('');

  const workbook = XLSX.readFile(config.inputPath);
  const sheet = workbook.Sheets[config.sheetName] || workbook.Sheets[workbook.SheetNames[0]];
  if (!sheet) {
    throw new Error('No worksheet found in Excel file.');
  }

  const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' }) as RawRow[];
  if (rows.length === 0) {
    console.log('No rows found in the Excel sheet.');
    return;
  }

  const parsedRows = rows
    .map(toOrderRow)
    .filter((row): row is OrderRow => row !== null);

  if (parsedRows.length === 0) {
    console.log('No valid rows found after parsing.');
    return;
  }

  const ordersRef = db.collection('PENDING_ORDERS');
  const errors: string[] = [];
  const warnings: string[] = [];

  const aggregates = new Map<string, OrderAggregate>();

  for (const row of parsedRows) {
    if (!row.clientId) {
      errors.push('Row missing client_id.');
      continue;
    }
    if (!row.clientName) {
      errors.push(`Row missing client_name for client_id: ${row.clientId}`);
      continue;
    }
    if (!row.deliveryZoneCity) {
      errors.push(`Row missing delivery_zone_city for client_id: ${row.clientId}`);
      continue;
    }
    if (!row.deliveryZoneRegion) {
      errors.push(`Row missing delivery_zone_region for client_id: ${row.clientId}`);
      continue;
    }
    if (!row.productId) {
      errors.push(`Row missing product_id for client_id: ${row.clientId}`);
      continue;
    }
    if (row.estimatedTrips <= 0) {
      errors.push(`Row has invalid estimated_trips for product_id: ${row.productId}`);
      continue;
    }
    if (row.fixedQuantityPerTrip <= 0) {
      errors.push(`Row has invalid fixed_quantity_per_trip for product_id: ${row.productId}`);
      continue;
    }
    if (row.unitPrice < 0) {
      errors.push(`Row has invalid unit_price for product_id: ${row.productId}`);
      continue;
    }

    const orderKey = row.orderId || row.orderKey || `${row.clientId}:${row.deliveryZoneCity}:${row.deliveryZoneRegion}`;

    let aggregate = aggregates.get(orderKey);
    if (!aggregate) {
      aggregate = {
        orderId: row.orderId,
        orderKey,
        orderNumber: row.orderNumber,
        organizationId: row.organizationId || config.orgId,
        clientId: row.clientId,
        clientName: row.clientName,
        clientPhone: row.clientPhone,
        priority: row.priority || 'normal',
        status: row.status || 'pending',
        createdBy: row.createdBy || 'migration',
        createdAt: parseDate(row.createdAt),
        updatedAt: parseDate(row.updatedAt),
        advanceAmount: row.advanceAmount,
        advancePaymentAccountId: row.advancePaymentAccountId,
        deliveryZoneId: row.deliveryZoneId,
        deliveryZoneCity: row.deliveryZoneCity,
        deliveryZoneRegion: row.deliveryZoneRegion,
        items: [],
      };
      aggregates.set(orderKey, aggregate);
    }

    if (row.orderNumber && aggregate.orderNumber && row.orderNumber !== aggregate.orderNumber) {
      warnings.push(`Order number mismatch for order_key ${orderKey}`);
    }

    const subtotal = row.estimatedTrips * row.fixedQuantityPerTrip * row.unitPrice;
    let gstAmount = row.gstAmount ?? 0;
    if (row.gstPercent && gstAmount === 0) {
      gstAmount = subtotal * (row.gstPercent / 100);
    }
    const total = subtotal + gstAmount;

    aggregate.items.push({
      productId: row.productId,
      productName: row.productName || '',
      estimatedTrips: Math.round(row.estimatedTrips),
      fixedQuantityPerTrip: row.fixedQuantityPerTrip,
      scheduledTrips: 0,
      unitPrice: row.unitPrice,
      subtotal,
      total,
      ...(row.gstPercent ? { gstPercent: row.gstPercent } : {}),
      ...(gstAmount > 0 ? { gstAmount } : {}),
    });
  }

  if (errors.length > 0) {
    console.error('Errors found while parsing rows:');
    for (const err of errors) {
      console.error(`- ${err}`);
    }
    throw new Error('Import aborted due to errors.');
  }

  if (warnings.length > 0) {
    console.warn('Warnings while parsing rows:');
    for (const warning of warnings) {
      console.warn(`- ${warning}`);
    }
  }

  console.log(`\nOrders to process: ${aggregates.size}`);

  if (config.dryRun) {
    console.log('\n[Dry run] No data will be written.');
    return;
  }

  let batch = db.batch();
  let writeCount = 0;
  let batchCount = 0;
  let createdCount = 0;
  let updatedCount = 0;

  const commitBatch = async () => {
    if (writeCount === 0) return;
    await batch.commit();
    batchCount += 1;
    console.log(`Committed batch ${batchCount} (${writeCount} writes)`);
    batch = db.batch();
    writeCount = 0;
  };

  for (const aggregate of aggregates.values()) {
    const orderRef = aggregate.orderId ? ordersRef.doc(aggregate.orderId) : ordersRef.doc();
    const existing = aggregate.orderId ? await orderRef.get() : null;

    if (existing?.exists && !config.allowUpdates) {
      console.log(`Skipping existing order (updates disabled): ${orderRef.id}`);
      continue;
    }

    const normalizedPhone = normalizePhone(aggregate.clientPhone);

    const subtotal = aggregate.items.reduce((sum, item) => sum + (item.subtotal || 0), 0);
    const totalGst = aggregate.items.reduce((sum, item) => sum + (item.gstAmount || 0), 0);
    const totalAmount = subtotal + totalGst;

    const pricing: Record<string, any> = {
      subtotal,
      totalAmount,
      currency: 'INR',
    };
    if (totalGst > 0) {
      pricing.totalGst = totalGst;
    }

    const remainingAmount =
      aggregate.advanceAmount && aggregate.advanceAmount > 0
        ? totalAmount - aggregate.advanceAmount
        : undefined;

    const orderData: Record<string, any> = {
      orderId: orderRef.id,
      orderNumber: aggregate.orderNumber || '',
      organizationId: aggregate.organizationId,
      clientId: aggregate.clientId,
      clientName: aggregate.clientName,
      name_lc: aggregate.clientName.toLowerCase(),
      clientPhone: normalizedPhone || aggregate.clientPhone || '',
      items: aggregate.items,
      deliveryZone: {
        zone_id: aggregate.deliveryZoneId || '',
        city_name: aggregate.deliveryZoneCity,
        region: aggregate.deliveryZoneRegion,
      },
      pricing,
      priority: aggregate.priority,
      status: aggregate.status,
      scheduledTrips: [],
      totalScheduledTrips: 0,
      createdBy: aggregate.createdBy,
      updatedAt: aggregate.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
    };

    if (aggregate.createdAt) {
      orderData.createdAt = aggregate.createdAt;
    } else {
      orderData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    if (aggregate.advanceAmount && aggregate.advanceAmount > 0) {
      orderData.advanceAmount = aggregate.advanceAmount;
    }
    if (aggregate.advancePaymentAccountId) {
      orderData.advancePaymentAccountId = aggregate.advancePaymentAccountId;
    }
    if (remainingAmount !== undefined) {
      orderData.remainingAmount = remainingAmount;
    }

    if (existing?.exists) {
      if (config.updateMode === 'merge') {
        batch.set(orderRef, orderData, { merge: true });
      } else {
        batch.set(orderRef, orderData, { merge: false });
      }
      updatedCount += 1;
    } else {
      batch.set(orderRef, orderData, { merge: false });
      createdCount += 1;
    }
    writeCount += 1;

    if (writeCount >= 400) {
      await commitBatch();
    }
  }

  await commitBatch();

  console.log('\n=== Import Complete ===');
  console.log(`Created orders: ${createdCount}`);
  console.log(`Updated orders: ${updatedCount}`);
}

importPendingOrders().catch((error) => {
  console.error('Import failed:', error);
  process.exitCode = 1;
});
