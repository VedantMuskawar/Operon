const {setGlobalOptions} = require("firebase-functions");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// =============================================================================
// SYSTEM METADATA FUNCTIONS
// =============================================================================

/**
 * Initialize system metadata counters
 * This function should be called once to set up initial counters
 */
exports.webInitializeSystemMetadata = onCall(async (request) => {
  try {
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    
    const initialData = {
      totalOrganizations: 0,
      totalUsers: 0,
      totalRevenue: 0.0,
      activeSubscriptions: 0,
      lastOrgIdCounter: 0,
      lastUserIdCounter: 0,
      lastUpdated: FieldValue.serverTimestamp(),
    };

    await countersRef.set(initialData);
    
    logger.info('System metadata initialized successfully');
    return { success: true, message: 'System metadata initialized' };
  } catch (error) {
    logger.error('Error initializing system metadata:', error);
    throw new Error(`Failed to initialize system metadata: ${error.message}`);
  }
});

/**
 * Get system metadata counters
 */
exports.webGetSystemMetadata = onCall(async (request) => {
  try {
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    const doc = await countersRef.get();
    
    if (!doc.exists) {
      // Initialize if doesn't exist
      await exports.webInitializeSystemMetadata.run(request);
      const newDoc = await countersRef.get();
      return newDoc.data();
    }
    
    return doc.data();
  } catch (error) {
    logger.error('Error getting system metadata:', error);
    throw new Error(`Failed to get system metadata: ${error.message}`);
  }
});

/**
 * Update system metadata counters atomically
 */
exports.webUpdateSystemMetadata = onCall(async (request) => {
  try {
    const { updates } = request.data;
    
    if (!updates || typeof updates !== 'object') {
      throw new Error('Updates object is required');
    }

    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    
    // Add timestamp to updates
    updates.lastUpdated = FieldValue.serverTimestamp();
    
    await countersRef.update(updates);
    
    logger.info('System metadata updated successfully', { updates });
    return { success: true, message: 'System metadata updated' };
  } catch (error) {
    logger.error('Error updating system metadata:', error);
    throw new Error(`Failed to update system metadata: ${error.message}`);
  }
});

// =============================================================================
// ORGANIZATION TRIGGERS
// =============================================================================

/**
 * Trigger: When a new organization is created
 */
exports.webOnOrganizationCreated = onDocumentCreated({
  document: 'ORGANIZATIONS/{orgId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const orgData = event.data.data();
    
    logger.info(`New organization created: ${orgId}`);
    
    // Increment organization counter
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    await countersRef.update({
      totalOrganizations: FieldValue.increment(1),
      lastOrgIdCounter: FieldValue.increment(1),
      lastUpdated: FieldValue.serverTimestamp()
    });

    // Create activity log
    await db.collection('ACTIVITY').add({
      type: 'ORGANIZATION_CREATED',
      orgId: orgId,
      orgName: orgData.orgName,
      timestamp: FieldValue.serverTimestamp(),
      performedBy: orgData.createdBy || 'system',
      details: {
        email: orgData.email,
        gstNo: orgData.gstNo,
        status: orgData.status
      }
    });

    logger.info(`Organization ${orgId} processed successfully`);
  } catch (error) {
    logger.error('Error processing organization creation:', error);
  }
});

/**
 * Trigger: When an organization is updated
 */
exports.webOnOrganizationUpdated = onDocumentUpdated({
  document: 'ORGANIZATIONS/{orgId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    
    logger.info(`Organization updated: ${orgId}`);
    
    // Create activity log for significant changes
    const changes = [];
    
    if (beforeData.orgName !== afterData.orgName) {
      changes.push(`Name: ${beforeData.orgName} → ${afterData.orgName}`);
    }
    
    if (beforeData.status !== afterData.status) {
      changes.push(`Status: ${beforeData.status} → ${afterData.status}`);
    }
    
    if (changes.length > 0) {
      await db.collection('ACTIVITY').add({
        type: 'ORGANIZATION_UPDATED',
        orgId: orgId,
        orgName: afterData.orgName,
        timestamp: FieldValue.serverTimestamp(),
        performedBy: 'system',
        details: {
          changes: changes,
          previousData: beforeData,
          newData: afterData
        }
      });
    }

    logger.info(`Organization ${orgId} update processed successfully`);
  } catch (error) {
    logger.error('Error processing organization update:', error);
  }
});

/**
 * Trigger: When an organization is deleted
 */
exports.webOnOrganizationDeleted = onDocumentDeleted({
  document: 'ORGANIZATIONS/{orgId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const orgData = event.data.data();
    
    logger.info(`Organization deleted: ${orgId}`);
    
    // Decrement organization counter
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    await countersRef.update({
      totalOrganizations: FieldValue.increment(-1),
      lastUpdated: FieldValue.serverTimestamp()
    });

    // Create activity log
    await db.collection('ACTIVITY').add({
      type: 'ORGANIZATION_DELETED',
      orgId: orgId,
      orgName: orgData.orgName,
      timestamp: FieldValue.serverTimestamp(),
      performedBy: 'system',
      details: {
        email: orgData.email,
        gstNo: orgData.gstNo,
        status: orgData.status
      }
    });

    logger.info(`Organization ${orgId} deletion processed successfully`);
  } catch (error) {
    logger.error('Error processing organization deletion:', error);
  }
});

// =============================================================================
// USER TRIGGERS
// =============================================================================

