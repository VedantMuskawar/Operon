/**
 * EMPLOYEES Export Script - From Target Project
 * 
 * Exports all EMPLOYEES from the Target (Operon) Firebase project to Excel.
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
    path.join(process.cwd(), 'data/employees-export.xlsx');

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

async function exportEmployees() {
  const config = resolveConfig();
  const target = initApp(config);
  const targetDb = target.firestore();

  console.log('=== Exporting EMPLOYEES from Target Project ===');
  console.log('Output file:', config.outputPath);
  if (config.targetOrgId) {
    console.log('Target Org ID:', config.targetOrgId);
  }
  console.log('');

  // Fetch all employees
  console.log('Fetching employees from Target project...');
  let allEmployees: admin.firestore.QueryDocumentSnapshot[] = [];
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;

  while (true) {
    let query: admin.firestore.Query = targetDb.collection('EMPLOYEES');
    
    // If orgId filter is provided, use it
    if (config.targetOrgId) {
      query = query.where('organizationId', '==', config.targetOrgId);
    }
    
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    
    const snapshot = await query.limit(1000).get();
    
    if (snapshot.empty) break;
    
    allEmployees = allEmployees.concat(snapshot.docs);
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    
    console.log(`Fetched batch ${batchCount}: ${snapshot.size} employees (total: ${allEmployees.length})`);
    
    if (snapshot.size < 1000) break; // Last batch
  }

  console.log(`\nTotal employees fetched: ${allEmployees.length}`);

  if (allEmployees.length === 0) {
    console.log('No employees found to export');
    return;
  }

  // Convert to Excel rows
  console.log('Converting to Excel format...');
  const rows = allEmployees.map((doc) => {
    const data = doc.data();
    
    // Extract wage information
    const wage = data.wage || {};
    const wageType = wage.type || '';
    const wageBaseAmount = wage.baseAmount || '';
    const wageRate = wage.rate || '';
    
    // Extract job roles
    const jobRoleIds = Array.isArray(data.jobRoleIds) ? data.jobRoleIds.join(', ') : '';
    const jobRoles = data.jobRoles || {};
    const jobRolesList = Object.values(jobRoles).map((role: any) => 
      `${role.jobRoleTitle || ''}${role.isPrimary ? ' (Primary)' : ''}`
    ).join(', ');
    
    return {
      'Document ID': doc.id,
      'Employee ID': data.employeeId || doc.id,
      'Employee Name': data.employeeName || '',
      'Organization ID': data.organizationId || '',
      'Job Role IDs': jobRoleIds,
      'Job Roles': jobRolesList,
      'Wage Type': wageType,
      'Wage Base Amount': wageBaseAmount,
      'Wage Rate': wageRate,
      'Opening Balance': data.openingBalance || 0,
      'Current Balance': data.currentBalance || 0,
      'Created At': data.createdAt ? timestampToDate(data.createdAt)?.toISOString() || '' : '',
      'Updated At': data.updatedAt ? timestampToDate(data.updatedAt)?.toISOString() || '' : '',
    };
  });

  // Create workbook and worksheet
  const worksheet = XLSX.utils.json_to_sheet(rows);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'EMPLOYEES');

  // Ensure output directory exists
  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write to file
  console.log(`Writing to ${config.outputPath}...`);
  XLSX.writeFile(workbook, config.outputPath);

  console.log(`\n=== Export Complete ===`);
  console.log(`Total employees exported: ${allEmployees.length}`);
  console.log(`Output file: ${config.outputPath}`);
}

exportEmployees().catch((error) => {
  console.error('Export failed:', error);
  process.exitCode = 1;
});



