import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface MigrationConfig {
  serviceAccount: string;
  projectId?: string;
}

function resolveConfig(): MigrationConfig {
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

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: MigrationConfig): admin.app.App {
  const serviceAccount = readServiceAccount(config.serviceAccount);
  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: config.projectId || serviceAccount.project_id,
  });
}

/**
 * Verifies if Admin App Access Roles exist for all organizations
 */
async function verifyAppAccessRoles() {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  console.log('Fetching all organizations...');
  const orgsSnapshot = await db.collection('ORGANIZATIONS').get();

  if (orgsSnapshot.empty) {
    console.log('No organizations found.');
    await app.delete();
    return;
  }

  console.log(`Found ${orgsSnapshot.size} organizations.\n`);
  console.log('Checking for Admin App Access Roles...\n');

  let found = 0;
  let missing = 0;

  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgName = orgDoc.data().org_name || 'Unknown';
    console.log(`Checking: ${orgName} (${orgId})`);

    try {
      const adminRoleRef = db
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('APP_ACCESS_ROLES')
        .doc('admin');

      const adminRole = await adminRoleRef.get();

      if (adminRole.exists) {
        found++;
        const data = adminRole.data();
        console.log(`  ✓ Admin role EXISTS`);
        console.log(`    - Name: ${data?.name || 'N/A'}`);
        console.log(`    - isAdmin: ${data?.isAdmin || 'N/A'}`);
        console.log(`    - Color: ${data?.colorHex || 'N/A'}`);
        console.log(`    - Path: ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/admin\n`);
      } else {
        missing++;
        console.log(`  ✗ Admin role MISSING`);
        console.log(`    - Path checked: ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/admin\n`);
      }
    } catch (error) {
      console.error(`  ✗ Error checking ${orgName}:`, error);
      missing++;
    }
  }

  console.log('\n=== Verification Summary ===');
  console.log(`Total organizations: ${orgsSnapshot.size}`);
  console.log(`Admin roles found: ${found}`);
  console.log(`Admin roles missing: ${missing}`);

  await app.delete();
}

// Run verification
verifyAppAccessRoles().catch((error) => {
  console.error('Verification failed:', error);
  process.exit(1);
});
