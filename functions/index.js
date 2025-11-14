const {setGlobalOptions} = require("firebase-functions");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const logger = require("firebase-functions/logger");

const DM_TRACKING_SUBCOLLECTION = "DM_TRACKING";
const DM_LEDGER_SUBCOLLECTION = "DM_LEDGER";
const SCHEDULED_ORDERS_COLLECTION = "SCH_ORDERS";
const DASHBOARD_METADATA_COLLECTION = "DASHBOARD_METADATA";
const DASHBOARD_CLIENTS_DOC_ID = "CLIENTS";
const DASHBOARD_FINANCIAL_YEAR_SUBCOLLECTION = "FINANCIAL_YEARS";
const CLIENTS_COLLECTION = "CLIENTS";
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
const DEFAULT_START_DM_NUMBER = 1;

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const auth = getAuth();

// Set global options for cost control
setGlobalOptions({ maxInstances: 10 });

// ============================================================================
// DM NUMBER FUNCTIONS
// ============================================================================

exports.generateDmNumber = onCall(async (request) => {
  const { organizationId, scheduleId, orderId } = request.data || {};

  if (!organizationId || !scheduleId) {
    throw new Error("organizationId and scheduleId are required");
  }

  const financialYearId = getFinancialYearId();
  const dmDocRef = db
    .collection("ORGANIZATIONS")
    .doc(organizationId)
    .collection(DM_TRACKING_SUBCOLLECTION)
    .doc(financialYearId);
  const scheduleRef = db
    .collection(SCHEDULED_ORDERS_COLLECTION)
    .doc(scheduleId);

  let responsePayload = null;

  await db.runTransaction(async (transaction) => {
    const scheduleSnap = await transaction.get(scheduleRef);
    if (!scheduleSnap.exists) {
      throw new Error("Scheduled order not found");
    }

    const scheduleData = scheduleSnap.data();
    if ((scheduleData.organizationId || scheduleData.orgId) !== organizationId) {
      throw new Error("Scheduled order does not belong to the organization");
    }

    if (scheduleData.dmNumber) {
      responsePayload = {
        success: true,
        dmNumber: scheduleData.dmNumber,
        financialYearId,
        alreadyGenerated: true,
      };
      return;
    }

    const dmSnap = await transaction.get(dmDocRef);
    let startDmNumber = DEFAULT_START_DM_NUMBER;
    let lastAssignedNumber = 0;
    let currentDmNumber = 0;

    if (!dmSnap.exists) {
      transaction.set(
        dmDocRef,
        {
          startDmNumber: startDmNumber,
          currentDmNumber: 0,
          lastDmNumber: 0,
          createdAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } else {
      const dmData = dmSnap.data();
      startDmNumber = coerceInt(
        dmData.startDmNumber,
        DEFAULT_START_DM_NUMBER,
      );
      currentDmNumber = coerceInt(dmData.currentDmNumber, 0);
      lastAssignedNumber = coerceInt(dmData.lastDmNumber, 0);
    }

    const nextDmNumber = currentDmNumber + 1;

    const nowTimestamp = FieldValue.serverTimestamp();

    transaction.set(
      dmDocRef,
      {
        startDmNumber,
        currentDmNumber: nextDmNumber,
        lastDmNumber: nextDmNumber,
        lastAssignedOrderId: scheduleId,
        lastOrderId: orderId || scheduleData.orderId || null,
        lastAssignedAt: nowTimestamp,
        updatedAt: nowTimestamp,
      },
      { merge: true },
    );

    const scheduleUpdate = {
      dmNumber: nextDmNumber,
      dmFinancialYearId: financialYearId,
      dmGeneratedAt: nowTimestamp,
    };

    if (orderId) {
      scheduleUpdate.dmOrderId = orderId;
    }

    transaction.update(scheduleRef, scheduleUpdate);

    const ledgerDocId = `${nextDmNumber}`;
    const ledgerRef = dmDocRef
      .collection(DM_LEDGER_SUBCOLLECTION)
      .doc(ledgerDocId);

    transaction.set(
      ledgerRef,
      {
        dmNumber: nextDmNumber,
        scheduleId,
        orderId: orderId || scheduleData.orderId || null,
        status: "active",
        generatedAt: nowTimestamp,
      },
      { merge: true },
    );

    responsePayload = {
      success: true,
      dmNumber: nextDmNumber,
      financialYearId,
      alreadyGenerated: false,
      previousDmNumber: currentDmNumber || lastAssignedNumber,
    };
  });

  if (responsePayload && !responsePayload.alreadyGenerated) {
    logger.info("DM number generated", {
      organizationId,
      scheduleId,
      dmNumber: responsePayload.dmNumber,
      financialYearId: responsePayload.financialYearId,
    });
  }

  return responsePayload;
});

exports.cancelDmNumber = onCall(async (request) => {
  const { organizationId, scheduleId } = request.data || {};

  if (!organizationId || !scheduleId) {
    throw new Error("organizationId and scheduleId are required");
  }

  const scheduleRef = db
    .collection(SCHEDULED_ORDERS_COLLECTION)
    .doc(scheduleId);

  let responsePayload = null;

  await db.runTransaction(async (transaction) => {
    const scheduleSnap = await transaction.get(scheduleRef);
    if (!scheduleSnap.exists) {
      throw new Error("Scheduled order not found");
    }

    const scheduleData = scheduleSnap.data();
    if ((scheduleData.organizationId || scheduleData.orgId) !== organizationId) {
      throw new Error("Scheduled order does not belong to the organization");
    }

    if (!scheduleData.dmNumber) {
      responsePayload = { success: true, alreadyCleared: true };
      return;
    }

    if (scheduleData.status && scheduleData.status !== "scheduled") {
      throw new Error("DM can only be cancelled while schedule status is 'scheduled'");
    }

    const dmNumber = coerceInt(scheduleData.dmNumber);
    const financialYearId =
      typeof scheduleData.dmFinancialYearId === "string" &&
      scheduleData.dmFinancialYearId.length > 0
        ? scheduleData.dmFinancialYearId
        : getFinancialYearId();

    const dmDocRef = db
      .collection("ORGANIZATIONS")
      .doc(organizationId)
      .collection(DM_TRACKING_SUBCOLLECTION)
      .doc(financialYearId);

    const ledgerDocId = `${dmNumber}`;
    const ledgerRef = dmDocRef
      .collection(DM_LEDGER_SUBCOLLECTION)
      .doc(ledgerDocId);

    const ledgerSnap = await transaction.get(ledgerRef);
    let ledgerData = ledgerSnap.exists ? ledgerSnap.data() : null;

    if (!ledgerData) {
      ledgerData = {
        dmNumber,
        scheduleId,
        orderId: scheduleData.orderId || null,
        status: "active",
        generatedAt: scheduleData.dmGeneratedAt || FieldValue.serverTimestamp(),
      };
      transaction.set(ledgerRef, ledgerData, { merge: true });
    } else if (ledgerData.status === "cancelled") {
      transaction.update(scheduleRef, {
        dmNumber: FieldValue.delete(),
        dmFinancialYearId: FieldValue.delete(),
        dmGeneratedAt: FieldValue.delete(),
        dmOrderId: FieldValue.delete(),
      });

      responsePayload = {
        success: true,
        cancelledDmNumber: dmNumber,
        financialYearId,
        alreadyCancelled: true,
      };
      return;
    }

    const nowTimestamp = FieldValue.serverTimestamp();

    transaction.update(dmDocRef, {
      lastDmNumber: dmNumber,
      lastAssignedOrderId: FieldValue.delete(),
      lastOrderId: FieldValue.delete(),
      lastAssignedAt: FieldValue.delete(),
      updatedAt: nowTimestamp,
    });

    transaction.update(ledgerRef, {
      status: "cancelled",
      cancelledAt: nowTimestamp,
    });

    transaction.update(scheduleRef, {
      dmNumber: FieldValue.delete(),
      dmFinancialYearId: FieldValue.delete(),
      dmGeneratedAt: FieldValue.delete(),
      dmOrderId: FieldValue.delete(),
    });

    responsePayload = {
      success: true,
      cancelledDmNumber: dmNumber,
      financialYearId,
      status: "cancelled",
    };
  });

  if (responsePayload && responsePayload.success) {
    logger.info("DM number cancelled", {
      organizationId,
      scheduleId,
      dmNumber: responsePayload.cancelledDmNumber,
      financialYearId: responsePayload.financialYearId,
    });
  }

  return responsePayload;
});

// ============================================================================
// ORGANIZATION MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Creates a new organization with admin user and sends invitation
 * Trigger: SuperAdmin creates organization via dashboard
 */
exports.organizationCreate = onCall(async (request) => {
  // Verify SuperAdmin permissions - check if user exists and has SuperAdmin role
  if (!request.auth) {
    throw new Error('Authentication required');
  }

  try {
    // Check if user is SuperAdmin by looking up their user document
    const userDoc = await db.collection('USERS').doc(request.auth.uid).get();
    if (!userDoc.exists) {
      throw new Error('User not found');
    }

    const userData = userDoc.data();
    const isSuperAdmin = userData.organizations && 
                        userData.organizations.length > 0 &&
                        userData.organizations[0].orgId === 'superadmin_org' &&
                        userData.organizations[0].role === 0;

    if (!isSuperAdmin) {
      throw new Error('SuperAdmin access required');
    }
  } catch (error) {
    logger.error('Error verifying SuperAdmin status:', error);
    throw new Error('Failed to verify SuperAdmin status');
  }

  const {
    orgName,
    email,
    gstNo,
    industry,
    location,
    adminName,
    adminPhone,
    adminEmail,
    subscription
  } = request.data;

  try {
    const batch = db.batch();

    // Generate IDs
    const orgId = db.collection('ORGANIZATIONS').doc().id;
    const userId = db.collection('USERS').doc().id;
    const subscriptionId = `${orgId}_${Date.now()}`;

    // Create organization document
    const organizationRef = db.collection('ORGANIZATIONS').doc(orgId);
    batch.set(organizationRef, {
      orgId,
      orgName,
      email,
      gstNo,
      industry: industry || null,
      location: location || null,
      status: 'active',
      createdDate: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
      createdBy: request.auth.uid,
      metadata: {
        totalUsers: 1,
        activeUsers: 1,
        industry: industry || null,
        location: location || null,
      }
    });

    // Create subscription document
    const subscriptionRef = organizationRef.collection('subscriptions').doc(subscriptionId);
    batch.set(subscriptionRef, {
      subscriptionId,
      tier: subscription.tier,
      subscriptionType: subscription.subscriptionType,
      startDate: FieldValue.serverTimestamp(),
      endDate: FieldValue.serverTimestamp(),
      userLimit: subscription.userLimit,
      status: 'active',
      amount: subscription.amount,
      currency: subscription.currency,
      isActive: true,
      autoRenew: subscription.autoRenew,
      createdDate: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
    });

    // Create admin user document
    const userRef = db.collection('USERS').doc(userId);
    batch.set(userRef, {
      userId,
      name: adminName,
      phoneNo: adminPhone,
      email: adminEmail || null, // Optional
      profilePhotoUrl: null,
      status: 'active',
      createdDate: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
      lastLoginDate: null,
      metadata: {
        totalOrganizations: 1,
        primaryOrgId: orgId,
        notificationPreferences: {
          sms: true,
          email: !!adminEmail,
          push: true,
        },
      },
      organizations: [{
        orgId,
        role: 1, // Admin role
        status: 'active',
        joinedDate: FieldValue.serverTimestamp(),
        isPrimary: true,
        permissions: ['all'],
      }],
    });

    // Create organization-user relationship
    const orgUserRef = organizationRef.collection('users').doc(userId);
    batch.set(orgUserRef, {
      userId,
      role: 1, // Admin role
      name: adminName,
      phoneNo: adminPhone,
      email: adminEmail || null,
      status: 'active',
      addedDate: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
      addedBy: request.auth.uid,
      permissions: ['all'],
    });

    // Commit batch
    await batch.commit();

    // Send SMS invitation to admin
    await exports.adminInvitationSendSMS.run({
      data: {
        adminPhone,
        adminName,
        orgName,
        orgId,
      }
    });

    // Send email notification if email provided
    if (adminEmail) {
      await exports.adminInvitationSendEmail.run({
        data: {
          adminEmail,
          adminName,
          orgName,
          orgId,
        }
      });
    }

    return { orgId, userId, success: true };

  } catch (error) {
    logger.error('Error creating organization:', error);
    throw new Error(`Failed to create organization: ${error.message}`);
  }
});

/**
 * Updates organization details
 * Trigger: SuperAdmin updates organization via dashboard
 */
exports.organizationUpdate = onCall(async (request) => {
  if (!request.auth || !request.auth.token.superAdmin) {
    throw new Error('SuperAdmin access required');
  }

  const { orgId, updateData } = request.data;

  try {
    await db.collection('ORGANIZATIONS').doc(orgId).update({
      ...updateData,
      updatedDate: FieldValue.serverTimestamp(),
    });

    return { success: true };

  } catch (error) {
    logger.error('Error updating organization:', error);
    throw new Error(`Failed to update organization: ${error.message}`);
  }
});

/**
 * Activates organization after setup completion
 * Trigger: Admin completes organization setup
 */
exports.organizationActivate = onCall(async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { orgId } = request.data;

  try {
    await db.collection('ORGANIZATIONS').doc(orgId).update({
      status: 'active',
      activatedAt: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
    });

    // Send activation notifications
    await exports.notificationSendActivation.run({
      data: { orgId }
    });

    return { success: true };

  } catch (error) {
    logger.error('Error activating organization:', error);
    throw new Error(`Failed to activate organization: ${error.message}`);
  }
});

// ============================================================================
// USER MANAGEMENT FUNCTIONS
// ============================================================================

/**
 * Sends SMS invitation to admin user
 * Trigger: Called during organization creation
 */
exports.adminInvitationSendSMS = onCall(async (request) => {
  const { adminPhone, adminName, orgName, orgId } = request.data;

  try {
    // Generate OTP for admin verification
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store OTP in Firestore with expiry
    await db.collection('admin_invitations').doc(adminPhone).set({
      otp,
      orgId,
      adminName,
      orgName,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: FieldValue.serverTimestamp(),
      verified: false,
    });

    // For now, just log the SMS (you'll need to integrate Twilio)
    logger.info(`SMS would be sent to ${adminPhone}: Welcome to OPERON! ${adminName}, you've been invited to manage ${orgName}. Your verification code is: ${otp}. This code expires in 24 hours.`);

    return { success: true, otp }; // Return OTP for testing

  } catch (error) {
    logger.error('Error sending SMS:', error);
    throw new Error(`Failed to send SMS invitation: ${error.message}`);
  }
});

/**
 * Verifies admin OTP and creates Firebase Auth user
 * Trigger: Admin enters OTP during onboarding
 */
exports.adminInvitationVerifyOTP = onCall(async (request) => {
  const { phoneNumber, otp } = request.data;

  try {
    const invitationRef = db.collection('admin_invitations').doc(phoneNumber);
    const invitationDoc = await invitationRef.get();

    if (!invitationDoc.exists) {
      throw new Error('Invitation not found');
    }

    const invitation = invitationDoc.data();
    
    // Check if OTP is correct and not expired
    if (invitation.otp !== otp) {
      throw new Error('Invalid OTP');
    }

    if (invitation.expiresAt.toDate() < new Date()) {
      throw new Error('OTP expired');
    }

    // Mark invitation as verified
    await invitationRef.update({
      verified: true,
      verifiedAt: FieldValue.serverTimestamp(),
    });

    // Create Firebase Auth user for admin
    const adminUser = await auth.createUser({
      phoneNumber: phoneNumber,
      displayName: invitation.adminName,
      disabled: false,
    });

    // Update user document with Firebase Auth UID
    const userQuery = await db.collection('USERS')
      .where('phoneNo', '==', phoneNumber)
      .limit(1)
      .get();

    if (!userQuery.empty) {
      const userDoc = userQuery.docs[0];
      await userDoc.ref.update({
        firebaseUid: adminUser.uid,
        lastLoginDate: FieldValue.serverTimestamp(),
      });
    }

    return { 
      success: true, 
      firebaseUid: adminUser.uid,
      orgId: invitation.orgId,
      adminName: invitation.adminName,
    };

  } catch (error) {
    logger.error('Error verifying OTP:', error);
    throw new Error(`Failed to verify OTP: ${error.message}`);
  }
});

/**
 * Creates additional users in organization
 * Trigger: Admin invites team members
 */
exports.userCreateInOrganization = onCall(async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { orgId, userName, userPhone, userEmail, userRole } = request.data;

  try {
    const userId = db.collection('USERS').doc().id;

    // Create user document
    await db.collection('USERS').doc(userId).set({
      userId,
      name: userName,
      phoneNo: userPhone,
      email: userEmail || null,
      status: 'active',
      createdDate: FieldValue.serverTimestamp(),
      updatedDate: FieldValue.serverTimestamp(),
      metadata: {
        totalOrganizations: 1,
        primaryOrgId: orgId,
        notificationPreferences: {
          sms: true,
          email: !!userEmail,
          push: true,
        },
      },
      organizations: [{
        orgId,
        role: userRole,
        status: 'active',
        joinedDate: FieldValue.serverTimestamp(),
        isPrimary: true,
        permissions: getRolePermissions(userRole),
      }],
    });

    // Add to organization users
    await db.collection('organizations').doc(orgId)
      .collection('users').doc(userId).set({
        userId,
        role: userRole,
        name: userName,
        phoneNo: userPhone,
        email: userEmail || null,
        status: 'active',
        addedDate: FieldValue.serverTimestamp(),
        updatedDate: FieldValue.serverTimestamp(),
        addedBy: request.auth.uid,
        permissions: getRolePermissions(userRole),
      });

    return { userId, success: true };

  } catch (error) {
    logger.error('Error creating user:', error);
    throw new Error(`Failed to create user: ${error.message}`);
  }
});

