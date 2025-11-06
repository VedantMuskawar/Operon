/**
 * Setup Helper Script
 * Creates necessary directories for migration setup
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 Setting up migration directory structure...\n');

// Create service-accounts directory
const serviceAccountsDir = path.join(__dirname, 'service-accounts');
if (!fs.existsSync(serviceAccountsDir)) {
  fs.mkdirSync(serviceAccountsDir, { recursive: true });
  console.log('✅ Created: service-accounts/');
} else {
  console.log('ℹ️  Directory already exists: service-accounts/');
}

// Create .gitkeep file to ensure directory is tracked in git
const gitkeepPath = path.join(serviceAccountsDir, '.gitkeep');
if (!fs.existsSync(gitkeepPath)) {
  fs.writeFileSync(gitkeepPath, '# Service account JSON files go here\n# Add files:\n# - paveboard-service-account.json\n# - operon-service-account.json\n');
  console.log('✅ Created: service-accounts/.gitkeep');
}

// Create .env file if it doesn't exist
const envPath = path.join(__dirname, '.env');
const envExamplePath = path.join(__dirname, '.env.example');

if (!fs.existsSync(envPath) && fs.existsSync(envExamplePath)) {
  fs.copyFileSync(envExamplePath, envPath);
  console.log('✅ Created: .env (from .env.example)');
} else if (fs.existsSync(envPath)) {
  console.log('ℹ️  File already exists: .env');
} else {
  console.log('ℹ️  .env.example not found, skipping .env creation');
}

console.log('\n📋 Next steps:');
console.log('1. Download service account JSON files from Firebase Console:');
console.log('   - PaveBoard (apex-21cd0): Project Settings > Service Accounts > Generate New Private Key');
console.log('   - OPERON (operanapp): Project Settings > Service Accounts > Generate New Private Key');
console.log('2. Place the downloaded files in service-accounts/ folder:');
console.log('   Location: C:\\Vedant\\OPERON\\migration\\service-accounts\\');
console.log('   Expected filenames:');
console.log('   - apex-21cd0-firebase-adminsdk-f7hnl-3371c464e2.json');
console.log('   - operanapp-firebase-adminsdk-fbsvc-090c355102.json');
console.log('   (If your files have different names, update config.js)');
console.log('3. Run: npm run migrate-clients:dry-run (to test)');
console.log('4. Run: npm run migrate-clients (to migrate)\n');

