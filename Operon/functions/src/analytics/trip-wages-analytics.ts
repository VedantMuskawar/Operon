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
  const analyticsDocId = `${TRIP_WAGES_ANALYTICS_SOURCE_KEY}_${organizationId}_${financialYear}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);

  const tripWagesSnapshot = await db
    .collection(TRIP_WAGES_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'processed')
    .get();

  const wagesPaidByFixedQuantityMonthly: Record<string, Record<string, number>> = {};
  const wagesPaidByFixedQuantityYearly: Record<string, number> = {};
  const totalTripWagesMonthly: Record<string, number> = {};

  tripWagesSnapshot.forEach((doc) => {
    const tw = doc.data();
    const totalWages = (tw.totalWages as number) || 0;
    const quantityDelivered = (tw.quantityDelivered as number) ?? 0;
    const qtyKey = String(quantityDelivered);

    // Use createdAt or payment date - TRIP_WAGES may not have paymentDate; use createdAt
    const createdAt = (tw.createdAt as admin.firestore.Timestamp)?.toDate?.();
    const paymentDate = (tw.paymentDate as admin.firestore.Timestamp)?.toDate?.();
    const wageDate = paymentDate || createdAt;

    if (!wageDate || wageDate < fyStart || wageDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(wageDate);

    totalTripWagesMonthly[monthKey] =
      (totalTripWagesMonthly[monthKey] || 0) + totalWages;

    wagesPaidByFixedQuantityYearly[qtyKey] =
      (wagesPaidByFixedQuantityYearly[qtyKey] || 0) + totalWages;

    if (!wagesPaidByFixedQuantityMonthly[qtyKey]) {
      wagesPaidByFixedQuantityMonthly[qtyKey] = {};
    }
    wagesPaidByFixedQuantityMonthly[qtyKey][monthKey] =
      (wagesPaidByFixedQuantityMonthly[qtyKey][monthKey] || 0) + totalWages;
  });

  await seedTripWagesAnalyticsDoc(analyticsRef, financialYear, organizationId);

  await analyticsRef.set(
    {
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.wagesPaidByFixedQuantityMonthly': wagesPaidByFixedQuantityMonthly,
      'metrics.wagesPaidByFixedQuantityYearly': wagesPaidByFixedQuantityYearly,
      'metrics.totalTripWagesMonthly.values': totalTripWagesMonthly,
    },
    { merge: true },
  );
}
