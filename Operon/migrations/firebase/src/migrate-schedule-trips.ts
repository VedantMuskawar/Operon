/**
 * SCHEDULE_TRIPS Migration Script - From Pave
 * 
 * Migrates scheduled trip data from Pave (legacy Firebase project) to the new Operon Firebase project.
 * Only migrates data up to December 31, 2025 (31.12.25).
 * Only migrates documents where deliveryStatus = true.
 * 
 * Before running:
 * 1. Review and fill in SCHEDULE_TRIPS_MIGRATION_MAPPING.md with field mappings
 * 2. Update field names in this script based on the mapping document
 * 3. Ensure Firestore indexes are created for the queries
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

// Cache for lookups to avoid repeated queries
const vehicleCache = new Map<string, string>(); // vehicleNumber (normalized) -> vehicleId
const driverCache = new Map<string, string>(); // driverName -> driverId
const productCache = new Map<string, string>(); // productName (normalized) -> productId
const paymentAccountCache = new Map<string, { accountId: string; name: string; type: string }>(); // toAccount (normalized) -> account info

interface TripWithSlot {
  doc: admin.firestore.QueryDocumentSnapshot;
  dispatchStart: string | admin.firestore.Timestamp | Date | null;
  dispatchEnd: string | admin.firestore.Timestamp | Date | null;
  scheduledDate: admin.firestore.Timestamp;
}

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

/**
 * Normalize phone number to E.164 format
 */
function normalizePhone(raw?: string | null): string | undefined {
  if (!raw) return undefined;
  const digits = raw.replace(/[^0-9+]/g, '');
  if (/^[0-9]{10}$/.test(digits)) {
    return `+91${digits}`;
  }
  if (/^91[0-9]{10}$/.test(digits) && !digits.startsWith('+')) {
    return `+${digits}`;
  }
  return digits.startsWith('+') ? digits : digits;
}

/**
 * Normalize string for lookup (lowercase, trim)
 */
function normalizeString(str?: string | null): string {
  if (!str) return '';
  return str.trim().toLowerCase();
}

/**
 * Lookup vehicle ID by vehicle number
 */
async function lookupVehicleId(
  targetDb: admin.firestore.Firestore,
  vehicleNumber: string,
  targetOrgId: string,
): Promise<string | null> {
  const normalized = vehicleNumber.replace(/\s+/g, '').trim();
  const cacheKey = `${targetOrgId}:${normalized}`;
  if (vehicleCache.has(cacheKey)) {
    return vehicleCache.get(cacheKey) || null;
  }

  try {
    const snapshot = await targetDb
      .collection('ORGANIZATIONS')
      .doc(targetOrgId)
      .collection('VEHICLES')
      .where('vehicleNumber', '==', normalized)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      const vehicleId = snapshot.docs[0].id;
      vehicleCache.set(cacheKey, vehicleId);
      return vehicleId;
    }
  } catch (error) {
    console.warn(`Error looking up vehicle ${vehicleNumber}: ${error}`);
  }

  return null;
}

/**
 * Lookup driver ID by driver name
 */
async function lookupDriverId(
  targetDb: admin.firestore.Firestore,
  driverName: string,
  targetOrgId: string,
): Promise<string | null> {
  const normalized = normalizeString(driverName);
  if (driverCache.has(normalized)) {
    return driverCache.get(normalized) || null;
  }

  try {
    const snapshot = await targetDb
      .collection('EMPLOYEES')
      .where('organizationId', '==', targetOrgId)
      .where('employeeName', '==', driverName.trim())
      .limit(1)
      .get();

    if (!snapshot.empty) {
      const driverId = snapshot.docs[0].id;
      driverCache.set(normalized, driverId);
      return driverId;
    }
  } catch (error) {
    console.warn(`Error looking up driver ${driverName}: ${error}`);
  }

  return null;
}

/**
 * Lookup product ID by product name
 */