// ============================================================================
// NOTIFICATION FUNCTIONS
// ============================================================================

/**
 * Sends email invitation to admin (optional)
 * Trigger: Called during organization creation if email provided
 */
exports.adminInvitationSendEmail = onCall(async (request) => {
  const { adminEmail, adminName, orgName, orgId } = request.data;

  try {
    // For now, just log the email (you'll need to integrate email service)
    logger.info(`Email would be sent to ${adminEmail}: Welcome to OPERON - ${orgName}`);

    return { success: true };

  } catch (error) {
    logger.error('Error sending email:', error);
    // Don't throw error for email failures - SMS is primary
    return { success: false, error: error.message };
  }
});

/**
 * Sends activation notification after organization setup
 * Trigger: Organization activation
 */
exports.notificationSendActivation = onCall(async (request) => {
  const orgId = typeof request.data === 'string' ? request.data : request.data.orgId;

  try {
    const orgDoc = await db.collection('ORGANIZATIONS').doc(orgId).get();
    const orgData = orgDoc.data();

    // Get admin user
    const adminQuery = await db.collection('USERS')
      .where('organizations', 'array-contains', { orgId, role: 1 })
      .limit(1)
      .get();

    if (!adminQuery.empty) {
      const adminDoc = adminQuery.docs[0];
      const adminData = adminDoc.data();

      // Log SMS notification
      if (adminData.phoneNo) {
        logger.info(`SMS would be sent to ${adminData.phoneNo}: 🎉 Congratulations! ${orgData.orgName} setup is complete. Your organization is now live on OPERON!`);
      }

      // Log email notification if available
      if (adminData.email) {
        logger.info(`Activation email would be sent to: ${adminData.email}`);
      }
    }

    return { success: true };

  } catch (error) {
    logger.error('Error sending activation notifications:', error);
    return { success: false, error: error.message };
  }
});

