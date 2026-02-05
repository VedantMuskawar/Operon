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
import { getYearMonth } from '../shared/date-helpers';

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
    const monthKey = getYearMonth(createdAt); // Use YYYY-MM format
    const analyticsRef = db
      .collection(ANALYTICS_COLLECTION)
      .doc(`${SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set(
      {
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        'metrics.totalActiveClients':
          admin.firestore.FieldValue.increment(1),
        'metrics.userOnboarding': admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  });

/**
 * Core logic to rebuild client analytics for all organizations.
 * Now writes to monthly documents instead of yearly.
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

  // Group clients by organization and month
  const clientsByOrgMonth: Record<string, Record<string, FirebaseFirestore.DocumentSnapshot[]>> = {};
  
  Object.entries(clientsByOrg).forEach(([organizationId, orgClients]) => {
    clientsByOrgMonth[organizationId] = {};
    orgClients.forEach((doc) => {
      const createdAt = getCreationDate(doc);
      if (createdAt >= fyStart && createdAt < fyEnd) {
        const monthKey = getYearMonth(createdAt);
        if (!clientsByOrgMonth[organizationId][monthKey]) {
          clientsByOrgMonth[organizationId][monthKey] = [];
        }
        clientsByOrgMonth[organizationId][monthKey].push(doc);
      }
    });
  });

  const analyticsUpdates: Promise<void>[] = [];
  
  Object.entries(clientsByOrgMonth).forEach(([organizationId, monthClients]) => {
    // Calculate total active clients (all clients, not just in FY)
    const totalActiveClients = clientsByOrg[organizationId].length;
    
    Object.entries(monthClients).forEach(([monthKey, monthDocs]) => {
      const analyticsRef = db
        .collection(ANALYTICS_COLLECTION)
        .doc(`${SOURCE_KEY}_${organizationId}_${monthKey}`);
      
      const onboardingCount = monthDocs.length;
      
      analyticsUpdates.push(
        seedAnalyticsDoc(analyticsRef, monthKey, organizationId).then(() =>
          analyticsRef.set(
            {
              generatedAt: admin.firestore.FieldValue.serverTimestamp(),
              'metrics.totalActiveClients': totalActiveClients,
              'metrics.userOnboarding': onboardingCount,
            },
            { merge: true },
          )
        )
      );
    });
  });

  await Promise.all(analyticsUpdates);
  console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
}

