import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export all Cloud Functions
export * from './clients/client-analytics';
export * from './clients/client-whatsapp';
export * from './transactions';
export * from './orders';
export * from './vendors';
export * from './raw-materials/stock-handlers';
export * from './cleanup';
export * from './maintenance';
export * from './production-batches';
export * from './trip-wages';
export * from './ledger-maintenance';
export * from './employees/employee-analytics';
