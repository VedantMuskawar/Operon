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
const db = (0, firestore_helpers_1.getFirestore)();
const SCHEDULED_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
async function loadWhatsappSettings(organizationId) {
    var _a;
    // First, try to load organization-specific settings
    if (organizationId) {
        const trimmedOrgId = organizationId.trim();
        const orgSettingsRef = db.collection(constants_1.WHATSAPP_SETTINGS_COLLECTION).doc(trimmedOrgId);
        const orgSettingsDoc = await orgSettingsRef.get();
        if (orgSettingsDoc.exists) {
            const data = orgSettingsDoc.data();
            if (data && data.enabled === true) {
                if (!data.token || !data.phoneId) {
                    return null;
                }
                return {
                    enabled: true,
                    token: data.token,
                    phoneId: data.phoneId,
                    welcomeTemplateId: data.welcomeTemplateId,
                    languageCode: data.languageCode,
                    orderConfirmationTemplateId: data.orderConfirmationTemplateId,
                };
            }
            return null;
        }
    }
    // Fallback to global config
    const globalConfig = (_a = functions.config().whatsapp) !== null && _a !== void 0 ? _a : {};
    if (globalConfig.token &&
        globalConfig.phone_id &&
        globalConfig.enabled !== 'false') {
        return {
            enabled: true,
            token: globalConfig.token,
            phoneId: globalConfig.phone_id,
            welcomeTemplateId: globalConfig.welcome_template_id,
            languageCode: globalConfig.language_code,
            orderConfirmationTemplateId: globalConfig.order_confirmation_template_id,
        };
    }
    return null;
}
/**
 * Sends WhatsApp notification to client when a trip is dispatched
 */
async function sendTripDispatchMessage(to, clientName, organizationId, tripId, tripData) {
    const settings = await loadWhatsappSettings(organizationId);
    if (!settings) {
        console.log('[WhatsApp Trip Dispatch] Skipping send – no settings or disabled.', { tripId, organizationId });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format trip items for message
    const itemsText = tripData.items && tripData.items.length > 0
        ? tripData.items
            .map((item, index) => {
            const itemNum = index + 1;
            const gstText = item.gstAmount && item.gstAmount > 0
                ? `\n   GST: ₹${item.gstAmount.toFixed(2)}`
                : '';
            return `${itemNum}. ${item.productName}\n   Qty: ${item.fixedQuantityPerTrip} units\n   Unit Price: ₹${item.unitPrice.toFixed(2)}${gstText}`;
        })
            .join('\n\n')
        : 'No items';
    // Format trip pricing
    const pricing = tripData.tripPricing;
    const pricingText = pricing
        ? `Subtotal: ₹${pricing.subtotal.toFixed(2)}\n` +
            (pricing.gstAmount > 0 ? `GST: ₹${pricing.gstAmount.toFixed(2)}\n` : '') +
            `Total: ₹${pricing.total.toFixed(2)}`
        : 'Pricing not available';
    // Format scheduled date
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
            console.error('[WhatsApp Trip Dispatch] Error formatting date', e);
        }
    }
    // Format driver info
    const driverInfo = tripData.driverName && tripData.driverPhone
        ? `Driver: ${tripData.driverName}\nDriver Contact: ${tripData.driverPhone}`
        : tripData.driverName
            ? `Driver: ${tripData.driverName}`
            : 'Driver information not available';
    // Format vehicle and slot info
    const vehicleInfo = tripData.vehicleNumber
        ? `Vehicle: ${tripData.vehicleNumber}`
        : '';
    const slotInfo = tripData.slotName || (tripData.slot ? `Slot ${tripData.slot}` : '');
    const scheduleInfo = [vehicleInfo, slotInfo].filter(Boolean).join(' | ');
    // Build message body
    const messageBody = `Hello ${displayName}!\n\n` +
        `Your trip has been dispatched!\n\n` +
        `Trip Details:\n` +
        `Date: ${scheduledDateText}\n` +
        (scheduleInfo ? `${scheduleInfo}\n` : '') +
        `\nItems:\n${itemsText}\n\n` +
        `Pricing:\n${pricingText}\n\n` +
        `${driverInfo}\n\n` +
        `Thank you!`;
    console.log('[WhatsApp Trip Dispatch] Sending dispatch notification', {
        organizationId,
        tripId,
        to: to.substring(0, 4) + '****', // Mask phone number
        phoneId: settings.phoneId,
        hasItems: tripData.items && tripData.items.length > 0,
    });
    await sendWhatsappMessage(url, settings.token, to, messageBody, {
        organizationId,
        tripId,
    });
}
async function sendWhatsappMessage(url, token, to, messageBody, context) {
    var _a, _b;
    const payload = {
        messaging_product: 'whatsapp',
        to: to,
        type: 'text',
        text: {
            body: messageBody,
        },
    };
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
    });
    if (!response.ok) {
        const text = await response.text();
        let errorDetails;
        try {
            errorDetails = JSON.parse(text);
        }
        catch (_c) {
            errorDetails = text;
        }
        console.error('[WhatsApp Trip Dispatch] Failed to send dispatch notification', {
            status: response.status,
            statusText: response.statusText,
            error: errorDetails,
            organizationId: context.organizationId,
            tripId: context.tripId,
            url,
        });
    }
    else {
        const result = await response.json().catch(() => ({}));
        console.log('[WhatsApp Trip Dispatch] Dispatch notification sent successfully', {
            tripId: context.tripId,
            to: to.substring(0, 4) + '****',
            organizationId: context.organizationId,
            messageId: (_b = (_a = result.messages) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.id,
        });
    }
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
        console.log('[WhatsApp Trip Dispatch] Trip status not changed to dispatched, skipping', {
            tripId,
            beforeStatus,
            afterStatus,
        });
        return;
    }
    const tripData = after;
    if (!tripData) {
        console.log('[WhatsApp Trip Dispatch] No trip data found', { tripId });
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
            console.error('[WhatsApp Trip Dispatch] Error fetching client data', {
                tripId,
                clientId: tripData.clientId,
                error,
            });
        }
    }
    if (!clientPhone) {
        console.log('[WhatsApp Trip Dispatch] No phone found for trip, skipping notification.', { tripId, clientId: tripData.clientId });
        return;
    }
    await sendTripDispatchMessage(clientPhone, clientName, tripData.organizationId, tripId, tripData);
});
//# sourceMappingURL=trip-dispatch-whatsapp.js.map