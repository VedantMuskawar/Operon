/**
 * Client Migration Script
 * Migrates clients from PaveBoard to OPERON Firebase projects
 */

const admin = require('firebase-admin');
const config = require('./config');
const utils = require('./utils');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');

// Initialize Firebase Admin SDKs
let sourceDb;
let destDb;

// Migration statistics
const stats = {
  total: 0,
  migrated: 0,
  updated: 0,
  failed: 0,
  skipped: 0,
  filteredByDate: 0,
  errors: []
};

// Report file path
const reportPath = path.join(__dirname, `migration-report-${Date.now()}.json`);

/**
 * Initialize Firebase Admin SDKs for both projects
 */
async function initializeFirebase() {
  try {
    // Check if service account files exist
    const sourcePath = path.resolve(config.source.serviceAccountPath);
    const destPath = path.resolve(config.destination.serviceAccountPath);
    
    if (!fs.existsSync(sourcePath)) {
      const sourceFilename = config.source.serviceAccountPath.split('/').pop();
      throw new Error(
        `❌ PaveBoard service account file not found: ${sourcePath}\n` +
        `   Please create the file or update PAVEBOARD_SERVICE_ACCOUNT_PATH in config.js or .env\n` +
        `   Expected location: migration/service-accounts/${sourceFilename}`
      );
    }
    
    if (!fs.existsSync(destPath)) {
      const destFilename = config.destination.serviceAccountPath.split('/').pop();
      throw new Error(
        `❌ OPERON service account file not found: ${destPath}\n` +
        `   Please create the file or update OPERON_SERVICE_ACCOUNT_PATH in config.js or .env\n` +
        `   Expected location: migration/service-accounts/${destFilename}`
      );
    }

    // Initialize source Firebase (PaveBoard)
    if (!admin.apps.find(app => app.name === 'source')) {
      const sourceServiceAccount = require(sourcePath);
      admin.initializeApp({
        credential: admin.credential.cert(sourceServiceAccount),
        projectId: config.source.projectId
      }, 'source');
    }
    sourceDb = admin.app('source').firestore();

    // Initialize destination Firebase (OPERON)
    if (!admin.apps.find(app => app.name === 'destination')) {
      const destServiceAccount = require(destPath);
      admin.initializeApp({
        credential: admin.credential.cert(destServiceAccount),
        projectId: config.destination.projectId
      }, 'destination');
    }
    destDb = admin.app('destination').firestore();

    console.log('✅ Firebase Admin SDKs initialized successfully');
    console.log(`   Source: ${config.source.projectId}`);
    console.log(`   Destination: ${config.destination.projectId}`);
  } catch (error) {
    if (error.code === 'MODULE_NOT_FOUND' || error.message.includes('not found')) {
      console.error('\n' + '='.repeat(60));
      console.error('SETUP REQUIRED');
      console.error('='.repeat(60));
      console.error('\nService account files are required to connect to Firebase.');
      console.error('\nTo fix this:');
      console.error('1. Create a "service-accounts" folder in the migration directory:');
      console.error('   C:\\Vedant\\OPERON\\migration\\service-accounts\\');
      console.error('2. Download service account JSON files from Firebase Console:');
      console.error(`   - PaveBoard (${config.source.projectId}): Project Settings > Service Accounts > Generate New Private Key`);
      console.error(`   - OPERON (${config.destination.projectId}): Project Settings > Service Accounts > Generate New Private Key`);
      console.error('3. Place the downloaded files in service-accounts/ folder:');
      const sourceFilename = config.source.serviceAccountPath.split('/').pop();
      const destFilename = config.destination.serviceAccountPath.split('/').pop();
      console.error(`   - C:\\Vedant\\OPERON\\migration\\service-accounts\\${sourceFilename}`);
      console.error(`   - C:\\Vedant\\OPERON\\migration\\service-accounts\\${destFilename}`);
      console.error('\nSee README.md for detailed setup instructions.\n');
      console.error('='.repeat(60) + '\n');
    }
    throw error;
  }
}

/**
 * Fetch existing OPERON clients and create a phone-to-clientId map
 * @returns {Map<string, string>} Map of normalized phone to clientId
 */
async function getExistingClientsMap() {
  try {
    console.log('📋 Fetching existing OPERON clients...');
    const snapshot = await destDb
      .collection(config.destination.collection)
      .where('organizationId', '==', config.destination.organizationId)
      .get();

    const phoneMap = new Map();
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const phoneNumber = data.phoneNumber;
      if (phoneNumber) {
        // Normalize phone number (without country code) for duplicate checking
        // This allows matching even if stored format includes country code
        const normalized = utils.normalizePhoneNumber(phoneNumber);
        if (normalized) {
          phoneMap.set(normalized, doc.id);
        }
      }
    });

    console.log(`   Found ${phoneMap.size} existing clients`);
    return phoneMap;
  } catch (error) {
    console.error('❌ Error fetching existing clients:', error.message);
    throw error;
  }
}

