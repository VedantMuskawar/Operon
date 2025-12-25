"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.cancelDM = exports.generateDM = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const admin = __importStar(require("firebase-admin"));
const financial_year_1 = require("../shared/financial-year");
const constants_1 = require("../shared/constants");
const db = (0, firestore_1.getFirestore)();
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
exports.generateDM = (0, https_1.onCall)(async (request) => {
    var _a, _b;
    const { organizationId, tripId, scheduleTripId, tripData, generatedBy } = request.data;
    if (!organizationId || !tripId || !scheduleTripId || !tripData || !generatedBy) {
        throw new Error('Missing required parameters');
    }
    try {
        // Check if DM number already exists for this trip
        const tripDoc = await db.collection(SCHEDULE_TRIPS_COLLECTION).doc(tripId).get();
        if (tripDoc.exists) {
            const tripData = tripDoc.data();
            if (tripData === null || tripData === void 0 ? void 0 : tripData.dmNumber) {
                return {
                    success: false,
                    error: 'DM already exists for this trip',
                    dmId: tripData.dmId || `DM/${(0, financial_year_1.getFinancialContext)(((_a = tripData.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate()) || new Date()).fyLabel}/${tripData.dmNumber}`,
                    dmNumber: tripData.dmNumber,
                };
            }
        }
        // Get financial year from scheduled date
        const scheduledDate = tripData.scheduledDate.toDate();
        const fyContext = (0, financial_year_1.getFinancialContext)(scheduledDate);
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
            let currentDMNumber;
            if (fyDoc.exists) {
                const fyData = fyDoc.data();
                currentDMNumber = fyData.currentDMNumber || 0;
            }
            else {
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
            return { dmId, dmNumber: newDMNumber, financialYear, tripData };
        });
        // After DM is generated, create credit transaction if payment type requires it
        const paymentType = ((_b = tripData.paymentType) === null || _b === void 0 ? void 0 : _b.toLowerCase()) || '';
        if (paymentType === 'pay_later' || paymentType === 'pay_on_delivery') {
            const tripPricing = tripData.tripPricing || {};
            const tripTotal = tripPricing.total || 0;
            if (tripTotal > 0) {
                try {
                    // Create credit transaction with DM number
                    const transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc();
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
                }
                catch (txnError) {
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
    }
    catch (error) {
        console.error('[DM Generation] Error:', error);
        throw new Error(`Failed to generate DM: ${error}`);
    }
});
/**
 * Cancel DM (mark as CANCELLED, remove dmNumber from trip)
 * Called from Flutter when user clicks "Cancel DM"
 */
exports.cancelDM = (0, https_1.onCall)(async (request) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s;
    const { tripId, dmId, cancelledBy, cancellationReason } = request.data;
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
        }
        else {
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
            const dmNumber = tripData.dmNumber;
            if (!dmNumber) {
                throw new Error('No dmNumber on trip to create cancelled DM snapshot');
            }
            const scheduledDate = ((_a = tripData.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate)
                ? tripData.scheduledDate.toDate()
                : new Date();
            const financialYear = (0, financial_year_1.getFinancialContext)(scheduledDate).fyLabel;
            const dmIdToUse = tripData.dmId || `DM/${financialYear}/${dmNumber}`;
            // Build delivery memo snapshot from trip data
            const deliveryMemoData = {
                dmNumber,
                dmId: dmIdToUse,
                scheduleTripId: tripData.scheduleTripId || tripId,
                tripId,
                financialYear,
                organizationId: tripData.organizationId || '',
                orderId: tripData.orderId || '',
                clientId: tripData.clientId || '',
                clientName: tripData.clientName || '',
                customerNumber: tripData.customerNumber || '',
                scheduledDate: tripData.scheduledDate || admin.firestore.FieldValue.serverTimestamp(),
                scheduledDay: tripData.scheduledDay || '',
                vehicleId: tripData.vehicleId || '',
                vehicleNumber: tripData.vehicleNumber || '',
                slot: tripData.slot || 0,
                slotName: tripData.slotName || '',
                driverId: (_b = tripData.driverId) !== null && _b !== void 0 ? _b : null,
                driverName: (_c = tripData.driverName) !== null && _c !== void 0 ? _c : null,
                driverPhone: (_d = tripData.driverPhone) !== null && _d !== void 0 ? _d : null,
                deliveryZone: tripData.deliveryZone || {},
                items: tripData.items || [],
                pricing: tripData.pricing || {},
                tripPricing: tripData.tripPricing || null,
                priority: tripData.priority || 'normal',
                paymentType: tripData.paymentType || '',
                orderStatus: tripData.orderStatus || 'pending',
                tripStatus: tripData.tripStatus || 'pending',
                status: 'cancelled',
                initialReading: (_e = tripData.initialReading) !== null && _e !== void 0 ? _e : null,
                finalReading: (_f = tripData.finalReading) !== null && _f !== void 0 ? _f : null,
                distanceTravelled: (_g = tripData.distanceTravelled) !== null && _g !== void 0 ? _g : null,
                deliveryPhotoUrl: (_h = tripData.deliveryPhotoUrl) !== null && _h !== void 0 ? _h : null,
                dispatchedAt: (_j = tripData.dispatchedAt) !== null && _j !== void 0 ? _j : null,
                dispatchedBy: (_k = tripData.dispatchedBy) !== null && _k !== void 0 ? _k : null,
                dispatchedByRole: (_l = tripData.dispatchedByRole) !== null && _l !== void 0 ? _l : null,
                deliveredAt: (_m = tripData.deliveredAt) !== null && _m !== void 0 ? _m : null,
                deliveredBy: (_o = tripData.deliveredBy) !== null && _o !== void 0 ? _o : null,
                deliveredByRole: (_p = tripData.deliveredByRole) !== null && _p !== void 0 ? _p : null,
                returnedAt: (_q = tripData.returnedAt) !== null && _q !== void 0 ? _q : null,
                returnedBy: (_r = tripData.returnedBy) !== null && _r !== void 0 ? _r : null,
                returnedByRole: (_s = tripData.returnedByRole) !== null && _s !== void 0 ? _s : null,
                paymentDetails: tripData.paymentDetails || [],
                totalPaidOnReturn: tripData.totalPaidOnReturn || 0,
                paymentStatus: tripData.paymentStatus || 'pending',
                remainingAmount: tripData.remainingAmount || null,
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
        }
        else {
            const dmDoc = dmQuery.docs[0];
            const dmData = dmDoc.data();
            // Update items to mark as CANCELLED
            const items = dmData.items || [];
            const updatedItems = items.map((item) => {
                if (typeof item === 'object' && item !== null) {
                    return Object.assign(Object.assign({}, item), { productName: 'CANCELLED', fixedQuantityPerTrip: 0 });
                }
                return item;
            });
            // Use transaction for atomicity
            await db.runTransaction(async (transaction) => {
                // Update DELIVERY_MEMOS
                const dmRef = dmDoc.ref;
                const updateData = {
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
    }
    catch (error) {
        console.error('[DM Cancellation] Error:', error);
        throw new Error(`Failed to cancel DM: ${error}`);
    }
});
//# sourceMappingURL=delivery-memo.js.map