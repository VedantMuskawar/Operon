import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export all Cloud Functions
export * from './clients/client-analytics';
export * from './clients/client-whatsapp';
export * from './transactions';
export * from './orders';