/**
 * Fetch PaveBoard clients filtered by orgID and registration date
 * @returns {Promise<Array>} Array of client documents
 */
async function fetchPaveBoardClients() {
  try {
    console.log(`📥 Fetching PaveBoard clients with orgID: ${config.source.orgID}...`);
    
    // Fetch all clients by orgID (no date filter in query to avoid index requirement)
    const query = sourceDb
      .collection(config.source.collection)
      .where('orgID', '==', config.source.orgID);
    
    const snapshot = await query.get();

    let clients = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    const totalBeforeFilter = clients.length;
    
    // Apply date filter client-side (avoids need for composite index)
    if (config.source.registeredBeforeDate) {
      console.log(`   Applying date filter: Only clients registered on or before ${config.source.registeredBeforeDate.toISOString().split('T')[0]}`);
      const filterTimestamp = config.source.registeredBeforeDate.getTime();
      const filteredCount = clients.length;
      
      clients = clients.filter(client => {
        if (!client.registeredTime) {
          stats.filteredByDate++;
          return false;
        }
        
        let clientTimestamp;
        if (client.registeredTime.toDate) {
          clientTimestamp = client.registeredTime.toDate().getTime();
        } else if (client.registeredTime._seconds) {
          clientTimestamp = client.registeredTime._seconds * 1000;
        } else if (client.registeredTime instanceof Date) {
          clientTimestamp = client.registeredTime.getTime();
        } else {
          stats.filteredByDate++;
          return false;
        }
        
        if (clientTimestamp > filterTimestamp) {
          stats.filteredByDate++;
          return false;
        }
        
        return true;
      });
      
      if (filteredCount > clients.length) {
        console.log(`   Filtered out ${filteredCount - clients.length} clients registered after ${config.source.registeredBeforeDate.toISOString().split('T')[0]}`);
      }
    }

    console.log(`   Found ${clients.length} clients to migrate${config.source.registeredBeforeDate ? ' (after date filtering)' : ''}`);
    return clients;
  } catch (error) {
    console.error('❌ Error fetching PaveBoard clients:', error.message);
    throw error;
  }
}

/**
 * Process a single client
 * @param {Object} paveClient - PaveBoard client document
 * @param {Map<string, string>} existingClientsMap - Map of existing clients
 * @param {Object} batch - Firestore batch object
 * @param {number} batchIndex - Current batch index
 * @returns {Promise<boolean>} Success status
 */
async function processClient(paveClient, existingClientsMap, batch, batchIndex) {
  try {
    // Transform data
    const operonData = utils.transformClientData(paveClient, config.destination.organizationId);
    
    // Check if phone number is valid (as-is from PaveBoard)
    if (!operonData.phoneNumber || operonData.phoneNumber.trim().length === 0) {
      stats.skipped++;
      stats.errors.push({
        clientId: paveClient.id,
        name: paveClient.name,
        error: 'No valid phone number found',
        debugInfo: {
          contactInfo: paveClient.contactInfo,
          phoneNumber: paveClient.phoneNumber,
          phone: paveClient.phone
        }
      });
      return false;
    }
    
    // Check normalized phone for duplicate detection
    const normalizedPhoneForCheck = operonData._normalizedPhoneForCheck || utils.normalizePhoneNumber(operonData.phoneNumber);
    if (!normalizedPhoneForCheck || normalizedPhoneForCheck.length === 0) {
      stats.skipped++;
      stats.errors.push({
        clientId: paveClient.id,
        name: paveClient.name,
        error: 'Could not normalize phone number for duplicate checking'
      });
      return false;
    }

    // Check for duplicate using normalized phone (without country code)
    // This ensures we match even if stored formats differ
    const existingClientId = existingClientsMap.get(normalizedPhoneForCheck);
    
    // Convert dates to Firestore Timestamps
    // Remove internal field (_normalizedPhoneForCheck) before saving
    const { _normalizedPhoneForCheck, ...dataToSave } = operonData;
    const operonDataWithTimestamps = {
      ...dataToSave,
      createdAt: admin.firestore.Timestamp.fromDate(operonData.createdAt),
      updatedAt: admin.firestore.Timestamp.fromDate(operonData.updatedAt)
    };

    if (existingClientId) {
      // Update existing client (preserve clientId)
      if (!isDryRun) {
        const docRef = destDb.collection(config.destination.collection).doc(existingClientId);
        // Remove clientId from update data to preserve existing one
        const { clientId, ...updateData } = operonDataWithTimestamps;
        batch.update(docRef, updateData);
      }
      stats.updated++;
      console.log(`   ✓ Updated: ${operonData.name} (${operonData.phoneNumber})`);
    } else {
      // Create new client
      if (!isDryRun) {
        const docRef = destDb.collection(config.destination.collection).doc();
        // Set clientId to match document ID (OPERON's pattern)
        operonDataWithTimestamps.clientId = docRef.id;
        batch.set(docRef, operonDataWithTimestamps);
      }
      stats.migrated++;
      console.log(`   ✓ Migrated: ${operonData.name} (${operonData.phoneNumber})`);
    }

    return true;
  } catch (error) {
    stats.failed++;
    stats.errors.push({
      clientId: paveClient.id,
      name: paveClient.name || 'Unknown',
      error: error.message
    });
    console.error(`   ✗ Failed: ${paveClient.name || 'Unknown'} - ${error.message}`);
    return false;
  }
}

