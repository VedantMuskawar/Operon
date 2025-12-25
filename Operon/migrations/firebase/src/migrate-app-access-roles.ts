import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
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
 * Migrates all existing organizations to have a default Admin App Access Role
 */
async function migrateAppAccessRoles() {
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

  console.log(`Found ${orgsSnapshot.size} organizations.`);
  console.log('Creating default Admin App Access Roles...\n');

  let processed = 0;
  let created = 0;
  let skipped = 0;

  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgName = orgDoc.data().org_name || 'Unknown';
    console.log(`Processing: ${orgName} (${orgId})`);

    try {
      const adminRoleRef = db
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('APP_ACCESS_ROLES')
        .doc('admin');

      const existing = await adminRoleRef.get();
      if (existing.exists) {
        skipped++;
        console.log(`  - Admin role already exists, skipping\n`);
      } else {
        const roleData = {
          roleId: 'admin',
          name: 'Admin',
          description: 'Full access to all features and settings',
          colorHex: '#FF6B6B',
          isAdmin: true,
          permissions: {
            sections: {},
            pages: {},
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await adminRoleRef.set(roleData);
        
        // Verify the write succeeded
        const verify = await adminRoleRef.get();
        if (verify.exists) {
          created++;
          console.log(`  ✓ Created admin role`);
          console.log(`    - Path: ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/admin\n`);
        } else {
          throw new Error('Write succeeded but document not found on verification');
        }
      }
      processed++;
    } catch (error) {
      console.error(`  ✗ Error processing ${orgName}:`, error);
    }
  }

  console.log('\n=== Migration Summary ===');
  console.log(`Total organizations: ${orgsSnapshot.size}`);
  console.log(`Processed: ${processed}`);
  console.log(`Created: ${created}`);
  console.log(`Skipped (already exists): ${skipped}`);
  console.log(`Errors: ${orgsSnapshot.size - processed}`);

  await app.delete();
}

// Run migration
migrateAppAccessRoles().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});
