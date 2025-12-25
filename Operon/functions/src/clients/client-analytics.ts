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
        [`metrics.activeClients.values.${monthKey}`]:
          admin.firestore.FieldValue.increment(1),
        [`metrics.userOnboarding.values.${monthKey}`]:
          admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  });

/**
 * Cloud Function: Scheduled function to rebuild client analytics
 * Runs every 24 hours to recalculate analytics for all organizations
 */
export const rebuildClientAnalytics = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('UTC')
  .onRun(async () => {
    const now = new Date();
    const { fyLabel, fyStart, fyEnd } = getFinancialContext(now);

    // Get all clients and group by organizationId
    const clientsSnapshot = await db.collection(CLIENTS_COLLECTION).get();
    
    // Group clients by organizationId
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

    // Process analytics for each organization
    const analyticsUpdates = Object.entries(clientsByOrg).map(async ([organizationId, orgClients]) => {
      const analyticsRef = db
        .collection(ANALYTICS_COLLECTION)
        .doc(`${SOURCE_KEY}_${organizationId}_${fyLabel}`);

      const onboardingCounts: Record<string, number> = {};
      const creationDates: Date[] = [];

      orgClients.forEach((doc) => {
        const createdAt = getCreationDate(doc);
        if (createdAt < fyEnd) {
          creationDates.push(createdAt);
        }

        if (createdAt >= fyStart && createdAt < fyEnd) {
          const { monthKey } = getFinancialContext(createdAt);
          onboardingCounts[monthKey] = (onboardingCounts[monthKey] ?? 0) + 1;
        }
      });

      creationDates.sort((a, b) => a.getTime() - b.getTime());

      const activeCounts: Record<string, number> = {};
      let pointer = 0;

      for (let i = 0; i < 12; i += 1) {
        const iterMonth = new Date(
          Date.UTC(fyStart.getUTCFullYear(), fyStart.getUTCMonth() + i, 1),
        );
        const monthKey = `${iterMonth.getUTCFullYear()}-${String(
          iterMonth.getUTCMonth() + 1,
        ).padStart(2, '0')}`;
        const monthEnd = new Date(iterMonth);
        monthEnd.setUTCMonth(monthEnd.getUTCMonth() + 1, 0);
        monthEnd.setUTCHours(23, 59, 59, 999);

        while (
          pointer < creationDates.length &&
          creationDates[pointer].getTime() <= monthEnd.getTime()
        ) {
          pointer += 1;
        }

        activeCounts[monthKey] = pointer;
      }

      await seedAnalyticsDoc(analyticsRef, fyLabel, organizationId);
      await analyticsRef.set(
        {
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          'metrics.activeClients.values': activeCounts,
          'metrics.userOnboarding.values': onboardingCounts,
        },
        { merge: true },
      );
    });

    await Promise.all(analyticsUpdates);
    console.log(`[Client Analytics] Rebuilt analytics for ${Object.keys(clientsByOrg).length} organizations`);
  });