async function lookupProductId(
  targetDb: admin.firestore.Firestore,
  productName: string,
  targetOrgId: string,
): Promise<string | null> {
  const normalized = normalizeString(productName);
  if (productCache.has(normalized)) {
    return productCache.get(normalized) || null;
  }

  try {
    // Try exact match first
    let snapshot = await targetDb
      .collection('ORGANIZATIONS')
      .doc(targetOrgId)
      .collection('PRODUCTS')
      .where('name', '==', productName.trim())
      .limit(1)
      .get();

    if (snapshot.empty) {
      // Try case-insensitive by fetching all and filtering
      snapshot = await targetDb
        .collection('ORGANIZATIONS')
        .doc(targetOrgId)
        .collection('PRODUCTS')
        .get();
      
      const match = snapshot.docs.find(
        (doc) => normalizeString(doc.data().name) === normalized,
      );
      if (match) {
        const productId = match.id;
        productCache.set(normalized, productId);
        return productId;
      }
    } else {
      const productId = snapshot.docs[0].id;
      productCache.set(normalized, productId);
      return productId;
    }
  } catch (error) {
    console.warn(`Error looking up product ${productName}: ${error}`);
  }

  return null;
}

/**
 * Lookup payment account by toAccount
 */
async function lookupPaymentAccount(
  targetDb: admin.firestore.Firestore,
  toAccount: string,
  targetOrgId: string,
): Promise<{ accountId: string; name: string; type: string } | null> {
  const normalized = normalizeString(toAccount);
  if (paymentAccountCache.has(normalized)) {
    return paymentAccountCache.get(normalized) || null;
  }

  try {
    const snapshot = await targetDb
      .collection('ORGANIZATIONS')
      .doc(targetOrgId)
      .collection('PAYMENT_ACCOUNTS')
      .get();

    const match = snapshot.docs.find((doc) => {
      const data = doc.data();
      return normalizeString(data.name) === normalized;
    });

    if (match) {
      const data = match.data();
      const accountInfo = {
        accountId: match.id,
        name: data.name as string,
        type: data.type as string,
      };
      paymentAccountCache.set(normalized, accountInfo);
      return accountInfo;
    }
  } catch (error) {
    console.warn(`Error looking up payment account ${toAccount}: ${error}`);
  }

  return null;
}

/**
 * Parse time string to minutes since midnight for comparison
 */
function parseTimeToMinutes(timeValue: string | admin.firestore.Timestamp | Date | null | undefined): number | null {
  if (!timeValue) return null;
  
  // Handle Firestore Timestamp
  if (timeValue instanceof admin.firestore.Timestamp) {
    const date = timeValue.toDate();
    return date.getHours() * 60 + date.getMinutes();
  }
  
  // Handle Date object
  if (timeValue instanceof Date) {
    return timeValue.getHours() * 60 + timeValue.getMinutes();
  }
  
  // Handle string
  if (typeof timeValue !== 'string') {
    return null;
  }
  
  const timeStr = String(timeValue);
  
  // Try to parse various time formats
  const timeMatch = timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
  if (timeMatch) {
    let hours = parseInt(timeMatch[1], 10);
    const minutes = parseInt(timeMatch[2], 10);
    const period = timeMatch[3]?.toUpperCase();

    if (period === 'PM' && hours !== 12) {
      hours += 12;
    } else if (period === 'AM' && hours === 12) {
      hours = 0;
    }

    return hours * 60 + minutes;
  }

  // Try ISO format
  try {
    const date = new Date(timeStr);
    if (!isNaN(date.getTime())) {
      return date.getHours() * 60 + date.getMinutes();
    }
  } catch {
    // Ignore
  }

  return null;
}

/**
 * Calculate slots for trips based on dispatchStart times
 */
