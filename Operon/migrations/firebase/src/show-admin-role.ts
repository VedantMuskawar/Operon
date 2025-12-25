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

async function showAdminRole() {
  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  const orgId = process.env.ORG_ID || 'unWyJiHDvYmrYNQ5G8lQ';
  console.log(`Fetching admin role for organization: ${orgId}\n`);

  const adminRoleRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('APP_ACCESS_ROLES')
    .doc('admin');

  const adminRole = await adminRoleRef.get();

  if (adminRole.exists) {
    const data = adminRole.data();
    console.log('✓ Admin role found!\n');
    console.log('Full document data:');
    console.log(JSON.stringify(data, null, 2));
    console.log('\n');
    console.log('Firestore Path:');
    console.log(`ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/admin`);
    console.log('\n');
    console.log('Document ID:', adminRole.id);
    console.log('Document exists:', adminRole.exists);
  } else {
    console.log('✗ Admin role NOT found at path:');
    console.log(`ORGANIZATIONS/${orgId}/APP_ACCESS_ROLES/admin`);
    
    // Check if collection exists
    const collectionRef = db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('APP_ACCESS_ROLES');
    
    const allRoles = await collectionRef.get();
    console.log(`\nFound ${allRoles.size} documents in APP_ACCESS_ROLES collection:`);
    allRoles.docs.forEach((doc) => {
      console.log(`  - ${doc.id}`);
    });
  }

  await app.delete();
}

showAdminRole().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