/**
 * Sends SMS notification to user
 * Trigger: Various system events
 */
exports.notificationSendSMS = onCall(async (request) => {
  const { phoneNumber, message, type } = request.data;

  try {
    // For now, just log the SMS (you'll need to integrate Twilio)
    logger.info(`SMS would be sent to ${phoneNumber}: ${message}`);

    // Log notification
    await db.collection('notification_logs').add({
      type: type || 'general',
      phoneNumber,
      message,
      sentAt: FieldValue.serverTimestamp(),
      status: 'sent',
    });

    return { success: true };

  } catch (error) {
    logger.error('Error sending SMS:', error);
    throw new Error(`Failed to send SMS: ${error.message}`);
  }
});

// ============================================================================
// ONBOARDING FUNCTIONS
// ============================================================================

/**
 * Completes organization setup process
 * Trigger: Admin completes final setup steps
 */
exports.onboardingCompleteSetup = onCall(async (request) => {
  if (!request.auth) {
    throw new Error('User must be authenticated');
  }

  const { orgId, setupData } = request.data;

  try {
    // Update organization with setup completion
    await db.collection('ORGANIZATIONS').doc(orgId).update({
      setupCompleted: true,
      setupCompletedAt: FieldValue.serverTimestamp(),
      setupData,
      updatedDate: FieldValue.serverTimestamp(),
    });

    // Send completion notifications
    await exports.notificationSendActivation.run({
      data: { orgId }
    });

    return { success: true };

  } catch (error) {
    logger.error('Error completing setup:', error);
    throw new Error(`Failed to complete setup: ${error.message}`);
  }
});

