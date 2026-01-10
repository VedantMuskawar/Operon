/**
 * DELIVERY_MEMOS Migration Script - From Excel
 * 
 * Migrates delivery memo data from Excel file to the Operon Firebase project.
 * 
 * Before running:
 * 1. Review and fill in DELIVERY_MEMOS_MIGRATION_MAPPING.md with Excel column mappings
 * 2. Update column mappings in this script based on the mapping document
 * 3. Place Excel file in data/delivery-memos.xlsx or set EXCEL_FILE_PATH environment variable
 * 4. Ensure Firestore indexes are created if needed
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
  overwriteExisting: boolean;
  skipInvalidRows: boolean;
}

const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS'; // Default target organization ID

// Financial year calculation (matches functions/src/shared/financial-year.ts)
interface FinancialContext {
  fyLabel: string;
  fyStart: Date;
  fyEnd: Date;
}

function getFinancialContext(date: Date): FinancialContext {
  const month = date.getUTCMonth(); // 0-based
  const year = date.getUTCFullYear();
  const fyStartYear = month >= 3 ? year : year - 1; // FY starts in April
  const fyLabel = `FY${String(fyStartYear % 100).padStart(2, '0')}${String(
    (fyStartYear + 1) % 100,
  ).padStart(2, '0')}`;

  const fyStart = new Date(Date.UTC(fyStartYear, 3, 1, 0, 0, 0));
  const fyEnd = new Date(Date.UTC(fyStartYear + 1, 3, 1, 0, 0, 0));

  return { fyLabel, fyStart, fyEnd };
}

function resolveConfig(): MigrationConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  // Excel file path
  const excelFilePath =
    resolvePath(process.env.EXCEL_FILE_PATH) ??
    path.join(process.cwd(), 'data/delivery-memos.xlsx');

  if (!fs.existsSync(excelFilePath)) {
    throw new Error(
      `Excel file not found: ${excelFilePath}\n\n` +
        'Please place the Excel file at:\n' +
        `  - ${path.join(process.cwd(), 'data/delivery-memos.xlsx')}\n\n` +
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
 * Handles Excel serial dates, ISO strings, and common date formats
 */
function parseDate(value: any): Date | null {
  if (!value) return null;

  // If it's already a Date object
  if (value instanceof Date) {
    return value;
  }

  // If it's a number (Excel serial date)
  if (typeof value === 'number') {
    // Excel serial date: days since January 1, 1900
    // JavaScript Date uses milliseconds since January 1, 1970
    // Excel epoch: 1900-01-01, but Excel incorrectly treats 1900 as a leap year
    // So we need to adjust: (value - 2) * 86400000 + new Date('1900-01-01').getTime()
    const excelEpoch = new Date('1899-12-30').getTime();
    const jsDate = new Date(excelEpoch + value * 86400000);
    return jsDate;
  }

  // If it's a string, try to parse it
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;

    // Try ISO format first
    const isoDate = new Date(trimmed);
    if (!isNaN(isoDate.getTime())) {
      return isoDate;
    }

    // Try common formats: DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY
    const formats = [
      /^(\d{1,2})\/(\d{1,2})\/(\d{4})/, // DD/MM/YYYY or MM/DD/YYYY
      /^(\d{1,2})-(\d{1,2})-(\d{4})/,   // DD-MM-YYYY
      /^(\d{4})-(\d{1,2})-(\d{1,2})/,   // YYYY-MM-DD
    ];

    for (const format of formats) {
      const match = trimmed.match(format);
      if (match) {
        let day: number, month: number, year: number;
        if (format === formats[2]) {
          // YYYY-MM-DD
          year = parseInt(match[1], 10);
          month = parseInt(match[2], 10) - 1;
          day = parseInt(match[3], 10);
        } else {
          // DD/MM/YYYY or MM/DD/YYYY or DD-MM-YYYY
          const part1 = parseInt(match[1], 10);
          const part2 = parseInt(match[2], 10);
          const part3 = parseInt(match[3], 10);

          // Try to determine format (assume DD/MM/YYYY if day > 12)
          if (part1 > 12) {
            day = part1;
            month = part2 - 1;
            year = part3;
          } else {
            // Could be MM/DD/YYYY, but we'll default to DD/MM/YYYY
            day = part2;
            month = part1 - 1;
            year = part3;
          }
        }

        const date = new Date(year, month, day);
        if (!isNaN(date.getTime())) {
          return date;
        }
      }
    }
  }

  return null;
}

