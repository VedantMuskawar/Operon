import { onSchedule } from 'firebase-functions/v2/scheduler';
import { PENDING_ORDERS_COLLECTION } from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { SCHEDULED_FUNCTION_OPTS } from '../shared/function-config';

const db = getFirestore();

const BATCH_SIZE = 500; // Firestore batch limit

/**
 * Weekly cleanup: delete PENDING_ORDERS that are fully_scheduled.
 * Runs every Sunday at 03:00 UTC.
 * Deleting the order document triggers onOrderDeleted (transactions, trip marking).
 */
export const deleteFullyScheduledOrdersWeekly = onSchedule(
  {
    schedule: '0 3 * * 0',
    timeZone: 'UTC',
    ...SCHEDULED_FUNCTION_OPTS,
  },
  async () => {
    console.log('[Cleanup] Starting weekly delete of fully_scheduled orders');

    let totalDeleted = 0;
    let hasMore = true;

    while (hasMore) {
      const snapshot = await db
        .collection(PENDING_ORDERS_COLLECTION)
        .where('status', '==', 'fully_scheduled')
        .limit(BATCH_SIZE)
        .get();

      if (snapshot.empty) {
        hasMore = false;
        break;
      }

      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      totalDeleted += snapshot.docs.length;

      console.log('[Cleanup] Deleted batch of fully_scheduled orders', {
        batchSize: snapshot.docs.length,
        totalDeletedSoFar: totalDeleted,
      });

      if (snapshot.docs.length < BATCH_SIZE) {
        hasMore = false;
      }
    }

    console.log('[Cleanup] Weekly delete of fully_scheduled orders completed', {
      totalDeleted,
    });
  },
);
