/**
 * Location Pricing Migration Script - From Excel
 * 
 * Migrates location/zone pricing data from Excel file to the Operon Firebase project.
 * 
 * Excel Format:
 * - City Name (required)
 * - Region (required)
 * - Product ID or Product Name (required)
 * - Unit Price (required)
 * - Deliverable (optional, default: true)
 * 
 * Creates/updates DELIVERY_ZONES and sets prices for products.
 * Supports both flattened prices (recommended) and subcollection structure.
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

interface MigrationConfig {
  excelFilePath: string;
  excelSheetName?: string;
  newServiceAccount: string;
  newProjectId?: string;
  targetOrgId: string;
  useFlattenedPrices: boolean; // true = flattened prices map, false = subcollection
  overwriteExisting: boolean;
  skipInvalidRows: boolean;
}

const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS';

function resolveConfig(): MigrationConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  // Excel file path
  const excelFilePath =
    resolvePath(process.env.EXCEL_FILE_PATH) ??
    path.join(process.cwd(), 'data/location-pricing.xlsx');

  if (!fs.existsSync(excelFilePath)) {
    throw new Error(
      `Excel file not found: ${excelFilePath}\n\n` +
        'Please place the Excel file at:\n' +
        `  - ${path.join(process.cwd(), 'data/location-pricing.xlsx')}\n\n` +
        'Or set EXCEL_FILE_PATH environment variable with full path.',
    );
  }

  // Service account
  const newServiceAccount =
    resolvePath(process.env.NEW_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/new-service-account.json');

  if (!fs.existsSync(newServiceAccount)) {
    throw new Error(
      `Service account file not found: ${newServiceAccount}\n\n` +
        'Please download service account JSON file from Google Cloud Console and place it in:\n' +
        `  - ${path.join(process.cwd(), 'creds/new-service-account.json')}\n\n` +
        'Or set NEW_SERVICE_ACCOUNT environment variable with full path.',
    );
  }

  return {
    excelFilePath,
    excelSheetName: process.env.EXCEL_SHEET_NAME,
    newServiceAccount,
    newProjectId: process.env.NEW_PROJECT_ID,
    targetOrgId: process.env.TARGET_ORG_ID ?? FALLBACK_TARGET_ORG,
    useFlattenedPrices: process.env.USE_FLATTENED_PRICES !== 'false', // Default: true
    overwriteExisting: process.env.OVERWRITE_EXISTING === 'true',
    skipInvalidRows: process.env.SKIP_INVALID_ROWS !== 'false',
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: MigrationConfig): admin.app.App {
  return admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.newServiceAccount),
      ),
      projectId: config.newProjectId,
    },
    'target',
  );
}

/**
 * Parse date from Excel cell value
 */
function parseDate(value: any): Date | null {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'number') {
    const excelEpoch = new Date('1899-12-30').getTime();
    return new Date(excelEpoch + value * 86400000);
  }
  if (typeof value === 'string') {
    const date = new Date(value);
    if (!isNaN(date.getTime())) return date;
  }
  return null;
}

/**
 * Read Excel file and return rows as array of objects
 */
function readExcelFile(
  filePath: string,
  sheetName?: string,
): Array<Record<string, any>> {
  const workbook = XLSX.readFile(filePath);
  const sheet = sheetName
    ? workbook.Sheets[sheetName]
    : workbook.Sheets[workbook.SheetNames[0]];

  if (!sheet) {
    throw new Error(
      `Sheet "${sheetName || workbook.SheetNames[0]}" not found in Excel file`,
    );
  }

  const rows = XLSX.utils.sheet_to_json(sheet, { raw: false });
  return rows as Array<Record<string, any>>;
}

/**
 * Lookup product ID by product name
 */
async function lookupProductId(
  db: admin.firestore.Firestore,
  productName: string,
  orgId: string,
): Promise<string | null> {
  try {
    const snapshot = await db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('PRODUCTS')
      .where('name', '==', productName.trim())
      .limit(1)
      .get();

    if (!snapshot.empty) {
      return snapshot.docs[0].id;
    }

    // Try case-insensitive
    const allProducts = await db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('PRODUCTS')
      .get();

    const match = allProducts.docs.find(
      (doc) => doc.data().name?.toLowerCase() === productName.toLowerCase().trim(),
    );

    return match ? match.id : null;
  } catch (error) {
    console.warn(`Error looking up product "${productName}": ${error}`);
    return null;
  }
}