/**
 * Normalize phone number to E.164 format
 */
function normalizePhone(phone: string | null | undefined): string | null {
  if (!phone) return null;
  const cleaned = String(phone).trim().replace(/\D/g, ''); // Remove non-digits
  if (!cleaned) return null;

  // If it starts with country code, use as is
  if (cleaned.startsWith('91') && cleaned.length === 12) {
    return `+${cleaned}`;
  }
  // If it's 10 digits (Indian number), add +91
  if (cleaned.length === 10) {
    return `+91${cleaned}`;
  }
  // If it already has +, return as is
  if (String(phone).startsWith('+')) {
    return String(phone);
  }

  return cleaned;
}

/**
 * Parse items from Excel cell
 * Supports JSON string or returns empty array
 */
function parseItems(value: any): any[] {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

/**
 * Get day name from date
 */
function getDayName(date: Date): string {
  const days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  return days[date.getDay()];
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
 * Delete existing DELIVERY_MEMOS data for the target organization
 */
async function deleteExistingDeliveryMemos(
  targetDb: admin.firestore.Firestore,
  targetOrgId: string,
) {
  console.log('\n=== Deleting existing DELIVERY_MEMOS data ===');
  console.log('Target Org ID:', targetOrgId);

  // Delete all delivery memos for the target organization
  const snapshot = await targetDb
    .collection('DELIVERY_MEMOS')
    .where('organizationId', '==', targetOrgId)
    .get();

  if (snapshot.empty) {
    console.log('No existing delivery memos found to delete.');
    return;
  }

  console.log(`Found ${snapshot.size} existing delivery memo documents to delete`);

  const batchSize = 400;
  let deleted = 0;
  let batch = targetDb.batch();

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    deleted += 1;

    if (deleted % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Deleted ${deleted} delivery memo docs...`);
    }
  }

  if (deleted % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`Cleanup complete. Total delivery memos deleted: ${deleted}\n`);
}

/**
 * Get or create financial year document and get next DM number
 */
async function getOrCreateFYDocument(
  db: admin.firestore.Firestore,
  organizationId: string,
  financialYear: string,
  scheduledDate: Date,
): Promise<number> {
  const fyRef = db
    .collection('ORGANIZATIONS')
    .doc(organizationId)
    .collection('DM')
    .doc(financialYear);

  const fyDoc = await fyRef.get();

  if (fyDoc.exists) {
    const fyData = fyDoc.data()!;
    return (fyData.currentDMNumber as number) || 0;
  } else {
    // Create FY document
    const fyContext = getFinancialContext(scheduledDate);
    const fyStart = new Date(fyContext.fyStart);
    const fyEnd = new Date(fyContext.fyEnd);

    await fyRef.set({
      startDMNumber: 1,
      currentDMNumber: 0,
      previousFYStartDMNumber: null,
      previousFYEndDMNumber: null,
      financialYear: financialYear,
      startDate: fyStart,
      endDate: fyEnd,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return 0;
  }
}

/**
 * Check if DM already exists
 */
async function dmExists(
  db: admin.firestore.Firestore,
  financialYear: string,
  dmNumber: number,
): Promise<boolean> {
  const snapshot = await db
    .collection('DELIVERY_MEMOS')
    .where('financialYear', '==', financialYear)
    .where('dmNumber', '==', dmNumber)
    .limit(1)
    .get();

  return !snapshot.empty;
}

/**
 * Transform Excel row to DeliveryMemo document
 * 
 * TODO: Update column mappings based on your Excel file structure
 * Fill in the Excel column names in the mapping below
 */
function transformRow(
  row: Record<string, any>,
  targetOrgId: string,
  financialYear: string,
  dmNumber: number,
): firestore.DocumentData | null {
  // TODO: Update these column names to match your Excel file
  // Example mappings - replace with actual column names from your Excel
  
  // Required fields
  // Use DATE column (based on mapping document)
  const scheduledDate = parseDate(
    row['DATE'] || row['Scheduled Date'] || row['scheduledDate'] || row['Date'],
  );
  if (!scheduledDate) {
    console.warn('Skipping row: missing scheduledDate (DATE column)', row);
    return null;
  }

  // Get client name from CLIENT column (based on mapping document)
  const clientNameRaw =
    row['CLIENT'] || row['Client Name'] || row['clientName'] || row['Customer Name'] || '';
  
  // Check if this is a cancelled DM (CLIENT column contains "CANCAL D M")
  const isCancelledByClient = clientNameRaw && 
    String(clientNameRaw).toUpperCase().trim().includes('CANCAL D M');
  
  // For cancelled DMs, use a default name
  // For regular DMs, use the actual client name
  const clientName = isCancelledByClient ? 'Cancelled DM' : clientNameRaw;
  
  if (!clientNameRaw) {
    console.warn('Skipping row: missing CLIENT/clientName', row);
    return null;
  }

  // Optional fields with defaults
  const dmId = `DM/${financialYear}/${dmNumber}`;
  const tripId = row['Trip ID'] || row['tripId'] || '';
  const scheduleTripId =
    row['Schedule Trip ID'] || row['scheduleTripId'] || '';
  const orderId = row['Order ID'] || row['orderId'] || '';
  const clientId = row['Client ID'] || row['clientId'] || '';
  const customerNumber = normalizePhone(
    row['Customer Number'] ||
      row['customerNumber'] ||
      row['Phone'] ||
      row['phone'],
  );

  const scheduledDay = getDayName(scheduledDate);
  const vehicleId = row['Vehicle ID'] || row['vehicleId'] || '';
  const vehicleNumber =
    row['VehicleNO'] || // Based on mapping document
    row['Vehicle Number'] ||
    row['vehicleNumber'] ||
    row['Vehicle'] ||
    '';
  const slot = parseInt(row['Slot'] || row['slot'] || '0', 10) || 0;
  const slotName = row['Slot Name'] || row['slotName'] || '';

  const driverId = row['Driver ID'] || row['driverId'] || null;
  const driverName = row['Driver Name'] || row['driverName'] || null;
  const driverPhone = normalizePhone(
    row['Driver Phone'] || row['driverPhone'] || null,
  );

  // Delivery zone
  const deliveryZone = {
    zoneId: row['Zone ID'] || row['zoneId'] || '',
    city: row['City'] || row['city'] || '',
    region: row['Region'] || row['region'] || '',
  };

  // Parse Items from Excel columns: Product, Quantity, Unit
  const productRaw = String(row['Product'] || row['product'] || '').trim();
  const quantityRaw = row['Quantity'] || row['quantity'] || '0';
  const unitRaw = row['Unit'] || row['unit'] || '0';

  // Check if Unit = "1" means cancelled (DM-level cancellation indicator)
  const isCancelledByUnit = String(unitRaw).trim() === '1';

  // Parse quantity and unit price
  // If Unit = "1" indicates cancellation, we still parse it as unitPrice = 1
  const fixedQuantityPerTrip = parseFloat(String(quantityRaw)) || 0;
  const unitPrice = parseFloat(String(unitRaw)) || 0;

  // DM is cancelled if either CLIENT contains "CANCAL D M" OR Unit = "1"
  const isCancelled = isCancelledByClient || isCancelledByUnit;

  // Determine productName and productId based on Product column
  let productName = productRaw;
  let productId = '';
  
  if (productRaw && productRaw.toUpperCase().includes('BRICKS')) {
    productName = 'Bricks';
    productId = '1765277893839';
  }

  // Calculate pricing
  const calculatedSubtotal = unitPrice * fixedQuantityPerTrip;
  const calculatedTotal = unitPrice * fixedQuantityPerTrip;

  // Build items array
  const items: any[] = [];
  if (productRaw && fixedQuantityPerTrip > 0) {
    items.push({
      productId: productId || '',
      productName: productName || productRaw,
      fixedQuantityPerTrip: fixedQuantityPerTrip,
      quantity: fixedQuantityPerTrip, // Also set quantity field
      unitPrice: unitPrice,
      subtotal: calculatedSubtotal,
      gstAmount: 0, // Default to 0 if not provided
      total: calculatedTotal,
    });
  }

  // Calculate trip pricing
  const tripPricing = {
    subtotal: calculatedSubtotal,
    gstAmount: 0, // Default to 0 if not provided
    total: calculatedTotal,
  };

  // Calculate order pricing
  const pricing = {
    subtotal: calculatedSubtotal,
    totalGst: 0, // Default to 0 if not provided
    totalAmount: calculatedTotal,
    currency: 'INR',
  };

  // Status fields
  const priority =
    row['Priority'] || row['priority'] || 'normal';
  const paymentType =
    row['Payment Type'] || row['paymentType'] || '';
  
  // Set status: 'cancelled' if CLIENT contains "CANCAL D M" OR Unit = "1", otherwise 'active'
  const status = isCancelled ? 'cancelled' : (row['Status'] || row['status'] || 'active');
  
  // tripStatus: If active DM, always set to "returned", otherwise use provided value or default
  const tripStatus = status === 'active' 
    ? 'returned' 
    : (row['Trip Status'] || row['tripStatus'] || (isCancelled ? 'cancelled' : 'scheduled'));
  
  const orderStatus =
    row['Order Status'] || row['orderStatus'] || 'pending';

  // Build the base document
  const baseDocument = {
    dmId,
    dmNumber,
    tripId,
    scheduleTripId,
    financialYear,
    organizationId: targetOrgId,
    orderId,

    clientId,
    clientName,
    customerNumber: customerNumber || '',

    scheduledDate: admin.firestore.Timestamp.fromDate(scheduledDate),
    scheduledDay,
    vehicleId,
    vehicleNumber,
    slot,
    slotName,

    driverId,
    driverName,
    driverPhone,

    deliveryZone,

    items,
    pricing,
    tripPricing: tripPricing.total > 0 ? tripPricing : null,

    priority,
    paymentType,
    tripStatus,
    orderStatus,
    status,

    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    generatedBy: 'excel_migration',
    source: 'excel_migration',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Add cancelled fields if this is a cancelled DM
  if (isCancelled) {
    let cancellationReason = 'Cancelled DM from Excel migration';
    if (isCancelledByClient && isCancelledByUnit) {
      cancellationReason = 'Cancelled DM from Excel migration (CLIENT column contained "CANCAL D M" and Unit = "1")';
    } else if (isCancelledByClient) {
      cancellationReason = 'Cancelled DM from Excel migration (CLIENT column contained "CANCAL D M")';
    } else if (isCancelledByUnit) {
      cancellationReason = 'Cancelled DM from Excel migration (Unit = "1")';
    }
    
    return {
      ...baseDocument,
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: 'excel_migration',
      cancellationReason: cancellationReason,
    };
  }

  return baseDocument;
}

async function migrateDeliveryMemos() {
  const config = resolveConfig();
  const target = initApp(config);

  const targetDb = target.firestore();

  console.log('=== Migrating DELIVERY_MEMOS from Excel ===');
  console.log('Excel file:', config.excelFilePath);
  console.log('Sheet:', config.excelSheetName || 'First sheet');
  console.log('Target Org ID:', config.targetOrgId);
  console.log('Overwrite existing:', config.overwriteExisting);
  console.log('Skip invalid rows:', config.skipInvalidRows);
  console.log('');

  // Delete existing delivery memos before migration
  await deleteExistingDeliveryMemos(targetDb, config.targetOrgId);

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
  let skippedExisting = 0;
  const batchSize = 400;
  let batch = targetDb.batch();

  // Track financial year documents to update
  const fyUpdates: Map<
    string,
    { ref: admin.firestore.DocumentReference; maxDMNumber: number }
  > = new Map();

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const rowNum = i + 2; // +2 because Excel rows are 1-indexed and first row is header

    try {
      // Parse scheduled date to determine financial year
      // Use DATE column (based on mapping document)
      const scheduledDate = parseDate(
        row['DATE'] || row['Scheduled Date'] || row['scheduledDate'] || row['Date'],
      );
      if (!scheduledDate) {
        if (config.skipInvalidRows) {
          console.warn(
            `Row ${rowNum}: Skipping - missing scheduledDate (DATE column)`,
          );
          skippedInvalid += 1;
          continue;
        } else {
          throw new Error(`Row ${rowNum}: Missing required field: scheduledDate (DATE column)`);
        }
      }

      const fyContext = getFinancialContext(scheduledDate);
      const financialYear = fyContext.fyLabel;

      // Get or determine DM number
      // Use DM_NO column (based on mapping document)
      let dmNumber: number;
      if (row['DM_NO'] || row['DM Number'] || row['dmNumber']) {
        dmNumber = parseInt(
          String(row['DM_NO'] || row['DM Number'] || row['dmNumber']),
          10,
        );
        if (isNaN(dmNumber)) {
          console.warn(`Row ${rowNum}: Invalid DM number, will auto-generate`);
          dmNumber = 0; // Will be determined below
        }
      } else {
        dmNumber = 0; // Will be determined below
      }

      // If DM number not provided, get next number from FY document
      if (dmNumber === 0) {
        const currentDMNumber = await getOrCreateFYDocument(
          targetDb,
          config.targetOrgId,
          financialYear,
          scheduledDate,
        );
        dmNumber = currentDMNumber + 1;

        // Track for update
        const fyRef = targetDb
          .collection('ORGANIZATIONS')
          .doc(config.targetOrgId)
          .collection('DM')
          .doc(financialYear);
        const existing = fyUpdates.get(financialYear);
        if (!existing || dmNumber > existing.maxDMNumber) {
          fyUpdates.set(financialYear, { ref: fyRef, maxDMNumber: dmNumber });
        }
      }

      // Check if DM already exists
      if (!config.overwriteExisting) {
        const exists = await dmExists(targetDb, financialYear, dmNumber);
        if (exists) {
          console.warn(
            `Row ${rowNum}: DM ${financialYear}/${dmNumber} already exists, skipping`,
          );
          skippedExisting += 1;
          continue;
        }
      }

      // Transform row to document
      const transformed = transformRow(
        row,
        config.targetOrgId,
        financialYear,
        dmNumber,
      );

      if (!transformed) {
        if (config.skipInvalidRows) {
          console.warn(`Row ${rowNum}: Skipping - transformation returned null`);
          skippedInvalid += 1;
          continue;
        } else {
          throw new Error(`Row ${rowNum}: Failed to transform row`);
        }
      }

      // Log if this is a cancelled DM
      if (transformed.status === 'cancelled') {
        console.log(`Row ${rowNum}: Creating cancelled DM ${financialYear}/${dmNumber}`);
      }

      // Add to batch
      const dmRef = targetDb.collection('DELIVERY_MEMOS').doc();
      batch.set(dmRef, transformed);
      processed += 1;

      // Commit batch if needed
      if (processed % batchSize === 0) {
        await batch.commit();
        batch = targetDb.batch();
        console.log(`Committed ${processed} delivery memo docs...`);
      }
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

  // Commit remaining batch
  if (processed % batchSize !== 0) {
    await batch.commit();
  }

  // Update financial year documents
  console.log('\nUpdating financial year documents...');
  for (const [fy, update] of fyUpdates.entries()) {
    await update.ref.update({
      currentDMNumber: update.maxDMNumber,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`Updated ${fy}: currentDMNumber = ${update.maxDMNumber}`);
  }

  console.log(`\n=== Migration Complete ===`);
  console.log(`Total rows processed: ${processed}`);
  if (skipped > 0) {
    console.log(`Skipped ${skipped} rows`);
  }
  if (skippedInvalid > 0) {
    console.log(`Skipped ${skippedInvalid} invalid rows`);
  }
  if (skippedExisting > 0) {
    console.log(`Skipped ${skippedExisting} existing DMs (use OVERWRITE_EXISTING=true to overwrite)`);
  }
}

migrateDeliveryMemos().catch((error) => {
  console.error('Delivery memo migration failed:', error);
  process.exitCode = 1;
});

