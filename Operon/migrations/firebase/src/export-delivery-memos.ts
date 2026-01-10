/**
 * DELIVERY_MEMOS Export Script - From Legacy Project
 * 
 * Exports DELIVERY_MEMOS from the Legacy (Pave) Firebase project to Excel.
 * Period range: April 1, 2025 to December 31, 2025 (1/4/25 - 31/12/25)
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

interface ExportConfig {
  legacyServiceAccount: string;
  legacyProjectId?: string;
  legacyOrgId?: string;
  outputPath: string;
}

const FALLBACK_LEGACY_ORG = 'K4Q6vPOuTcLPtlcEwdw0'; // Filter data from old database

function resolveConfig(): ExportConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const legacyServiceAccount =
    resolvePath(process.env.LEGACY_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/legacy-service-account.json');

  if (!fs.existsSync(legacyServiceAccount)) {
    throw new Error(
      `Service account file not found: ${legacyServiceAccount}\n\n` +
        'Please download service account JSON file from Google Cloud Console and place it in:\n' +
        `  - ${path.join(process.cwd(), 'creds/legacy-service-account.json')}\n\n` +
        'Or set LEGACY_SERVICE_ACCOUNT environment variable with full path.',
    );
  }

  const outputPath =
    resolvePath(process.env.OUTPUT_PATH) ??
    path.join(process.cwd(), 'data/delivery-memos-export.xlsx');

  return {
    legacyServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    legacyOrgId: process.env.LEGACY_ORG_ID ?? FALLBACK_LEGACY_ORG,
    outputPath,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: ExportConfig): admin.app.App {
  return admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.legacyServiceAccount),
      ),
      projectId: config.legacyProjectId,
    },
    'legacy',
  );
}

/**
 * Convert Firestore Timestamp to Excel date
 */
function timestampToDate(timestamp: admin.firestore.Timestamp | null | undefined): Date | null {
  if (!timestamp) return null;
  if (timestamp instanceof admin.firestore.Timestamp) {
    return timestamp.toDate();
  }
  // Handle serialized timestamp format
  if (typeof timestamp === 'object' && timestamp !== null && '_seconds' in timestamp) {
    return new Date((timestamp as any)._seconds * 1000);
  }
  return null;
}

/**
 * Convert any date value to milliseconds for comparison
 */
function dateToMillis(dateValue: any): number | null {
  if (!dateValue) return null;
  
  // Firestore Timestamp
  if (dateValue instanceof admin.firestore.Timestamp) {
    return dateValue.toMillis();
  }
  
  // Serialized timestamp format {_seconds, _nanoseconds}
  if (typeof dateValue === 'object' && dateValue !== null && '_seconds' in dateValue) {
    return (dateValue as any)._seconds * 1000 + ((dateValue as any)._nanoseconds || 0) / 1000000;
  }
  
  // Date object
  if (dateValue instanceof Date) {
    return dateValue.getTime();
  }
  
  // String date
  if (typeof dateValue === 'string') {
    const date = new Date(dateValue);
    if (!isNaN(date.getTime())) {
      return date.getTime();
    }
  }
  
  // Number (milliseconds or seconds)
  if (typeof dateValue === 'number') {
    // If it's less than year 2000 in milliseconds, assume it's seconds
    if (dateValue < 946684800000) {
      return dateValue * 1000;
    }
    return dateValue;
  }
  
  return null;
}

/**
 * Convert any value to string for Excel
 */
function valueToString(value: any): string {
  if (value === null || value === undefined) return '';
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return JSON.stringify(value);
  }
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}

