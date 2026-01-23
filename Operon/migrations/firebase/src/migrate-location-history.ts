/**
 * Location History Migration Script
 * 
 * Migrates location history data to the new schema format:
 * - Old: Various formats (single locations, different paths, etc.)
 * - New: SCHEDULE_TRIPS/{tripId}/history/{docId} with 'locations' array
 * 
 * Before running:
 * 1. Review the old data structure in Firestore
 * 2. Update the migration logic based on your old schema
 * 3. Test on a small subset first
 * 4. Ensure Firestore indexes are created for queries
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

interface MigrationConfig {
  serviceAccount: string;
  projectId?: string;
  organizationId?: string; // Optional: migrate only for specific org
  dryRun: boolean; // If true, only logs what would be migrated
  batchSize: number; // Number of trips to process at once
}

const FALLBACK_TARGET_ORG = 'NlQgs9kADbZr4ddBRkhS';

interface LocationData {
  lat: number;
  lng: number;
  bearing: number;
  speed: number;
  status: string;
  timestamp: number; // milliseconds since epoch
}

interface HistoryDocument {
  locations: LocationData[];
  createdAt: firestore.Timestamp;
}

function resolveConfig(): MigrationConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  // Try multiple possible service account file names
  const possiblePaths = [
    resolvePath(process.env.SERVICE_ACCOUNT),
    resolvePath(process.env.NEW_SERVICE_ACCOUNT),
    path.join(process.cwd(), 'creds/new-service-account.json'),
    path.join(process.cwd(), 'creds/service-account.json'),
  ].filter((p): p is string => p !== undefined);

  let serviceAccount: string | undefined;
  for (const possiblePath of possiblePaths) {
    if (fs.existsSync(possiblePath)) {
      serviceAccount = possiblePath;
      break;
    }
  }

  if (!serviceAccount) {
    throw new Error(
      `Service account file not found. Tried:\n${possiblePaths.map(p => `  - ${p}`).join('\n')}\n\n` +
        'Please download service account JSON file from Google Cloud Console and place it in:\n' +
        `  - ${path.join(process.cwd(), 'creds/new-service-account.json')}\n\n` +
        'Or set SERVICE_ACCOUNT or NEW_SERVICE_ACCOUNT environment variable with full path.',
    );
  }

  return {
    serviceAccount: serviceAccount!,
    projectId: process.env.PROJECT_ID,
    organizationId: process.env.ORGANIZATION_ID,
    dryRun: process.env.DRY_RUN === 'true',
    batchSize: parseInt(process.env.BATCH_SIZE ?? '10', 10),
  };
}

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

function initApp(config: MigrationConfig): admin.app.App {
  return admin.initializeApp(
    {
      credential: admin.credential.cert(readServiceAccount(config.serviceAccount)),
      projectId: config.projectId,
    },
    'migration',
  );
}

/**
 * Normalizes location data to the new schema format
 */
function normalizeLocation(loc: any): LocationData | null {
  try {
    // Handle different possible field names and formats
    const lat = typeof loc.lat === 'number' ? loc.lat : parseFloat(loc.latitude ?? loc.lat ?? 0);
    const lng = typeof loc.lng === 'number' ? loc.lng : parseFloat(loc.longitude ?? loc.lng ?? 0);
    const bearing = typeof loc.bearing === 'number' ? loc.bearing : parseFloat(loc.heading ?? loc.bearing ?? 0);
    const speed = typeof loc.speed === 'number' ? loc.speed : parseFloat(loc.speed ?? 0);
    const status = loc.status ?? loc.state ?? 'active';
    
    // Handle timestamp - could be milliseconds, seconds, or Timestamp
    let timestamp: number;
    if (typeof loc.timestamp === 'number') {
      timestamp = loc.timestamp;
      // If timestamp is in seconds (less than year 2000 in ms), convert to ms
      if (timestamp < 946684800000) {
        timestamp = timestamp * 1000;
      }
    } else if (loc.timestamp?.toMillis) {
      timestamp = loc.timestamp.toMillis();
    } else if (loc.createdAt?.toMillis) {
      timestamp = loc.createdAt.toMillis();
    } else {
      timestamp = Date.now(); // Fallback to current time
    }

    if (isNaN(lat) || isNaN(lng)) {
      return null;
    }

    return {
      lat,
      lng,
      bearing: isNaN(bearing) ? 0 : bearing,
      speed: isNaN(speed) ? 0 : speed,
      status: String(status),
      timestamp,
    };
  } catch (error) {
    console.error('Error normalizing location:', error, loc);
    return null;
  }
}

/**
 * Migrates location history for a single trip
 */
