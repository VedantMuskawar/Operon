import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  PRODUCTION_BATCHES_COLLECTION,
  PRODUCTIONS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore, seedProductionsAnalyticsDoc } from '../shared/firestore-helpers';
import { getYearMonth } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Rebuild productions analytics for a single organization and financial year.
 * Tracks: total production (bricks produced/stacked) per month and year.
 */
export async function rebuildProductionsAnalyticsForOrg(
  organizationId: string,
  financialYear: string,
  fyStart: Date,
  fyEnd: Date,
): Promise<void> {
  const batchesSnapshot = await db
    .collection(PRODUCTION_BATCHES_COLLECTION)
    .where('organizationId', '==', organizationId)
    .get();

  // Group batches by month
  const batchesByMonth: Record<string, {
    totalProduction: number;
    totalRawMaterials: number;
  }> = {};

  batchesSnapshot.forEach((doc) => {
    const batch = doc.data();
    const batchDate = (batch.batchDate as admin.firestore.Timestamp)?.toDate?.();
    if (!batchDate || batchDate < fyStart || batchDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(batchDate);
    
    if (!batchesByMonth[monthKey]) {
      batchesByMonth[monthKey] = {
        totalProduction: 0,
        totalRawMaterials: 0,
      };
    }

    const produced = (batch.totalBricksProduced as number) || 0;
    const stacked = (batch.totalBricksStacked as number) || 0;
    const total = produced + stacked;

    batchesByMonth[monthKey].totalProduction += total;

    const metadata = (batch.metadata as Record<string, unknown>) || {};
    const rawConsumed = (metadata.rawMaterialsConsumed as number) ?? 0;
    if (rawConsumed > 0) {
      batchesByMonth[monthKey].totalRawMaterials += rawConsumed;
    }
  });

  // Write to each month's document
  const monthPromises = Object.entries(batchesByMonth).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${PRODUCTIONS_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedProductionsAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.totalProductionMonthly': monthData.totalProduction,
      'metrics.totalRawMaterialsMonthly': monthData.totalRawMaterials,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
