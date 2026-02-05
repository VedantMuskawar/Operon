import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  TRIP_WAGES_COLLECTION,
  TRIP_WAGES_ANALYTICS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore, seedTripWagesAnalyticsDoc } from '../shared/firestore-helpers';
import { getYearMonth } from '../shared/date-helpers';

const db = getFirestore();

/**
 * Rebuild trip wages analytics for a single organization and financial year.
 * Tracks: wages paid by fixed quantity bucket, total trip wages per month.
 */
export async function rebuildTripWagesAnalyticsForOrg(
  organizationId: string,
  financialYear: string,
  fyStart: Date,
  fyEnd: Date,
): Promise<void> {
  const tripWagesSnapshot = await db
    .collection(TRIP_WAGES_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'processed')
    .get();

  // Group wages by month
  const wagesByMonth: Record<string, {
    totalTripWages: number;
    wagesByQuantity: Record<string, number>;
  }> = {};

  tripWagesSnapshot.forEach((doc) => {
    const tw = doc.data();
    const totalWages = (tw.totalWages as number) || 0;
    const quantityDelivered = (tw.quantityDelivered as number) ?? 0;
    const qtyKey = String(quantityDelivered);

    const createdAt = (tw.createdAt as admin.firestore.Timestamp)?.toDate?.();
    const paymentDate = (tw.paymentDate as admin.firestore.Timestamp)?.toDate?.();
    const wageDate = paymentDate || createdAt;

    if (!wageDate || wageDate < fyStart || wageDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(wageDate);

    if (!wagesByMonth[monthKey]) {
      wagesByMonth[monthKey] = {
        totalTripWages: 0,
        wagesByQuantity: {},
      };
    }

    wagesByMonth[monthKey].totalTripWages += totalWages;
    wagesByMonth[monthKey].wagesByQuantity[qtyKey] =
      (wagesByMonth[monthKey].wagesByQuantity[qtyKey] || 0) + totalWages;
  });

  // Write to each month's document
  const monthPromises = Object.entries(wagesByMonth).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${TRIP_WAGES_ANALYTICS_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedTripWagesAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.totalTripWagesMonthly': monthData.totalTripWages,
      'metrics.wagesPaidByFixedQuantityMonthly': monthData.wagesByQuantity,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
