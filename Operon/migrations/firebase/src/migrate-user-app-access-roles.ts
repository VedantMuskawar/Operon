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
 * Finds matching App Access Role for a given role_in_org string
 */
async function findMatchingAppAccessRole(
  db: admin.firestore.Firestore,
  orgId: string,
  roleInOrg: string,
): Promise<string | null> {
  try {
    const appAccessRolesRef = db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('APP_ACCESS_ROLES');

    // First, try to find by ID (if roleInOrg is already an ID)
    const roleById = await appAccessRolesRef.doc(roleInOrg).get();
    if (roleById.exists) {
      return roleInOrg;
    }

    // Then, try to find by name (case-insensitive)
    const allRoles = await appAccessRolesRef.get();
    for (const roleDoc of allRoles.docs) {
      const roleData = roleDoc.data();
      const roleName = (roleData.name as string) || '';
      if (roleName.toUpperCase() === roleInOrg.toUpperCase()) {
        return roleDoc.id;
      }
    }

    // Default to "admin" role if it exists
    const adminRole = await appAccessRolesRef.doc('admin').get();
    if (adminRole.exists) {
      return 'admin';
    }

    // If no roles exist, return null
    return null;
  } catch (error) {
    console.error(`  Error finding role for "${roleInOrg}":`, error);
    return null;
  }
}

/**
 * Migrates all user-org documents to include app_access_role_id
 */
async function migrateUserAppAccessRoles() {
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
  console.log('Migrating user-org documents to include app_access_role_id...\n');

  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalErrors = 0;

  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgName = orgDoc.data().org_name || 'Unknown';
    console.log(`Processing: ${orgName} (${orgId})`);

    try {
      // Get all users in this organization
      const orgUsersRef = db
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('USERS');

      const orgUsersSnapshot = await orgUsersRef.get();

      if (orgUsersSnapshot.empty) {
        console.log(`  - No users found\n`);
        continue;
      }

      console.log(`  - Found ${orgUsersSnapshot.size} users`);

      for (const userDoc of orgUsersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const roleInOrg = (userData.role_in_org as string) || '';
        const existingAppAccessRoleId = userData.app_access_role_id as string | undefined;

        totalProcessed++;

        // Skip if already has app_access_role_id
        if (existingAppAccessRoleId) {
          totalSkipped++;
          continue;
        }

        // Find matching App Access Role
        const appAccessRoleId = await findMatchingAppAccessRole(db, orgId, roleInOrg);

        if (!appAccessRoleId) {
          console.log(`    ⚠ User ${userId}: No matching role found for "${roleInOrg}"`);
          totalErrors++;
          continue;
        }

        // Update both user-org documents
        const batch = db.batch();

        // Update ORGANIZATIONS/{orgId}/USERS/{userId}
        const orgUserRef = orgUsersRef.doc(userId);
        batch.update(orgUserRef, {
          app_access_role_id: appAccessRoleId,
        });

        // Update USERS/{userId}/ORGANIZATIONS/{orgId}
        const userOrgRef = db
          .collection('USERS')
          .doc(userId)
          .collection('ORGANIZATIONS')
          .doc(orgId);

        batch.update(userOrgRef, {
          app_access_role_id: appAccessRoleId,
        });

        await batch.commit();
        totalUpdated++;
        console.log(`    ✓ User ${userId}: Set app_access_role_id = "${appAccessRoleId}"`);
      }

      console.log('');
    } catch (error) {
      console.error(`  ✗ Error processing ${orgName}:`, error);
      totalErrors++;
    }
  }

  console.log('\n=== Migration Summary ===');
  console.log(`Total user-org documents processed: ${totalProcessed}`);
  console.log(`Updated: ${totalUpdated}`);
  console.log(`Skipped (already has app_access_role_id): ${totalSkipped}`);
  console.log(`Errors: ${totalErrors}`);

  await app.delete();
}

// Run migration
migrateUserAppAccessRoles().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});
