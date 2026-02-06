import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { getFinancialContext } from '../shared/financial-year';
import { TRANSACTIONS_COLLECTION } from '../shared/constants';
import { getFirestore } from '../shared/firestore-helpers';
import { CALLABLE_OPTS } from '../shared/function-config';

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
/** Recursively remove undefined values (Firestore does not allow undefined). */
function stripUndefined(obj: unknown): unknown {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(stripUndefined);
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
    if (v !== undefined) out[k] = stripUndefined(v);
  }
  return out;
}

export const generateDM = onCall(
  { ...CALLABLE_OPTS },
  async (request) => {
    if (!request.data || typeof request.data !== 'object') {
      throw new HttpsError('invalid-argument', 'Missing request data');
    }
    const { organizationId, tripId, scheduleTripId, tripData, generatedBy } = request.data as Record<string, unknown>;

    console.log('[DM Generation] Request received', {
      organizationId,
      tripId,
      scheduleTripId,
      hasTripData: !!tripData,
      generatedBy,
      scheduledDateType: tripData && typeof tripData === 'object' && 'scheduledDate' in tripData ? typeof (tripData as any).scheduledDate : 'missing',
    });

    if (!organizationId || !tripId || !scheduleTripId || !tripData || !generatedBy) {
      throw new HttpsError('invalid-argument', 'Missing required parameters: organizationId, tripId, scheduleTripId, tripData, or generatedBy');
    }

  try {
    // Check if DM number already exists for this trip
    const tripDoc = await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId as string).get();
    if (tripDoc.exists) {
      const existingTripData = tripDoc.data();
      if (existingTripData?.dmNumber) {
        console.log('[DM Generation] DM already exists for trip', {tripId, dmNumber: existingTripData.dmNumber});
        return {
          success: false,
          error: 'DM already exists for this trip',
          dmId: existingTripData.dmId || `DM/${getFinancialContext(existingTripData.scheduledDate?.toDate() || new Date()).fyLabel}/${existingTripData.dmNumber}`,
          dmNumber: existingTripData.dmNumber,
        };
      }
    }

    // Get financial year from scheduled date
    // Handle serialized Timestamp format from client (map with _seconds and _nanoseconds)
    const tripDataAny = tripData as any;
    let scheduledDate: Date;
    if (tripDataAny.scheduledDate && typeof tripDataAny.scheduledDate === 'object' && '_seconds' in tripDataAny.scheduledDate) {
      const sec = tripDataAny.scheduledDate._seconds;
      if (typeof sec !== 'number' || !Number.isFinite(sec)) {
        throw new HttpsError('invalid-argument', 'Invalid scheduledDate: _seconds must be a finite number');
      }
      scheduledDate = new Date(sec * 1000);
      console.log('[DM Generation] Deserialized scheduledDate from client format', { scheduledDate: scheduledDate.toISOString() });
    } else if (tripDataAny.scheduledDate && typeof tripDataAny.scheduledDate?.toDate === 'function') {
      scheduledDate = tripDataAny.scheduledDate.toDate();
      console.log('[DM Generation] Used Firestore Timestamp toDate()', {scheduledDate: scheduledDate.toISOString()});
    } else {
      throw new HttpsError(
        'invalid-argument',
        `Invalid scheduledDate format. Expected Timestamp with _seconds or toDate(). Got: ${typeof tripDataAny.scheduledDate}`,
      );
    }
    if (Number.isNaN(scheduledDate.getTime())) {
      throw new HttpsError('invalid-argument', 'Invalid scheduledDate: date is not valid');
    }
    const fyContext = getFinancialContext(scheduledDate);
    const financialYear = fyContext.fyLabel; // e.g., "FY2425"

    // Use transaction for atomicity
    const result = await db.runTransaction(async (transaction) => {
      const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId as string);
      const tripDoc = await transaction.get(tripRef);
      if (!tripDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Trip not found. It may have been deleted or the trip ID is incorrect.',
        );
      }
      if (tripDoc.data()?.dmNumber != null) {
        throw new HttpsError(
          'already-exists',
          'DM already exists for this trip',
        );
      }

      // Get or create FY document
      const fyRef = db
          .collection(ORGANIZATIONS_COLLECTION)
          .doc(organizationId as string)
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
          startDate: admin.firestore.Timestamp.fromDate(fyStart),
          endDate: admin.firestore.Timestamp.fromDate(fyEnd),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Generate new DM number
      const newDMNumber = currentDMNumber + 1;
      const dmId = `DM/${financialYear}/${newDMNumber}`;

      // Get itemIndex and productId from trip data (required for multi-product support)
      const itemIndex = (tripDataAny.itemIndex as number) ?? 0;
      const productId = (tripDataAny.productId as string) || null;

      // Extract tripPricing and conditionally include GST fields
      const tripPricingData = tripDataAny.tripPricing || {};
      const tripPricing: any = {
        subtotal: tripPricingData.subtotal || 0,
        total: tripPricingData.total || 0,
      };
      
      // Only include gstAmount if it exists and is > 0
      if (tripPricingData.gstAmount !== undefined && tripPricingData.gstAmount > 0) {
        tripPricing.gstAmount = tripPricingData.gstAmount;
      }
      
      // Include advanceAmountDeducted if present
      if (tripPricingData.advanceAmountDeducted !== undefined) {
        tripPricing.advanceAmountDeducted = tripPricingData.advanceAmountDeducted;
      }

      // Create DELIVERY_MEMOS document with all scheduled trip data (use Firestore Timestamp for dates)
      const deliveryMemoData: any = {
        dmId,
        dmNumber: newDMNumber,
        tripId,
        scheduleTripId: scheduleTripId,
        financialYear,
        organizationId,
        orderId: tripDataAny.orderId || '',
        itemIndex,
        productId: productId || '',

        clientId: tripDataAny.clientId || '',
        clientName: tripDataAny.clientName || '',
        customerNumber: tripDataAny.clientPhone || tripDataAny.customerNumber || '',

        scheduledDate: admin.firestore.Timestamp.fromDate(scheduledDate),
        scheduledDay: tripDataAny.scheduledDay || '',
        vehicleId: tripDataAny.vehicleId || '',
        vehicleNumber: tripDataAny.vehicleNumber || '',
        slot: tripDataAny.slot || 0,
        slotName: tripDataAny.slotName || '',

        driverId: tripDataAny.driverId || null,
        driverName: tripDataAny.driverName || null,
        driverPhone: tripDataAny.driverPhone || null,

        deliveryZone: stripUndefined(tripDataAny.deliveryZone || {}) as Record<string, unknown>,

        items: (tripDataAny.items || []).map((item: unknown) => stripUndefined(item)),
        tripPricing,
        priority: tripDataAny.priority || 'normal',
        paymentType: tripDataAny.paymentType || '',

        tripStatus: 'scheduled',
        orderStatus: tripDataAny.orderStatus || 'pending',
        status: 'active', // DM status: active, cancelled, returned

        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy,
        source: 'dm_generation',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const dmRef = db.collection(DELIVERY_MEMOS_COLLECTION).doc();
      transaction.set(dmRef, deliveryMemoData);

      transaction.update(tripRef, {
        dmNumber: newDMNumber,
        dmId: dmId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update FY document with new currentDMNumber
      transaction.update(fyRef, {
        currentDMNumber: newDMNumber,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { dmId, dmNumber: newDMNumber, financialYear, tripData: tripDataAny, dmDocumentId: dmRef.id };
    });

    // After DM is generated, create credit transaction if payment type requires it
    const paymentType = (tripDataAny.paymentType as string)?.toLowerCase() || '';
    if (paymentType === 'pay_later' || paymentType === 'pay_on_delivery') {
      const tripPricing = (tripDataAny.tripPricing as any) || {};
      const tripTotal = (tripPricing.total as number) || 0;
      
      if (tripTotal > 0) {
        try {
          // Create credit transaction with DM number
          const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
          const transactionId = transactionRef.id;
          const transactionData = {
            transactionId, // Include transactionId field for consistency
            organizationId,
            clientId: tripDataAny.clientId || '',
            ledgerType: 'clientLedger',
            type: 'credit', // Credit = client owes us (increases receivable)
            category: 'clientCredit', // Client owes (PayLater order)
            amount: tripTotal,
            tripId, // Schedule Trip document ID
            description: `Order Credit - DM-${result.dmNumber} (${paymentType === 'pay_later' ? 'Pay Later' : 'Pay on Delivery'})`,
            metadata: {
              tripId,
              dmNumber: result.dmNumber,
              paymentType,
              scheduledDate: scheduledDate, // Use the deserialized Date object
              tripTotal,
            },
            createdBy: generatedBy,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            financialYear: result.financialYear,
          };

          await transactionRef.set(transactionData);

          // Store transaction ID in trip document for reference
          await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId as string).update({
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
    const message = error instanceof Error ? error.message : 'Failed to generate DM';
    const stack = error instanceof Error ? error.stack : undefined;
    console.error('[DM Generation] Error:', message, stack);
    if (error instanceof HttpsError) throw error;
    // Surface a clear message so client doesn't only see "internal"
    throw new HttpsError(
      'internal',
      `Failed to generate DM: ${message}`,
    );
  }
});

/**
 * Cancel DM (mark as CANCELLED, remove dmNumber from trip)
 * Called from Flutter when user clicks "Cancel DM"
 */
export const cancelDM = onCall(
  { ...CALLABLE_OPTS },
  async (request) => {
    const { tripId, dmId, cancelledBy, cancellationReason } = request.data as Record<string, unknown>;

    if (!tripId || !cancelledBy) {
      throw new HttpsError('invalid-argument', 'Missing required parameters: tripId and cancelledBy');
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
      throw new HttpsError(
        'not-found',
        'DM document not found. DM must be generated before it can be cancelled.',
      );
    }

    // Update existing DM document status to 'cancelled'
    const dmDoc = dmQuery.docs[0];

    // Get trip document to retrieve creditTransactionId before updating
    const tripRef = db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId as string);
    const tripDoc = await tripRef.get();
    const tripData = tripDoc.exists ? tripDoc.data() : null;
    const creditTransactionId = tripData?.creditTransactionId as string | undefined;

    // Update DM document status to 'cancelled'
    await dmDoc.ref.update({
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy,
      cancellationReason: cancellationReason || 'DM cancelled',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Remove dmNumber and creditTransactionId from SCHEDULE_TRIPS
    await tripRef.update({
      dmNumber: null,
      dmId: null,
      creditTransactionId: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Delete the credit transaction if it exists
    // This will trigger onTransactionDeleted Cloud Function to reverse the ledger and analytics
    let transactionDeleted = false;
    if (creditTransactionId) {
      try {
        const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc(creditTransactionId);
        const transactionDoc = await transactionRef.get();
        
        if (transactionDoc.exists) {
          await transactionRef.delete();
          transactionDeleted = true;
          console.log('[DM Cancellation] Credit transaction deleted', {
            tripId,
            dmId,
            transactionId: creditTransactionId,
          });
        } else {
          console.warn('[DM Cancellation] Credit transaction not found (may have been already deleted)', {
            tripId,
            dmId,
            transactionId: creditTransactionId,
          });
        }
      } catch (txnError) {
        console.error('[DM Cancellation] Error deleting credit transaction', {
          tripId,
          dmId,
          transactionId: creditTransactionId,
          error: txnError,
        });
        // Don't throw - transaction deletion failure shouldn't prevent DM cancellation
      }
    }

    // Fallback: if trip had no creditTransactionId (e.g. DM generation's trip update failed),
    // find and delete the credit transaction by tripId + type/category
    if (!transactionDeleted) {
      try {
        const creditTxns = await db
          .collection(TRANSACTIONS_COLLECTION)
          .where('tripId', '==', tripId)
          .where('type', '==', 'credit')
          .where('category', '==', 'clientCredit')
          .limit(1)
          .get();
        if (!creditTxns.empty) {
          const txnDoc = creditTxns.docs[0];
          await txnDoc.ref.delete();
          transactionDeleted = true;
          console.log('[DM Cancellation] Credit transaction deleted (found by tripId)', {
            tripId,
            dmId,
            transactionId: txnDoc.id,
          });
        }
      } catch (fallbackError) {
        console.error('[DM Cancellation] Error in fallback credit transaction lookup/delete', {
          tripId,
          dmId,
          error: fallbackError,
        });
      }
    }

    if (!transactionDeleted) {
      console.log('[DM Cancellation] No credit transaction to delete (payment type may not have required it)', {
        tripId,
        dmId,
      });
    }

    return {
      success: true,
      message: 'DM cancelled successfully',
    };
  } catch (error) {
    console.error('[DM Cancellation] Error:', error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      'internal',
      error instanceof Error ? error.message : 'Failed to cancel DM',
    );
  }
  });

