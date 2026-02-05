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
import { getYearMonth } from '../shared/date-helpers';

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

  // Group deliveries by month
  const deliveriesByMonth: Record<string, {
    quantity: number;
    quantityByRegion: Record<string, number>;
    clientTotals: Record<string, { amount: number; count: number }>;
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

    if (!deliveriesByMonth[monthKey]) {
      deliveriesByMonth[monthKey] = {
        quantity: 0,
        quantityByRegion: {},
        clientTotals: {},
      };
    }

    // Sum quantity from items
    let qty = 0;
    const items = (dm.items as any[]) || [];
    for (const item of items) {
      const fixedQty = (item?.fixedQuantityPerTrip as number) ?? 0;
      qty += fixedQty;
    }

    deliveriesByMonth[monthKey].quantity += qty;

    // Region distribution
    const dz = (dm.deliveryZone as Record<string, unknown>) || {};
    const city = (dz.city_name as string) || (dz.city as string) || 'Unknown';
    const region = (dz.region as string) || city;

    deliveriesByMonth[monthKey].quantityByRegion[city] = 
      (deliveriesByMonth[monthKey].quantityByRegion[city] || 0) + qty;
    if (region !== city) {
      deliveriesByMonth[monthKey].quantityByRegion[region] = 
        (deliveriesByMonth[monthKey].quantityByRegion[region] || 0) + qty;
    }

    // Top clients
    const tripPricing = (dm.tripPricing as Record<string, unknown>) || {};
    const totalAmount = (tripPricing.total as number) || 0;
    const clientId = (dm.clientId as string) || '';

    if (clientId) {
      if (!clientNameMap[clientId]) {
        clientNameMap[clientId] = (dm.clientName as string) || 'Unknown';
      }
      if (!deliveriesByMonth[monthKey].clientTotals[clientId]) {
        deliveriesByMonth[monthKey].clientTotals[clientId] = { amount: 0, count: 0 };
      }
      deliveriesByMonth[monthKey].clientTotals[clientId].amount += totalAmount;
      deliveriesByMonth[monthKey].clientTotals[clientId].count += 1;
    }
  });

  // Write to each month's document
  const monthPromises = Object.entries(deliveriesByMonth).map(async ([monthKey, monthData]) => {
    const analyticsRef = db.collection(ANALYTICS_COLLECTION)
      .doc(`${DELIVERIES_SOURCE_KEY}_${organizationId}_${monthKey}`);

    // Calculate top 20 clients for this month
    const top20Clients = Object.entries(monthData.clientTotals)
      .map(([cid, data]) => ({
        clientId: cid,
        clientName: clientNameMap[cid] || 'Unknown',
        totalAmount: data.amount,
        orderCount: data.count,
      }))
      .sort((a, b) => b.totalAmount - a.totalAmount)
      .slice(0, 20);

    await seedDeliveriesAnalyticsDoc(analyticsRef, monthKey, organizationId);

    await analyticsRef.set({
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      'metrics.totalQuantityDeliveredMonthly': monthData.quantity,
      'metrics.quantityByRegion': monthData.quantityByRegion,
      'metrics.top20ClientsByOrderValueMonthly': top20Clients,
    }, { merge: true });
  });

  await Promise.all(monthPromises);
}
