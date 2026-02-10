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
  createCities: boolean;
  allowUpdates: boolean;
}

interface RawRow {
  [key: string]: any;
}

interface ZoneRow {
  zoneId?: string;
  cityId?: string;
  cityName: string;
  region: string;
  isActive?: boolean;
  roundtripKm?: number;
  productId?: string;
  productName?: string;
  unitPrice?: number;
  deliverable?: boolean;
}

interface ZoneAggregate {
  zoneId?: string;
  cityId: string;
  cityName: string;
  region: string;
  isActive: boolean;
  roundtripKm?: number;
  prices: Record<string, { unitPrice: number; deliverable: boolean; productName?: string }>
}

const DEFAULT_PRODUCT_ID = '1765277893839';
const DEFAULT_PRODUCT_NAME = 'Bricks';

const HEADER_MAP: Record<string, keyof ZoneRow> = {
  zoneid: 'zoneId',
  zone_id: 'zoneId',
  cityid: 'cityId',
  city_id: 'cityId',
  cityname: 'cityName',
  city_name: 'cityName',
  city: 'cityName',
  region: 'region',
  isactive: 'isActive',
  is_active: 'isActive',
  roundtripkm: 'roundtripKm',
  roundtrip_km: 'roundtripKm',
  productid: 'productId',
  product_id: 'productId',
  productname: 'productName',
  product_name: 'productName',
  unitprice: 'unitPrice',
  unit_price: 'unitPrice',
  deliverable: 'deliverable',
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
    path.join(process.cwd(), 'data', 'delivery-zones-import.xlsx');

  if (!fs.existsSync(inputPath)) {
    throw new Error(
      `Input file not found: ${inputPath}\n` +
        'Set INPUT_PATH to the Excel file you want to import.',
    );
  }

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
    orgId,
    inputPath,
    sheetName: process.env.SHEET_NAME || 'DELIVERY_ZONES',
    dryRun: parseBoolean(process.env.DRY_RUN, false),
    createCities: parseBoolean(process.env.CREATE_CITIES, true),
    allowUpdates: parseBoolean(process.env.ALLOW_UPDATES, true),
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
    'import-delivery-zones',
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

function toZoneRow(row: RawRow): ZoneRow | null {
  const zoneRow: Partial<ZoneRow> = {};

  for (const [key, value] of Object.entries(row)) {
    const normalized = normalizeHeader(key);
    const mapped = HEADER_MAP[normalized];
    if (!mapped) continue;
    (zoneRow as any)[mapped] = value;
  }

  const cityName = String(zoneRow.cityName ?? '').trim();
  const region = String(zoneRow.region ?? '').trim();

  if (!cityName && !region && !zoneRow.zoneId && !zoneRow.productId) {
    return null;
  }

  const unitPrice = parseNumber(zoneRow.unitPrice);
  let productId = zoneRow.productId ? String(zoneRow.productId).trim() : undefined;
  let productName = zoneRow.productName ? String(zoneRow.productName).trim() : undefined;

  if (!productId && unitPrice !== undefined) {
    productId = DEFAULT_PRODUCT_ID;
    productName = productName || DEFAULT_PRODUCT_NAME;
  }

  return {
    zoneId: zoneRow.zoneId ? String(zoneRow.zoneId).trim() : undefined,
    cityId: zoneRow.cityId ? String(zoneRow.cityId).trim() : undefined,
    cityName,
    region,
    isActive: zoneRow.isActive !== undefined ? parseBoolean(zoneRow.isActive, true) : undefined,
    roundtripKm: parseNumber(zoneRow.roundtripKm),
    productId,
    productName,
    unitPrice,
    deliverable: zoneRow.deliverable !== undefined ? parseBoolean(zoneRow.deliverable, true) : undefined,
  };
}

function buildZoneKey(cityId: string, region: string): string {
  return `${cityId.toLowerCase()}::${region.toLowerCase()}`;
}

async function importDeliveryZones() {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  console.log('=== Importing Delivery Zones ===');
  console.log('Org ID:', config.orgId);
  console.log('Input:', config.inputPath);
  console.log('Sheet:', config.sheetName);
  console.log('Dry run:', config.dryRun);
  console.log('Create cities:', config.createCities);
  console.log('Allow updates:', config.allowUpdates);
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
    .map(toZoneRow)
    .filter((row): row is ZoneRow => row !== null);

  if (parsedRows.length === 0) {
    console.log('No valid rows found after parsing.');
    return;
  }

  const citiesRef = db
    .collection('ORGANIZATIONS')
    .doc(config.orgId)
    .collection('DELIVERY_CITIES');
  const zonesRef = db
    .collection('ORGANIZATIONS')
    .doc(config.orgId)
    .collection('DELIVERY_ZONES');

  const citiesSnapshot = await citiesRef.get();
  const cityNameToId = new Map<string, string>();
  const cityIdToName = new Map<string, string>();

  for (const doc of citiesSnapshot.docs) {
    const name = String(doc.data().name ?? '').trim();
    if (!name) continue;
    cityNameToId.set(name.toLowerCase(), doc.id);
    cityIdToName.set(doc.id, name);
  }

  const templateCityNames = new Set(
    parsedRows
      .map((row) => row.cityName.trim())
      .filter((name) => name.length > 0)
      .map((name) => name.toLowerCase()),
  );

  if (config.createCities && templateCityNames.size > 0) {
    for (const cityKey of templateCityNames) {
      if (cityNameToId.has(cityKey)) continue;
      const cityName = cityKey
        .split(' ')
        .map((part) => (part ? part[0].toUpperCase() + part.slice(1) : part))
        .join(' ');

      if (!config.dryRun) {
        const cityDoc = citiesRef.doc();
        await cityDoc.set({
          name: cityName,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        cityNameToId.set(cityKey, cityDoc.id);
        cityIdToName.set(cityDoc.id, cityName);
        console.log(`Created city from template: ${cityName} (${cityDoc.id})`);
      } else {
        const dryId = `dryrun-${cityKey.replace(/\s+/g, '-')}`;
        cityNameToId.set(cityKey, dryId);
        cityIdToName.set(dryId, cityName);
        console.log(`[Dry run] Would create city from template: ${cityName}`);
      }
    }
  }

  const zonesSnapshot = await zonesRef.get();
  const zoneKeyToId = new Map<string, string>();
  const zoneIdToData = new Map<string, admin.firestore.DocumentData>();

  for (const doc of zonesSnapshot.docs) {
    zoneIdToData.set(doc.id, doc.data());
    const data = doc.data();
    const cityId = String(data.city_id ?? '').trim();
    const region = String(data.region ?? '').trim();
    if (cityId && region) {
      zoneKeyToId.set(buildZoneKey(cityId, region), doc.id);
    }
  }

  const zonesByKey = new Map<string, ZoneAggregate>();
  const errors: string[] = [];

  for (const row of parsedRows) {
    let cityName = row.cityName.trim();
    let region = row.region.trim();

    if ((!cityName || !region) && row.zoneId) {
      const existingZone = zoneIdToData.get(row.zoneId);
      if (existingZone) {
        cityName = cityName || String(existingZone.city_name ?? '').trim();
        region = region || String(existingZone.region ?? '').trim();
        row.cityId = row.cityId || String(existingZone.city_id ?? '').trim();
      }
    }

    if (!cityName) {
      errors.push('Row missing city_name.');
      continue;
    }
    if (!region) {
      errors.push(`Row missing region for city: ${cityName}`);
      continue;
    }

    let cityId = row.cityId;
    if (!cityId) {
      cityId = cityNameToId.get(cityName.toLowerCase());
    }

    if (!cityId) {
      if (!config.createCities) {
        errors.push(`City not found and CREATE_CITIES=false: ${cityName}`);
        continue;
      }

      if (!config.dryRun) {
        const cityDoc = citiesRef.doc();
        await cityDoc.set({
          name: cityName,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        cityId = cityDoc.id;
        console.log(`Created city: ${cityName} (${cityId})`);
      } else {
        cityId = `dryrun-${cityName.toLowerCase().replace(/\s+/g, '-')}`;
        console.log(`[Dry run] Would create city: ${cityName}`);
      }

      cityNameToId.set(cityName.toLowerCase(), cityId);
      cityIdToName.set(cityId, cityName);
    }

    const key = row.zoneId ?? buildZoneKey(cityId, region);

    const existing = zonesByKey.get(key);
    if (existing) {
      if (row.isActive !== undefined) existing.isActive = row.isActive;
      if (row.roundtripKm !== undefined) existing.roundtripKm = row.roundtripKm;
      if (row.productId) {
        existing.prices[row.productId] = {
          unitPrice: row.unitPrice ?? 0,
          deliverable: row.deliverable ?? true,
          productName: row.productName,
        };
      }
      continue;
    }

    const zoneId = row.zoneId || zoneKeyToId.get(buildZoneKey(cityId, region));

    zonesByKey.set(key, {
      zoneId,
      cityId,
      cityName,
      region,
      isActive: row.isActive ?? true,
      roundtripKm: row.roundtripKm,
      prices: row.productId
        ? {
            [row.productId]: {
              unitPrice: row.unitPrice ?? 0,
              deliverable: row.deliverable ?? true,
              productName: row.productName,
            },
          }
        : {},
    });
  }

  if (errors.length > 0) {
    console.error('Errors found while parsing rows:');
    for (const err of errors) {
      console.error(`- ${err}`);
    }
    throw new Error('Import aborted due to errors.');
  }

  console.log(`\nZones to process: ${zonesByKey.size}`);

  if (config.dryRun) {
    console.log('\n[Dry run] No data will be written.');
    return;
  }

  let batch = db.batch();
  let batchCount = 0;
  let writeCount = 0;
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

  for (const zone of zonesByKey.values()) {
    const zoneRef = zone.zoneId ? zonesRef.doc(zone.zoneId) : zonesRef.doc();
    const hasExisting = zone.zoneId && zoneIdToData.has(zone.zoneId);

    if (hasExisting && !config.allowUpdates) {
      console.log(`Skipping existing zone (updates disabled): ${zone.zoneId}`);
      continue;
    }

    const baseData: Record<string, any> = {
      city_id: zone.cityId,
      city_name: zone.cityName,
      region: zone.region,
      is_active: zone.isActive,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (zone.roundtripKm !== undefined) {
      baseData.roundtrip_km = zone.roundtripKm;
    }

    if (!hasExisting) {
      baseData.created_at = admin.firestore.FieldValue.serverTimestamp();
      baseData.prices = Object.fromEntries(
        Object.entries(zone.prices).map(([productId, price]) => [
          productId,
          {
            unit_price: price.unitPrice,
            deliverable: price.deliverable,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
            ...(price.productName ? { product_name: price.productName } : {}),
          },
        ]),
      );
      batch.set(zoneRef, baseData, { merge: false });
      createdCount += 1;
      writeCount += 1;
    } else {
      const updateData: Record<string, any> = { ...baseData };
      for (const [productId, price] of Object.entries(zone.prices)) {
        updateData[`prices.${productId}`] = {
          unit_price: price.unitPrice,
          deliverable: price.deliverable,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
          ...(price.productName ? { product_name: price.productName } : {}),
        };
      }
      batch.update(zoneRef, updateData);
      updatedCount += 1;
      writeCount += 1;
    }

    if (writeCount >= 400) {
      await commitBatch();
    }
  }

  await commitBatch();

  console.log('\n=== Import Complete ===');
  console.log(`Created zones: ${createdCount}`);
  console.log(`Updated zones: ${updatedCount}`);
}

importDeliveryZones().catch((error) => {
  console.error('Import failed:', error);
  process.exitCode = 1;
});
