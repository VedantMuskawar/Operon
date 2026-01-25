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
exports.onTripDispatchedSendWhatsapp = void 0;
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const whatsapp_service_1 = require("../shared/whatsapp-service");
const logger_1 = require("../shared/logger");
const db = (0, firestore_helpers_1.getFirestore)();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * Sends WhatsApp notification to client when a trip is dispatched
 */
async function sendTripDispatchMessage(to, clientName, organizationId, tripId, tripData) {
    var _a;
    const settings = await (0, whatsapp_service_1.loadWhatsappSettings)(organizationId);
    if (!(settings === null || settings === void 0 ? void 0 : settings.tripDispatchTemplateId)) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'sendTripDispatchMessage', 'Skipping send – no settings or disabled', {
            tripId,
            organizationId,
        });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format scheduled date for parameter 2
    let scheduledDateText = 'N/A';
    if (tripData.scheduledDate) {
        try {
            const date = tripData.scheduledDate.toDate
                ? tripData.scheduledDate.toDate()
                : new Date(tripData.scheduledDate);
            scheduledDateText = date.toLocaleDateString('en-IN', {
                day: '2-digit',
                month: 'short',
                year: 'numeric',
            });
        }
        catch (e) {
            (0, logger_1.logError)('Trip/WhatsApp', 'sendTripDispatchMessage', 'Error formatting date', e instanceof Error ? e : new Error(String(e)));
        }
    }
    // Format vehicle and slot info for parameter 3
    const vehicleInfo = tripData.vehicleNumber
        ? `Vehicle: ${tripData.vehicleNumber}`
        : '';
    const slotInfo = tripData.slotName || (tripData.slot ? `Slot ${tripData.slot}` : '');
    const scheduleInfo = [vehicleInfo, slotInfo].filter(Boolean).join(' | ') || '';
    // Format items list for parameter 4
    const itemsText = tripData.items && tripData.items.length > 0
        ? tripData.items
            .map((item, index) => {
            const itemNum = index + 1;
            return `${itemNum}. ${item.productName} - Qty: ${item.fixedQuantityPerTrip} units - ₹${item.unitPrice.toFixed(2)}`;
        })
            .join('\n')
        : 'No items';
    // Format total amount for parameter 5
    const pricing = tripData.tripPricing;
    const totalAmountText = pricing
        ? pricing.gstAmount > 0
            ? `₹${pricing.total.toFixed(2)} (Subtotal: ₹${pricing.subtotal.toFixed(2)}, GST: ₹${pricing.gstAmount.toFixed(2)})`
            : `₹${pricing.total.toFixed(2)} (Subtotal: ₹${pricing.subtotal.toFixed(2)})`
        : 'Pricing not available';
    // Format driver information for parameter 6
    const driverInfo = tripData.driverName && tripData.driverPhone
        ? `Driver: ${tripData.driverName} | Contact: ${tripData.driverPhone}`
        : tripData.driverName
            ? `Driver: ${tripData.driverName}`
            : 'Driver information not available';
    // Prepare template parameters
    const parameters = [
        displayName, // Parameter 1: Client name
        scheduledDateText, // Parameter 2: Trip date
        scheduleInfo, // Parameter 3: Vehicle and slot info
        itemsText, // Parameter 4: Items list
        totalAmountText, // Parameter 5: Total amount with breakdown
        driverInfo, // Parameter 6: Driver information
    ];
    (0, logger_1.logInfo)('Trip/WhatsApp', 'sendTripDispatchMessage', 'Sending dispatch notification', {
        organizationId,
        tripId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        templateId: settings.tripDispatchTemplateId,
        hasItems: tripData.items && tripData.items.length > 0,
    });
    await (0, whatsapp_service_1.sendWhatsappTemplateMessage)(url, settings.token, to, settings.tripDispatchTemplateId, (_a = settings.languageCode) !== null && _a !== void 0 ? _a : 'en', parameters, 'trip-dispatch', {
        organizationId,
        tripId,
    });
}
/**
 * Cloud Function: Triggered when a trip status is updated to 'dispatched'
 * Sends WhatsApp notification to client with trip details and driver information
 */
exports.onTripDispatchedSendWhatsapp = functions.firestore
    .document(`${SCHEDULED_TRIPS_COLLECTION}/{tripId}`)
    .onUpdate(async (change, context) => {
    const tripId = context.params.tripId;
    const before = change.before.data();
    const after = change.after.data();
    // Only proceed if trip status changed to 'dispatched'
    const beforeStatus = before.tripStatus;
    const afterStatus = after.tripStatus;
    if (beforeStatus === afterStatus || afterStatus !== 'dispatched') {
        (0, logger_1.logInfo)('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'Trip status not changed to dispatched, skipping', {
            tripId,
            beforeStatus,
            afterStatus,
        });
        return;
    }
    const tripData = after;
    if (!tripData) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'No trip data found', { tripId });
        return;
    }
    // Get client phone number
    let clientPhone = tripData.customerNumber || tripData.clientPhone;
    let clientName = tripData.clientName;
    // If phone not in trip, fetch from client document
    if (!clientPhone && tripData.clientId) {
        try {
            const clientDoc = await db
                .collection(constants_1.CLIENTS_COLLECTION)
                .doc(tripData.clientId)
                .get();
            if (clientDoc.exists) {
                const clientData = clientDoc.data();
                clientPhone = (clientData === null || clientData === void 0 ? void 0 : clientData.primaryPhoneNormalized) || (clientData === null || clientData === void 0 ? void 0 : clientData.primaryPhone);
                if (!clientName) {
                    clientName = clientData === null || clientData === void 0 ? void 0 : clientData.name;
                }
            }
        }
        catch (error) {
            (0, logger_1.logError)('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : new Error(String(error)), {
                tripId,
                clientId: tripData.clientId,
            });
        }
    }
    if (!clientPhone) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'onTripDispatchedSendWhatsapp', 'No phone found for trip, skipping notification', {
            tripId,
            clientId: tripData.clientId,
        });
        return;
    }
    await sendTripDispatchMessage(clientPhone, clientName, tripData.organizationId, tripId, tripData);
});
//# sourceMappingURL=trip-dispatch-whatsapp.js.map