/**
 * Validates organization setup completion
 * Trigger: System checks setup status
 */
exports.onboardingValidateSetup = onCall(async (request) => {
  const { orgId } = request.data;

  try {
    const orgDoc = await db.collection('ORGANIZATIONS').doc(orgId).get();
    const orgData = orgDoc.data();

    const validationResults = {
      hasAdmin: false,
      hasSubscription: false,
      hasBasicInfo: false,
      setupComplete: orgData.setupCompleted || false,
    };

    // Check if admin exists
    const adminQuery = await db.collection('organizations').doc(orgId)
      .collection('users').where('role', '==', 1).limit(1).get();
    validationResults.hasAdmin = !adminQuery.empty;

    // Check if subscription exists
    const subscriptionQuery = await db.collection('organizations').doc(orgId)
      .collection('subscriptions').limit(1).get();
    validationResults.hasSubscription = !subscriptionQuery.empty;

    // Check basic info
    validationResults.hasBasicInfo = !!(orgData.orgName && orgData.email);

    return validationResults;

  } catch (error) {
    logger.error('Error validating setup:', error);
    throw new Error(`Failed to validate setup: ${error.message}`);
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS
// ============================================================================

/**
 * Cleans up expired admin invitations
 * Trigger: Runs every 24 hours
 */
exports.scheduledCleanupExpiredInvitations = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'UTC'
}, async (event) => {
  const now = FieldValue.serverTimestamp();
  
  const expiredInvitations = await db.collection('admin_invitations')
    .where('expiresAt', '<', now)
    .get();

  const batch = db.batch();
  expiredInvitations.docs.forEach(doc => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  logger.info(`Cleaned up ${expiredInvitations.size} expired invitations`);
});

/**
 * Sends setup reminder notifications
 * Trigger: Runs daily to check for incomplete setups
 */
exports.scheduledSendSetupReminders = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'UTC'
}, async (event) => {
  const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
  
  // Find organizations created more than 24 hours ago without setup completion
  const incompleteOrgs = await db.collection('organizations')
    .where('setupCompleted', '==', false)
    .where('createdDate', '<', FieldValue.serverTimestamp())
    .get();

  for (const orgDoc of incompleteOrgs.docs) {
    const orgData = orgDoc.data();
    
    // Get admin user
    const adminQuery = await db.collection('USERS')
      .where('organizations', 'array-contains', { orgId: orgDoc.id, role: 1 })
      .limit(1)
      .get();

    if (!adminQuery.empty) {
      const adminData = adminQuery.docs[0].data();
      
      // Log reminder SMS
      if (adminData.phoneNo) {
        logger.info(`Reminder SMS would be sent to ${adminData.phoneNo}: Complete your ${orgData.orgName} setup on OPERON to activate all features.`);
      }
    }
  }

  logger.info(`Sent setup reminders to ${incompleteOrgs.size} organizations`);
});