async function exportDeliveryMemos() {
  const config = resolveConfig();
  const legacy = initApp(config);
  const legacyDb = legacy.firestore();

  // Date range: April 1, 2025 to December 31, 2025
  const startDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-04-01T00:00:00.000Z'),
  );
  const endDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-12-31T23:59:59.999Z'),
  );

  console.log('=== Exporting DELIVERY_MEMOS from Legacy Project ===');
  console.log('Period range: April 1, 2025 to December 31, 2025');
  console.log('Start date:', startDate.toDate().toISOString());
  console.log('End date:', endDate.toDate().toISOString());
  if (config.legacyOrgId) {
    console.log('Legacy Org ID:', config.legacyOrgId);
  }
  console.log('Output file:', config.outputPath);
  console.log('');

  // Fetch all delivery memos
  console.log('Fetching delivery memos from Legacy project...');
  let allMemos: admin.firestore.QueryDocumentSnapshot[] = [];
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;

  try {
    while (true) {
      let query: admin.firestore.Query = legacyDb.collection('DELIVERY_MEMOS');
      
      // Don't filter by organizationId - legacy project might not have this field
      // If orgId filter is needed, uncomment below (but it might fail if field doesn't exist)
      // if (config.legacyOrgId) {
      //   query = query.where('organizationId', '==', config.legacyOrgId);
      // }
      
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      
      const snapshot = await query.limit(1000).get();
      
      if (snapshot.empty) break;
      
      allMemos = allMemos.concat(snapshot.docs);
      batchCount += 1;
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      
      console.log(`Fetched batch ${batchCount}: ${snapshot.size} memos (total: ${allMemos.length})`);
      
      if (snapshot.size < 1000) break; // Last batch
    }
  } catch (error: any) {
    if (error.code === 5 || error.message?.includes('not found')) {
      console.error('\n❌ ERROR: DELIVERY_MEMOS collection not found in Legacy project!');
      console.error('The DELIVERY_MEMOS collection might not exist in the legacy Pave project.');
      console.error('DELIVERY_MEMOS were migrated FROM Excel, not from the legacy project.');
      console.error('\nPossible solutions:');
      console.error('1. Export DELIVERY_MEMOS from the Target project instead');
      console.error('2. Check if the collection has a different name in the legacy project');
      console.error('3. Verify you have the correct service account and project ID');
      throw error;
    }
    throw error;
  }

  console.log(`\nTotal delivery memos fetched: ${allMemos.length}`);

  if (allMemos.length === 0) {
    console.log('⚠️  WARNING: No documents found in DELIVERY_MEMOS collection');
    console.log('This might mean:');
    console.log('  1. The collection doesn\'t exist in the legacy project');
    console.log('  2. The collection is empty');
    console.log('  3. You don\'t have read permissions');
    return;
  }

  // Log sample document structure for debugging
  if (allMemos.length > 0) {
    const sampleDoc = allMemos[0];
    const sampleData = sampleDoc.data();
    console.log('\nSample document structure (first document):');
    console.log('  Document ID:', sampleDoc.id);
    console.log('  Fields:', Object.keys(sampleData).join(', '));
    console.log('  Date fields found:', Object.keys(sampleData).filter(k => 
      k.toLowerCase().includes('date') || k.toLowerCase().includes('time')
    ).join(', '));
  }

  // Filter by date range in memory - use deliveryDate field (based on sample document)
  const startMillis = startDate.toMillis();
  const endMillis = endDate.toMillis();
  const filteredMemos = allMemos.filter((doc) => {
    const data = doc.data();
    
    // Use deliveryDate field (primary field in legacy structure)
    const deliveryDate = data.deliveryDate;
    const dateMillis = dateToMillis(deliveryDate);
    
    if (dateMillis === null) {
      // If no deliveryDate, try createdAt as fallback
      const createdAt = data.createdAt;
      const createdAtMillis = dateToMillis(createdAt);
      
      if (createdAtMillis === null) {
        // If no date field found, include it anyway (user can filter manually)
        return true;
      }
      return createdAtMillis >= startMillis && createdAtMillis <= endMillis;
    }
    
    return dateMillis >= startMillis && dateMillis <= endMillis;
  });

  console.log(`After date filtering: ${filteredMemos.length} delivery memos`);

  if (filteredMemos.length === 0) {
    console.log('No delivery memos found matching the date range');
    return;
  }

  // Convert to Excel rows - based on actual legacy DELIVERY_MEMOS structure
  console.log('Converting to Excel format...');
  const rows = filteredMemos.map((doc) => {
    const data = doc.data();
    
    // Build row based on actual legacy structure
    const row: Record<string, any> = {
      'Document ID': doc.id,
      'Address': data.address || '',
      'Client ID': data.clientID || data.clientId || '',
      'Client Name': data.clientName || '',
      'Client Phone Number': data.clientPhoneNumber || '',
      'Created At': data.createdAt ? (timestampToDate(data.createdAt)?.toISOString() || valueToString(data.createdAt)) : '',
      'Def Order ID': data.defOrderID || '',
      'Order ID': data.orderID || data.orderId || '',
      'Delivery Date': data.deliveryDate ? (timestampToDate(data.deliveryDate)?.toISOString() || valueToString(data.deliveryDate)) : '',
      'Dispatch Start': data.dispatchStart ? valueToString(data.dispatchStart) : '',
      'Dispatch End': data.dispatchEnd ? valueToString(data.dispatchEnd) : '',
      'DM Number': data.dmNumber || '',
      'Driver Name': data.driverName || '',
      'Org ID': data.orgID || data.organizationId || '',
      'Pay Schedule': data.paySchedule || '',
      'Payment Status': data.paymentStatus !== undefined ? (data.paymentStatus ? 'true' : 'false') : '',
      'Product Name': data.productName || '',
      'Product Quantity': data.productQuant || data.productQuant || 0,
      'Product Unit Price': data.productUnitPrice || 0,
      'Region Name': data.regionName || '',
      'Status': data.status || '',
      'To Account': data.toAccount || '',
      'Vehicle Number': data.vehicleNumber || '',
    };
    
    // Calculate totals if we have quantity and unit price
    if (row['Product Quantity'] && row['Product Unit Price']) {
      row['Subtotal'] = (row['Product Quantity'] as number) * (row['Product Unit Price'] as number);
      row['Total Amount'] = row['Subtotal'];
    }
    
    // Add any additional fields that aren't in the standard schema
    for (const [key, value] of Object.entries(data)) {
      const normalizedKey = key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1').trim();
      if (!row.hasOwnProperty(normalizedKey) && !row.hasOwnProperty(key) && !key.startsWith('_')) {
        row[key] = valueToString(value);
      }
    }
    
    return row;
  });

  // Create workbook and worksheet
  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'DELIVERY_MEMOS');

  // Ensure output directory exists
  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write to file
  console.log(`Writing to ${config.outputPath}...`);
  XLSX.writeFile(workbook, config.outputPath);

  console.log(`\n=== Export Complete ===`);
  console.log(`Total delivery memos exported: ${filteredMemos.length}`);
  console.log(`Output file: ${config.outputPath}`);
}

exportDeliveryMemos().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});

