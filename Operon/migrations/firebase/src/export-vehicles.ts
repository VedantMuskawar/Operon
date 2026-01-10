/**
 * VEHICLES Export Script - From Target Project
 * 
 * Exports all VEHICLES from the Target (Operon) Firebase project to Excel.
 * VEHICLES are stored as subcollections: ORGANIZATIONS/{orgId}/VEHICLES/{vehicleId}
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
  targetOrgId?: string;
  outputPath: string;
}

const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS';

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
    path.join(process.cwd(), 'data/vehicles-export.xlsx');

  return {
    newServiceAccount,
    newProjectId: process.env.NEW_PROJECT_ID,
    targetOrgId: process.env.TARGET_ORG_ID ?? FALLBACK_TARGET_ORG,
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

async function exportVehicles() {
  const config = resolveConfig();
  const target = initApp(config);
  const targetDb = target.firestore();

  console.log('=== Exporting VEHICLES from Target Project ===');
  console.log('Output file:', config.outputPath);
  if (config.targetOrgId) {
    console.log('Target Org ID:', config.targetOrgId);
  }
  console.log('');

  let allVehicles: Array<{
    doc: admin.firestore.QueryDocumentSnapshot;
    orgId: string;
  }> = [];

  // If specific org ID is provided, only export from that org
  if (config.targetOrgId) {
    console.log(`Fetching vehicles from organization: ${config.targetOrgId}...`);
    const vehiclesRef = targetDb
      .collection('ORGANIZATIONS')
      .doc(config.targetOrgId)
      .collection('VEHICLES');
    
    let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
    let batchCount = 0;

    while (true) {
      let query: admin.firestore.Query = vehiclesRef;
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      const snapshot = await query.limit(1000).get();
      
      if (snapshot.empty) break;
      
      allVehicles = allVehicles.concat(
        snapshot.docs.map((doc) => ({ doc, orgId: config.targetOrgId! }))
      );
      batchCount += 1;
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      
      console.log(`Fetched batch ${batchCount}: ${snapshot.size} vehicles (total: ${allVehicles.length})`);
      
      if (snapshot.size < 1000) break;
    }
  } else {
    // Export from all organizations
    console.log('Fetching vehicles from all organizations...');
    const orgsSnapshot = await targetDb.collection('ORGANIZATIONS').get();
    console.log(`Found ${orgsSnapshot.size} organizations`);

    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      console.log(`\nFetching vehicles from organization: ${orgId}...`);
      
      const vehiclesRef = targetDb
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('VEHICLES');
      
      let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
      let batchCount = 0;

      while (true) {
        let query: admin.firestore.Query = vehiclesRef;
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }
        const snapshot = await query.limit(1000).get();
        
        if (snapshot.empty) break;
        
        allVehicles = allVehicles.concat(
          snapshot.docs.map((doc) => ({ doc, orgId }))
        );
        batchCount += 1;
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        
        console.log(`  Batch ${batchCount}: ${snapshot.size} vehicles (org total: ${allVehicles.filter(v => v.orgId === orgId).length})`);
        
        if (snapshot.size < 1000) break;
      }
    }
  }

  console.log(`\nTotal vehicles fetched: ${allVehicles.length}`);

  if (allVehicles.length === 0) {
    console.log('No vehicles found to export');
    return;
  }

  // Convert to Excel rows
  console.log('Converting to Excel format...');
  const rows = allVehicles.map(({ doc, orgId }) => {
    const data = doc.data();
    return {
      'Document ID': doc.id,
      'Organization ID': orgId,
      'Vehicle ID': data.vehicleId || doc.id,
      'Vehicle Number': data.vehicleNumber || '',
      'Vehicle Type': data.vehicleType || '',
      'Driver ID': data.driverId || '',
      'Tag': data.tag || '',
      'Is Active': data.isActive !== undefined ? (data.isActive ? 'true' : 'false') : '',
      'Vehicle Capacity': data.vehicleCapacity || '',
      'Weekly Capacity': JSON.stringify(data.weeklyCapacity || {}),
      'Product Capacities': JSON.stringify(data.productCapacities || {}),
      'Insurance Number': data.insuranceNumber || '',
      'Insurance Expiry': data.insuranceExpiry ? timestampToDate(data.insuranceExpiry)?.toISOString() || '' : '',
      'Created At': data.createdAt ? timestampToDate(data.createdAt)?.toISOString() || '' : '',
      'Updated At': data.updatedAt ? timestampToDate(data.updatedAt)?.toISOString() || '' : '',
    };
  });

  // Create workbook and worksheet
  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'VEHICLES');

  // Ensure output directory exists
  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write to file
  console.log(`Writing to ${config.outputPath}...`);
  XLSX.writeFile(workbook, config.outputPath);

  console.log(`\n=== Export Complete ===`);
  console.log(`Total vehicles exported: ${allVehicles.length}`);
  console.log(`Output file: ${config.outputPath}`);
}

exportVehicles().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});

