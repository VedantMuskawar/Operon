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
  const analyticsDocId = `${DELIVERIES_SOURCE_KEY}_${organizationId}_${financialYear}`;
  const analyticsRef = db.collection(ANALYTICS_COLLECTION).doc(analyticsDocId);

  const dmSnapshot = await db
    .collection(DELIVERY_MEMOS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'delivered')
    .get();

  const totalQuantityDeliveredMonthly: Record<string, number> = {};
  let totalQuantityDeliveredYearly = 0;
  const quantityByRegion: Record<string, Record<string, number>> = {};
  const clientTotalsByMonth: Record<string, Record<string, { amount: number; count: number }>> = {};
  const clientTotalsByYear: Record<string, { amount: number; count: number }> = {};

  dmSnapshot.forEach((doc) => {
    const dm = doc.data();
    const scheduledDate = (dm.scheduledDate as admin.firestore.Timestamp)?.toDate?.();
    const deliveredAt = (dm.deliveredAt as admin.firestore.Timestamp)?.toDate?.();
    const dmDate = deliveredAt || scheduledDate;

    if (!dmDate || dmDate < fyStart || dmDate >= fyEnd) {
      return;
    }

    const monthKey = getYearMonth(dmDate);

    // Sum quantity from items
    let qty = 0;
    const items = (dm.items as any[]) || [];
    for (const item of items) {
      const fixedQty = (item?.fixedQuantityPerTrip as number) ?? 0;
      qty += fixedQty;
    }

    totalQuantityDeliveredMonthly[monthKey] =
      (totalQuantityDeliveredMonthly[monthKey] || 0) + qty;
    totalQuantityDeliveredYearly += qty;

    // Region distribution: city_name primary, then region
    const dz = (dm.deliveryZone as Record<string, unknown>) || {};
    const city = (dz.city_name as string) || (dz.city as string) || 'Unknown';
    const region = (dz.region as string) || city;

    if (!quantityByRegion[city]) {
      quantityByRegion[city] = {};
    }
    quantityByRegion[city][monthKey] = (quantityByRegion[city][monthKey] || 0) + qty;
    if (region !== city) {
      if (!quantityByRegion[region]) {
        quantityByRegion[region] = {};
      }
      quantityByRegion[region][monthKey] = (quantityByRegion[region][monthKey] || 0) + qty;
    }

    // Top clients: tripPricing.total as order value
    const tripPricing = (dm.tripPricing as Record<string, unknown>) || {};
    const totalAmount = (tripPricing.total as number) || 0;
    const clientId = (dm.clientId as string) || '';

    if (clientId) {
      if (!clientTotalsByYear[clientId]) {
        clientTotalsByYear[clientId] = { amount: 0, count: 0 };
      }
      clientTotalsByYear[clientId].amount += totalAmount;
      clientTotalsByYear[clientId].count += 1;

      if (!clientTotalsByMonth[monthKey]) {
        clientTotalsByMonth[monthKey] = {};
      }
      if (!clientTotalsByMonth[monthKey][clientId]) {
        clientTotalsByMonth[monthKey][clientId] = { amount: 0, count: 0 };
      }
      clientTotalsByMonth[monthKey][clientId].amount += totalAmount;
      clientTotalsByMonth[monthKey][clientId].count += 1;
    }
  });

  // Get client names from first DM we find per client
  const clientNameMap: Record<string, string> = {};
  dmSnapshot.forEach((d) => {
    const dta = d.data();
    const cid = dta.clientId as string;
    if (cid && !clientNameMap[cid]) {
      clientNameMap[cid] = (dta.clientName as string) || 'Unknown';
    }
  });

  const top20YearlyWithNames: TopClientEntry[] = Object.entries(clientTotalsByYear)
    .map(([cid, data]) => ({
      clientId: cid,
      clientName: clientNameMap[cid] || 'Unknown',
      totalAmount: data.amount,
      orderCount: data.count,
    }))
    .sort((a, b) => b.totalAmount - a.totalAmount)
    .slice(0, 20);

  const top20ByMonth: Record<string, TopClientEntry[]> = {};
  for (const [monthKey, clientData] of Object.entries(clientTotalsByMonth)) {
    top20ByMonth[monthKey] = Object.entries(clientData)
      .map(([cid, data]) => ({
        clientId: cid,
        clientName: clientNameMap[cid] || 'Unknown',
        totalAmount: data.amount,
        orderCount: data.count,
      }))
      .sort((a, b) => b.totalAmount - a.totalAmount)
      .slice(0, 20);
  }

  await seedDeliveriesAnalyticsDoc(analyticsRef, financialYear, organizationId);

  const updateData: Record<string, unknown> = {
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    'metrics.totalQuantityDeliveredMonthly.values': totalQuantityDeliveredMonthly,
    'metrics.totalQuantityDeliveredYearly': totalQuantityDeliveredYearly,
    'metrics.quantityByRegion': quantityByRegion,
    'metrics.top20ClientsByOrderValueYearly': top20YearlyWithNames,
    'metrics.top20ClientsByOrderValueMonthly': top20ByMonth,
  };

  await analyticsRef.set(updateData, { merge: true });
}