/**
 * Trigger: When a new user is created
 */
exports.webOnUserCreated = onDocumentCreated({
  document: 'USERS/{userId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const userId = event.params.userId;
    const userData = event.data.data();
    
    logger.info(`New user created: ${userId}`);
    
    // Increment user counter
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    await countersRef.update({
      totalUsers: FieldValue.increment(1),
      lastUserIdCounter: FieldValue.increment(1),
      lastUpdated: FieldValue.serverTimestamp()
    });

    // Create activity log
    await db.collection('ACTIVITY').add({
      type: 'USER_CREATED',
      userId: userId,
      userName: userData.name,
      timestamp: FieldValue.serverTimestamp(),
      performedBy: userData.createdBy || 'system',
      details: {
        phoneNo: userData.phoneNo,
        email: userData.email,
        status: userData.status,
        role: userData.organizations?.[0]?.role || 'unknown'
      }
    });

    logger.info(`User ${userId} processed successfully`);
  } catch (error) {
    logger.error('Error processing user creation:', error);
  }
});

/**
 * Trigger: When a user is updated
 */
exports.webOnUserUpdated = onDocumentUpdated({
  document: 'USERS/{userId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const userId = event.params.userId;
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    
    logger.info(`User updated: ${userId}`);
    
    // Create activity log for significant changes
    const changes = [];
    
    if (beforeData.status !== afterData.status) {
      changes.push(`Status: ${beforeData.status} → ${afterData.status}`);
    }
    
    if (beforeData.name !== afterData.name) {
      changes.push(`Name: ${beforeData.name} → ${afterData.name}`);
    }
    
    if (changes.length > 0) {
      await db.collection('ACTIVITY').add({
        type: 'USER_UPDATED',
        userId: userId,
        userName: afterData.name,
        timestamp: FieldValue.serverTimestamp(),
        performedBy: 'system',
        details: {
          changes: changes,
          previousData: beforeData,
          newData: afterData
        }
      });
    }

    logger.info(`User ${userId} update processed successfully`);
  } catch (error) {
    logger.error('Error processing user update:', error);
  }
});

// =============================================================================
// SUBSCRIPTION TRIGGERS
// =============================================================================

/**
 * Trigger: When a subscription is created/updated
 */
exports.webOnSubscriptionUpdated = onDocumentUpdated({
  document: 'ORGANIZATIONS/{orgId}/SUBSCRIPTION/{subscriptionId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const subscriptionId = event.params.subscriptionId;
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    
    logger.info(`Subscription updated: ${subscriptionId} for org ${orgId}`);
    
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    
    // Handle status changes
    if (beforeData.status !== afterData.status) {
      if (afterData.status === 'active' && beforeData.status !== 'active') {
        // Subscription activated
        await countersRef.update({
          activeSubscriptions: FieldValue.increment(1),
          lastUpdated: FieldValue.serverTimestamp()
        });
      } else if (beforeData.status === 'active' && afterData.status !== 'active') {
        // Subscription deactivated
        await countersRef.update({
          activeSubscriptions: FieldValue.increment(-1),
          lastUpdated: FieldValue.serverTimestamp()
        });
      }
    }

    // Create activity log
    await db.collection('ACTIVITY').add({
      type: 'SUBSCRIPTION_UPDATED',
      orgId: orgId,
      subscriptionId: subscriptionId,
      timestamp: FieldValue.serverTimestamp(),
      performedBy: 'system',
      details: {
        tier: afterData.tier,
        status: afterData.status,
        changes: beforeData.status !== afterData.status ? 
          `Status: ${beforeData.status} → ${afterData.status}` : 'Other updates'
      }
    });

    logger.info(`Subscription ${subscriptionId} update processed successfully`);
  } catch (error) {
    logger.error('Error processing subscription update:', error);
  }
});

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Get system statistics
 */
exports.webGetSystemStats = onCall(async (request) => {
  try {
    const countersRef = db.collection('SYSTEM_METADATA').doc('counters');
    const countersDoc = await countersRef.get();
    
    if (!countersDoc.exists) {
      await exports.webInitializeSystemMetadata.run(request);
      const newDoc = await countersRef.get();
      return newDoc.data();
    }
    
    // Get additional stats from collections
    const [orgsSnapshot, usersSnapshot] = await Promise.all([
      db.collection('ORGANIZATIONS').get(),
      db.collection('USERS').get()
    ]);
    
    const stats = countersDoc.data();
    stats.actualOrgCount = orgsSnapshot.size;
    stats.actualUserCount = usersSnapshot.size;
    
    return stats;
  } catch (error) {
    logger.error('Error getting system stats:', error);
    throw new Error(`Failed to get system stats: ${error.message}`);
  }
});

/**
 * Clean up old activity logs (keep last 1000 entries)
 */
exports.webCleanupActivityLogs = onCall(async (request) => {
  try {
    const activityRef = db.collection('ACTIVITY');
    const snapshot = await activityRef
      .orderBy('timestamp', 'desc')
      .offset(1000)
      .get();
    
    if (snapshot.empty) {
      return { success: true, message: 'No old logs to clean up' };
    }
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    logger.info(`Cleaned up ${snapshot.size} old activity logs`);
    return { success: true, message: `Cleaned up ${snapshot.size} old logs` };
  } catch (error) {
    logger.error('Error cleaning up activity logs:', error);
    throw new Error(`Failed to cleanup logs: ${error.message}`);
  }
});