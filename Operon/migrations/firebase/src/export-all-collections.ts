/**
 * Export All Collections from Legacy Database
 * 
 * Exports complete collections: CLIENTS, SCH_ORDERS, TRANSACTIONS, DELIVERY_MEMOS
 * from Legacy (Pave) Firebase project to Excel files.
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
  outputDir: string;
}

const COLLECTIONS = [
  { name: 'CLIENTS', fileName: 'clients-export' },
  { name: 'SCH_ORDERS', fileName: 'sch-orders-export' },
  { name: 'TRANSACTIONS', fileName: 'transactions-export' },
  { name: 'DELIVERY_MEMOS', fileName: 'delivery-memos-export' },
];

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

  const outputDir =
    resolvePath(process.env.OUTPUT_DIR) ??
    path.join(process.cwd(), 'data');

  return {
    legacyServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    outputDir,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: ExportConfig): admin.app.App {
  const serviceAccount = readServiceAccount(config.legacyServiceAccount);
  
  return admin.initializeApp(
    {
      credential: admin.credential.cert(serviceAccount),
      projectId: config.legacyProjectId || serviceAccount.project_id,
    },
    'legacy',
  );
}

/**
 * Convert Firestore Timestamp to ISO date string
 */
function timestampToDate(timestamp: admin.firestore.Timestamp | null | undefined): string {
  if (!timestamp) return '';
  if (timestamp instanceof admin.firestore.Timestamp) {
    return timestamp.toDate().toISOString();
  }
  // Handle serialized timestamp format
  if (typeof timestamp === 'object' && timestamp !== null && '_seconds' in timestamp) {
    return new Date((timestamp as any)._seconds * 1000).toISOString();
  }
  return '';
}

/**
 * Convert any value to string for Excel
 */
function valueToString(value: any): string {
  if (value === null || value === undefined) return '';
  if (value instanceof admin.firestore.Timestamp) {
    return timestampToDate(value);
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (Array.isArray(value)) {
    return JSON.stringify(value);
  }
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
}

/**
 * Flatten document data for Excel export
 */
function flattenDocument(docId: string, data: any): Record<string, any> {
  const row: Record<string, any> = {
    'Document ID': docId,
  };

  // Add all fields from document
  for (const [key, value] of Object.entries(data)) {
    if (key.startsWith('_')) continue; // Skip internal fields
    
    // Convert value to string format
    if (value === null || value === undefined) {
      row[key] = '';
    } else if (value instanceof admin.firestore.Timestamp) {
      row[key] = timestampToDate(value);
    } else if (value instanceof Date) {
      row[key] = value.toISOString();
    } else if (Array.isArray(value)) {
      row[key] = JSON.stringify(value);
    } else if (typeof value === 'object') {
      row[key] = JSON.stringify(value);
    } else {
      row[key] = value;
    }
  }

  return row;
}

/**
 * Export a collection to Excel
 */
async function exportCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  outputPath: string,
): Promise<number> {
  console.log(`\n=== Exporting ${collectionName} ===`);
  console.log(`Output: ${outputPath}`);

  let allDocs: admin.firestore.QueryDocumentSnapshot[] = [];
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;

  // Fetch all documents in batches
  while (true) {
    let query: admin.firestore.Query = db.collection(collectionName);
    
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    
    const snapshot = await query.limit(1000).get();
    
    if (snapshot.empty) break;
    
    allDocs = allDocs.concat(snapshot.docs);
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    
    console.log(`  Fetched batch ${batchCount}: ${snapshot.size} documents (total: ${allDocs.length})`);
    
    if (snapshot.size < 1000) break; // Last batch
  }

  console.log(`  Total documents: ${allDocs.length}`);

  if (allDocs.length === 0) {
    console.log(`  No documents found in ${collectionName}`);
    return 0;
  }

  // Convert to Excel rows
  console.log('  Converting to Excel format...');
  const rows = allDocs.map((doc) => flattenDocument(doc.id, doc.data()));

  // Create workbook and worksheet
  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, collectionName);

  // Ensure output directory exists
  const outputDir = path.dirname(outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write to file
  XLSX.writeFile(workbook, outputPath);
  console.log(`  ✓ Exported ${allDocs.length} documents to ${outputPath}`);

  return allDocs.length;
}

async function exportAllCollections() {
  const config = resolveConfig();
  const legacy = initApp(config);
  const legacyDb = legacy.firestore();

  console.log('=== Exporting All Collections from Legacy Database ===');
  console.log('Legacy Service Account:', config.legacyServiceAccount);
  console.log('Output Directory:', config.outputDir);
  console.log('');

  // Create timestamp for file naming
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  
  const results: Array<{ collection: string; count: number; file: string }> = [];

  // Export each collection
  for (const collection of COLLECTIONS) {
    try {
      const outputPath = path.join(
        config.outputDir,
        `${collection.fileName}-${timestamp}.xlsx`,
      );

      const count = await exportCollection(legacyDb, collection.name, outputPath);
      
      results.push({
        collection: collection.name,
        count,
        file: path.basename(outputPath),
      });
    } catch (error: any) {
      console.error(`\n✗ Error exporting ${collection.name}:`, error.message);
      results.push({
        collection: collection.name,
        count: 0,
        file: 'ERROR',
      });
    }
  }

  // Print summary
  console.log('\n=== Export Summary ===');
  console.table(results);
  
  const totalDocs = results.reduce((sum, r) => sum + r.count, 0);
  console.log(`\nTotal documents exported: ${totalDocs}`);
  console.log(`\nFiles saved in: ${config.outputDir}`);
}

exportAllCollections().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});
