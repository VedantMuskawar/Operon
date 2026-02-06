import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  PRODUCTION_BATCHES_COLLECTION,
  PRODUCTIONS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore, seedProductionsAnalyticsDoc } from '../shared/firestore-helpers';
import { getYearMonth, formatDate } from '../shared/date-helpers';

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

  // Group batches by month and by day (daily data only)
  const batchesByMonthDay: Record<string, {
    productionDaily: Record<string, number>;
    rawMaterialsDaily: Record<string, number>;
  }> = {};

  batchesSnapshot.forEach((doc) => {
    const batch = doc.data();
    const batchDate = (batch.batchDate as admin.firestore.Timestamp)?.toDate?.();
    if (!batchDate || batchDate < fyStart || batchDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(batchDate);
    const dateString = formatDate(batchDate);

    if (!batchesByMonthDay[monthKey]) {
      batchesByMonthDay[monthKey] = {
        productionDaily: {},
        rawMaterialsDaily: {},
      };
    }

    const produced = (batch.totalBricksProduced as number) || 0;
    const stacked = (batch.totalBricksStacked as number) || 0;
    const total = produced + stacked;

    batchesByMonthDay[monthKey].productionDaily[dateString] =
      (batchesByMonthDay[monthKey].productionDaily[dateString] || 0) + total;

    const metadata = (batch.metadata as Record<string, unknown>) || {};
    const rawConsumed = (metadata.rawMaterialsConsumed as number) ?? 0;
    if (rawConsumed > 0) {
      batchesByMonthDay[monthKey].rawMaterialsDaily[dateString] =
        (batchesByMonthDay[monthKey].rawMaterialsDaily[dateString] || 0) + rawConsumed;
    }
  });

  const monthPromises = Object.entries(batchesByMonthDay).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${PRODUCTIONS_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedProductionsAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.productionDaily': monthData.productionDaily,
      'metrics.rawMaterialsDaily': monthData.rawMaterialsDaily,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
