import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getFirestore } from '../shared/firestore-helpers';
import { logInfo, logError, logWarning } from '../shared/logger';
import {
  checkPointInGeofence,
  haversineDistance,
  isNearGeofence,
  Point,
  Geofence,
} from './geofence-utils';

const db = getFirestore();
const rtdb = admin.database();

// In-memory cache for geofences (5-minute TTL)
interface GeofenceWithId extends Geofence {
  id?: string;
}

interface CachedGeofences {
  geofences: GeofenceWithId[];
  timestamp: number;
}

const geofenceCache = new Map<string, CachedGeofences>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes
const DEBOUNCE_INTERVAL_MS = 30 * 1000; // 30 seconds
const MIN_DISTANCE_METERS = 50; // 50 meters

/**
 * Cloud Function: Monitor geofences when driver location is updated in RTDB
 * 
 * Cost optimizations:
 * - Debouncing: Only check if last check was >30s ago
 * - Distance-based: Only check if moved >50m from last checked position
 * - Caching: Cache geofences in memory (5-min TTL)
 * - State in RTDB: Store last state in RTDB instead of querying Firestore
 */
export const onDriverLocationUpdate = functions.database
  .ref('/active_drivers/{uid}')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const locationData = change.after.val();

    // Early exit if location data is deleted
    if (!locationData) {
      return null;
    }

    const lat = locationData.lat as number | undefined;
    const lng = locationData.lng as number | undefined;

    if (lat == null || lng == null) {
      logWarning('GeofenceMonitor', 'onDriverLocationUpdate', 'Missing lat/lng in location data', {
        uid,
      });
      return null;
    }

    const currentPoint: Point = { lat, lng };

    try {
      // Early exit checks (no Firestore reads)
      const shouldProcess = await shouldProcessGeofenceCheck(uid, currentPoint);
      if (!shouldProcess) {
        return null;
      }

      // Update last check state in RTDB
      await updateLastCheckState(uid, currentPoint);

      // Get user's organizations
      const orgIds = await getUserOrganizations(uid);
      if (orgIds.length === 0) {
        logInfo('GeofenceMonitor', 'onDriverLocationUpdate', 'User has no organizations', { uid });
        return null;
      }

      // Process geofences for each organization
      for (const orgId of orgIds) {
        await processGeofencesForOrganization(uid, orgId, currentPoint, locationData);
      }

      return null;
    } catch (error) {
      logError(
        'GeofenceMonitor',
        'onDriverLocationUpdate',
        'Error processing geofence check',
        error instanceof Error ? error : new Error(String(error)),
        { uid },
      );
      return null;
    }
  });

/**
 * Check if we should process geofence check (debounce + distance check)
 */
async function shouldProcessGeofenceCheck(
  uid: string,
  currentPoint: Point,
): Promise<boolean> {
  const driverRef = rtdb.ref(`active_drivers/${uid}`);

  // Check debounce (last check time)
  const lastCheckSnapshot = await driverRef.child('geofence_last_check').once('value');
  const lastCheckTime = lastCheckSnapshot.val() as number | null;

  if (lastCheckTime != null) {
    const timeSinceLastCheck = Date.now() - lastCheckTime;
    if (timeSinceLastCheck < DEBOUNCE_INTERVAL_MS) {
      // Too soon, skip
      return false;
    }
  }

  // Check distance from last checked position
  const lastPositionSnapshot = await driverRef.child('geofence_last_position').once('value');
  const lastPosition = lastPositionSnapshot.val() as { lat: number; lng: number } | null;

  if (lastPosition != null) {
    const distance = haversineDistance(
      currentPoint.lat,
      currentPoint.lng,
      lastPosition.lat,
      lastPosition.lng,
    );

    if (distance < MIN_DISTANCE_METERS) {
      // Not moved enough, skip
      return false;
    }
  }

  return true;
}

/**
 * Update last check state in RTDB
 */