function calculateSlots(trips: TripWithSlot[]): Map<string, number> {
  // Group trips by date (YYYY-MM-DD)
  const tripsByDate = new Map<string, TripWithSlot[]>();
  
  for (const trip of trips) {
    const dateKey = trip.scheduledDate.toDate().toISOString().split('T')[0];
    if (!tripsByDate.has(dateKey)) {
      tripsByDate.set(dateKey, []);
    }
    tripsByDate.get(dateKey)!.push(trip);
  }

  const slotMap = new Map<string, number>();

  // For each date, sort by dispatchStart and assign slots
  for (const [dateKey, dateTrips] of tripsByDate.entries()) {
    // Sort by dispatchStart time
    dateTrips.sort((a, b) => {
      const timeA = parseTimeToMinutes(a.dispatchStart);
      const timeB = parseTimeToMinutes(b.dispatchStart);
      
      if (timeA === null && timeB === null) return 0;
      if (timeA === null) return 1;
      if (timeB === null) return -1;
      
      return timeA - timeB;
    });

    // Assign slot numbers
    dateTrips.forEach((trip, index) => {
      slotMap.set(trip.doc.id, index + 1);
    });
  }

  return slotMap;
}

/**
 * Get slot name from dispatchStart time
 */
function getSlotName(dispatchStart: string | admin.firestore.Timestamp | Date | null | undefined, slot: number): string {
  const minutes = parseTimeToMinutes(dispatchStart);
  if (minutes !== null) {
    if (minutes >= 360 && minutes < 720) {
      // 6:00 AM - 12:00 PM
      return 'Morning';
    } else if (minutes >= 720 && minutes < 1020) {
      // 12:00 PM - 5:00 PM
      return 'Afternoon';
    } else if (minutes >= 1020 && minutes < 1260) {
      // 5:00 PM - 9:00 PM
      return 'Evening';
    } else {
      // 9:00 PM - 6:00 AM
      return 'Night';
    }
  }
  return `Slot ${slot}`;
}

/**
 * Get day name from date
 */
function getDayName(date: admin.firestore.Timestamp): string {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[date.toDate().getDay()];
}

/**
 * Map payment type from paySchedule
 */
function mapPaymentType(paySchedule?: string | null): string {
  if (!paySchedule) return 'cash';
  const schedule = String(paySchedule).trim().toUpperCase();
  if (schedule === 'POD') return 'pay_on_delivery';
  if (schedule === 'PL') return 'pay_later';
  return 'cash';
}

async function deleteExistingTrips(
  targetDb: admin.firestore.Firestore,
  targetOrgId: string,
) {
  console.log('\n=== Deleting existing SCHEDULE_TRIPS data ===');
  console.log('Target Org ID:', targetOrgId);

  const snapshot = await targetDb
    .collection('SCHEDULE_TRIPS')
    .where('organizationId', '==', targetOrgId)
    .get();

  if (snapshot.empty) {
    console.log('No existing trips found to delete.');
    return;
  }

  console.log(`Found ${snapshot.size} existing trip documents to delete`);

  const batchSize = 400;
  let deleted = 0;
  let batch = targetDb.batch();

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    deleted += 1;

    if (deleted % batchSize === 0) {
      await batch.commit();
      batch = targetDb.batch();
      console.log(`Deleted ${deleted} trip docs...`);
    }
  }

  if (deleted % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`Cleanup complete. Total trips deleted: ${deleted}\n`);
}

