import {onCall} from 'firebase-functions/v2/https';
import {getFirestore} from 'firebase-admin/firestore';
import * as admin from 'firebase-admin';
import {getFinancialContext} from '../shared/financial-year';
import {TRANSACTIONS_COLLECTION} from '../shared/constants';

const db = getFirestore();

const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
const ORGANIZATIONS_COLLECTION = 'ORGANIZATIONS';

/**
 * Generate DM for a scheduled trip
 * Called from Flutter when user clicks "Generate DM"
 * 
 * Flow:
 * 1. Check if DM already exists for scheduleTripId
 * 2. Get/calculate current FY
 * 3. Get or create FY document in ORGANIZATIONS/{orgId}/DM/{FYXXYY}
 * 4. Increment currentDMNumber
 * 5. Create DELIVERY_MEMOS document
 * 6. Update SCHEDULE_TRIPS with dmNumber
 * 7. Update FY document with new currentDMNumber
 */
export const generateDM = onCall(async (request) => {
  const {organizationId, tripId, scheduleTripId, tripData, generatedBy} = request.data;

  if (!organizationId || !tripId || !scheduleTripId || !tripData || !generatedBy) {
    throw new Error('Missing required parameters');
  }

  try {
    // Check if DM number already exists for this trip
    const tripDoc = await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId).get();
    if (tripDoc.exists) {
      const tripData = tripDoc.data();
      if (tripData?.dmNumber) {
        return {
          success: false,
          error: 'DM already exists for this trip',
          dmId: tripData.dmId || `DM/${getFinancialContext(tripData.scheduledDate?.toDate() || new Date()).fyLabel}/${tripData.dmNumber}`,
          dmNumber: tripData.dmNumber,
        };
      }
    }

    // Get financial year from scheduled date
    const scheduledDate = tripData.scheduledDate.toDate();
    const fyContext = getFinancialContext(scheduledDate);
    const financialYear = fyContext.fyLabel; // e.g., "FY2425"

    // Use transaction for atomicity
    const result = await db.runTransaction(async (transaction) => {
      // Get or create FY document
      const fyRef = db
          .collection(ORGANIZATIONS_COLLECTION)
          .doc(organizationId)
          .collection('DM')
          .doc(financialYear);

      const fyDoc = await transaction.get(fyRef);

      let currentDMNumber: number;

      if (fyDoc.exists) {
        const fyData = fyDoc.data()!;
        currentDMNumber = (fyData.currentDMNumber as number) || 0;
      } else {
        // Auto-create FY document
        currentDMNumber = 0;

        const fyStart = new Date(fyContext.fyStart);
        const fyEnd = new Date(fyContext.fyEnd);

        transaction.set(fyRef, {
          startDMNumber: 1,
          currentDMNumber: 0,
          previousFYStartDMNumber: null,
          previousFYEndDMNumber: null,
          financialYear: financialYear,
          startDate: fyStart,
          endDate: fyEnd,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }

      // Generate new DM number
      const newDMNumber = currentDMNumber + 1;
      const dmId = `DM/${financialYear}/${newDMNumber}`;

      // DO NOT create DELIVERY_MEMOS document here
      // DM document will be created only when trip is returned (via onTripReturnedCreateDM)

      // Update SCHEDULE_TRIPS with dmNumber
      const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId);
      transaction.update(tripRef, {
        dmNumber: newDMNumber,
        dmId: dmId,
        updatedAt: new Date(),
      });

      // Update FY document with new currentDMNumber
      transaction.update(fyRef, {
        currentDMNumber: newDMNumber,
        updatedAt: new Date(),
      });

      return {dmId, dmNumber: newDMNumber, financialYear, tripData};
    });

    // After DM is generated, create credit transaction if payment type requires it
    const paymentType = (tripData.paymentType as string)?.toLowerCase() || '';
    if (paymentType === 'pay_later' || paymentType === 'pay_on_delivery') {
      const tripPricing = (tripData.tripPricing as any) || {};
      const tripTotal = (tripPricing.total as number) || 0;
      
      if (tripTotal > 0) {
        try {
          // Create credit transaction with DM number
          const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
          const transactionData = {
            organizationId,
            clientId: tripData.clientId || '',
            type: 'credit',
            category: 'income',
            amount: tripTotal,
            status: 'completed',
            orderId: tripData.orderId || '',
            description: `Credit - DM-${result.dmNumber}${paymentType === 'pay_later' ? ' (Pay Later)' : ' (Pay on Delivery)'}`,
            metadata: {
              tripId,
              dmNumber: result.dmNumber,
              paymentType,
              scheduledDate: tripData.scheduledDate,
              tripTotal,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            createdBy: generatedBy,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            financialYear: result.financialYear,
          };

          await transactionRef.set(transactionData);

          // Store transaction ID in trip document for reference
          await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId).update({
            creditTransactionId: transactionRef.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log('[DM Generation] Credit transaction created', {
            tripId,
            transactionId: transactionRef.id,
            dmNumber: result.dmNumber,
            amount: tripTotal,
            paymentType,
          });
        } catch (txnError) {
          console.error('[DM Generation] Error creating credit transaction', {
            tripId,
            error: txnError,
          });
          // Don't throw - transaction creation failure shouldn't prevent DM generation
        }
      }
    }

    return {
      success: true,
      dmId: result.dmId,
      dmNumber: result.dmNumber,
      financialYear: result.financialYear,
    };
  } catch (error) {
    console.error('[DM Generation] Error:', error);
    throw new Error(`Failed to generate DM: ${error}`);
  }
});

/**
 * Cancel DM (mark as CANCELLED, remove dmNumber from trip)
 * Called from Flutter when user clicks "Cancel DM"
 */
export const cancelDM = onCall(async (request) => {
  const {tripId, dmId, cancelledBy, cancellationReason} = request.data;

  if (!tripId || !cancelledBy) {
    throw new Error('Missing required parameters: tripId and cancelledBy');
  }

  try {
    // Find DELIVERY_MEMOS document
    let dmQuery;
    
    if (dmId) {
      // Find by dmId (more specific)
      dmQuery = await db
          .collection(DELIVERY_MEMOS_COLLECTION)
          .where('dmId', '==', dmId)
          .where('tripId', '==', tripId)
          .limit(1)
          .get();
    } else {
      // Fallback to tripId
      dmQuery = await db
          .collection(DELIVERY_MEMOS_COLLECTION)
          .where('tripId', '==', tripId)
          .where('status', '==', 'active')
          .limit(1)
          .get();
    }

    if (dmQuery.empty) {
      // No DM doc yet (typical for dispatch DM); create a cancelled DM snapshot
      const tripSnap = await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId).get();
      if (!tripSnap.exists) {
        throw new Error('Trip not found to create cancelled DM snapshot');
      }
      const tripData = tripSnap.data() || {};
      const dmNumber = tripData.dmNumber as number | undefined;
      if (!dmNumber) {
        throw new Error('No dmNumber on trip to create cancelled DM snapshot');
      }
      const scheduledDate = tripData.scheduledDate?.toDate
        ? tripData.scheduledDate.toDate()
        : new Date();
      const financialYear = getFinancialContext(scheduledDate).fyLabel;
      const dmIdToUse =
        (tripData.dmId as string | undefined) || `DM/${financialYear}/${dmNumber}`;

      // Build delivery memo snapshot from trip data
      const deliveryMemoData = {
        dmNumber,
        dmId: dmIdToUse,
        scheduleTripId: (tripData as any).scheduleTripId || tripId,
        tripId,
        financialYear,
        organizationId: (tripData as any).organizationId || '',
        orderId: (tripData as any).orderId || '',
        clientId: (tripData as any).clientId || '',
        clientName: (tripData as any).clientName || '',
        customerNumber: (tripData as any).customerNumber || '',
        scheduledDate: tripData.scheduledDate || admin.firestore.FieldValue.serverTimestamp(),
        scheduledDay: (tripData as any).scheduledDay || '',
        vehicleId: (tripData as any).vehicleId || '',
        vehicleNumber: (tripData as any).vehicleNumber || '',
        slot: (tripData as any).slot || 0,
        slotName: (tripData as any).slotName || '',
        driverId: (tripData as any).driverId ?? null,
        driverName: (tripData as any).driverName ?? null,
        driverPhone: (tripData as any).driverPhone ?? null,
        deliveryZone: (tripData as any).deliveryZone || {},
        items: (tripData as any).items || [],
        pricing: (tripData as any).pricing || {},
        tripPricing: (tripData as any).tripPricing || null,
        priority: (tripData as any).priority || 'normal',
        paymentType: (tripData as any).paymentType || '',
        orderStatus: (tripData as any).orderStatus || 'pending',
        tripStatus: (tripData as any).tripStatus || 'pending',
        status: 'cancelled',
        initialReading: (tripData as any).initialReading ?? null,
        finalReading: (tripData as any).finalReading ?? null,
        distanceTravelled: (tripData as any).distanceTravelled ?? null,
        deliveryPhotoUrl: (tripData as any).deliveryPhotoUrl ?? null,
        dispatchedAt: (tripData as any).dispatchedAt ?? null,
        dispatchedBy: (tripData as any).dispatchedBy ?? null,
        dispatchedByRole: (tripData as any).dispatchedByRole ?? null,
        deliveredAt: (tripData as any).deliveredAt ?? null,
        deliveredBy: (tripData as any).deliveredBy ?? null,
        deliveredByRole: (tripData as any).deliveredByRole ?? null,
        returnedAt: (tripData as any).returnedAt ?? null,
        returnedBy: (tripData as any).returnedBy ?? null,
        returnedByRole: (tripData as any).returnedByRole ?? null,
        paymentDetails: (tripData as any).paymentDetails || [],
        totalPaidOnReturn: (tripData as any).totalPaidOnReturn || 0,
        paymentStatus: (tripData as any).paymentStatus || 'pending',
        remainingAmount: (tripData as any).remainingAmount || null,
        generatedAt: new Date(),
        createdBy: cancelledBy,
        updatedAt: new Date(),
        cancelledAt: new Date(),
        cancelledBy,
        cancellationReason: cancellationReason || 'Cancelled before dispatch',
        source: 'cancel_dm',
      };

      await db.runTransaction(async (transaction) => {
        const dmRef = db.collection(DELIVERY_MEMOS_COLLECTION).doc();
        transaction.set(dmRef, deliveryMemoData);

        // Remove dmNumber from SCHEDULE_TRIPS
        const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId);
        transaction.update(tripRef, {
          dmNumber: null,
          dmId: null,
          updatedAt: new Date(),
        });
      });
    } else {
      const dmDoc = dmQuery.docs[0];
      const dmData = dmDoc.data();

      // Update items to mark as CANCELLED
      const items = (dmData.items as any[]) || [];
      const updatedItems = items.map((item: any) => {
        if (typeof item === 'object' && item !== null) {
          return {
            ...item,
            productName: 'CANCELLED',
            fixedQuantityPerTrip: 0,
          };
        }
        return item;
      });

      // Use transaction for atomicity
      await db.runTransaction(async (transaction) => {
        // Update DELIVERY_MEMOS
        const dmRef = dmDoc.ref;
        const updateData: any = {
          status: 'cancelled',
          clientName: 'CANCELLED',
          items: updatedItems,
          cancelledAt: new Date(),
          cancelledBy: cancelledBy,
          updatedAt: new Date(),
        };

        if (cancellationReason) {
          updateData.cancellationReason = cancellationReason;
        }

        transaction.update(dmRef, updateData);

        // Remove dmNumber from SCHEDULE_TRIPS
        const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId);
        transaction.update(tripRef, {
          dmNumber: null,
          dmId: null,
          updatedAt: new Date(),
        });
      });
    }

    return {
      success: true,
      message: 'DM cancelled successfully',
    };
  } catch (error) {
    console.error('[DM Cancellation] Error:', error);
    throw new Error(`Failed to cancel DM: ${error}`);
  }
});

