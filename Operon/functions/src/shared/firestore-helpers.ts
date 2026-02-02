import * as admin from 'firebase-admin';
import {
  SOURCE_KEY,
  EMPLOYEES_SOURCE_KEY,
  VENDORS_SOURCE_KEY,
  DELIVERIES_SOURCE_KEY,
  PRODUCTIONS_SOURCE_KEY,
  TRIP_WAGES_ANALYTICS_SOURCE_KEY,
} from './constants';

const db = admin.firestore();

/**
 * Get creation date from a Firestore document snapshot
 */
export function getCreationDate(
  snapshot: FirebaseFirestore.DocumentSnapshot,
): Date {
  const createdAt = snapshot.get('createdAt') as
    | admin.firestore.Timestamp
    | undefined;
  if (createdAt) {
    return createdAt.toDate();
  }
  return snapshot.createTime?.toDate() ?? new Date();
}

/**
 * Seed/initialize an analytics document with default structure
 */
export async function seedAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
          admin.firestore.FieldValue.arrayUnion('CLIENTS'),
      'metrics.activeClients.type': 'monthly',
      'metrics.activeClients.unit': 'count',
      'metrics.userOnboarding.type': 'monthly',
      'metrics.userOnboarding.unit': 'count',
    },
    { merge: true },
  );
}

/**
 * Seed/initialize an employee analytics document with default structure
 */
export async function seedEmployeeAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: EMPLOYEES_SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
          admin.firestore.FieldValue.arrayUnion('EMPLOYEES', 'TRANSACTIONS'),
      'metrics.wagesCreditMonthly.type': 'monthly',
      'metrics.wagesCreditMonthly.unit': 'currency',
    },
    { merge: true },
  );
}

/**
 * Seed/initialize a vendor analytics document with default structure
 */
export async function seedVendorAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: VENDORS_SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
          admin.firestore.FieldValue.arrayUnion('VENDORS', 'TRANSACTIONS'),
      'metrics.purchasesByVendorType.type': 'monthly',
      'metrics.purchasesByVendorType.unit': 'currency',
    },
    { merge: true },
  );
}

/**
 * Seed/initialize a deliveries analytics document with default structure
 */
export async function seedDeliveriesAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: DELIVERIES_SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
        admin.firestore.FieldValue.arrayUnion('DELIVERY_MEMOS'),
    },
    { merge: true },
  );
}

/**
 * Seed/initialize a productions analytics document with default structure
 */
export async function seedProductionsAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: PRODUCTIONS_SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
        admin.firestore.FieldValue.arrayUnion('PRODUCTION_BATCHES'),
    },
    { merge: true },
  );
}

/**
 * Seed/initialize a trip wages analytics document with default structure
 */
export async function seedTripWagesAnalyticsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  fyLabel: string,
  organizationId?: string,
): Promise<void> {
  await docRef.set(
    {
      source: TRIP_WAGES_ANALYTICS_SOURCE_KEY,
      financialYear: fyLabel,
      ...(organizationId && { organizationId }),
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metadata.sourceCollections':
        admin.firestore.FieldValue.arrayUnion('TRIP_WAGES', 'TRANSACTIONS'),
    },
    { merge: true },
  );
}

/**
 * Get Firestore database instance
 */
export function getFirestore(): FirebaseFirestore.Firestore {
  return db;
}