async function updateLastCheckState(uid: string, point: Point): Promise<void> {
  const driverRef = rtdb.ref(`active_drivers/${uid}`);
  await driverRef.update({
    geofence_last_check: Date.now(),
    geofence_last_position: {
      lat: point.lat,
      lng: point.lng,
    },
  });
}

/**
 * Get user's organization IDs
 */
async function getUserOrganizations(uid: string): Promise<string[]> {
  const userOrgsSnapshot = await db
    .collection('USERS')
    .doc(uid)
    .collection('ORGANIZATIONS')
    .get();

  return userOrgsSnapshot.docs.map((doc) => doc.id);
}

/**
 * Process geofences for a specific organization
 */
async function processGeofencesForOrganization(
  uid: string,
  orgId: string,
  currentPoint: Point,
  locationData: any,
): Promise<void> {
  // Get cached or fresh geofences
  const geofences = await getCachedGeofences(orgId);

  if (geofences.length === 0) {
    return;
  }

  // Get vehicle info
  const vehicleNumber = locationData.vehicleNumber as string | undefined;

  // Check each geofence
  for (const geofence of geofences) {
    // Quick bounding box check first
    if (!isNearGeofence(currentPoint, geofence)) {
      continue;
    }

    // Check if point is inside geofence
    const isInside = checkPointInGeofence(currentPoint, geofence);

    // Get last known state from RTDB
    const lastState = await getLastGeofenceState(uid, geofence.id || '');

    // Check if state changed
    if (lastState?.isInside !== isInside) {
      // State changed - create event and notifications
      await handleGeofenceStateChange(
        uid,
        orgId,
        geofence,
        currentPoint,
        isInside,
        vehicleNumber,
      );

      // Update state in RTDB
      await updateGeofenceState(uid, geofence.id || '', isInside);
    }
  }
}

/**
 * Get cached geofences or fetch from Firestore
 */
async function getCachedGeofences(orgId: string): Promise<GeofenceWithId[]> {
  const cacheKey = `geofences_${orgId}`;
  const cached = geofenceCache.get(cacheKey);

  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.geofences;
  }

  // Fetch from Firestore
  const geofencesSnapshot = await db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('GEOFENCES')
    .where('is_active', '==', true)
    .get();

  const geofences: GeofenceWithId[] = geofencesSnapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      type: data.type as 'circle' | 'polygon',
      centerLat: data.center_lat as number,
      centerLng: data.center_lng as number,
      radiusMeters: data.radius_meters as number | undefined,
      polygonPoints: data.polygon_points as Array<{ lat: number; lng: number }> | undefined,
    } as GeofenceWithId;
  });

  // Update cache
  geofenceCache.set(cacheKey, {
    geofences,
    timestamp: Date.now(),
  });

  return geofences;
}

/**
 * Get last known geofence state from RTDB
 */
async function getLastGeofenceState(
  uid: string,
  geofenceId: string,
): Promise<{ isInside: boolean; timestamp: number } | null> {
  const stateRef = rtdb.ref(`active_drivers/${uid}/geofence_states/${geofenceId}`);
  const snapshot = await stateRef.once('value');
  const data = snapshot.val();

  if (data == null) {
    return null;
  }

  return {
    isInside: data.is_inside as boolean,
    timestamp: data.last_updated as number,
  };
}

/**
 * Update geofence state in RTDB
 */
async function updateGeofenceState(
  uid: string,
  geofenceId: string,
  isInside: boolean,
): Promise<void> {
  const stateRef = rtdb.ref(`active_drivers/${uid}/geofence_states/${geofenceId}`);
  await stateRef.set({
    is_inside: isInside,
    last_updated: Date.now(),
  });
}

/**
 * Handle geofence state change - create event and notifications
 */
