/**
 * EMPLOYEES Migration Script - From Pave
 * 
 * Migrates employee data from Pave (legacy Firebase project) to the new Operon Firebase project.
 * Only migrates data up to December 31, 2025 (31.12.25).
 * 
 * Before running:
 * 1. Review and fill in EMPLOYEES_MIGRATION_MAPPING.md with field mappings
 * 2. Update field names in this script based on the mapping document
 * 3. Ensure Firestore indexes are created for the query (organizationId + date field)
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface MigrationConfig {
  legacyServiceAccount: string;
  newServiceAccount: string;
  legacyProjectId?: string;
  newProjectId?: string;
  legacyOrgId: string;
  targetOrgId: string;
}

const FALLBACK_LEGACY_ORG = 'K4Q6vPOuTcLPtlcEwdw0'; // Filter data from old database
const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS'; // Assign this OrgID in target database

// Role mapping from employeeTags to roleId and roleTitle
interface RoleMapping {
  roleId: string;
  roleTitle: string;
}

const ROLE_MAPPING: Record<string, RoleMapping> = {
  loader: {
    roleId: '1767517117335',
    roleTitle: 'Loader',
  },
  production: {
    roleId: '1767517127165',
    roleTitle: 'Production',
  },
  staff: {
    roleId: '1767517567211',
    roleTitle: 'Staff',
  },
  driver: {
    roleId: '1766649058877',
    roleTitle: 'Driver',
  },
};

function resolveConfig(): MigrationConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const legacyServiceAccount =
    resolvePath(process.env.LEGACY_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/legacy-service-account.json');
  const newServiceAccount =
    resolvePath(process.env.NEW_SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/new-service-account.json');

  if (!fs.existsSync(legacyServiceAccount) || !fs.existsSync(newServiceAccount)) {
    const missing = [];
    if (!fs.existsSync(legacyServiceAccount)) {
      missing.push(`Legacy: ${legacyServiceAccount}`);
    }
    if (!fs.existsSync(newServiceAccount)) {
      missing.push(`New: ${newServiceAccount}`);
    }
    throw new Error(
      `Service account files not found:\n${missing.join('\n')}\n\n` +
        'Please download service account JSON files from Google Cloud Console and place them in:\n' +
        `  - ${path.join(process.cwd(), 'creds/legacy-service-account.json')}\n` +
        `  - ${path.join(process.cwd(), 'creds/new-service-account.json')}\n\n` +
        'Or set LEGACY_SERVICE_ACCOUNT and NEW_SERVICE_ACCOUNT environment variables with full paths.',
    );
  }

  return {
    legacyServiceAccount,
    newServiceAccount,
    legacyProjectId: process.env.LEGACY_PROJECT_ID,
    newProjectId: process.env.NEW_PROJECT_ID,
    legacyOrgId: process.env.LEGACY_ORG_ID ?? FALLBACK_LEGACY_ORG,
    targetOrgId: process.env.NEW_ORG_ID ?? FALLBACK_TARGET_ORG,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApps(
  config: MigrationConfig,
): { legacy: admin.app.App; target: admin.app.App } {
  const legacy = admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.legacyServiceAccount),
      ),
      projectId: config.legacyProjectId,
    },
    'legacy',
  );

  const target = admin.initializeApp(
    {
      credential: admin.credential.cert(
        readServiceAccount(config.newServiceAccount),
      ),
      projectId: config.newProjectId,
    },
    'target',
  );

  return { legacy, target };
}

async function deleteExistingEmployees(
  targetDb: admin.firestore.Firestore,
  targetOrgId: string,
) {
  console.log('\n=== Deleting existing EMPLOYEES data ===');
  console.log('Target Org ID:', targetOrgId);

  // Delete all employees for the target organization
  const snapshot = await targetDb
    .collection('EMPLOYEES')
    .where('organizationId', '==', targetOrgId)
    .get();

  if (snapshot.empty) {
    console.log('No existing employees found to delete.');
    return;
  }

  console.log(`Found ${snapshot.size} existing employee documents to delete`);

  const batchSize = 400;
  let deleted = 0;
  let batch = targetDb.batch();

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    deleted += 1;

    if (deleted % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Deleted ${deleted} employee docs...`);
    }
  }

  if (deleted % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`Cleanup complete. Total employees deleted: ${deleted}\n`);
}

/**
 * Map employeeTags to roleId and roleTitle
 */
