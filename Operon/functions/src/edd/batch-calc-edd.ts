import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { getFirestore } from '../shared/firestore-helpers';
import {
  ORGANIZATIONS_COLLECTION,
  PENDING_ORDERS_COLLECTION,
  VEHICLE_AVAILABILITY_FORECAST,
} from '../shared/constants';
import { CALLABLE_OPTS } from '../shared/function-config';

const db = getFirestore();
const BUFFER_DAYS_NORMAL = 1;

interface CalculateEddPayload {
  organizationId: string;
}

interface VehicleCandidate {
  vehicleId: string;
  vehicleName: string;
  vehicleCapacity?: number;
  productCapacities?: Record<string, number>;
}

interface OrderItemInput {
  productId?: string;
  fixedQuantityPerTrip?: number;
  estimatedTrips?: number;
}

function getVehicleCapacityForProduct(vehicle: VehicleCandidate, productId: string | undefined): number {
  if (productId && vehicle.productCapacities?.[productId] != null) {
    return vehicle.productCapacities[productId] as number;
  }
  return vehicle.vehicleCapacity ?? 0;
}

function scheduleTrips(
  freeSlots: Record<string, number>,
  tripsNeeded: number,
  bufferDays: number,
): string[] {
  const sorted = Object.keys(freeSlots).sort();
  const out: string[] = [];
  let lastDate: Date | null = null;

  for (const key of sorted) {
    if (out.length >= tripsNeeded) break;
    const cap = freeSlots[key] ?? 0;
    if (cap < 1) continue;

    const parts = key.split('-').map(Number);
    const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));

    if (lastDate != null && bufferDays >= 1) {
      const minNext = new Date(lastDate);
      minNext.setUTCDate(minNext.getUTCDate() + 2);
      if (d < minNext) continue;
    }

    out.push(key);
    freeSlots[key] = cap - 1;
    lastDate = d;
  }

  return out;
}

function normalizeEstimatedTrips(value: unknown): number {
  const parsed = Math.max(0, Math.floor(Number(value)) || 0);
  return parsed <= 0 ? 1 : parsed;
}

function normalizeFixedQuantity(value: unknown): number {
  const parsed = Math.max(0, Math.floor(Number(value)) || 0);
  return parsed;
}

export const calculateEddForAllPendingOrders = onCall(
  { ...CALLABLE_OPTS },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const { organizationId } = (request.data || {}) as CalculateEddPayload;
    if (typeof organizationId !== 'string' || !organizationId.trim()) {
      throw new HttpsError('invalid-argument', 'organizationId is required.');
    }

    const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
    const vehiclesSnap = await orgRef.collection('VEHICLES').where('isActive', '==', true).get();

    const vehicles: VehicleCandidate[] = vehiclesSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        vehicleId: doc.id,
        vehicleName: (data.vehicleNumber as string) ?? doc.id,
        vehicleCapacity: data.vehicleCapacity as number | undefined,
        productCapacities: data.productCapacities as Record<string, number> | undefined,
      };
    });

    if (vehicles.length == 0) {
      return { success: false, message: 'No active vehicles found.', updatedOrders: 0 };
    }

    const pendingSnap = await db
      .collection(PENDING_ORDERS_COLLECTION)
      .where('organizationId', '==', organizationId)
      .where('status', '==', 'pending')
      .get();

    const updates: Array<Promise<admin.firestore.WriteResult>> = [];

    for (const orderDoc of pendingSnap.docs) {
      const order = orderDoc.data();
      const items = (order.items as OrderItemInput[]) ?? [];
      if (items.length === 0) continue;

      const priority = (order.priority as string) ?? 'normal';
      const bufferDays = priority === 'high' ? 0 : BUFFER_DAYS_NORMAL;

      let bestResult: {
        vehicleId: string;
        vehicleName: string;
        estimatedStartDate: string;
        estimatedCompletionDate: string;
        items: Array<{ itemIndex: number; productId: string | null; tripsRequired: number; tripDates: string[] }>;
      } | null = null;

      for (const vehicle of vehicles) {
        const forecastDoc = await orgRef
          .collection(VEHICLE_AVAILABILITY_FORECAST)
          .doc(vehicle.vehicleId)
          .get();
        const freeSlots: Record<string, number> = (forecastDoc.data()?.freeSlots as Record<string, number>) ?? {};
        const mutableSlots: Record<string, number> = { ...freeSlots };

        const itemSchedules: Array<{ itemIndex: number; productId: string | null; tripsRequired: number; tripDates: string[] }> = [];
        let scheduleFailed = false;

        items.forEach((item, index) => {
          if (scheduleFailed) return;
          const productId = item.productId ?? null;
          const fixedQty = normalizeFixedQuantity(item.fixedQuantityPerTrip);
          const estimatedTrips = normalizeEstimatedTrips(item.estimatedTrips);
          const capacity = getVehicleCapacityForProduct(vehicle, productId ?? undefined);

          if (capacity <= 0 || fixedQty <= 0) {
            scheduleFailed = true;
            return;
          }

          const tripsRequired = fixedQty <= capacity
            ? estimatedTrips
            : Math.max(1, Math.ceil((estimatedTrips * fixedQty) / capacity));

          const tripDates = scheduleTrips(mutableSlots, tripsRequired, bufferDays);
          if (tripDates.length < tripsRequired) {
            scheduleFailed = true;
            return;
          }

          itemSchedules.push({
            itemIndex: index,
            productId,
            tripsRequired,
            tripDates,
          });
        });

        if (scheduleFailed || itemSchedules.length === 0) {
          continue;
        }

        const allDates = itemSchedules.flatMap((item) => item.tripDates);
        const sortedDates = allDates.slice().sort();
        const estimatedStartDate = sortedDates[0];
        const estimatedCompletionDate = sortedDates[sortedDates.length - 1];

        if (!bestResult || estimatedCompletionDate < bestResult.estimatedCompletionDate) {
          bestResult = {
            vehicleId: vehicle.vehicleId,
            vehicleName: vehicle.vehicleName,
            estimatedStartDate,
            estimatedCompletionDate,
            items: itemSchedules,
          };
        }
      }

      if (!bestResult) {
        continue;
      }

      updates.push(
        orderDoc.ref.update({
          edd: {
            calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
            vehicleId: bestResult.vehicleId,
            vehicleName: bestResult.vehicleName,
            estimatedStartDate: bestResult.estimatedStartDate,
            estimatedCompletionDate: bestResult.estimatedCompletionDate,
            items: bestResult.items,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      );
    }

    await Promise.all(updates);

    return {
      success: true,
      updatedOrders: updates.length,
    };
  },
);
