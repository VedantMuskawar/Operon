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
exports.onTripDeliveredSendWhatsapp = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const logger_1 = require("../shared/logger");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * Sends WhatsApp notification to client when a trip is delivered
 */
async function sendTripDeliveryMessage(whatsapp, to, clientName, organizationId, tripId, tripData) {
    var _a;
    const settings = await whatsapp.loadWhatsappSettings(organizationId);
    if (!(settings === null || settings === void 0 ? void 0 : settings.tripDeliveryTemplateId)) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'sendTripDeliveryMessage', 'Skipping send – no settings or disabled', {
            tripId,
            organizationId,
        });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format trip date for parameter 2
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
            (0, logger_1.logError)('Trip/WhatsApp', 'sendTripDeliveryMessage', 'Error formatting date', e instanceof Error ? e : new Error(String(e)));
        }
    }
    // Format items delivered for parameter 3
    const itemsText = tripData.items && tripData.items.length > 0
        ? tripData.items
            .map((item, index) => {
            const itemNum = index + 1;
            return `${itemNum}. ${item.productName} - ${item.fixedQuantityPerTrip} units`;
        })
            .join('\n')
        : 'No items';
    // Prepare template parameters
    const parameters = [
        displayName, // Parameter 1: Client name
        scheduledDateText, // Parameter 2: Trip date
        itemsText, // Parameter 3: Items delivered list
    ];
    (0, logger_1.logInfo)('Trip/WhatsApp', 'sendTripDeliveryMessage', 'Sending delivery notification', {
        organizationId,
        tripId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        templateId: settings.tripDeliveryTemplateId,
        hasItems: tripData.items && tripData.items.length > 0,
    });
    await whatsapp.sendWhatsappTemplateMessage(url, settings.token, to, settings.tripDeliveryTemplateId, (_a = settings.languageCode) !== null && _a !== void 0 ? _a : 'en', parameters, 'trip-delivery', {
        organizationId,
        tripId,
    });
}
/**
 * Cloud Function: Triggered when a trip status is updated to 'delivered'
 * Sends WhatsApp notification to client with delivery confirmation
 */
exports.onTripDeliveredSendWhatsapp = (0, firestore_1.onDocumentUpdated)(Object.assign({ document: `${SCHEDULED_TRIPS_COLLECTION}/{tripId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c, _d;
    const tripId = event.params.tripId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    // Only proceed if trip status changed to 'delivered'
    const beforeStatus = (_c = before.tripStatus) === null || _c === void 0 ? void 0 : _c.toLowerCase();
    const afterStatus = (_d = after.tripStatus) === null || _d === void 0 ? void 0 : _d.toLowerCase();
    if (beforeStatus === afterStatus || afterStatus !== 'delivered') {
        (0, logger_1.logInfo)('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Trip status not changed to delivered, skipping', {
            tripId,
            beforeStatus,
            afterStatus,
        });
        return;
    }
    // Do not send when return is reverted (returned → delivered)
    if (beforeStatus === 'returned' && afterStatus === 'delivered') {
        (0, logger_1.logInfo)('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Trip return reverted, skipping WhatsApp', {
            tripId,
            beforeStatus,
            afterStatus,
        });
        return;
    }
    const tripData = after;
    if (!tripData) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'No trip data found', { tripId });
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
            (0, logger_1.logError)('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : new Error(String(error)), {
                tripId,
                clientId: tripData.clientId,
            });
        }
    }
    if (!clientPhone) {
        (0, logger_1.logWarning)('Trip/WhatsApp', 'onTripDeliveredSendWhatsapp', 'No phone found for trip, skipping notification', {
            tripId,
            clientId: tripData.clientId,
        });
        return;
    }
    const whatsapp = await Promise.resolve().then(() => __importStar(require('../shared/whatsapp-service')));
    await sendTripDeliveryMessage(whatsapp, clientPhone, clientName, tripData.organizationId, tripId, tripData);
});
//# sourceMappingURL=trip-delivery-whatsapp.js.map