import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore } from '../shared/firestore-helpers';
import {
  PENDING_ORDERS_COLLECTION,
  ORGANIZATIONS_COLLECTION,
  SCHEDULE_TRIPS_COLLECTION,
  EDD_RECALC_QUEUE,
} from '../shared/constants';
import { LIGHT_TRIGGER_OPTS, SCHEDULED_FUNCTION_OPTS } from '../shared/function-config';
import { recalculateVehicleQueue } from './simulation-engine';

const db = getFirestore();
const DEBOUNCE_SECONDS = 60;

function shallowEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a == null || b == null) return false;
  if (typeof a !== 'object' || typeof b !== 'object') return a === b;
  const ka = Object.keys(a as object).sort();
  const kb = Object.keys(b as object).sort();
  if (ka.length !== kb.length) return false;
  for (let i = 0; i < ka.length; i++) {
    if (ka[i] !== kb[i]) return false;
    const key = ka[i];
    const va = (a as Record<string, unknown>)[key];
    const vb = (b as Record<string, unknown>)[key];
    if (typeof va === 'object' && va !== null && typeof vb === 'object' && vb !== null) {
      if (!shallowEqual(va, vb)) return false;
    } else if (va !== vb) return false;
  }
  return true;
}

function orderRelevantChange(before: admin.firestore.DocumentSnapshot, after: admin.firestore.DocumentSnapshot): boolean {
  if (!before.exists) return true; // create
  if (!after.exists) return true; // delete
  const b = before.data()!;
  const a = after.data()!;
  if ((b.status as string) !== (a.status as string)) return true;
  if ((b.priority as string) !== (a.priority as string)) return true;
  const bItems = (b.items as unknown[]) ?? [];
  const aItems = (a.items as unknown[]) ?? [];
  if (bItems.length !== aItems.length) return true;
  if (!shallowEqual(bItems, aItems)) return true;
  const bTrips = (b.scheduledTrips as unknown[]) ?? [];
  const aTrips = (a.scheduledTrips as unknown[]) ?? [];
  if (bTrips.length !== aTrips.length) return true;
  if ((b.totalScheduledTrips as number) !== (a.totalScheduledTrips as number)) return true;
  // Check for autoSchedule changes (especially suggestedVehicleId which affects EDD)
  const bAutoSchedule = b.autoSchedule as { suggestedVehicleId?: string } | undefined;
  const aAutoSchedule = a.autoSchedule as { suggestedVehicleId?: string } | undefined;
  if (!shallowEqual(bAutoSchedule, aAutoSchedule)) return true;
  return false;
}

async function getAffectedVehicleIds(
  orderId: string,
  organizationId: string,
  before: admin.firestore.DocumentSnapshot,
  after: admin.firestore.DocumentSnapshot,
): Promise<Set<string>> {
  const out = new Set<string>();
  const suggested = (after.exists ? after.data()! : before.exists ? before.data()! : {})?.autoSchedule as
    | { suggestedVehicleId?: string }
    | undefined;
  if (suggested?.suggestedVehicleId) {
    out.add(suggested.suggestedVehicleId);
  }
  const tripsSnap = await db
    .collection(SCHEDULE_TRIPS_COLLECTION)
    .where('orderId', '==', orderId)
    .get();
  for (const doc of tripsSnap.docs) {
    const v = doc.data().vehicleId as string;
    if (v) out.add(v);
  }
  return out;
}

/**
 * onWrite PENDING_ORDERS: enqueue EDD recalc for affected vehicles (debounced 60s).
 */
export const onOrderWriteEddRecalc = onDocumentWritten(
  {
    document: `${PENDING_ORDERS_COLLECTION}/{orderId}`,
    ...LIGHT_TRIGGER_OPTS,
  },
  async (event) => {
    const change = event.data;
    if (!change) return;
    const before = change.before;
    const after = change.after;
    const orderId = event.params.orderId;

    if (!orderRelevantChange(before, after)) {
      return;
    }

    const snapshot = after.exists ? after : before;
    if (!snapshot.exists) return;
    const data = snapshot.data()!;
    const organizationId = data.organizationId as string | undefined;
    if (!organizationId) {
      return;
    }

    const vehicleIds = await getAffectedVehicleIds(orderId, organizationId, before, after);
    if (vehicleIds.size === 0) {
      return;
    }

    const scheduledAt = new Date(Date.now() + DEBOUNCE_SECONDS * 1000);
    const orgRef = db.collection(ORGANIZATIONS_COLLECTION).doc(organizationId);
    const queueRef = orgRef.collection(EDD_RECALC_QUEUE);

    await Promise.all(
      Array.from(vehicleIds).map((vehicleId) =>
        queueRef.doc(vehicleId).set({
          scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
          organizationId,
          vehicleId,
          enqueuedAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      ),
    );

    console.log('[EDD Trigger] Enqueued recalc', {
      orderId,
      organizationId,
      vehicleIds: Array.from(vehicleIds),
      scheduledAt: scheduledAt.toISOString(),
    });
  },
);

/**
 * Scheduled processor for EDD_RECALC_QUEUE. Runs every 2 minutes, processes due items.
 */
export const processEddRecalcQueueScheduled = onSchedule(
  {
    schedule: '*/2 * * * *',
    timeZone: 'UTC',
    ...SCHEDULED_FUNCTION_OPTS,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const orgsSnap = await db.collection(ORGANIZATIONS_COLLECTION).get();

    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      const queueRef = db
        .collection(ORGANIZATIONS_COLLECTION)
        .doc(orgId)
        .collection(EDD_RECALC_QUEUE);
      const dueSnap = await queueRef.where('scheduledAt', '<=', now).get();

      for (const doc of dueSnap.docs) {
        const d = doc.data();
        const vehicleId = doc.id;
        const organizationId = (d.organizationId as string) || orgId;
        try {
          await recalculateVehicleQueue(vehicleId, organizationId);
        } catch (e) {
          console.error('[EDD Queue] Recalc failed', { vehicleId, organizationId, error: e });
        }
        await doc.ref.delete();
      }
    }
  },
);
