/**
 * Inspect Trip History Script
 * 
 * Diagnostic tool to check what location history data exists for trips.
 * Helps identify the schema format before running migration.
 */

import 'dotenv/config';
import admin from 'firebase-admin';
import type { firestore } from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';

function resolvePath(value?: string) {
  if (!value) return undefined;
  return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
}

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

function readServiceAccount(pathname: string) {
  return JSON.parse(fs.readFileSync(pathname, 'utf8'));
}

const app = admin.initializeApp(
  {
    credential: admin.credential.cert(readServiceAccount(serviceAccount!)),
    projectId: process.env.PROJECT_ID,
  },
  'inspect',
);

const db = app.firestore();

async function inspectTrip(tripId: string) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Trip ID: ${tripId}`);
  console.log('='.repeat(60));

  try {
    // Check new format: SCHEDULE_TRIPS/{tripId}/history
    const newHistoryRef = db.collection('SCHEDULE_TRIPS').doc(tripId).collection('history');
    const newHistorySnapshot = await newHistoryRef.limit(5).get();
    
    console.log(`\n📁 New Format: SCHEDULE_TRIPS/${tripId}/history`);
    console.log(`   Documents found: ${newHistorySnapshot.size}`);
    
    if (newHistorySnapshot.size > 0) {
      const firstDoc = newHistorySnapshot.docs[0];
      const data = firstDoc.data();
      console.log(`   First document ID: ${firstDoc.id}`);
      console.log(`   Fields: ${Object.keys(data).join(', ')}`);
      if (data.locations && Array.isArray(data.locations)) {
        console.log(`   Locations array length: ${data.locations.length}`);
        if (data.locations.length > 0) {
          console.log(`   First location:`, JSON.stringify(data.locations[0], null, 2));
        }
      }
    }

    // Check old format: trips/{tripId}/history
    const oldHistoryRef = db.collection('trips').doc(tripId).collection('history');
    const oldHistorySnapshot = await oldHistoryRef.limit(5).get();
    
    console.log(`\n📁 Old Format: trips/${tripId}/history`);
    console.log(`   Documents found: ${oldHistorySnapshot.size}`);
    
    if (oldHistorySnapshot.size > 0) {
      const firstDoc = oldHistorySnapshot.docs[0];
      const data = firstDoc.data();
      console.log(`   First document ID: ${firstDoc.id}`);
      console.log(`   Fields: ${Object.keys(data).join(', ')}`);
      console.log(`   Sample data:`, JSON.stringify(data, null, 2));
    }

    // Check trip document for inline locationHistory
    const tripRef = db.collection('SCHEDULE_TRIPS').doc(tripId);
    const tripDoc = await tripRef.get();
    
    if (tripDoc.exists) {
      const tripData = tripDoc.data()!;
      console.log(`\n📄 Trip Document: SCHEDULE_TRIPS/${tripId}`);
      console.log(`   Fields: ${Object.keys(tripData).join(', ')}`);
      
      // Check for locationHistory field
      if (tripData.locationHistory) {
        console.log(`   ✅ Found 'locationHistory' field`);
        if (Array.isArray(tripData.locationHistory)) {
          console.log(`   Array length: ${tripData.locationHistory.length}`);
          if (tripData.locationHistory.length > 0) {
            console.log(`   First location:`, JSON.stringify(tripData.locationHistory[0], null, 2));
          }
        } else {
          console.log(`   Type: ${typeof tripData.locationHistory}`);
          console.log(`   Value:`, JSON.stringify(tripData.locationHistory, null, 2));
        }
      }

      // Check for other possible location fields
      const locationFields = Object.keys(tripData).filter(key => 
        key.toLowerCase().includes('location') || 
        key.toLowerCase().includes('history') ||
        key.toLowerCase().includes('track')
      );
      if (locationFields.length > 0) {
        console.log(`   ⚠️  Found potential location fields: ${locationFields.join(', ')}`);
        for (const field of locationFields) {
          const value = tripData[field];
          if (Array.isArray(value)) {
            console.log(`      ${field}: array with ${value.length} items`);
          } else {
            console.log(`      ${field}: ${typeof value}`);
          }
        }
      }

      // Show trip metadata
      console.log(`\n   Trip Metadata:`);
      console.log(`      driverId: ${tripData.driverId ?? 'N/A'}`);
      console.log(`      vehicleNumber: ${tripData.vehicleNumber ?? 'N/A'}`);
      console.log(`      scheduledDate: ${tripData.scheduledDate?.toDate?.() ?? tripData.scheduledDate ?? 'N/A'}`);
      console.log(`      tripStatus: ${tripData.tripStatus ?? 'N/A'}`);
    } else {
      console.log(`\n❌ Trip document does not exist`);
    }

    // Check RTDB for active driver location
    console.log(`\n📡 Realtime Database: active_drivers`);
    if (tripDoc.exists) {
      const tripData = tripDoc.data()!;
      if (tripData.driverId) {
        console.log(`   Driver ID: ${tripData.driverId}`);
        console.log(`   (RTDB inspection requires firebase-admin RTDB SDK)`);
        console.log(`   Check active_drivers/${tripData.driverId} in Firebase Console`);
      }
    }

  } catch (error) {
    console.error(`❌ Error inspecting trip:`, error);
  }
}

async function main() {
  console.log('🔍 Trip History Inspector\n');

  const tripIds = process.argv.slice(2);
  
  if (tripIds.length === 0) {
    // Get all trips, prioritize completed/in-progress ones
    console.log('📥 Fetching trips...');
    let query: admin.firestore.Query = db.collection('SCHEDULE_TRIPS');
    
    if (process.env.ORGANIZATION_ID) {
      query = query.where('organizationId', '==', process.env.ORGANIZATION_ID);
      console.log(`   Filtering by organizationId: ${process.env.ORGANIZATION_ID}`);
    }

    // Try to get completed/in-progress trips first (more likely to have history)
    const completedQuery = query.where('tripStatus', 'in', ['in_progress', 'delivered', 'completed']);
    const completedSnapshot = await completedQuery.limit(10).get();
    
    if (completedSnapshot.size > 0) {
      console.log(`   Found ${completedSnapshot.size} completed/in-progress trips\n`);
      for (const doc of completedSnapshot.docs) {
        await inspectTrip(doc.id);
      }
    } else {
      // Fallback to all trips
      const snapshot = await query.limit(10).get();
      console.log(`   Found ${snapshot.size} trips (showing first 10)\n`);
      for (const doc of snapshot.docs) {
        await inspectTrip(doc.id);
      }
    }
  } else {
    // Inspect specific trips
    for (const tripId of tripIds) {
      await inspectTrip(tripId);
    }
  }

  await app.delete();
}

main().catch(console.error);
