import * as functions from 'firebase-functions';
import {getFirestore} from 'firebase-admin/firestore';
import {getFinancialContext} from '../shared/financial-year';

const db = getFirestore();

const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
const ORGANIZATIONS_COLLECTION = 'ORGANIZATIONS';

/**
 * On trip status change to "returned", create a Delivery Memo snapshot if one does not exist.
 * Guard: if dmId/dmNumber already present on the trip, skip.
 */
export const onTripReturnedCreateDM = functions.firestore
  .document(`${SCHEDULE_TRIPS_COLLECTION}/{tripId}`)
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const tripId = context.params.tripId as string;

    if (!before || !after) return;

    // Only act on status change to returned
    if ((before.tripStatus || before.orderStatus) === 'returned') return;
    const afterStatus = (after.tripStatus || after.orderStatus || '').toLowerCase();
    if (afterStatus !== 'returned') return;

    // Check if a return DM was already created by this function
    // We want to create a new DM for returns, even if a dispatch DM exists
    // Only skip if this specific return DM was already created (check dmSource)
    if (after.dmSource === 'trip_return_trigger') {
      console.log('[Trip Return DM] Return DM already exists, skipping', {tripId, dmId: after.dmId, dmNumber: after.dmNumber});
      return;
    }

    const organizationId = after.organizationId as string | undefined;
    if (!organizationId) {
      console.warn('[Trip Return DM] Missing organizationId, skipping', {tripId});
      return;
    }

    // Choose a date for FY: prefer scheduledDate, fallback to returnedAt, else now
    let dateForFy: Date = new Date();
    try {
      if (after.scheduledDate?.toDate) {
        dateForFy = after.scheduledDate.toDate();
      } else if (after.returnedAt?.toDate) {
        dateForFy = after.returnedAt.toDate();
      }
    } catch (_) {
      // keep default
    }
    const fyContext = getFinancialContext(dateForFy);
    const financialYear = fyContext.fyLabel;

    // Run transaction: reserve DM number, create DM doc, stamp trip
    await db.runTransaction(async (transaction) => {
      const fyRef = db
        .collection(ORGANIZATIONS_COLLECTION)
        .doc(organizationId)
        .collection('DM')
        .doc(financialYear);

      const fyDoc = await transaction.get(fyRef);
      let currentDMNumber = 0;
      if (fyDoc.exists) {
        currentDMNumber = (fyDoc.data()?.currentDMNumber as number) || 0;
      } else {
        const fyStart = new Date(fyContext.fyStart);
        const fyEnd = new Date(fyContext.fyEnd);
        transaction.set(fyRef, {
          startDMNumber: 1,
          currentDMNumber: 0,
          previousFYStartDMNumber: null,
          previousFYEndDMNumber: null,
          financialYear,
          startDate: fyStart,
          endDate: fyEnd,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }

      const newDMNumber = currentDMNumber + 1;
      const dmId = `DM/${financialYear}/${newDMNumber}`;

      // Build DM payload from trip snapshot
      const deliveryMemoData = {
        dmId,
        dmNumber: newDMNumber,
        tripId,
        scheduleTripId: tripId,
        financialYear,
        organizationId,
        orderId: after.orderId || '',

        clientId: after.clientId || '',
        clientName: after.clientName || '',
        customerNumber: after.clientPhone || after.customerNumber || '',

        scheduledDate: after.scheduledDate || null,
        scheduledDay: after.scheduledDay || '',
        vehicleId: after.vehicleId || '',
        vehicleNumber: after.vehicleNumber || '',
        slot: after.slot || 0,
        slotName: after.slotName || '',

        driverId: after.driverId || null,
        driverName: after.driverName || null,
        driverPhone: after.driverPhone || null,

        deliveryZone: after.deliveryZone || {},

        items: after.items || [],
        pricing: after.pricing || {},
        tripPricing: after.tripPricing || null,
        priority: after.priority || 'normal',
        paymentType: after.paymentType || '',
        paymentStatus: after.paymentStatus || '',
        paymentDetails: after.paymentDetails || [],
        totalPaidOnReturn: after.totalPaidOnReturn ?? null,
        remainingAmount: after.remainingAmount ?? null,

        tripStatus: after.tripStatus || 'returned',
        orderStatus: after.orderStatus || '',
        status: 'returned', // Set status to 'returned' to distinguish from dispatch DMs

        meters: {
          initialReading: after.initialReading ?? null,
          finalReading: after.finalReading ?? null,
          distanceTravelled: after.distanceTravelled ?? null,
        },
        returnedAt: after.returnedAt || new Date(),
        returnedBy: after.returnedBy || null,

        generatedAt: new Date(),
        generatedBy: after.returnedBy || 'system',
        source: 'trip_return_trigger',
        updatedAt: new Date(),
      };

      const dmRef = db.collection(DELIVERY_MEMOS_COLLECTION).doc();
      transaction.set(dmRef, deliveryMemoData);

      // Stamp trip with return DM references
      // If a dispatch DM exists, preserve it in dispatchDmId/dispatchDmNumber
      const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId);
      const tripDoc = await transaction.get(tripRef);
      const tripData = tripDoc.data() || {};
      const existingDmId = tripData.dmId;
      const existingDmNumber = tripData.dmNumber;
      const existingDmSource = tripData.dmSource;
      
      const updateData: any = {
        returnDmId: dmId,
        returnDmNumber: newDMNumber,
        // Update main dmId/dmNumber to point to return DM (latest)
        dmId,
        dmNumber: newDMNumber,
        dmSource: 'trip_return_trigger',
        updatedAt: new Date(),
      };
      
      // Preserve dispatch DM reference if it exists and is not from return
      if (existingDmId && existingDmSource !== 'trip_return_trigger') {
        updateData.dispatchDmId = existingDmId;
        updateData.dispatchDmNumber = existingDmNumber;
      }
      
      transaction.update(tripRef, updateData);

      // Update FY counter
      transaction.update(fyRef, {
        currentDMNumber: newDMNumber,
        updatedAt: new Date(),
      });
    });

    console.log('[Trip Return DM] DM created on return', {tripId});
  });


