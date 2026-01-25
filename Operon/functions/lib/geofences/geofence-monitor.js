"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onDriverLocationUpdate = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const firestore_helpers_1 = require("../shared/firestore-helpers");
const logger_1 = require("../shared/logger");
const geofence_utils_1 = require("./geofence-utils");
const db = (0, firestore_helpers_1.getFirestore)();
const rtdb = admin.database();
const geofenceCache = new Map();
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
exports.onDriverLocationUpdate = functions.database
    .ref('/active_drivers/{uid}')
    .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const locationData = change.after.val();
    // Early exit if location data is deleted
    if (!locationData) {
        return null;
    }
    const lat = locationData.lat;
    const lng = locationData.lng;
    if (lat == null || lng == null) {
        (0, logger_1.logWarning)('GeofenceMonitor', 'onDriverLocationUpdate', 'Missing lat/lng in location data', {
            uid,
        });
        return null;
    }
    const currentPoint = { lat, lng };
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
            (0, logger_1.logInfo)('GeofenceMonitor', 'onDriverLocationUpdate', 'User has no organizations', { uid });
            return null;
        }
        // Process geofences for each organization
        for (const orgId of orgIds) {
            await processGeofencesForOrganization(uid, orgId, currentPoint, locationData);
        }
        return null;
    }
    catch (error) {
        (0, logger_1.logError)('GeofenceMonitor', 'onDriverLocationUpdate', 'Error processing geofence check', error instanceof Error ? error : new Error(String(error)), { uid });
        return null;
    }
});
/**
 * Check if we should process geofence check (debounce + distance check)
 */
async function shouldProcessGeofenceCheck(uid, currentPoint) {
    const driverRef = rtdb.ref(`active_drivers/${uid}`);
    // Check debounce (last check time)
    const lastCheckSnapshot = await driverRef.child('geofence_last_check').once('value');
    const lastCheckTime = lastCheckSnapshot.val();
    if (lastCheckTime != null) {
        const timeSinceLastCheck = Date.now() - lastCheckTime;
        if (timeSinceLastCheck < DEBOUNCE_INTERVAL_MS) {
            // Too soon, skip
            return false;
        }
    }
    // Check distance from last checked position
    const lastPositionSnapshot = await driverRef.child('geofence_last_position').once('value');
    const lastPosition = lastPositionSnapshot.val();
    if (lastPosition != null) {
        const distance = (0, geofence_utils_1.haversineDistance)(currentPoint.lat, currentPoint.lng, lastPosition.lat, lastPosition.lng);
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
async function updateLastCheckState(uid, point) {
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
async function getUserOrganizations(uid) {
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
async function processGeofencesForOrganization(uid, orgId, currentPoint, locationData) {
    // Get cached or fresh geofences
    const geofences = await getCachedGeofences(orgId);
    if (geofences.length === 0) {
        return;
    }
    // Get vehicle info
    const vehicleNumber = locationData.vehicleNumber;
    // Check each geofence
    for (const geofence of geofences) {
        // Quick bounding box check first
        if (!(0, geofence_utils_1.isNearGeofence)(currentPoint, geofence)) {
            continue;
        }
        // Check if point is inside geofence
        const isInside = (0, geofence_utils_1.checkPointInGeofence)(currentPoint, geofence);
        // Get last known state from RTDB
        const lastState = await getLastGeofenceState(uid, geofence.id || '');
        // Check if state changed
        if ((lastState === null || lastState === void 0 ? void 0 : lastState.isInside) !== isInside) {
            // State changed - create event and notifications
            await handleGeofenceStateChange(uid, orgId, geofence, currentPoint, isInside, vehicleNumber);
            // Update state in RTDB
            await updateGeofenceState(uid, geofence.id || '', isInside);
        }
    }
}
/**
 * Get cached geofences or fetch from Firestore
 */
async function getCachedGeofences(orgId) {
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
    const geofences = geofencesSnapshot.docs.map((doc) => {
        const data = doc.data();
        return {
            id: doc.id,
            type: data.type,
            centerLat: data.center_lat,
            centerLng: data.center_lng,
            radiusMeters: data.radius_meters,
            polygonPoints: data.polygon_points,
        };
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
async function getLastGeofenceState(uid, geofenceId) {
    const stateRef = rtdb.ref(`active_drivers/${uid}/geofence_states/${geofenceId}`);
    const snapshot = await stateRef.once('value');
    const data = snapshot.val();
    if (data == null) {
        return null;
    }
    return {
        isInside: data.is_inside,
        timestamp: data.last_updated,
    };
}
/**
 * Update geofence state in RTDB
 */
async function updateGeofenceState(uid, geofenceId, isInside) {
    const stateRef = rtdb.ref(`active_drivers/${uid}/geofence_states/${geofenceId}`);
    await stateRef.set({
        is_inside: isInside,
        last_updated: Date.now(),
    });
}
/**
 * Handle geofence state change - create event and notifications
 */
async function handleGeofenceStateChange(uid, orgId, geofence, point, isInside, vehicleNumber) {
    const eventType = isInside ? 'entered' : 'exited';
    // Get geofence document to get recipients
    const geofenceDoc = await db
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('GEOFENCES')
        .doc(geofence.id || '')
        .get();
    if (!geofenceDoc.exists) {
        (0, logger_1.logWarning)('GeofenceMonitor', 'handleGeofenceStateChange', 'Geofence document not found', {
            geofenceId: geofence.id,
        });
        return;
    }
    const geofenceData = geofenceDoc.data();
    const recipientIds = geofenceData.notification_recipient_ids || [];
    const geofenceName = geofenceData.name || 'Geofence';
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
        await createNotifications(orgId, recipientIds, {
            geofenceId: geofence.id || '',
            geofenceName,
            eventType,
            vehicleNumber,
            driverName: driverInfo.name,
            point,
        });
    }
    (0, logger_1.logInfo)('GeofenceMonitor', 'handleGeofenceStateChange', `Vehicle ${eventType} geofence`, {
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
async function getDriverInfo(uid, orgId) {
    try {
        const userDoc = await db
            .collection('ORGANIZATIONS')
            .doc(orgId)
            .collection('USERS')
            .doc(uid)
            .get();
        if (userDoc.exists) {
            const data = userDoc.data();
            return {
                name: data.user_name || 'Unknown Driver',
            };
        }
    }
    catch (error) {
        (0, logger_1.logWarning)('GeofenceMonitor', 'getDriverInfo', 'Failed to get driver info', {
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
async function createNotifications(orgId, recipientIds, eventData) {
    const batch = db.batch();
    const notificationsRef = db
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('NOTIFICATIONS');
    const eventTypeLabel = eventData.eventType === 'entered' ? 'entered' : 'left';
    const title = `Vehicle ${eventTypeLabel} geofence`;
    const message = `${eventData.driverName || 'A vehicle'} ${eventTypeLabel} ${eventData.geofenceName}${eventData.vehicleNumber ? ` (${eventData.vehicleNumber})` : ''}`;
    // Batch create notifications (Firestore limit is 500)
    const batches = [];
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
    (0, logger_1.logInfo)('GeofenceMonitor', 'createNotifications', 'Created notifications', {
        orgId,
        recipientCount: recipientIds.length,
        eventType: eventData.eventType,
    });
}
//# sourceMappingURL=geofence-monitor.js.map