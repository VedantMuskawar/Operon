import * as admin from 'firebase-admin';
import { getFirestore } from '../shared/firestore-helpers';
import { formatDate } from '../shared/date-helpers';
import {
  PENDING_ORDERS_COLLECTION,
  ORGANIZATIONS_COLLECTION,
  SCHEDULE_TRIPS_COLLECTION,
  VEHICLE_AVAILABILITY_FORECAST,
} from '../shared/constants';
import type { VehicleForecast } from './models';

const db = getFirestore();
const ROCK_STATUSES = ['scheduled', 'dispatched', 'delivered', 'returned'] as const;
const DEFAULT_CAPACITY = 5;
const FORECAST_DAYS = 60;

const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

interface VehicleInput {
  id: string;
  vehicleNumber: string;
  vehicleCapacity?: number;
  weeklyCapacity?: Record<string, number>;
  productCapacities?: Record<string, number>;
}

interface OrderItemInput {
  productId: string;
  totalQuantity: number;
  fixedQuantityPerTrip: number;
  estimatedTrips: number;
}

interface PendingOrderInput {
  orderId: string;
  organizationId: string;
  items: OrderItemInput[];
  priority: string;
  createdAt: admin.firestore.Timestamp;
  status: string;
  autoSchedule?: { suggestedVehicleId?: string };
}

function getDailyCapacity(vehicle: VehicleInput, date: Date): number {
  const dayIndex = date.getUTCDay();
  const dayOfWeek = DAY_NAMES[dayIndex];
  if (vehicle.weeklyCapacity?.[dayOfWeek] != null) {
    return vehicle.weeklyCapacity[dayOfWeek];
  }
  return vehicle.vehicleCapacity ?? DEFAULT_CAPACITY;
}

function getVehicleCapacityForProduct(vehicle: VehicleInput, productId: string): number {
  if (vehicle.productCapacities?.[productId] != null) {
    return vehicle.productCapacities[productId];
  }
  return vehicle.vehicleCapacity ?? DEFAULT_CAPACITY;
}

function totalQuantityForOrder(order: PendingOrderInput): number {
  const first = order.items[0];
  if (!first) return 0;
  return (first.estimatedTrips ?? 0) * (first.fixedQuantityPerTrip || first.totalQuantity || 0) || first.totalQuantity || 0;
}

function productIdForOrder(order: PendingOrderInput): string | null {
  return order.items[0]?.productId ?? null;
}

function parseScheduledDate(raw: admin.firestore.Timestamp | { _seconds: number } | undefined): Date | null {
  if (!raw) return null;
  if (typeof (raw as admin.firestore.Timestamp).toDate === 'function') {
    return (raw as admin.firestore.Timestamp).toDate();
  }
  const s = (raw as { _seconds: number })._seconds;
  if (typeof s === 'number') return new Date(s * 1000);
  return null;
}

/**
 * Build timeline map for the next FORECAST_DAYS days. Key = YYYY-MM-DD, value = trips remaining.
 */
function buildInitialTimeline(vehicle: VehicleInput): Map<string, number> {
  const timeline = new Map<string, number>();
  const start = new Date();
  start.setUTCHours(0, 0, 0, 0);
  // Start from today to avoid immediate overdue flags on fresh recalcs.

  for (let i = 0; i < FORECAST_DAYS; i++) {
    const d = new Date(start);
    d.setUTCDate(start.getUTCDate() + i);
    const key = formatDate(d);
    timeline.set(key, getDailyCapacity(vehicle, d));
  }
  return timeline;
}

/**
 * Subtract rocks (fixed trips) from timeline. Each rock occupies 1 slot on its scheduledDate.
 */
function subtractRocks(
  timeline: Map<string, number>,
  rocks: { scheduledDate: Date }[],
): void {
  for (const r of rocks) {
    const key = formatDate(r.scheduledDate);
    const cur = timeline.get(key) ?? 0;
    if (cur > 0) timeline.set(key, cur - 1);
  }
}

/**
 * Find earliest valid sequence of dates for `tripsNeeded` trips with given buffer.
 * Buffer 0 = consecutive days ok; 1 = must skip one day between trips.
 * Mutates timeline (occupies slots). Returns array of YYYY-MM-DD.
 */
function findAndOccupySlots(
  timeline: Map<string, number>,
  tripsNeeded: number,
  bufferDays: number,
): string[] {
  const sorted = Array.from(timeline.keys()).sort();
  const out: string[] = [];
  let lastDate: Date | null = null;

  for (const key of sorted) {
    if (out.length >= tripsNeeded) break;
    const capacity = timeline.get(key) ?? 0;
    if (capacity < 1) continue;

    const parts = key.split('-').map(Number);
    const d = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));

    if (lastDate != null && bufferDays >= 1) {
      const minNext = new Date(lastDate);
      minNext.setUTCDate(minNext.getUTCDate() + 2); // skip one day
      if (d < minNext) continue;
    }

    out.push(key);
    timeline.set(key, capacity - 1);
    lastDate = d;
  }

  return out;
}