function mapRole(employeeTags?: string | null): RoleMapping | null {
  if (!employeeTags) return null;
  const tag = String(employeeTags).toLowerCase().trim();
  return ROLE_MAPPING[tag] || null;
}

/**
 * Map salaryTags to wage type
 * - fixed → perMonth
 * - perTrip → perTrip
 * - perBatch → perBatch
 * - default → perMonth
 */
function mapWageType(salaryTags?: string | null): string {
  if (!salaryTags) return 'perMonth';
  const tag = String(salaryTags).toLowerCase().trim();
  
  if (tag === 'fixed') {
    return 'perMonth';
  }
  if (tag === 'pertrip' || tag.includes('trip')) {
    return 'perTrip';
  }
  if (tag === 'perbatch' || tag.includes('batch')) {
    return 'perBatch';
  }
  
  // Default fallback
  return 'perMonth';
}

async function migrateEmployees() {
  const config = resolveConfig();
  const { legacy, target } = initApps(config);

  const legacyDb = legacy.firestore();
  const targetDb = target.firestore();

  // Delete existing employees before migration
  await deleteExistingEmployees(targetDb, config.targetOrgId);

  // Date cutoff: December 31, 2025, 23:59:59 UTC
  const cutoffDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-12-31T23:59:59.999Z'),
  );

  console.log('=== Migrating EMPLOYEES from Pave ===');
  console.log('Cutoff date:', cutoffDate.toDate().toISOString());
  console.log('Legacy Org ID:', config.legacyOrgId);
  console.log('Target Org ID:', config.targetOrgId);
  console.log('Preserving Pave document IDs\n');

  // Fetch all employees from legacy (no org filter since employees might not have orgId field)
  // Date filtering will be done in memory after fetching
  console.log(
    'Fetching employees from Pave (this may take a while for large datasets)...',
  );
  const snapshot = await legacyDb.collection('EMPLOYEES').get();

  console.log(`Fetched ${snapshot.size} total employees from Pave`);

  if (snapshot.empty) {
    console.log('No legacy employees found');
    return;
  }

  // Filter by date in memory (to avoid needing composite index)
  const cutoffMillis = cutoffDate.toMillis();
  const docsToMigrate = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const docDate = data.createdAt as admin.firestore.Timestamp | undefined;
    if (!docDate) return true; // Include if no date (migrate anyway)
    return docDate.toMillis() <= cutoffMillis;
  });

  console.log(
    `After date filtering (<= ${cutoffDate.toDate().toISOString()}): ${docsToMigrate.length} documents to migrate`,
  );

  if (docsToMigrate.length === 0) {
    console.log('No employees found matching the date filter');
    return;
  }

  let processed = 0;
  let skipped = snapshot.size - docsToMigrate.length;
  let skippedInvalid = 0;
  const batchSize = 400;
  let batch = targetDb.batch();

  for (const doc of docsToMigrate) {
    const data = doc.data();

    // Map role from employeeTags
    const employeeTags = data.employeeTags as string | undefined;
    const roleMapping = mapRole(employeeTags);

    if (!roleMapping) {
      console.warn(
        `Skipping employee ${doc.id}: Invalid or missing employeeTags "${employeeTags}". Expected one of: loader, production, staff, driver`,
      );
      skippedInvalid += 1;
      continue;
    }

    // Fetch openingBalance from financialYears subcollection
    // Structure: EMPLOYEES/{employeeId}/financialYears/{financialYear}/openingBalance
    let openingBalance = 0;
    try {
      const financialYearsRef = legacyDb
        .collection('EMPLOYEES')
        .doc(doc.id)
        .collection('financialYears');
      
      // Try to get the 2025-26 financial year document
      const fyDoc = await financialYearsRef.doc('2025-26').get();
      if (fyDoc.exists) {
        const fyData = fyDoc.data();
        openingBalance = (fyData?.openingBalance as number | undefined) ?? 0;
      } else {
        // If 2025-26 doesn't exist, try to get the most recent financial year
        const fySnapshot = await financialYearsRef.orderBy('__name__', 'desc').limit(1).get();
        if (!fySnapshot.empty) {
          const latestFyData = fySnapshot.docs[0].data();
          openingBalance = (latestFyData?.openingBalance as number | undefined) ?? 0;
        }
      }
    } catch (error) {
      console.warn(
        `Warning: Could not fetch openingBalance from financialYears for employee ${doc.id}: ${error}`,
      );
      // Fallback to 0 if subcollection doesn't exist or has errors
      openingBalance = 0;
    }

    const transformed = transformEmployee(
      data,
      config.targetOrgId,
      roleMapping,
      doc.id,
      openingBalance,
    );

    // Preserve Pave's document ID
    const targetRef = targetDb.collection('EMPLOYEES').doc(doc.id);
    // Set employeeId from legacy 'id' field if available, otherwise use document ID
    const legacyId = (data.id as string | undefined) ?? doc.id;
    transformed.employeeId = legacyId;
    batch.set(targetRef, transformed, { merge: true });
    processed += 1;

    if (processed % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Committed ${processed} employee docs...`);
    }
  }

  if (processed % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`\n=== Migration Complete ===`);
  console.log(`Total employees processed: ${processed}`);
  if (skipped > 0) {
    console.log(`Skipped ${skipped} employees (date after cutoff)`);
  }
  if (skippedInvalid > 0) {
    console.log(
      `Skipped ${skippedInvalid} employees (invalid or missing employeeTags)`,
    );
  }
}

/**
 * Transform Pave employee data to Operon EMPLOYEES schema (Web App structure)
 * Field mappings based on EMPLOYEES_MIGRATION_MAPPING.md:
 * - id → employeeId (document ID)
 * - name → employeeName
 * - employeeTags → jobRoleIds, jobRoles (via mapping, all 4 roles with mapped one as primary)
 * - salaryTags → wage.type (via mapping)
 * - salaryValue → wage.baseAmount (converted from paise to rupees)
 * - openingBalance → openingBalance, currentBalance (from financialYears subcollection)
 * - createdAt → createdAt
 * - updatedAt → updatedAt
 */
function transformEmployee(
  data: firestore.DocumentData,
  targetOrgId: string,
  roleMapping: RoleMapping,
  legacyDocId: string,
  openingBalance: number,
): firestore.DocumentData {
  // Extract fields from Pave schema
  const employeeName = (data.name as string | undefined) ?? 'Unnamed Employee';
  const salaryTags = data.salaryTags as string | undefined;
  const salaryValue = data.salaryValue as number | undefined;

  // Map wage type
  const wageType = mapWageType(salaryTags);

  // Convert salaryAmount from paise to rupees (divide by 100)
  const baseAmount = salaryValue != null ? salaryValue / 100 : 0;

  // Build jobRoles structure - assign only the role from employeeTags mapping
  const jobRoleIds: string[] = [roleMapping.roleId];
  const jobRoles: Record<string, any> = {};
  const now = new Date().toISOString();

  // Add only the mapped role as primary
  jobRoles[roleMapping.roleId] = {
    jobRoleId: roleMapping.roleId,
    jobRoleTitle: roleMapping.roleTitle,
    assignedAt: now,
    isPrimary: true,
  };

  // Build wage structure
  const wage: Record<string, any> = {
    type: wageType,
  };
  
  // For perMonth, use baseAmount; for others, could use rate
  if (wageType === 'perMonth' && baseAmount > 0) {
    wage.baseAmount = baseAmount;
  } else if (baseAmount > 0) {
    wage.rate = baseAmount;
  }

  // Build the transformed document matching Operon EMPLOYEES schema (Web App)
  return {
    employeeId: legacyDocId, // Will be set to document ID after migration
    employeeName: employeeName.trim(),
    organizationId: targetOrgId,
    jobRoleIds: jobRoleIds,
    jobRoles: jobRoles,
    wage: wage,
    openingBalance: openingBalance,
    currentBalance: openingBalance, // Set same as openingBalance during migration
    createdAt:
      data.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

migrateEmployees().catch((error) => {
  console.error('Employee migration failed:', error);
  process.exitCode = 1;
});

