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
exports.onTripReturnedCreateDM = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-admin/firestore");
const financial_year_1 = require("../shared/financial-year");
const db = (0, firestore_1.getFirestore)();
const DELIVERY_MEMOS_COLLECTION = 'DELIVERY_MEMOS';
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
const ORGANIZATIONS_COLLECTION = 'ORGANIZATIONS';
/**
 * On trip status change to "returned", create a Delivery Memo snapshot if one does not exist.
 * Guard: if dmId/dmNumber already present on the trip, skip.
 */
exports.onTripReturnedCreateDM = functions.firestore
    .document(`${SCHEDULE_TRIPS_COLLECTION}/{tripId}`)
    .onUpdate(async (change, context) => {
    var _a, _b;
    const before = change.before.data();
    const after = change.after.data();
    const tripId = context.params.tripId;
    if (!before || !after)
        return;
    // Only act on status change to returned
    if ((before.tripStatus || before.orderStatus) === 'returned')
        return;
    const afterStatus = (after.tripStatus || after.orderStatus || '').toLowerCase();
    if (afterStatus !== 'returned')
        return;
    // Check if a return DM was already created by this function
    // We want to create a new DM for returns, even if a dispatch DM exists
    // Only skip if this specific return DM was already created (check dmSource)
    if (after.dmSource === 'trip_return_trigger') {
        console.log('[Trip Return DM] Return DM already exists, skipping', { tripId, dmId: after.dmId, dmNumber: after.dmNumber });
        return;
    }
    const organizationId = after.organizationId;
    if (!organizationId) {
        console.warn('[Trip Return DM] Missing organizationId, skipping', { tripId });
        return;
    }
    // Choose a date for FY: prefer scheduledDate, fallback to returnedAt, else now
    let dateForFy = new Date();
    try {
        if ((_a = after.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate) {
            dateForFy = after.scheduledDate.toDate();
        }
        else if ((_b = after.returnedAt) === null || _b === void 0 ? void 0 : _b.toDate) {
            dateForFy = after.returnedAt.toDate();
        }
    }
    catch (_) {
        // keep default
    }
    const fyContext = (0, financial_year_1.getFinancialContext)(dateForFy);
    const financialYear = fyContext.fyLabel;
    // Run transaction: reserve DM number, create DM doc, stamp trip
    await db.runTransaction(async (transaction) => {
        var _a, _b, _c, _d, _e, _f;
        const fyRef = db
            .collection(ORGANIZATIONS_COLLECTION)
            .doc(organizationId)
            .collection('DM')
            .doc(financialYear);
        const fyDoc = await transaction.get(fyRef);
        let currentDMNumber = 0;
        if (fyDoc.exists) {
            currentDMNumber = ((_a = fyDoc.data()) === null || _a === void 0 ? void 0 : _a.currentDMNumber) || 0;
        }
        else {
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
            totalPaidOnReturn: (_b = after.totalPaidOnReturn) !== null && _b !== void 0 ? _b : null,
            remainingAmount: (_c = after.remainingAmount) !== null && _c !== void 0 ? _c : null,
            tripStatus: after.tripStatus || 'returned',
            orderStatus: after.orderStatus || '',
            status: 'returned', // Set status to 'returned' to distinguish from dispatch DMs
            meters: {
                initialReading: (_d = after.initialReading) !== null && _d !== void 0 ? _d : null,
                finalReading: (_e = after.finalReading) !== null && _e !== void 0 ? _e : null,
                distanceTravelled: (_f = after.distanceTravelled) !== null && _f !== void 0 ? _f : null,
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
        const updateData = {
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
    console.log('[Trip Return DM] DM created on return', { tripId });
});
//# sourceMappingURL=trip-return-dm.js.map