async function handleGeofenceStateChange(
  uid: string,
  orgId: string,
  geofence: GeofenceWithId,
  point: Point,
  isInside: boolean,
  vehicleNumber?: string,
): Promise<void> {
  const eventType = isInside ? 'entered' : 'exited';

  // Get geofence document to get recipients
  const geofenceDoc = await db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('GEOFENCES')
    .doc(geofence.id || '')
    .get();

  if (!geofenceDoc.exists) {
    logWarning('GeofenceMonitor', 'handleGeofenceStateChange', 'Geofence document not found', {
      geofenceId: geofence.id,
    });
    return;
  }

  const geofenceData = geofenceDoc.data()!;
  const recipientIds = (geofenceData.notification_recipient_ids as string[]) || [];
  const geofenceName = geofenceData.name as string || 'Geofence';

  // Get driver info
  const driverInfo = await getDriverInfo(uid, orgId);

  // Create geofence event
  await db.collection('ORGANIZATIONS').doc(orgId).collection('GEOFENCE_EVENTS').add({
    geofence_id: geofence.id,
    user_id: uid,
    vehicle_number: vehicleNumber,
    event_type: eventType,
    latitude: point.lat,
    longitude: point.lng,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create notifications for recipients
  if (recipientIds.length > 0) {
    await createNotifications(
      orgId,
      recipientIds,
      {
        geofenceId: geofence.id || '',
        geofenceName,
        eventType,
        vehicleNumber,
        driverName: driverInfo.name,
        point,
      },
    );
  }

  logInfo('GeofenceMonitor', 'handleGeofenceStateChange', `Vehicle ${eventType} geofence`, {
    uid,
    orgId,
    geofenceId: geofence.id,
    geofenceName,
    eventType,
    vehicleNumber,
  });
}

/**
 * Get driver info (name) from organization
 */
async function getDriverInfo(uid: string, orgId: string): Promise<{ name: string }> {
  try {
    const userDoc = await db
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('USERS')
      .doc(uid)
      .get();

    if (userDoc.exists) {
      const data = userDoc.data()!;
      return {
        name: (data.user_name as string) || 'Unknown Driver',
      };
    }
  } catch (error) {
    logWarning('GeofenceMonitor', 'getDriverInfo', 'Failed to get driver info', {
      uid,
      orgId,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return { name: 'Unknown Driver' };
}

/**
 * Create notifications for recipients (batch write)
 */
async function createNotifications(
  orgId: string,
  recipientIds: string[],
  eventData: {
    geofenceId: string;
    geofenceName: string;
    eventType: string;
    vehicleNumber?: string;
    driverName?: string;
    point: Point;
  },
): Promise<void> {
  const batch = db.batch();
  const notificationsRef = db
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('NOTIFICATIONS');

  const eventTypeLabel = eventData.eventType === 'entered' ? 'entered' : 'left';
  const title = `Vehicle ${eventTypeLabel} geofence`;
  const message = `${eventData.driverName || 'A vehicle'} ${eventTypeLabel} ${eventData.geofenceName}${eventData.vehicleNumber ? ` (${eventData.vehicleNumber})` : ''}`;

  // Batch create notifications (Firestore limit is 500)
  const batches: typeof batch[] = [];
  let currentBatch = db.batch();
  let count = 0;

  for (const recipientId of recipientIds) {
    if (count >= 500) {
      batches.push(currentBatch);
      currentBatch = db.batch();
      count = 0;
    }

    const notifRef = notificationsRef.doc();
    currentBatch.set(notifRef, {
      user_id: recipientId,
      type: eventData.eventType === 'entered' ? 'geofenceEnter' : 'geofenceExit',
      title,
      message,
      geofence_id: eventData.geofenceId,
      vehicle_number: eventData.vehicleNumber,
      driver_name: eventData.driverName,
      is_read: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    count++;
  }

  if (count > 0) {
    batches.push(currentBatch);
  }

  // Commit all batches
  await Promise.all(batches.map((b) => b.commit()));

  logInfo('GeofenceMonitor', 'createNotifications', 'Created notifications', {
    orgId,
    recipientCount: recipientIds.length,
    eventType: eventData.eventType,
  });
}