// ============================================================================
// DATABASE TRIGGERS
// ============================================================================

/**
 * Trigger: When a client is created
 */
exports.onClientCreated = onDocumentCreated({
  document: `${CLIENTS_COLLECTION}/{clientId}`,
  region: 'us-central1'
}, async (event) => {
  try {
    const clientId = event.params.clientId;
    const clientData = event.data?.data();

    if (!clientData) {
      logger.warn('Client create trigger missing data', { clientId });
      return;
    }

    const createdAt = toDate(clientData.createdAt) || new Date();
    const financialYearId = getFinancialYearId(createdAt);
    const monthKey = getFinancialMonthKey(createdAt);
    const activeDelta = isClientActive(clientData.status) ? 1 : 0;

    await db.runTransaction(async (transaction) => {
      const summaryRef = clientsSummaryRef();
      const yearRef = clientsFinancialYearRef(financialYearId);

      const [summarySnap, yearSnap] = await Promise.all([
        transaction.get(summaryRef),
        transaction.get(yearRef),
      ]);

      const currentActive = summarySnap.exists
        ? coerceInt(summarySnap.data().totalActiveClients, 0)
        : 0;
      const nextActive = currentActive + activeDelta;
      const now = FieldValue.serverTimestamp();

      const summaryPayload = {
        totalActiveClients: nextActive,
        lastEventAt: now,
        updatedAt: now,
      };
      if (!summarySnap.exists) {
        summaryPayload.createdAt = now;
      }
      transaction.set(summaryRef, summaryPayload, { merge: true });

      const yearPayload = {
        financialYearId,
        totalOnboarded: FieldValue.increment(1),
        totalActiveClientsSnapshot: nextActive,
        updatedAt: now,
        lastEventAt: now,
      };
      yearPayload[`monthlyOnboarding.${monthKey}`] = FieldValue.increment(1);
      if (!yearSnap.exists) {
        yearPayload.createdAt = now;
      }
      transaction.set(yearRef, yearPayload, { merge: true });
    });

    logger.info('Client dashboard metadata updated (create)', {
      clientId,
      financialYearId,
      monthKey,
    });
  } catch (error) {
    logger.error('Error processing client creation:', error);
  }
});