async function migrateScheduleTrips() {
  const config = resolveConfig();
  const { legacy, target } = initApps(config);

  const legacyDb = legacy.firestore();
  const targetDb = target.firestore();

  // Date range: April 1, 2025 to December 31, 2025
  const startDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-04-01T00:00:00.000Z'),
  );
  const cutoffDate = admin.firestore.Timestamp.fromDate(
    new Date('2025-12-31T23:59:59.999Z'),
  );

  console.log('=== Migrating SCHEDULE_TRIPS from Pave ===');
  console.log('Date range: April 1, 2025 to December 31, 2025');
  console.log('Start date:', startDate.toDate().toISOString());
  console.log('End date:', cutoffDate.toDate().toISOString());
  console.log('Legacy Org ID:', config.legacyOrgId);
  console.log('Target Org ID:', config.targetOrgId);
  console.log('Preserving Pave document IDs\n');

  // Fetch all trips from legacy SCH_ORDERS collection
  console.log(
    'Fetching trips from Pave (this may take a while for large datasets)...',
  );
  const snapshot = await legacyDb.collection('SCH_ORDERS').get();

  console.log(`Fetched ${snapshot.size} total trips from Pave`);

  if (snapshot.empty) {
    console.log('No legacy trips found');
    return;
  }

  // Filter by deliveryStatus = true and date (April 1, 2025 to December 31, 2025)
  const startMillis = startDate.toMillis();
  const cutoffMillis = cutoffDate.toMillis();
  const docsToMigrate = snapshot.docs.filter((doc) => {
    const data = doc.data();
    const deliveryStatus = data.deliveryStatus as boolean | undefined;
    const deliveryDate = data.deliveryDate as admin.firestore.Timestamp | undefined;
    
    // Only migrate if deliveryStatus is true
    if (!deliveryStatus) return false;
    
    // Filter by date range (April 1, 2025 to December 31, 2025)
    if (!deliveryDate) return false; // Skip if no date
    const dateMillis = deliveryDate.toMillis();
    return dateMillis >= startMillis && dateMillis <= cutoffMillis;
  });

  console.log(
    `After filtering (deliveryStatus=true, ${startDate.toDate().toISOString()} to ${cutoffDate.toDate().toISOString()}): ${docsToMigrate.length} documents to migrate`,
  );

  if (docsToMigrate.length === 0) {
    console.log('No trips found matching the filters');
    return;
  }

  // Prepare trips for slot calculation
  const tripsWithSlot: TripWithSlot[] = docsToMigrate.map((doc) => {
    const data = doc.data();
    return {
      doc,
      dispatchStart: (data.dispatchStart as string | admin.firestore.Timestamp | Date | null | undefined) ?? null,
      dispatchEnd: (data.dispatchEnd as string | admin.firestore.Timestamp | Date | null | undefined) ?? null,
      scheduledDate: (data.deliveryDate as admin.firestore.Timestamp) ?? admin.firestore.Timestamp.now(),
    };
  });

  // Calculate slots
  console.log('Calculating slots based on dispatchStart times...');
  const slotMap = calculateSlots(tripsWithSlot);

  // Delete only the trips that will be migrated (to avoid duplicates)
  // IMPORTANT: This runs BEFORE writes, so it only deletes old documents, not new ones
  console.log('\n=== Deleting existing trips that will be migrated ===');
  const legacyDocIds = new Set(docsToMigrate.map((doc) => doc.id));
  
  // Get existing trips BEFORE any writes happen
  const existingTripsSnapshot = await targetDb
    .collection('SCHEDULE_TRIPS')
    .where('organizationId', '==', config.targetOrgId)
    .get();
  
  console.log(`Found ${existingTripsSnapshot.size} existing trips in collection`);
  
  const tripsToDelete = existingTripsSnapshot.docs.filter((doc) =>
    legacyDocIds.has(doc.id),
  );
  
  if (tripsToDelete.length > 0) {
    console.log(`Deleting ${tripsToDelete.length} existing trips that will be re-migrated...`);
    const deleteBatchSize = 400;
    let deleted = 0;
    let deleteBatch = targetDb.batch();

    for (const doc of tripsToDelete) {
      deleteBatch.delete(doc.ref);
      deleted += 1;

      if (deleted % deleteBatchSize === 0) {
        await deleteBatch.commit();
        deleteBatch = targetDb.batch();
        console.log(`Deleted ${deleted}/${tripsToDelete.length} trips...`);
      }
    }

    if (deleted % deleteBatchSize !== 0) {
      await deleteBatch.commit();
    }
    console.log(`Deleted ${deleted} existing trips\n`);
  } else {
    console.log('No existing trips to delete\n');
  }
  
  // Add a small delay to ensure delete operations complete before writes
  console.log('Waiting 1 second before starting writes...');
  await new Promise(resolve => setTimeout(resolve, 1000));

  let processed = 0;
  let skipped = snapshot.size - docsToMigrate.length;
  let skippedInvalid = 0;
  let batchOperations = 0; // Track operations in current batch
  let totalBatchesCommitted = 0;
  const batchSize = 400;
  let batch = targetDb.batch();
  
  // Track document IDs to detect duplicates
  const processedDocIds = new Set<string>();
  let duplicateCount = 0;

  for (const doc of docsToMigrate) {
    const data = doc.data();

    // Skip if deliveryStatus is not true (shouldn't happen after filter, but double-check)
    const deliveryStatus = data.deliveryStatus as boolean | undefined;
    if (!deliveryStatus) {
      skippedInvalid += 1;
      continue;
    }

    try {
      const transformed = await transformTrip(
        data,
        config.targetOrgId,
        doc.id,
        slotMap.get(doc.id) ?? 1,
        targetDb,
      );

      if (!transformed) {
        skippedInvalid += 1;
        continue;
      }

      // Check for duplicate document IDs
      if (processedDocIds.has(doc.id)) {
        duplicateCount += 1;
        console.warn(`⚠️  Duplicate document ID detected: ${doc.id} (will overwrite previous document)`);
      }
      processedDocIds.add(doc.id);

      // Preserve Pave's document ID
      const targetRef = targetDb.collection('SCHEDULE_TRIPS').doc(doc.id);
      
      // Debug: Log first few writes
      if (processed < 3) {
        console.log(`Writing document ${doc.id} to SCHEDULE_TRIPS collection`);
        console.log(`  organizationId: ${transformed.organizationId}`);
        console.log(`  orderId: ${transformed.orderId}`);
      }
      
      batch.set(targetRef, transformed, { merge: true });
      processed += 1;
      batchOperations += 1;

      if (batchOperations >= batchSize) {
        try {
          await batch.commit();
          totalBatchesCommitted += 1;
          console.log(`✓ Committed batch #${totalBatchesCommitted} of ${batchOperations} trip docs (total processed: ${processed})...`);
          
          // Verify the last document was written (quick check)
          try {
            const lastDocRef = targetDb.collection('SCHEDULE_TRIPS').doc(doc.id);
            const lastDoc = await lastDocRef.get();
            if (!lastDoc.exists) {
              console.warn(`⚠️  WARNING: Last document ${doc.id} not found after batch commit!`);
            }
          } catch (verifyError) {
            console.warn(`⚠️  Could not verify last document: ${verifyError}`);
          }
          
          batch = targetDb.batch();
          batchOperations = 0;
        } catch (error: any) {
          console.error(`✗ Error committing batch at ${processed} trips: ${error}`);
          console.error(`  Error details: ${error.message || error}`);
          console.error(`  Batch operations that failed: ${batchOperations}`);
          throw error; // Re-throw to stop migration on batch commit failure
        }
      }
    } catch (error) {
      console.error(`Error processing trip ${doc.id}: ${error}`);
      skippedInvalid += 1;
    }
  }

  // Commit any remaining documents in the batch
  if (batchOperations > 0) {
    try {
      await batch.commit();
      totalBatchesCommitted += 1;
      console.log(`✓ Committed final batch #${totalBatchesCommitted} of ${batchOperations} trip docs (total processed: ${processed})...`);
    } catch (error) {
      console.error(`✗ Error committing final batch: ${error}`);
      throw error;
    }
  } else {
    console.log('No remaining documents in batch to commit.');
  }
  
  console.log(`\nBatch Summary: ${totalBatchesCommitted} batches committed, ${processed} documents processed`);
  if (duplicateCount > 0) {
    console.log(`⚠️  Warning: ${duplicateCount} duplicate document IDs detected (may have caused overwrites)`);
  }
  console.log(`Unique document IDs processed: ${processedDocIds.size}`);

  console.log(`\n=== Migration Complete ===`);
  console.log(`Total trips processed: ${processed}`);
  if (skipped > 0) {
    console.log(`Skipped ${skipped} trips (deliveryStatus=false or date after cutoff)`);
  }
  if (skippedInvalid > 0) {
    console.log(`Skipped ${skippedInvalid} trips (errors or invalid data)`);
  }
  
  // Verify the write by checking the collection
  console.log('\n=== Verifying Migration ===');
  console.log('Waiting 2 seconds for Firestore to index...');
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Check total count in collection (without filter) - get all
  let totalCount = 0;
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let batchCount = 0;
  while (true) {
    let query: admin.firestore.Query = targetDb.collection('SCHEDULE_TRIPS');
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snapshot = await query.limit(1000).get();
    if (snapshot.empty) break;
    totalCount += snapshot.size;
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < 1000) break; // Last batch
  }
  console.log(`Total documents in SCHEDULE_TRIPS collection: ${totalCount} (fetched in ${batchCount} batches)`);
  
  // Check with organizationId filter - get all
  let orgCount = 0;
  lastDoc = null;
  batchCount = 0;
  while (true) {
    let query: admin.firestore.Query = targetDb.collection('SCHEDULE_TRIPS')
      .where('organizationId', '==', config.targetOrgId);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snapshot = await query.limit(1000).get();
    if (snapshot.empty) break;
    orgCount += snapshot.size;
    batchCount += 1;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < 1000) break; // Last batch
  }
  console.log(`Documents with organizationId=${config.targetOrgId}: ${orgCount} (fetched in ${batchCount} batches)`);
  
  // Get sample documents
  const orgSnapshot = await targetDb
    .collection('SCHEDULE_TRIPS')
    .where('organizationId', '==', config.targetOrgId)
    .limit(10)
    .get();
  
  if (orgCount > 0) {
    console.log(`\nFirst 10 document IDs: ${orgSnapshot.docs.slice(0, 10).map(d => d.id).join(', ')}`);
    
    // Check a sample document to verify structure
    const sampleDoc = orgSnapshot.docs[0];
    const sampleData = sampleDoc.data();
    console.log(`\nSample document (${sampleDoc.id}) structure:`);
    console.log(`  - organizationId: ${sampleData.organizationId}`);
    console.log(`  - scheduleTripId: ${sampleData.scheduleTripId}`);
    console.log(`  - orderId: ${sampleData.orderId}`);
    console.log(`  - clientName: ${sampleData.clientName}`);
    console.log(`  - tripStatus: ${sampleData.tripStatus}`);
    console.log(`  - Has items: ${Array.isArray(sampleData.items) ? sampleData.items.length : 'no'}`);
    
    // Check if documents have the expected fields
    const missingOrgId = orgSnapshot.docs.filter(d => !d.data().organizationId).length;
    if (missingOrgId > 0) {
      console.log(`\n⚠️  WARNING: ${missingOrgId} documents are missing organizationId field!`);
    }
  } else {
    console.log('\n⚠️  WARNING: No documents found with organizationId filter!');
    if (totalCount > 0) {
      console.log(`But ${totalCount} documents exist in the collection.`);
      console.log('This might indicate an organizationId mismatch. Checking sample document...');
      const sampleSnapshot = await targetDb
        .collection('SCHEDULE_TRIPS')
        .limit(1)
        .get();
      if (!sampleSnapshot.empty) {
        const sampleDoc = sampleSnapshot.docs[0];
        const sampleData = sampleDoc.data();
        console.log(`Sample document organizationId: ${sampleData.organizationId || 'MISSING'}`);
        console.log(`Expected organizationId: ${config.targetOrgId}`);
      }
    } else {
      console.log('No documents found in collection at all. This might indicate a write failure.');
      console.log(`Expected ${processed} documents but found 0.`);
      console.log('Possible causes:');
      console.log('  1. Batch commits may have failed silently');
      console.log('  2. Documents may have been deleted after write');
      console.log('  3. Firestore permissions issue');
      console.log('  4. Wrong database/project being written to');
    }
  }
}

