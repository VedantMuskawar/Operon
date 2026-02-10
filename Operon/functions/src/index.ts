import * as admin from 'firebase-admin';

admin.initializeApp();

// Eager init Firestore for global caching (optional; getFirestore() also inits on first use)
import { getFirestore } from './shared/firestore-helpers';
getFirestore();

// Re-export all Cloud Functions for Firebase deploy (root-level names required)
export * from './analytics';
export * from './clients';
export * from './transactions';
export * from './orders';
export * from './vendors';
export * from './raw-materials';
export * from './cleanup';
export * from './maintenance';
export * from './production-batches';
export * from './trip-wages';
export * from './ledger-maintenance';
export * from './employees/employee-analytics';
export * from './geofences';
export * from './edd';
export * from './whatsapp/whatsapp-message-queue';
export * from './whatsapp/whatsapp-webhook';

// Grouped exports (domain objects) for clarity
import * as ordersNs from './orders';
import * as transactionsNs from './transactions';

export const orders = {
  onOrderDeleted: ordersNs.onOrderDeleted,
  onPendingOrderCreated: ordersNs.onPendingOrderCreated,
  onOrderUpdated: ordersNs.onOrderUpdated,
  onScheduledTripCreated: ordersNs.onScheduledTripCreated,
  onScheduledTripDeleted: ordersNs.onScheduledTripDeleted,
  onTripStatusUpdated: ordersNs.onTripStatusUpdated,
  generateDM: ordersNs.generateDM,
  cancelDM: ordersNs.cancelDM,
  onOrderCreatedSendWhatsapp: ordersNs.onOrderCreatedSendWhatsapp,
  onOrderUpdatedSendWhatsapp: ordersNs.onOrderUpdatedSendWhatsapp,
  onTripDispatchedSendWhatsapp: ordersNs.onTripDispatchedSendWhatsapp,
  onTripDeliveredSendWhatsapp: ordersNs.onTripDeliveredSendWhatsapp,
  onTripReturnedCreateDM: ordersNs.onTripReturnedCreateDM,
  deleteFullyScheduledOrdersWeekly: ordersNs.deleteFullyScheduledOrdersWeekly,
};

export const transactions = {
  onTransactionCreated: transactionsNs.onTransactionCreated,
  onTransactionDeleted: transactionsNs.onTransactionDeleted,
  rebuildClientLedgers: transactionsNs.rebuildClientLedgers,
};
