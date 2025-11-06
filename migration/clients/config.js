/**
 * Migration Configuration
 * Configuration for migrating clients from PaveBoard to OPERON
 */

require('dotenv').config();

module.exports = {
  // Source Firebase project (PaveBoard)
  source: {
    projectId: 'apex-21cd0',
    collection: 'CLIENTS',
    orgID: 'K4Q6vPOuTcLPtlcEwdw0',
    // Service account key path - relative to migration folder (C:\Vedant\OPERON\migration)
    // Default: Actual Firebase-generated service account filename
    // Can be overridden via PAVEBOARD_SERVICE_ACCOUNT_PATH environment variable
    serviceAccountPath: process.env.PAVEBOARD_SERVICE_ACCOUNT_PATH || './service-accounts/apex-21cd0-firebase-adminsdk-f7hnl-3371c464e2.json',
    // Date filter: Only migrate clients registered on or before this date
    // Format: 'YYYY-MM-DD' or Date object
    // Set to null to disable date filtering
    // Example: '2025-11-01' (November 1, 2025)
    registeredBeforeDate: process.env.REGISTERED_BEFORE_DATE ? new Date(process.env.REGISTERED_BEFORE_DATE) : new Date('2025-11-01T23:59:59.999Z')
  },

  // Destination Firebase project (OPERON)
  destination: {
    projectId: 'operanapp',
    collection: 'CLIENTS',
    organizationId: 'wuqC6llSwDSME9lwf8fL',
    // Service account key path - relative to migration folder (C:\Vedant\OPERON\migration)
    // Default: Actual Firebase-generated service account filename
    // Can be overridden via OPERON_SERVICE_ACCOUNT_PATH environment variable
    serviceAccountPath: process.env.OPERON_SERVICE_ACCOUNT_PATH || './service-accounts/operanapp-firebase-adminsdk-fbsvc-090c355102.json'
  },

  // Field mappings
  fieldMappings: {
    name: 'name',
    registeredTime: 'createdAt',
    primaryPhone: 'phoneNumber',
    phoneList: 'phoneList' // New field
  },

  // Default values for OPERON
  defaults: {
    status: 'active'
  },

  // Batch processing settings
  batch: {
    size: 500 // Firestore batch limit
  }
};

