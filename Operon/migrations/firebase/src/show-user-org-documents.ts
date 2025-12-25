import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

function resolveConfig() {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const serviceAccount =
    resolvePath(process.env.SERVICE_ACCOUNT) ??
    path.join(process.cwd(), 'creds/service-account.json');

  if (!fs.existsSync(serviceAccount)) {
    throw new Error(`Service account file not found: ${serviceAccount}`);
  }

  return {
    serviceAccount,
    projectId: process.env.PROJECT_ID,
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: any): admin.app.App {
  const serviceAccount = readServiceAccount(config.serviceAccount);
  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: config.projectId || serviceAccount.project_id,
  });
}

async function showUserOrgDocuments() {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  const orgId = process.env.ORG_ID || 'unWyJiHDvYmrYNQ5G8lQ';
  console.log(`Showing documents for organization: ${orgId}\n`);

  // Show ORGANIZATIONS/{orgId}/USERS/{userId}
  console.log('=== ORGANIZATIONS/{orgId}/USERS/{userId} ===\n');
  const orgUsersRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('USERS');

  const orgUsersSnapshot = await orgUsersRef.get();
  
  for (const userDoc of orgUsersSnapshot.docs) {
    const userId = userDoc.id;
    const data = userDoc.data();
    console.log(`Document: ORGANIZATIONS/${orgId}/USERS/${userId}`);
    console.log('Full document data:');
    console.log(JSON.stringify(data, null, 2));
    console.log('\n');
  }

  // Show USERS/{userId}/ORGANIZATIONS/{orgId}
  console.log('=== USERS/{userId}/ORGANIZATIONS/{orgId} ===\n');
  const allUsersSnapshot = await db.collection('USERS').get();
  
  for (const userDoc of allUsersSnapshot.docs) {
    const userId = userDoc.id;
    const userOrgRef = db
      .collection('USERS')
      .doc(userId)
      .collection('ORGANIZATIONS')
      .doc(orgId);
    
    const userOrgDoc = await userOrgRef.get();
    
    if (userOrgDoc.exists) {
      const data = userOrgDoc.data();
      console.log(`Document: USERS/${userId}/ORGANIZATIONS/${orgId}`);
      console.log('Full document data:');
      console.log(JSON.stringify(data, null, 2));
      console.log('\n');
    }
  }

  // Show APP_ACCESS_ROLES
  console.log('=== ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES ===\n');
  const rolesRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('APP_ACCESS_ROLES');
  
  const rolesSnapshot = await rolesRef.get();
  
  for (const roleDoc of rolesSnapshot.docs) {
    const data = roleDoc.data();
    console.log(`Document: ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/${roleDoc.id}`);
    console.log('Full document data:');
    console.log(JSON.stringify(data, null, 2));
    console.log('\n');
  }

  await app.delete();
}

showUserOrgDocuments().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
