import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  TRIP_WAGES_COLLECTION,
  TRIP_WAGES_ANALYTICS_SOURCE_KEY,
} from '../shared/constants';
import { getFirestore, seedTripWagesAnalyticsDoc } from '../shared/firestore-helpers';
import { getYearMonth, formatDate } from '../shared/date-helpers';

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

  // Group wages by month and by day (daily data only)
  const wagesByMonthDay: Record<string, {
    tripWagesDaily: Record<string, number>;
    wagesByQuantityDaily: Record<string, Record<string, number>>;
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
    const dateString = formatDate(wageDate);

    if (!wagesByMonthDay[monthKey]) {
      wagesByMonthDay[monthKey] = {
        tripWagesDaily: {},
        wagesByQuantityDaily: {},
      };
    }

    wagesByMonthDay[monthKey].tripWagesDaily[dateString] =
      (wagesByMonthDay[monthKey].tripWagesDaily[dateString] || 0) + totalWages;

    if (!wagesByMonthDay[monthKey].wagesByQuantityDaily[dateString]) {
      wagesByMonthDay[monthKey].wagesByQuantityDaily[dateString] = {};
    }
    wagesByMonthDay[monthKey].wagesByQuantityDaily[dateString][qtyKey] =
      (wagesByMonthDay[monthKey].wagesByQuantityDaily[dateString][qtyKey] || 0) + totalWages;
  });

  const monthPromises = Object.entries(wagesByMonthDay).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${TRIP_WAGES_ANALYTICS_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedTripWagesAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.tripWagesDaily': monthData.tripWagesDaily,
      'metrics.wagesByQuantityDaily': monthData.wagesByQuantityDaily,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
