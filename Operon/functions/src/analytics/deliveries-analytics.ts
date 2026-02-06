import * as admin from 'firebase-admin';
import {
  ANALYTICS_COLLECTION,
  DELIVERY_MEMOS_COLLECTION,
  DELIVERIES_SOURCE_KEY,
} from '../shared/constants';
import {
  getFirestore,
  seedDeliveriesAnalyticsDoc,
} from '../shared/firestore-helpers';
import { getYearMonth, formatDate } from '../shared/date-helpers';

const db = getFirestore();

export interface TopClientEntry {
  clientId: string;
  clientName: string;
  totalAmount: number;
  orderCount: number;
}

/**
 * Rebuild deliveries analytics for a single organization and financial year.
 * Tracks: total quantity delivered, quantity by region (city/region), top 20 clients by order value.
 */
export async function rebuildDeliveriesAnalyticsForOrg(
  organizationId: string,
  financialYear: string,
  fyStart: Date,
  fyEnd: Date,
): Promise<void> {
  // Group deliveries by month - will write to multiple monthly documents

  const dmSnapshot = await db
    .collection(DELIVERY_MEMOS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'delivered')
    .get();

  // Group deliveries by month and by day (daily data only)
  const deliveriesByMonthDay: Record<string, {
    quantityDaily: Record<string, number>;
    quantityByRegionDaily: Record<string, Record<string, number>>;
    clientTotalsDaily: Record<string, Record<string, { amount: number; count: number }>>;
  }> = {};

  const clientNameMap: Record<string, string> = {};

  dmSnapshot.forEach((doc) => {
    const dm = doc.data();
    const scheduledDate = (dm.scheduledDate as admin.firestore.Timestamp)?.toDate?.();
    const deliveredAt = (dm.deliveredAt as admin.firestore.Timestamp)?.toDate?.();
    const dmDate = deliveredAt || scheduledDate;

    if (!dmDate || dmDate < fyStart || dmDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(dmDate);
    const dateString = formatDate(dmDate);

    if (!deliveriesByMonthDay[monthKey]) {
      deliveriesByMonthDay[monthKey] = {
        quantityDaily: {},
        quantityByRegionDaily: {},
        clientTotalsDaily: {},
      };
    }

    let qty = 0;
    const items = (dm.items as any[]) || [];
    for (const item of items) {
      const fixedQty = (item?.fixedQuantityPerTrip as number) ?? 0;
      qty += fixedQty;
    }

    deliveriesByMonthDay[monthKey].quantityDaily[dateString] =
      (deliveriesByMonthDay[monthKey].quantityDaily[dateString] || 0) + qty;

    const dz = (dm.deliveryZone as Record<string, unknown>) || {};
    const city = (dz.city_name as string) || (dz.city as string) || 'Unknown';
    const region = (dz.region as string) || city;

    if (!deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString]) {
      deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString] = {};
    }
    const regionMap = deliveriesByMonthDay[monthKey].quantityByRegionDaily[dateString];
    regionMap[city] = (regionMap[city] || 0) + qty;
    if (region !== city) {
      regionMap[region] = (regionMap[region] || 0) + qty;
    }

    const tripPricing = (dm.tripPricing as Record<string, unknown>) || {};
    const totalAmount = (tripPricing.total as number) || 0;
    const clientId = (dm.clientId as string) || '';

    if (clientId) {
      if (!clientNameMap[clientId]) {
        clientNameMap[clientId] = (dm.clientName as string) || 'Unknown';
      }
      if (!deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString]) {
        deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString] = {};
      }
      const dayClients = deliveriesByMonthDay[monthKey].clientTotalsDaily[dateString];
      if (!dayClients[clientId]) {
        dayClients[clientId] = { amount: 0, count: 0 };
      }
      dayClients[clientId].amount += totalAmount;
      dayClients[clientId].count += 1;
    }
  });

  const monthPromises = Object.entries(deliveriesByMonthDay).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${DELIVERIES_SOURCE_KEY}_${organizationId}_${monthKey}`);

    await seedDeliveriesAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.quantityDeliveredDaily': monthData.quantityDaily,
      'metrics.quantityByRegionDaily': monthData.quantityByRegionDaily,
      'metrics.clientTotalsDaily': monthData.clientTotalsDaily,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