/**
 * Trigger: When a client is updated
 */
exports.onClientUpdated = onDocumentUpdated({
  document: `${CLIENTS_COLLECTION}/{clientId}`,
  region: 'us-central1'
}, async (event) => {
  try {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const clientId = event.params.clientId;

    if (!before || !after) {
      logger.warn('Client update missing data', { clientId });
      return;
    }

    const beforeActive = isClientActive(before.status);
    const afterActive = isClientActive(after.status);
    const delta = (afterActive ? 1 : 0) - (beforeActive ? 1 : 0);

    if (delta === 0) {
      return;
    }

    const createdAt =
      toDate(after.createdAt) ||
      toDate(before.createdAt) ||
      new Date();
    const financialYearId = getFinancialYearId(createdAt);

    await updateClientActiveCounts(financialYearId, delta);

    logger.info('Client dashboard metadata updated (status change)', {
      clientId,
      financialYearId,
      delta,
    });
  } catch (error) {
    logger.error('Error processing client update:', error);
  }
});

/**
 * Trigger: When a client is deleted
 */
exports.onClientDeleted = onDocumentDeleted({
  document: `${CLIENTS_COLLECTION}/{clientId}`,
  region: 'us-central1'
}, async (event) => {
  try {
    const clientId = event.params.clientId;
    const clientData = event.data?.data();

    if (!clientData) {
      return;
    }

    if (!isClientActive(clientData.status)) {
      return;
    }

    const createdAt = toDate(clientData.createdAt) || new Date();
    const financialYearId = getFinancialYearId(createdAt);

    await updateClientActiveCounts(financialYearId, -1);

    logger.info('Client dashboard metadata updated (delete)', {
      clientId,
      financialYearId,
    });
  } catch (error) {
    logger.error('Error processing client deletion:', error);
  }
});