/**
 * Get or create city document
 */
async function getOrCreateCity(
  db: admin.firestore.Firestore,
  orgId: string,
  cityName: string,
): Promise<string> {
  const citiesRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('DELIVERY_CITIES');

  // Try to find existing city
  const snapshot = await citiesRef
    .where('name', '==', cityName.trim())
    .limit(1)
    .get();

  if (!snapshot.empty) {
    return snapshot.docs[0].id;
  }

  // Create new city
  const cityRef = citiesRef.doc();
  await cityRef.set({
    name: cityName.trim(),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return cityRef.id;
}

/**
 * Get or create zone document
 */
async function getOrCreateZone(
  db: admin.firestore.Firestore,
  orgId: string,
  cityId: string,
  cityName: string,
  region: string,
): Promise<string> {
  const zonesRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('DELIVERY_ZONES');

  // Try to find existing zone by city_name and region
  const snapshot = await zonesRef
    .where('city_name', '==', cityName.trim())
    .where('region', '==', region.trim())
    .limit(1)
    .get();

  if (!snapshot.empty) {
    return snapshot.docs[0].id;
  }

  // Create new zone
  const zoneRef = zonesRef.doc();
  await zoneRef.set({
    organization_id: orgId,
    city_id: cityId,
    city_name: cityName.trim(),
    region: region.trim(),
    is_active: true,
    prices: {}, // Initialize empty prices map
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return zoneRef.id;
}

/**
 * Transform Excel row to zone price data
 */
function transformRow(
  row: Record<string, any>,
): {
  cityName: string;
  region: string;
  productId?: string;
  productName?: string;
  unitPrice: number;
  deliverable: boolean;
  roundtripKm?: number;
} | null {
  // Required fields
  const cityName =
    row['City Name'] ||
    row['City'] ||
    row['cityName'] ||
    row['city'] ||
    '';
  const region =
    row['Region'] ||
    row['region'] ||
    row['Region Name'] ||
    row['regionName'] ||
    '';
  const unitPriceRaw =
    row['Unit Price'] ||
    row['unitPrice'] ||
    row['Price'] ||
    row['price'] ||
    '0';
  const unitPrice = parseFloat(String(unitPriceRaw)) || 0;

  if (!cityName || !region) {
    console.warn('Skipping row: missing cityName or region', row);
    return null;
  }

  if (unitPrice <= 0) {
    console.warn('Skipping row: invalid unitPrice', row);
    return null;
  }

  // Product identification
  const productId = row['Product ID'] || row['productId'] || row['Product ID'] || '';
  const productName =
    row['Product Name'] ||
    row['productName'] ||
    row['Product'] ||
    row['product'] ||
    '';

  if (!productId && !productName) {
    console.warn('Skipping row: missing productId or productName', row);
    return null;
  }

  // Deliverable flag
  const deliverableRaw =
    row['Deliverable'] ||
    row['deliverable'] ||
    row['Can Deliver'] ||
    row['canDeliver'] ||
    'true';
  const deliverable =
    typeof deliverableRaw === 'boolean'
      ? deliverableRaw
      : String(deliverableRaw).toLowerCase() === 'true' ||
        String(deliverableRaw) === '1' ||
        String(deliverableRaw).toLowerCase() === 'yes';

  // Round Trip Distance (optional)
  const roundtripKmRaw =
    row['Round Trip Distance'] ||
    row['Round Trip KM'] ||
    row['roundTripDistance'] ||
    row['roundTripKm'] ||
    row['roundtrip_km'] ||
    row['Roundtrip KM'] ||
    '';
  const roundtripKm = roundtripKmRaw ? parseFloat(String(roundtripKmRaw)) : undefined;

  return {
    cityName: cityName.trim(),
    region: region.trim(),
    productId: productId ? productId.trim() : undefined,
    productName: productName ? productName.trim() : undefined,
    unitPrice,
    deliverable,
    roundtripKm: roundtripKm !== undefined && !isNaN(roundtripKm) ? roundtripKm : undefined,
  };
}

async function migrateLocationPricing() {
  const config = resolveConfig();
  const target = initApp(config);
  const targetDb = target.firestore();

  console.log('=== Migrating Location Pricing from Excel ===');
  console.log('Excel file:', config.excelFilePath);
  console.log('Sheet:', config.excelSheetName || 'First sheet');
  console.log('Target Org ID:', config.targetOrgId);
  console.log('Use Flattened Prices:', config.useFlattenedPrices);
  console.log('Overwrite existing:', config.overwriteExisting);
  console.log('Skip invalid rows:', config.skipInvalidRows);
  console.log('');

  // Read Excel file
  console.log('Reading Excel file...');
  const rows = readExcelFile(config.excelFilePath, config.excelSheetName);
  console.log(`Found ${rows.length} rows in Excel file\n`);

  if (rows.length === 0) {
    console.log('No rows found in Excel file');
    return;
  }

  let processed = 0;
  let skipped = 0;
  let skippedInvalid = 0;
  const batchSize = 400;
  let batch = targetDb.batch();

  // Step 1: Extract unique cities and create DELIVERY_CITIES first
  console.log('Step 1: Extracting unique cities and creating DELIVERY_CITIES...');
  const uniqueCities = new Set<string>();
  for (const row of rows) {
    const cityName =
      row['City Name'] ||
      row['City'] ||
      row['cityName'] ||
      row['city'] ||
      '';
    if (cityName && cityName.trim()) {
      uniqueCities.add(cityName.trim());
    }
  }

  console.log(`Found ${uniqueCities.size} unique cities`);
  const cityMap = new Map<string, string>(); // cityName -> cityId

  for (const cityName of uniqueCities) {
    const cityId = await getOrCreateCity(targetDb, config.targetOrgId, cityName);
    cityMap.set(cityName, cityId);
    console.log(`  Created/Found city: ${cityName} (ID: ${cityId})`);
  }

  console.log(`\nStep 2: Processing rows and resolving product IDs...`);

  // Track zones and cities to create/update
  const zoneMap = new Map<string, { zoneId: string; cityId: string; cityName: string; region: string; roundtripKm?: number }>();
  const priceUpdates = new Map<
    string,
    Array<{ productId: string; unitPrice: number; deliverable: boolean }>
  >();
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const rowNum = i + 2; // +2 because Excel rows are 1-indexed and first row is header

    try {
      const transformed = transformRow(row);
      if (!transformed) {
        if (config.skipInvalidRows) {
          console.warn(`Row ${rowNum}: Skipping - transformation returned null`);
          skippedInvalid += 1;
          continue;
        } else {
          throw new Error(`Row ${rowNum}: Failed to transform row`);
        }
      }

      // Resolve product ID
      let productId = transformed.productId;
      if (!productId && transformed.productName) {
        productId = await lookupProductId(
          targetDb,
          transformed.productName,
          config.targetOrgId,
        );
        if (!productId) {
          console.warn(
            `Row ${rowNum}: Product "${transformed.productName}" not found, skipping`,
          );
          skippedInvalid += 1;
          continue;
        }
      }

      if (!productId) {
        console.warn(`Row ${rowNum}: Could not resolve product ID, skipping`);
        skippedInvalid += 1;
        continue;
      }

      // Track zone
      const zoneKey = `${transformed.cityName}::${transformed.region}`;
      if (!zoneMap.has(zoneKey)) {
        const cityId = cityMap.get(transformed.cityName);
        if (!cityId) {
          console.warn(
            `Row ${rowNum}: City "${transformed.cityName}" not found in city map, skipping`,
          );
          skippedInvalid += 1;
          continue;
        }
        const zoneId = await getOrCreateZone(
          targetDb,
          config.targetOrgId,
          cityId,
          transformed.cityName,
          transformed.region,
          transformed.roundtripKm,
        );
        zoneMap.set(zoneKey, {
          zoneId,
          cityId,
          cityName: transformed.cityName,
          region: transformed.region,
          roundtripKm: transformed.roundtripKm,
        });
      } else {
        // Update roundtripKm if provided and different
        const existingZone = zoneMap.get(zoneKey)!;
        if (transformed.roundtripKm !== undefined && existingZone.roundtripKm !== transformed.roundtripKm) {
          await getOrCreateZone(
            targetDb,
            config.targetOrgId,
            existingZone.cityId,
            transformed.cityName,
            transformed.region,
            transformed.roundtripKm,
          );
          existingZone.roundtripKm = transformed.roundtripKm;
        }
      }

      // Track price update
      const zoneInfo = zoneMap.get(zoneKey)!;
      if (!priceUpdates.has(zoneInfo.zoneId)) {
        priceUpdates.set(zoneInfo.zoneId, []);
      }
      priceUpdates.get(zoneInfo.zoneId)!.push({
        productId,
        unitPrice: transformed.unitPrice,
        deliverable: transformed.deliverable,
      });

      processed += 1;
    } catch (error) {
      if (config.skipInvalidRows) {
        console.error(`Row ${rowNum}: Error processing row:`, error);
        skippedInvalid += 1;
        continue;
      } else {
        throw error;
      }
    }
  }

  console.log(`\nProcessed ${processed} valid rows`);
  console.log(`Found ${zoneMap.size} unique zones`);
  console.log(`Total price updates: ${Array.from(priceUpdates.values()).reduce((sum, arr) => sum + arr.length, 0)}`);

  // Step 3: Update zones with prices
  console.log('\nStep 3: Updating zones with prices...');
  let updatedZones = 0;
  let updatedPrices = 0;

  for (const [zoneId, prices] of priceUpdates.entries()) {
    try {
      const zoneRef = targetDb
        .collection('ORGANIZATIONS')
        .doc(config.targetOrgId)
        .collection('DELIVERY_ZONES')
        .doc(zoneId);

      if (config.useFlattenedPrices) {
        // Update flattened prices map
        const zoneDoc = await zoneRef.get();
        const existingPrices = zoneDoc.exists
          ? (zoneDoc.data()?.prices as Record<string, any> || {})
          : {};

        const pricesMap: Record<string, any> = { ...existingPrices };
        for (const price of prices) {
          if (!config.overwriteExisting && pricesMap[price.productId]) {
            console.log(
              `Skipping price update for zone ${zoneId}, product ${price.productId} (already exists)`,
            );
            continue;
          }
          pricesMap[price.productId] = {
            unit_price: price.unitPrice,
            deliverable: price.deliverable,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          };
          updatedPrices += 1;
        }

        await zoneRef.update({
          prices: pricesMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Update subcollection structure
        const pricesRef = zoneRef.collection('PRICES');
        for (const price of prices) {
          const priceDocRef = pricesRef.doc(price.productId);
          const priceDoc = await priceDocRef.get();

          if (!config.overwriteExisting && priceDoc.exists) {
            console.log(
              `Skipping price update for zone ${zoneId}, product ${price.productId} (already exists)`,
            );
            continue;
          }

          // Get product name for denormalization
          const productDoc = await targetDb
            .collection('ORGANIZATIONS')
            .doc(config.targetOrgId)
            .collection('PRODUCTS')
            .doc(price.productId)
            .get();
          const productName = productDoc.exists
            ? (productDoc.data()?.name as string || '')
            : '';

          await priceDocRef.set(
            {
              product_id: price.productId,
              product_name: productName,
              unit_price: price.unitPrice,
              deliverable: price.deliverable,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
          updatedPrices += 1;
        }
      }

      updatedZones += 1;
      if (updatedZones % 10 === 0) {
        console.log(`Updated ${updatedZones}/${zoneMap.size} zones...`);
      }
    } catch (error) {
      console.error(`Error updating zone ${zoneId}:`, error);
      skipped += 1;
    }
  }

  console.log(`\n=== Migration Complete ===`);
  console.log(`Total rows processed: ${processed}`);
  console.log(`Zones updated: ${updatedZones}`);
  console.log(`Prices updated: ${updatedPrices}`);
  if (skipped > 0) {
    console.log(`Skipped ${skipped} zones (errors)`);
  }
  if (skippedInvalid > 0) {
    console.log(`Skipped ${skippedInvalid} invalid rows`);
  }
}

migrateLocationPricing().catch((error) => {
  console.error('Location pricing migration failed:', error);
  process.exitCode = 1;
});

