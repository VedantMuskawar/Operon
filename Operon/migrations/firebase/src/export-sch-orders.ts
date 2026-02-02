/**
 * SCH_ORDERS Export Script - From Legacy Database
 * 
 * Exports complete SCH_ORDERS collection from Legacy (Pave) Firebase project to Excel.
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
  collectionName: string;
  outputPath: string;
}

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

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  const outputPath =
    resolvePath(process.env.OUTPUT_PATH) ??
    path.join(process.cwd(), 'data', `sch-orders-export-${timestamp}.xlsx`);

  const collectionName = process.env.COLLECTION_NAME || 'SCH_ORDERS';

  return {
    legacyServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    collectionName,
    outputPath,
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

function timestampToDate(timestamp: admin.firestore.Timestamp | null | undefined): string {
  if (!timestamp) return '';
  if (timestamp instanceof admin.firestore.Timestamp) {
    return timestamp.toDate().toISOString();
  }
  if (typeof timestamp === 'object' && timestamp !== null && '_seconds' in timestamp) {
    return new Date((timestamp as any)._seconds * 1000).toISOString();
  }
  return '';
}

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

function flattenDocument(docId: string, data: any): Record<string, any> {
  const row: Record<string, any> = {
    'Document ID': docId,
  };

  for (const [key, value] of Object.entries(data)) {
    if (key.startsWith('_')) continue;
    row[key] = valueToString(value);
  }

  return row;
}

async function exportSchOrders() {
  const config = resolveConfig();
  const legacy = initApp(config);
  const legacyDb = legacy.firestore();

  console.log('=== Exporting SCH_ORDERS from Legacy Database ===');
  console.log('Collection:', config.collectionName);
  console.log('Output file:', config.outputPath);
  console.log('');

  let allOrders: admin.firestore.QueryDocumentSnapshot[] = [];
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;

  while (true) {
    let query: admin.firestore.Query = legacyDb.collection(config.collectionName);
    
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    
    const snapshot = await query.limit(1000).get();
    
    if (snapshot.empty) break;
    
    allOrders = allOrders.concat(snapshot.docs);
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    
    console.log(`Fetched batch ${batchCount}: ${snapshot.size} orders (total: ${allOrders.length})`);
    
    if (snapshot.size < 1000) break;
  }

  console.log(`\nTotal SCH_ORDERS fetched: ${allOrders.length}`);

  if (allOrders.length === 0) {
    console.log('No SCH_ORDERS found in collection:', config.collectionName);
    return;
  }

  const rows = allOrders.map((doc) => flattenDocument(doc.id, doc.data()));

  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'SCH_ORDERS');

  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  XLSX.writeFile(workbook, config.outputPath);

  console.log(`\n=== Export Complete ===`);
  console.log(`Total SCH_ORDERS exported: ${allOrders.length}`);
  console.log(`Output file: ${config.outputPath}`);
}

exportSchOrders().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});
