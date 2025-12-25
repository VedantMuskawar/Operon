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
 * Verifies app_access_role_id in user-org documents
 */
async function verifyUserAppAccessRoles() {
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

  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgName = orgDoc.data().org_name || 'Unknown';
    console.log(`\n=== ${orgName} (${orgId}) ===`);

    // Check ORGANIZATIONS/{orgId}/USERS/{userId}
    console.log('\nChecking ORGANIZATIONS/{orgId}/USERS/{userId}:');
    const orgUsersRef = db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('USERS');

    const orgUsersSnapshot = await orgUsersRef.get();
    
    if (orgUsersSnapshot.empty) {
      console.log('  No users found');
    } else {
      for (const userDoc of orgUsersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const roleInOrg = userData.role_in_org || 'N/A';
        const appAccessRoleId = userData.app_access_role_id;
        
        console.log(`  User: ${userId}`);
        console.log(`    role_in_org: ${roleInOrg}`);
        console.log(`    app_access_role_id: ${appAccessRoleId || '❌ MISSING'}`);
        
        if (appAccessRoleId) {
          // Verify the role exists
          const roleRef = db
            .collection('ORGANIZATIONS')
            .doc(orgId)
            .collection('APP_ACCESS_ROLES')
            .doc(appAccessRoleId);
          const roleDoc = await roleRef.get();
          console.log(`    Role exists: ${roleDoc.exists ? '✅' : '❌ NOT FOUND'}`);
        }
        console.log('');
      }
    }

    // Check USERS/{userId}/ORGANIZATIONS/{orgId}
    console.log('\nChecking USERS/{userId}/ORGANIZATIONS/{orgId}:');
    const allUsersSnapshot = await db.collection('USERS').get();
    let foundAny = false;
    
    for (const userDoc of allUsersSnapshot.docs) {
      const userId = userDoc.id;
      const userOrgRef = db
        .collection('USERS')
        .doc(userId)
        .collection('ORGANIZATIONS')
        .doc(orgId);
      
      const userOrgDoc = await userOrgRef.get();
      
      if (userOrgDoc.exists) {
        foundAny = true;
        const userOrgData = userOrgDoc.data();
        const roleInOrg = userOrgData?.role_in_org || 'N/A';
        const appAccessRoleId = userOrgData?.app_access_role_id;
        
        console.log(`  User: ${userId}`);
        console.log(`    role_in_org: ${roleInOrg}`);
        console.log(`    app_access_role_id: ${appAccessRoleId || '❌ MISSING'}`);
        console.log('');
      }
    }
    
    if (!foundAny) {
      console.log('  No user-org documents found');
    }

    // Check APP_ACCESS_ROLES
    console.log('\nChecking APP_ACCESS_ROLES:');
    const rolesRef = db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('APP_ACCESS_ROLES');
    
    const rolesSnapshot = await rolesRef.get();
    
    if (rolesSnapshot.empty) {
      console.log('  ❌ No App Access Roles found');
    } else {
      console.log(`  Found ${rolesSnapshot.size} role(s):`);
      for (const roleDoc of rolesSnapshot.docs) {
        const roleData = roleDoc.data();
        console.log(`    - ${roleDoc.id}: ${roleData.name || 'N/A'} (isAdmin: ${roleData.isAdmin || false})`);
      }
    }
  }

  await app.delete();
}

// Run verification
verifyUserAppAccessRoles().catch((error) => {
  console.error('Verification failed:', error);
  process.exit(1);
});