/**
 * Process clients in batches
 * @param {Array} clients - Array of client documents
 * @param {Map<string, string>} existingClientsMap - Map of existing clients
 */
async function processBatch(clients, existingClientsMap) {
  const batchSize = config.batch.size;
  const totalBatches = Math.ceil(clients.length / batchSize);

  console.log(`\n🔄 Processing ${clients.length} clients in ${totalBatches} batch(es)...\n`);

  for (let i = 0; i < clients.length; i += batchSize) {
    const batchIndex = Math.floor(i / batchSize) + 1;
    const batch = destDb.batch();
    const batchClients = clients.slice(i, i + batchSize);

    console.log(`📦 Batch ${batchIndex}/${totalBatches} (${batchClients.length} clients)...`);

    // Process each client in the batch
    for (const client of batchClients) {
      stats.total++;
      await processClient(client, existingClientsMap, batch, batchIndex);
    }

    // Commit batch
    if (!isDryRun) {
      try {
        await batch.commit();
        console.log(`   ✅ Batch ${batchIndex} committed successfully\n`);
      } catch (error) {
        console.error(`   ❌ Error committing batch ${batchIndex}:`, error.message);
        stats.failed += batchClients.length;
      }
    } else {
      console.log(`   ✅ Batch ${batchIndex} would be committed (dry-run)\n`);
    }
  }
}

/**
 * Generate and save migration report
 */
function generateReport() {
  const report = {
    timestamp: new Date().toISOString(),
    isDryRun: isDryRun,
    configuration: {
      source: config.source,
      destination: config.destination
    },
    statistics: {
      total: stats.total,
      migrated: stats.migrated,
      updated: stats.updated,
      failed: stats.failed,
      skipped: stats.skipped,
      filteredByDate: stats.filteredByDate
    },
    errors: stats.errors
  };

  // Save report to file
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n📊 Migration report saved to: ${reportPath}`);
  
  return report;
}

/**
 * Print summary statistics
 */
function printSummary() {
  console.log('\n' + '='.repeat(60));
  console.log('📈 MIGRATION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Mode: ${isDryRun ? 'DRY-RUN' : 'LIVE'}`);
  if (config.source.registeredBeforeDate) {
    console.log(`Date Filter: On or before ${config.source.registeredBeforeDate.toISOString().split('T')[0]}`);
  }
  console.log(`Total clients processed: ${stats.total}`);
  console.log(`✅ Successfully migrated: ${stats.migrated}`);
  console.log(`🔄 Updated (duplicates): ${stats.updated}`);
  console.log(`❌ Failed: ${stats.failed}`);
  console.log(`⏭️  Skipped: ${stats.skipped}`);
  if (stats.filteredByDate > 0) {
    console.log(`📅 Filtered by date: ${stats.filteredByDate}`);
  }
  console.log('='.repeat(60));

  if (stats.errors.length > 0) {
    console.log('\n⚠️  Errors encountered:');
    stats.errors.slice(0, 10).forEach((error, index) => {
      console.log(`   ${index + 1}. ${error.name} (${error.clientId}): ${error.error}`);
    });
    if (stats.errors.length > 10) {
      console.log(`   ... and ${stats.errors.length - 10} more errors (see report file)`);
    }
  }
}

/**
 * Main migration function
 */
async function main() {
  try {
    console.log('🚀 Starting Client Migration');
    console.log(`   Mode: ${isDryRun ? 'DRY-RUN (no changes will be made)' : 'LIVE'}`);
    console.log('');

    // Initialize Firebase
    await initializeFirebase();

    // Fetch existing OPERON clients
    const existingClientsMap = await getExistingClientsMap();

    // Fetch PaveBoard clients
    const paveBoardClients = await fetchPaveBoardClients();

    if (paveBoardClients.length === 0) {
      console.log('⚠️  No clients found to migrate');
      return;
    }

    // Process clients in batches
    await processBatch(paveBoardClients, existingClientsMap);

    // Generate and save report
    generateReport();

    // Print summary
    printSummary();

    console.log('\n✅ Migration completed!');
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    // Cleanup Firebase apps
    if (admin.apps.length > 0) {
      await Promise.all(admin.apps.map(app => app.delete()));
    }
  }
}

// Run migration
if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

module.exports = { main };