/**
 * Recalculate vehicle queue: build timeline, subtract rocks, pour pending orders,
 * produce forecast, batch-update order EDDs, write VehicleForecast.
 */
export async function recalculateVehicleQueue(
  vehicleId: string,
  organizationId: string,
): Promise<void> {
  const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
  const vehicleDoc = await orgRef.collection('VEHICLES').doc(vehicleId).get();
  if (!vehicleDoc.exists) {
    console.warn('[EDD] Vehicle not found', { vehicleId, organizationId });
    return;
  }

  const vData = vehicleDoc.data()!;
  const vehicle: VehicleInput = {
    id: vehicleDoc.id,
    vehicleNumber: (vData.vehicleNumber as string) ?? '',
    vehicleCapacity: vData.vehicleCapacity as number | undefined,
    weeklyCapacity: vData.weeklyCapacity as Record<string, number> | undefined,
    productCapacities: vData.productCapacities as Record<string, number> | undefined,
  };

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const endWindow = new Date(today);
  endWindow.setUTCDate(endWindow.getUTCDate() + FORECAST_DAYS + 1);

  const tripsSnap = await db
    .collection(SCHEDULE_TRIPS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('scheduledDate', '>=', today)
    .where('scheduledDate', '<', endWindow)
    .get();

  const rocks: { scheduledDate: Date }[] = [];
  for (const doc of tripsSnap.docs) {
    const data = doc.data();
    if (data.vehicleId !== vehicleId) continue;
    const st = (data.tripStatus as string)?.toLowerCase();
    if (!ROCK_STATUSES.includes(st as typeof ROCK_STATUSES[number])) continue;
    const sd = parseScheduledDate(data.scheduledDate as admin.firestore.Timestamp | { _seconds: number });
    if (sd) rocks.push({ scheduledDate: sd });
  }

  const pendingSnap = await db
    .collection(PENDING_ORDERS_COLLECTION)
    .where('organizationId', '==', organizationId)
    .where('status', '==', 'pending')
    .get();

  const pending: PendingOrderInput[] = [];
  for (const doc of pendingSnap.docs) {
    const data = doc.data();
    const suggested = (data.autoSchedule as { suggestedVehicleId?: string } | undefined)?.suggestedVehicleId;
    if (suggested !== vehicleId) continue;
    pending.push({
      orderId: doc.id,
      organizationId: data.organizationId as string,
      items: (data.items as OrderItemInput[]) ?? [],
      priority: (data.priority as string) ?? 'normal',
      createdAt: (data.createdAt as admin.firestore.Timestamp) ?? admin.firestore.Timestamp.now(),
      status: (data.status as string) ?? 'pending',
      autoSchedule: data.autoSchedule as { suggestedVehicleId?: string } | undefined,
    });
  }

  pending.sort((a, b) => {
    if (a.priority === 'high' && b.priority !== 'high') return -1;
    if (b.priority === 'high' && a.priority !== 'high') return 1;
    return a.createdAt.toMillis() - b.createdAt.toMillis();
  });

  const timeline = buildInitialTimeline(vehicle);
  subtractRocks(timeline, rocks);

  const updates: Record<string, string[]> = {};
  const timelineMutable = new Map(timeline);

  for (const order of pending) {
    const productId = productIdForOrder(order);
    const cap = Math.max(
      productId ? getVehicleCapacityForProduct(vehicle, productId) : (vehicle.vehicleCapacity ?? DEFAULT_CAPACITY),
      1,
    );
    const totalQty = totalQuantityForOrder(order);
    const tripsNeeded = Math.max(1, Math.ceil(totalQty / cap));
    const buffer = order.priority === 'high' ? 0 : 1;
    const seq = findAndOccupySlots(timelineMutable, tripsNeeded, buffer);
    if (seq.length > 0) {
      updates[order.orderId] = seq;
    }
  }

  const freeSlots: Record<string, number> = {};
  for (const [k, v] of timelineMutable) {
    if (v > 0) freeSlots[k] = v;
  }

  const forecastRef = orgRef.collection(VEHICLE_AVAILABILITY_FORECAST).doc(vehicleId);
  const forecast: VehicleForecast = {
    lastUpdated: admin.firestore.Timestamp.now(),
    freeSlots,
  };
  await forecastRef.set(forecast);

  const orderUpdates = Object.entries(updates).map(([orderId, dates]) => {
    const lastDate = dates[dates.length - 1];
    return {
      ref: db.collection(PENDING_ORDERS_COLLECTION).doc(orderId),
      estimatedDeliveryDate: admin.firestore.Timestamp.fromDate(new Date(lastDate + 'T12:00:00Z')),
    };
  });

  for (const { ref, estimatedDeliveryDate } of orderUpdates) {
    await ref.update({
      'autoSchedule.estimatedDeliveryDate': estimatedDeliveryDate,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  console.log('[EDD] Recalculated vehicle queue', {
    vehicleId,
    organizationId,
    ordersUpdated: orderUpdates.length,
    forecastDates: Object.keys(freeSlots).length,
  });
}
