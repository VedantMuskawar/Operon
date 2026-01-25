import * as functions from 'firebase-functions';
import { getFirestore } from '../shared/firestore-helpers';
import {
  ORGANIZATIONS_COLLECTION,
  VEHICLE_AVAILABILITY_FORECAST,
} from '../shared/constants';
import { CALLABLE_FUNCTION_CONFIG } from '../shared/function-config';
import type { QuoteResult } from './models';

const db = getFirestore();
const BUFFER_DAYS_NORMAL = 1;

interface GetDeliveryQuotePayload {
  totalQuantity: number;
  productType: string;
  organizationId: string;
}

/**
 * Staggered fit: find earliest sequence of `tripsNeeded` dates from freeSlots
 * with 1-day gap (Normal priority). Returns [D1, D2, ...] or [] if not fittable.
 */
function staggeredFit(
  freeSlots: Record<string, number>,
  tripsNeeded: number,
): string[] {
  const sorted = Object.keys(freeSlots).sort();
  const out: string[] = [];
  let lastDate: Date | null = null;
  const slots = { ...freeSlots };

  for (const key of sorted) {
    if (out.length >= tripsNeeded) break;
    const cap = slots[key] ?? 0;
    if (cap < 1) continue;

    const parts = key.split('-').map(Number);
    const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));

    if (lastDate != null && BUFFER_DAYS_NORMAL >= 1) {
      const minNext = new Date(lastDate);
      minNext.setUTCDate(minNext.getUTCDate() + 2);
      if (d < minNext) continue;
    }

    out.push(key);
    slots[key] = cap - 1;
    lastDate = d;
  }

  return out.length >= tripsNeeded ? out : [];
}

/**
 * Callable: getDeliveryQuote(totalQuantity, productType, organizationId).
 * Returns QuoteResult[] sorted by estimatedCompletionDate ascending.
 */
export const getDeliveryQuote = functions
  .region(CALLABLE_FUNCTION_CONFIG.region)
  .runWith({
    timeoutSeconds: CALLABLE_FUNCTION_CONFIG.timeoutSeconds,
    memory: '512MB',
  })
  .https.onCall(async (data: unknown, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { totalQuantity, productType, organizationId } = (data || {}) as GetDeliveryQuotePayload;
    if (typeof totalQuantity !== 'number' || totalQuantity <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'totalQuantity must be a positive number.');
    }
    if (typeof productType !== 'string' || !productType.trim()) {
      throw new functions.https.HttpsError('invalid-argument', 'productType is required.');
    }
    if (typeof organizationId !== 'string' || !organizationId.trim()) {
      throw new functions.https.HttpsError('invalid-argument', 'organizationId is required.');
    }

    const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
    const vehiclesSnap = await orgRef.collection('VEHICLES').where('isActive', '==', true).get();

    const candidates: { vehicleId: string; vehicleName: string; capacityPerTrip: number }[] = [];
    for (const doc of vehiclesSnap.docs) {
      const d = doc.data();
      const pc = (d.productCapacities as Record<string, number> | undefined) ?? {};
      const cap = pc[productType] ?? (d.vehicleCapacity as number) ?? 0;
      if (cap > 0) {
        candidates.push({
          vehicleId: doc.id,
          vehicleName: (d.vehicleNumber as string) ?? doc.id,
          capacityPerTrip: cap,
        });
      }
    }

    const results: QuoteResult[] = [];
    const forecastCol = orgRef.collection(VEHICLE_AVAILABILITY_FORECAST);

    for (const c of candidates) {
      const forecastDoc = await forecastCol.doc(c.vehicleId).get();
      const freeSlots: Record<string, number> = (forecastDoc.data()?.freeSlots as Record<string, number>) ?? {};

      const tripsRequired = Math.ceil(totalQuantity / c.capacityPerTrip);
      const scheduleBreakdown = staggeredFit(freeSlots, tripsRequired);
      if (scheduleBreakdown.length < tripsRequired) continue;

      const estimatedStartDate = scheduleBreakdown[0];
      const estimatedCompletionDate = scheduleBreakdown[scheduleBreakdown.length - 1];
      results.push({
        vehicleId: c.vehicleId,
        vehicleName: c.vehicleName,
        tripsRequired,
        estimatedStartDate,
        estimatedCompletionDate,
        scheduleBreakdown,
      });
    }

    results.sort(
      (a, b) => (a.estimatedCompletionDate < b.estimatedCompletionDate ? -1 : a.estimatedCompletionDate > b.estimatedCompletionDate ? 1 : 0),
    );

    return results;
  });
