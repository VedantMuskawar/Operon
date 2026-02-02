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
  const analyticsDocId = `${PRODUCTIONS_SOURCE_KEY}_${organizationId}_${financialYear}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);

  const batchesSnapshot = await db
    .collection(PRODUCTION_BATCHES_COLLECTION)
    .where('organizationId', '==', organizationId)
    .get();

  const totalProductionMonthly: Record<string, number> = {};
  let totalProductionYearly = 0;
  const totalRawMaterialsMonthly: Record<string, number> = {};

  batchesSnapshot.forEach((doc) => {
    const batch = doc.data();
    const batchDate = (batch.batchDate as admin.firestore.Timestamp)?.toDate?.();
    if (!batchDate || batchDate < fyStart || batchDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(batchDate);
    const produced = (batch.totalBricksProduced as number) || 0;
    const stacked = (batch.totalBricksStacked as number) || 0;
    const total = produced + stacked;

    totalProductionMonthly[monthKey] = (totalProductionMonthly[monthKey] || 0) + total;
    totalProductionYearly += total;

    // Raw materials: if metadata.rawMaterialsConsumed or similar exists, aggregate
    const metadata = (batch.metadata as Record<string, unknown>) || {};
    const rawConsumed = (metadata.rawMaterialsConsumed as number) ?? 0;
    if (rawConsumed > 0) {
      totalRawMaterialsMonthly[monthKey] =
        (totalRawMaterialsMonthly[monthKey] || 0) + rawConsumed;
    }
  });

  await seedProductionsAnalyticsDoc(analyticsRef, financialYear, organizationId);

  await analyticsRef.set(
    {
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.totalProductionMonthly.values': totalProductionMonthly,
      'metrics.totalProductionYearly': totalProductionYearly,
      'metrics.totalRawMaterialsMonthly.values': totalRawMaterialsMonthly,
    },
    { merge: true },
  );
}
