import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import {
  ANALYTICS_COLLECTION,
  CLIENTS_COLLECTION,
  SOURCE_KEY,
} from '../shared/constants';
import { getFinancialContext } from '../shared/financial-year';
import {
  getCreationDate,
  getFirestore,
  seedAnalyticsDoc,
} from '../shared/firestore-helpers';

const db = getFirestore();

/**
 * Cloud Function: Triggered when a client is created
 * Updates client analytics for the organization
 */

export const onClientCreated = functions.firestore
  .document(`${CLIENTS_COLLECTION}/{clientId}`)
  .onCreate(async (snapshot) => {
    const clientData = snapshot.data();
    const organizationId = clientData?.organizationId as string | undefined;
    
    if (!organizationId) {
      console.warn('[Client Analytics] Client created without organizationId', {
        clientId: snapshot.id,
      });
      return;
    }

    const createdAt = getCreationDate(snapshot);
    const { fyLabel, monthKey } = getFinancialContext(createdAt);
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${SOURCE_KEY}_${organizationId}_${fyLabel}`);

    await seedAnalyticsDoc(analyticsRef, fyLabel, organizationId);

    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveClients':
          admin.firestore.FieldValue.increment(1),
        [`metrics.userOnboarding.values.${monthKey}`]:
          admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  });

/**
 * Core logic to rebuild client analytics for all organizations.
 * Called by unified analytics scheduler.
 */
export async function rebuildClientAnalyticsCore(fyLabel: string, fyStart: Date, fyEnd: Date): Promise<void> {
  const clientsSnapshot = await db.collection(CLIENTS_COLLECTION).get();
  const clientsByOrg: Record<string, FirebaseFirestore.DocumentSnapshot[]> = {};

  clientsSnapshot.forEach((doc) => {
    const organizationId = doc.data()?.organizationId as string | undefined;
    if (organizationId) {
      if (!clientsByOrg[organizationId]) {
        clientsByOrg[organizationId] = [];
      }
      clientsByOrg[organizationId].push(doc);
    }
  });

  const analyticsUpdates = Object.entries(clientsByOrg).map(async ([organizationId, orgClients]) => {
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${SOURCE_KEY}_${organizationId}_${fyLabel}`);

    const onboardingCounts: Record<string, number> = {};
    const totalActiveClients = orgClients.length;

    orgClients.forEach((doc) => {
      const createdAt = getCreationDate(doc);
      if (createdAt >= fyStart && createdAt < fyEnd) {
        const { monthKey } = getFinancialContext(createdAt);
        onboardingCounts[monthKey] = (onboardingCounts[monthKey] ?? 0) + 1;
      }
    });

    await seedAnalyticsDoc(analyticsRef, fyLabel, organizationId);
    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveClients': totalActiveClients,
        'metrics.userOnboarding.values': onboardingCounts,
      },
      { merge: true },
    );
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
}

