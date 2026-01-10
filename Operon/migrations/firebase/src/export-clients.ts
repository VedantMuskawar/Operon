/**
 * CLIENTS Export Script - From Target Project
 * 
 * Exports all CLIENTS from the Target (Operon) Firebase project to Excel.
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

interface ExportConfig {
  newServiceAccount: string;
  newProjectId?: string;
  outputPath: string;
}

function resolveConfig(): ExportConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

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

  const outputPath =
    resolvePath(process.env.OUTPUT_PATH) ??
    path.join(process.cwd(), 'data/clients-export.xlsx');

  return {
    newServiceAccount,
    newProjectId: process.env.NEW_PROJECT_ID,
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
        readServiceAccount(config.newServiceAccount),
      ),
      projectId: config.newProjectId,
    },
    'target',
  );
}

/**
 * Convert Firestore Timestamp to Excel date
 */
function timestampToDate(timestamp: admin.firestore.Timestamp | null | undefined): Date | null {
  if (!timestamp) return null;
  return timestamp.toDate();
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

async function exportClients() {
  const config = resolveConfig();
  const target = initApp(config);
  const targetDb = target.firestore();

  console.log('=== Exporting CLIENTS from Target Project ===');
  console.log('Output file:', config.outputPath);
  console.log('');

  // Fetch all clients
  console.log('Fetching clients from Target project...');
  let allClients: admin.firestore.QueryDocumentSnapshot[] = [];
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;

  while (true) {
    let query: admin.firestore.Query = targetDb.collection('CLIENTS');
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snapshot = await query.limit(1000).get();
    
    if (snapshot.empty) break;
    
    allClients = allClients.concat(snapshot.docs);
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    
    console.log(`Fetched batch ${batchCount}: ${snapshot.size} clients (total: ${allClients.length})`);
    
    if (snapshot.size < 1000) break; // Last batch
  }

  console.log(`\nTotal clients fetched: ${allClients.length}`);

  if (allClients.length === 0) {
    console.log('No clients found to export');
    return;
  }

  // Convert to Excel rows
  console.log('Converting to Excel format...');
  const rows = allClients.map((doc) => {
    const data = doc.data();
    return {
      'Document ID': doc.id,
      'Client ID': data.clientId || '',
      'Name': data.name || '',
      'Name (Lowercase)': data.name_lc || '',
      'Organization ID': data.organizationId || '',
      'Primary Phone': data.primaryPhone || '',
      'Primary Phone Normalized': data.primaryPhoneNormalized || '',
      'Phones': JSON.stringify(data.phones || []),
      'Phone Index': JSON.stringify(data.phoneIndex || []),
      'Tags': JSON.stringify(data.tags || []),
      'Contacts': JSON.stringify(data.contacts || []),
      'Status': data.status || '',
      'Orders Count': data.stats?.orders || 0,
      'Lifetime Amount': data.stats?.lifetimeAmount || 0,
      'Created At': data.createdAt ? timestampToDate(data.createdAt)?.toISOString() || '' : '',
      'Updated At': data.updatedAt ? timestampToDate(data.updatedAt)?.toISOString() || '' : '',
    };
  });

  // Create workbook and worksheet
  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'CLIENTS');

  // Ensure output directory exists
  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write to file
  console.log(`Writing to ${config.outputPath}...`);
  XLSX.writeFile(workbook, config.outputPath);

  console.log(`\n=== Export Complete ===`);
  console.log(`Total clients exported: ${allClients.length}`);
  console.log(`Output file: ${config.outputPath}`);
}

exportClients().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});