/**
 * Trigger: When a new organization is created
 */
exports.onOrganizationCreated = onDocumentCreated({
  document: 'organizations/{orgId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const orgData = event.data.data();
    
    logger.info(`New organization created: ${orgId}`);
    
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
        status: orgData.status,
        industry: orgData.industry,
        location: orgData.location
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
exports.onOrganizationUpdated = onDocumentUpdated({
  document: 'organizations/{orgId}',
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

    if (beforeData.industry !== afterData.industry) {
      changes.push(`Industry: ${beforeData.industry} → ${afterData.industry}`);
    }

    if (beforeData.location !== afterData.location) {
      changes.push(`Location: ${beforeData.location} → ${afterData.location}`);
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
exports.onOrganizationDeleted = onDocumentDeleted({
  document: 'organizations/{orgId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const orgData = event.data.data();
    
    logger.info(`Organization deleted: ${orgId}`);
    
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
        status: orgData.status,
        industry: orgData.industry,
        location: orgData.location
      }
    });

    logger.info(`Organization ${orgId} deletion processed successfully`);
  } catch (error) {
    logger.error('Error processing organization deletion:', error);
  }
});

/**
 * Trigger: When a new user is created
 */
exports.onUserCreated = onDocumentCreated({
  document: 'users/{userId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const userId = event.params.userId;
    const userData = event.data.data();
    
    logger.info(`New user created: ${userId}`);
    
    // Create activity log
    await db.collection('ACTIVITY').add({
      type: 'USER_CREATED',
      userId: userId,
      userName: userData.name,
      timestamp: FieldValue.serverTimestamp(),
      performedBy: 'system',
      details: {
        phoneNo: userData.phoneNo,
        email: userData.email,
        status: userData.status,
        role: userData.organizations?.[0]?.role || 'unknown',
        primaryOrgId: userData.metadata?.primaryOrgId
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
exports.onUserUpdated = onDocumentUpdated({
  document: 'users/{userId}',
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

    if (beforeData.phoneNo !== afterData.phoneNo) {
      changes.push(`Phone: ${beforeData.phoneNo} → ${afterData.phoneNo}`);
    }

    if (beforeData.email !== afterData.email) {
      changes.push(`Email: ${beforeData.email} → ${afterData.email}`);
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

/**
 * Trigger: When a subscription is created/updated
 */
exports.onSubscriptionUpdated = onDocumentUpdated({
  document: 'organizations/{orgId}/subscriptions/{subscriptionId}',
  region: 'us-central1'
}, async (event) => {
  try {
    const orgId = event.params.orgId;
    const subscriptionId = event.params.subscriptionId;
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    
    logger.info(`Subscription updated: ${subscriptionId} for org ${orgId}`);
    
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
        isActive: afterData.isActive,
        changes: beforeData.status !== afterData.status ? 
          `Status: ${beforeData.status} → ${afterData.status}` : 'Other updates'
      }
    });

    logger.info(`Subscription ${subscriptionId} update processed successfully`);
  } catch (error) {
    logger.error('Error processing subscription update:', error);
  }
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Returns the financial year identifier (e.g. 2024-2025) for the supplied UTC
 * date, adjusted to IST (UTC+5:30).
 */
function getFinancialYearId(date = new Date()) {
  const istDate = new Date(date.getTime() + IST_OFFSET_MS);
  const month = istDate.getUTCMonth() + 1;
  const year = istDate.getUTCFullYear();
  const startYear = month >= 4 ? year : year - 1;
  const endYear = startYear + 1;
  return `${startYear}-${endYear}`;
}

function coerceInt(value, fallback = 0) {
  if (value === null || value === undefined) {
    return fallback;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function toDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function getFinancialMonthKey(date = new Date()) {
  const istDate = new Date(date.getTime() + IST_OFFSET_MS);
  const month = String(istDate.getUTCMonth() + 1).padStart(2, "0");
  const year = istDate.getUTCFullYear();
  return `${year}-${month}`;
}

function normalizeClientStatus(status) {
  if (typeof status !== "string") {
    return "";
  }
  return status.trim().toLowerCase();
}

function isClientActive(status) {
  return normalizeClientStatus(status) === "active";
}

function clientsSummaryRef() {
  return db.collection(DASHBOARD_METADATA_COLLECTION).doc(DASHBOARD_CLIENTS_DOC_ID);
}

function clientsFinancialYearRef(financialYearId) {
  return clientsSummaryRef()
    .collection(DASHBOARD_FINANCIAL_YEAR_SUBCOLLECTION)
    .doc(financialYearId);
}

async function updateClientActiveCounts(financialYearId, delta) {
  if (!delta) {
    return;
  }

  await db.runTransaction(async (transaction) => {
    const summaryRef = clientsSummaryRef();
    const yearRef = clientsFinancialYearRef(financialYearId);

    const [summarySnap, yearSnap] = await Promise.all([
      transaction.get(summaryRef),
      transaction.get(yearRef),
    ]);

    const currentActive = summarySnap.exists
      ? coerceInt(summarySnap.data().totalActiveClients, 0)
      : 0;
    const nextActive = Math.max(0, currentActive + delta);
    const now = FieldValue.serverTimestamp();

    const summaryPayload = {
      totalActiveClients: nextActive,
      lastEventAt: now,
      updatedAt: now,
    };
    if (!summarySnap.exists) {
      summaryPayload.createdAt = now;
    }
    transaction.set(summaryRef, summaryPayload, { merge: true });

    const yearPayload = {
      financialYearId,
      totalActiveClientsSnapshot: nextActive,
      updatedAt: now,
      lastEventAt: now,
    };
    if (!yearSnap.exists) {
      yearPayload.createdAt = now;
      yearPayload.totalOnboarded = 0;
    }

    transaction.set(yearRef, yearPayload, { merge: true });
  });
}

/**
 * Returns permissions based on user role
 */
function getRolePermissions(role) {
  switch (role) {
    case 0: // SuperAdmin
      return ['all'];
    case 1: // Admin
      return ['all'];
    case 2: // Manager
      return ['read', 'write', 'manage_users'];
    case 3: // Employee
      return ['read', 'write'];
    default:
      return ['read'];
  }
}