async function migrateTripHistory(
  db: admin.firestore.Firestore,
  tripId: string,
  config: MigrationConfig,
): Promise<{ migrated: number; skipped: number; errors: number }> {
  const stats = { migrated: 0, skipped: 0, errors: 0 };

  try {
    const tripRef = db.collection('SCHEDULE_TRIPS').doc(tripId);
    const tripDoc = await tripRef.get();

    if (!tripDoc.exists) {
      console.log(`  ⚠️  Trip ${tripId} does not exist, skipping`);
      stats.skipped++;
      return stats;
    }

    const historyRef = tripRef.collection('history');
    
    // Check if history already exists in new format
    const existingHistory = await historyRef.limit(1).get();
    if (!existingHistory.empty) {
      // Check if it's already in the new format (has 'locations' array)
      const firstDoc = existingHistory.docs[0];
      const data = firstDoc.data();
      if (data.locations && Array.isArray(data.locations)) {
        console.log(`  ✓ Trip ${tripId} already has new format history, skipping`);
        stats.skipped++;
        return stats;
      }
    }

    // TODO: Add logic here to read from old schema
    // Examples of old schemas you might need to handle:
    
    // Option 1: Old path - trips/{tripId}/history
    const oldHistoryRef = db.collection('trips').doc(tripId).collection('history');
    const oldHistorySnapshot = await oldHistoryRef.get();
    
    if (!oldHistorySnapshot.empty) {
      console.log(`  📦 Found ${oldHistorySnapshot.docs.length} old history documents for trip ${tripId}`);
      
      // Group locations by batch (similar to how location_service.dart does it)
      const locations: LocationData[] = [];
      
      for (const oldDoc of oldHistorySnapshot.docs) {
        const oldData = oldDoc.data();
        
        // Handle different old formats
        if (oldData.locations && Array.isArray(oldData.locations)) {
          // Already in array format, just normalize
          for (const loc of oldData.locations) {
            const normalized = normalizeLocation(loc);
            if (normalized) locations.push(normalized);
          }
        } else if (oldData.lat && oldData.lng) {
          // Single location per document
          const normalized = normalizeLocation(oldData);
          if (normalized) locations.push(normalized);
        } else {
          console.log(`  ⚠️  Unknown format in old doc ${oldDoc.id}`);
        }
      }

      if (locations.length > 0) {
        // Sort by timestamp
        locations.sort((a, b) => a.timestamp - b.timestamp);

        // Group into batches of 100 (matching location_service.dart buffer size)
        const batchSize = 100;
        for (let i = 0; i < locations.length; i += batchSize) {
          const batch = locations.slice(i, i + batchSize);
          const batchCreatedAt = batch[0]?.timestamp 
            ? admin.firestore.Timestamp.fromMillis(batch[0].timestamp)
            : admin.firestore.Timestamp.now();

          if (!config.dryRun) {
            await historyRef.add({
              locations: batch,
              createdAt: batchCreatedAt,
            });
          }
          stats.migrated += batch.length;
        }

        console.log(`  ✅ Migrated ${locations.length} locations for trip ${tripId}`);
      } else {
        console.log(`  ⚠️  No valid locations found for trip ${tripId}`);
        stats.skipped++;
      }
    } else {
      // Check for other possible old locations
      // Option 2: Locations stored directly in trip document
      const tripData = tripDoc.data();
      if (tripData?.locationHistory && Array.isArray(tripData.locationHistory)) {
        console.log(`  📦 Found locationHistory array in trip document ${tripId}`);
        const locations: LocationData[] = [];
        
        for (const loc of tripData.locationHistory) {
          const normalized = normalizeLocation(loc);
          if (normalized) locations.push(normalized);
        }

        if (locations.length > 0) {
          locations.sort((a, b) => a.timestamp - b.timestamp);
          
          const batchSize = 100;
          for (let i = 0; i < locations.length; i += batchSize) {
            const batch = locations.slice(i, i + batchSize);
            const batchCreatedAt = batch[0]?.timestamp 
              ? admin.firestore.Timestamp.fromMillis(batch[0].timestamp)
              : admin.firestore.Timestamp.now();

            if (!config.dryRun) {
              await historyRef.add({
                locations: batch,
                createdAt: batchCreatedAt,
              });
            }
            stats.migrated += batch.length;
          }

          // Optionally remove old field from trip document
          if (!config.dryRun && config.organizationId) {
            await tripRef.update({
              locationHistory: admin.firestore.FieldValue.delete(),
            });
          }

          console.log(`  ✅ Migrated ${locations.length} locations from trip document ${tripId}`);
        }
      } else {
        console.log(`  ⚠️  No old history found for trip ${tripId}`);
        stats.skipped++;
      }
    }
  } catch (error) {
    console.error(`  ❌ Error migrating trip ${tripId}:`, error);
    stats.errors++;
  }

  return stats;
}

async function main() {
  console.log('🚀 Starting Location History Migration\n');

  const config = resolveConfig();
  const app = initApp(config);
  const db = app.firestore();

  if (config.dryRun) {
    console.log('⚠️  DRY RUN MODE - No data will be written\n');
  }

  try {
    let query: admin.firestore.Query = db.collection('SCHEDULE_TRIPS');
    
    if (config.organizationId) {
      query = query.where('organizationId', '==', config.organizationId);
      console.log(`📋 Filtering by organizationId: ${config.organizationId}\n`);
    }

    console.log('📥 Fetching trips...');
    const tripsSnapshot = await query.get();
    console.log(`✅ Found ${tripsSnapshot.docs.length} trips to process\n`);

    const totalStats = { migrated: 0, skipped: 0, errors: 0 };
    let processed = 0;

    // Process in batches
    for (let i = 0; i < tripsSnapshot.docs.length; i += config.batchSize) {
      const batch = tripsSnapshot.docs.slice(i, i + config.batchSize);
      
      console.log(`\n📦 Processing batch ${Math.floor(i / config.batchSize) + 1} (${batch.length} trips)...`);

      for (const tripDoc of batch) {
        const tripId = tripDoc.id;
        console.log(`\n  Processing trip: ${tripId}`);
        
        const stats = await migrateTripHistory(db, tripId, config);
        totalStats.migrated += stats.migrated;
        totalStats.skipped += stats.skipped;
        totalStats.errors += stats.errors;
        processed++;

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      console.log(`\n  Progress: ${processed}/${tripsSnapshot.docs.length} trips processed`);
    }

    console.log('\n' + '='.repeat(50));
    console.log('📊 Migration Summary:');
    console.log(`  ✅ Locations migrated: ${totalStats.migrated}`);
    console.log(`  ⏭️  Trips skipped: ${totalStats.skipped}`);
    console.log(`  ❌ Errors: ${totalStats.errors}`);
    console.log('='.repeat(50));

  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await app.delete();
  }
}

main().catch(console.error);