/**
 * Transform Pave trip data to Operon SCHEDULE_TRIPS schema
 */
async function transformTrip(
  data: firestore.DocumentData,
  targetOrgId: string,
  legacyDocId: string,
  slot: number,
  targetDb: admin.firestore.Firestore,
): Promise<firestore.DocumentData | null> {
  // Extract fields from Pave schema
  const orderId = (data.defOrderID as string | undefined);
  const clientId = (data.clientID as string | undefined);
  const clientName = (data.clientName as string | undefined) ?? 'Unknown Client';
  const clientPhone = normalizePhone(data.clientPhoneNumber as string | undefined);
  const vehicleNumber = (data.vehicleNumber as string | undefined);
  const driverName = (data.driverName as string | undefined);
  const deliveryDate = (data.deliveryDate as admin.firestore.Timestamp | undefined);
  const dispatchStart = (data.dispatchStart as string | admin.firestore.Timestamp | Date | null | undefined) ?? null;
  const paySchedule = (data.paySchedule as string | undefined);
  const cityName = (data.city_name as string | undefined) ?? '';
  const region = (data.region as string | undefined) ?? '';
  // Items might be an array or a single object, handle both cases
  let items: any[] = [];
  if (data.items) {
    if (Array.isArray(data.items)) {
      items = data.items;
    } else {
      // Single item object, convert to array
      items = [data.items];
    }
  }
  
  // Debug: Log items structure for first few documents
  if (items.length === 0) {
    console.warn(`Warning: No items found for trip ${legacyDocId}. Available fields:`, Object.keys(data).join(', '));
    // Check for alternative field names
    if (data.productName || data.product_name) {
      console.warn(`  Found productName/product_name at root level, creating item from root fields`);
      items = [{
        productName: data.productName || data.product_name,
        productQuant: data.productQuant || data.product_quant || data.quantity,
        productUnitPrice: data.productUnitPrice || data.product_unit_price || data.unitPrice,
      }];
    }
  }
  const toAccount = (data.toAccount as string | undefined);
  const dmNumber = (data.dmNumber as string | undefined);

  // Required field validation
  if (!orderId || !clientId || !deliveryDate) {
    console.warn(`Skipping trip ${legacyDocId}: Missing required fields (orderId, clientId, or deliveryDate)`);
    return null;
  }
  
  // vehicleNumber is optional - if missing, use empty string
  const finalVehicleNumber = vehicleNumber?.trim() || '';

  // Lookup vehicle ID (optional - if not found, continue without it)
  const vehicleId = await lookupVehicleId(targetDb, vehicleNumber, targetOrgId);
  if (!vehicleId) {
    console.warn(`Warning: Vehicle not found for vehicleNumber "${vehicleNumber}" in trip ${legacyDocId}. Continuing without vehicleId.`);
  }

  // Lookup driver ID (optional)
  let driverId: string | null = null;
  if (driverName) {
    driverId = await lookupDriverId(targetDb, driverName, targetOrgId);
  }

  // Map payment type
  const paymentType = mapPaymentType(paySchedule);

  // Get scheduled day
  const scheduledDay = getDayName(deliveryDate);

  // Get slot name
  const slotName = getSlotName(dispatchStart, slot);

  // Transform items
  const transformedItems: any[] = [];
  for (const item of items) {
    // Try different field name variations
    const productName = (item.productName as string | undefined) 
      || (item.product_name as string | undefined)
      || (item.name as string | undefined);
    
    if (!productName) {
      console.warn(`Skipping item in trip ${legacyDocId}: No productName found. Item keys:`, Object.keys(item).join(', '));
      continue;
    }

    // Try different field name variations
    const productQuant = ((item.productQuant as number | undefined) 
      || (item.product_quant as number | undefined)
      || (item.quantity as number | undefined)
      || (item.qty as number | undefined))
      ?? 0;
    
    const productUnitPrice = ((item.productUnitPrice as number | undefined)
      || (item.product_unit_price as number | undefined)
      || (item.unitPrice as number | undefined)
      || (item.price as number | undefined))
      ?? 0;

    // Lookup product ID
    const productId = await lookupProductId(targetDb, productName, targetOrgId);

    // Calculate trip pricing
    const tripSubtotal = productQuant * productUnitPrice;
    const tripGstAmount = 0; // GST not available in legacy
    const tripTotal = tripSubtotal + tripGstAmount;

    transformedItems.push({
      productId: productId || '',
      productName: productName,
      quantity: productQuant,
      unitPrice: productUnitPrice,
      tripSubtotal: tripSubtotal,
      tripGstAmount: tripGstAmount,
      tripTotal: tripTotal,
    });
  }

  // Calculate trip pricing
  const tripSubtotal = transformedItems.reduce((sum, item) => sum + (item.tripSubtotal || 0), 0);
  const tripGstAmount = transformedItems.reduce((sum, item) => sum + (item.tripGstAmount || 0), 0);
  const tripTotal = transformedItems.reduce((sum, item) => sum + (item.tripTotal || 0), 0);

  const tripPricing = {
    subtotal: tripSubtotal,
    gstAmount: tripGstAmount,
    total: tripTotal,
  };

  // Build delivery zone - use the correct field names
  const deliveryZone = {
    city_name: cityName || '',
    region: region || '',
    zone_id: '', // Will be empty for migrated trips
  };

  // Build payment details for POD trips
  let paymentDetails: any[] | undefined = undefined;
  if (paySchedule === 'POD' && toAccount) {
    const paymentAccount = await lookupPaymentAccount(targetDb, toAccount, targetOrgId);
    if (paymentAccount) {
      // Calculate amount from items
      const amount = transformedItems.reduce((sum, item) => {
        return sum + ((item.quantity || 0) * (item.unitPrice || 0));
      }, 0);

      paymentDetails = [
        {
          amount: amount,
          paidAt: deliveryDate ?? admin.firestore.FieldValue.serverTimestamp(),
          paidBy: '', // Will need to be filled if available
          paymentAccountId: paymentAccount.accountId,
          paymentAccountName: paymentAccount.name,
          paymentAccountType: paymentAccount.type,
          returnPayment: true,
        },
      ];
    }
  }

  // Build the transformed document
  return {
    scheduleTripId: legacyDocId, // Use document ID as scheduleTripId
    orderId: orderId,
    organizationId: targetOrgId,
    clientId: clientId,
    clientName: clientName.trim(),
    clientPhone: clientPhone ?? '',
    customerNumber: clientPhone ?? '',
    paymentType: paymentType,
    scheduledDate: deliveryDate,
    scheduledDay: scheduledDay,
    vehicleId: vehicleId ?? null,
    vehicleNumber: finalVehicleNumber,
    driverId: driverId ?? null,
    driverName: driverName?.trim() ?? null,
    driverPhone: normalizePhone(data.driverPhoneNumber as string | undefined) ?? null,
    slot: slot,
    slotName: slotName,
    deliveryZone: deliveryZone,
    items: transformedItems,
    tripPricing: tripPricing,
    // Add pricing snapshot from order (for reference)
    pricing: {
      currency: 'INR',
      subtotal: tripPricing.subtotal,
      totalAmount: tripPricing.total,
      totalGst: tripPricing.gstAmount,
    },
    includeGstInTotal: false,
    priority: 'normal',
    tripStatus: 'returned', // deliveryStatus = true means returned
    createdAt: deliveryDate ?? admin.firestore.FieldValue.serverTimestamp(),
    createdBy: '', // Empty for migrated trips (no user context)
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(paymentDetails ? { paymentDetails: paymentDetails } : {}),
    ...(dmNumber ? { dmNumber: dmNumber } : {}),
    // Add flag to indicate this is a migrated trip - Cloud Functions should skip validation
    _migrated: true,
    _migrationSource: 'pave',
  };
}

migrateScheduleTrips().catch((error) => {
  console.error('Schedule trips migration failed:', error);
  process.exitCode = 1;
});

