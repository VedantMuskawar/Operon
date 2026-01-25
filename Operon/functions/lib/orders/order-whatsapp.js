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
exports.onOrderUpdatedSendWhatsapp = exports.onOrderCreatedSendWhatsapp = void 0;
const functions = __importStar(require("firebase-functions"));
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const whatsapp_service_1 = require("../shared/whatsapp-service");
const logger_1 = require("../shared/logger");
const db = (0, firestore_helpers_1.getFirestore)();
/**
 * Sends WhatsApp notification to client when an order is created
 */
async function sendOrderConfirmationMessage(to, clientName, organizationId, orderId, orderData) {
    var _a, _b;
    const settings = await (0, whatsapp_service_1.loadWhatsappSettings)(organizationId, true);
    if (!(settings === null || settings === void 0 ? void 0 : settings.orderConfirmationTemplateId)) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'sendOrderConfirmationMessage', 'Skipping – no WhatsApp settings or orderConfirmationTemplateId for org', {
            orderId,
            organizationId: organizationId !== null && organizationId !== void 0 ? organizationId : 'missing',
        });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format order items for template parameter 2
    const itemsText = orderData.items
        .map((item, index) => {
        var _a, _b, _c, _d;
        const itemNum = index + 1;
        // Calculate totalQuantity if not present: estimatedTrips × fixedQuantityPerTrip
        const estimatedTrips = (_a = item.estimatedTrips) !== null && _a !== void 0 ? _a : 0;
        const fixedQtyPerTrip = (_b = item.fixedQuantityPerTrip) !== null && _b !== void 0 ? _b : 1;
        const totalQuantity = (_c = item.totalQuantity) !== null && _c !== void 0 ? _c : (estimatedTrips * fixedQtyPerTrip);
        const total = (_d = item.total) !== null && _d !== void 0 ? _d : 0;
        return `${itemNum}. ${item.productName} - Qty: ${totalQuantity} units (${estimatedTrips} trips) - ₹${total.toFixed(2)}`;
    })
        .join('\n');
    // Format delivery zone for parameter 3
    const deliveryInfo = orderData.deliveryZone
        ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
        : 'To be confirmed';
    // Format total amount for parameter 4
    const totalGst = (_a = orderData.pricing.totalGst) !== null && _a !== void 0 ? _a : 0;
    const totalAmountText = totalGst > 0
        ? `₹${orderData.pricing.totalAmount.toFixed(2)} (Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}, GST: ₹${totalGst.toFixed(2)})`
        : `₹${orderData.pricing.totalAmount.toFixed(2)} (Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)})`;
    // Format advance payment info for parameter 5
    // WhatsApp rejects empty template parameters – use placeholder when no advance
    const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
        ? `Advance Paid: ₹${orderData.advanceAmount.toFixed(2)} | Remaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
        : '—';
    // Prepare template parameters
    const parameters = [
        displayName, // Parameter 1: Client name
        itemsText, // Parameter 2: Order items list
        deliveryInfo, // Parameter 3: Delivery zone
        totalAmountText, // Parameter 4: Total amount with breakdown
        advanceText, // Parameter 5: Advance payment info (never empty)
    ];
    (0, logger_1.logInfo)('Order/WhatsApp', 'sendOrderConfirmationMessage', 'Sending order confirmation', {
        organizationId,
        orderId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        templateId: settings.orderConfirmationTemplateId,
        hasItems: orderData.items.length > 0,
    });
    await (0, whatsapp_service_1.sendWhatsappTemplateMessage)(url, settings.token, to, settings.orderConfirmationTemplateId, (_b = settings.languageCode) !== null && _b !== void 0 ? _b : 'en', parameters, 'order-confirmation', {
        organizationId,
        orderId,
    });
}
/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function sendOrderUpdateMessage(to, clientName, organizationId, orderId, orderData) {
    var _a;
    const settings = await (0, whatsapp_service_1.loadWhatsappSettings)(organizationId);
    if (!settings) {
        console.log('[WhatsApp Order] Skipping send – no settings or disabled.', { orderId, organizationId });
        return;
    }
    const url = `https://graph.facebook.com/v19.0/${settings.phoneId}/messages`;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format order items for message
    const itemsText = orderData.items
        .map((item, index) => {
        var _a, _b, _c, _d;
        const itemNum = index + 1;
        // Calculate totalQuantity if not present: estimatedTrips × fixedQuantityPerTrip
        const estimatedTrips = (_a = item.estimatedTrips) !== null && _a !== void 0 ? _a : 0;
        const fixedQtyPerTrip = (_b = item.fixedQuantityPerTrip) !== null && _b !== void 0 ? _b : 1;
        const totalQuantity = (_c = item.totalQuantity) !== null && _c !== void 0 ? _c : (estimatedTrips * fixedQtyPerTrip);
        const total = (_d = item.total) !== null && _d !== void 0 ? _d : 0;
        return `${itemNum}. ${item.productName}\n   Qty: ${totalQuantity} units (${estimatedTrips} trips)\n   Amount: ₹${total.toFixed(2)}`;
    })
        .join('\n\n');
    // Format delivery zone
    const deliveryInfo = orderData.deliveryZone
        ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
        : 'To be confirmed';
    // Format pricing summary
    const totalGst = (_a = orderData.pricing.totalGst) !== null && _a !== void 0 ? _a : 0;
    const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
        (totalGst > 0 ? `GST: ₹${totalGst.toFixed(2)}\n` : '') +
        `Total: ₹${orderData.pricing.totalAmount.toFixed(2)}`;
    // Format advance payment info if applicable
    const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
        ? `\n\nAdvance Paid: ₹${orderData.advanceAmount.toFixed(2)}\nRemaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
        : '';
    // Format status if available
    const statusText = orderData.status && orderData.status !== 'pending'
        ? `\n\nStatus: ${orderData.status.charAt(0).toUpperCase() + orderData.status.slice(1)}`
        : '';
    // Build message body
    const messageBody = `Hello ${displayName}!\n\n` +
        `Your order has been updated!\n\n` +
        `Items:\n${itemsText}\n\n` +
        `Delivery: ${deliveryInfo}\n\n` +
        `Pricing:\n${pricingText}${advanceText}${statusText}\n\n` +
        `Thank you!`;
    (0, logger_1.logInfo)('Order/WhatsApp', 'sendOrderUpdateMessage', 'Sending order update', {
        organizationId,
        orderId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        hasItems: orderData.items.length > 0,
        status: orderData.status,
    });
    await (0, whatsapp_service_1.sendWhatsappMessage)(url, settings.token, to, messageBody, 'update', {
        organizationId,
        orderId,
    });
}
/**
 * Cloud Function: Triggered when an order is created
 * Sends WhatsApp notification to client with order details
 */
exports.onOrderCreatedSendWhatsapp = functions
    .region('us-central1')
    .firestore
    .document(`${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}`)
    .onCreate(async (snapshot, context) => {
    const orderId = context.params.orderId;
    const orderData = snapshot.data();
    if (!orderData) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'No order data in snapshot, skipping', { orderId });
        return;
    }
    // Get client phone number
    let clientPhone = orderData.clientPhone;
    let clientName = orderData.clientName;
    // If phone not in order, fetch from client document
    if (!clientPhone && orderData.clientId) {
        try {
            const clientDoc = await db
                .collection(constants_1.CLIENTS_COLLECTION)
                .doc(orderData.clientId)
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
            (0, logger_1.logError)('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : undefined, {
                orderId,
                clientId: orderData.clientId,
            });
        }
    }
    if (!clientPhone) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'No client phone for order, skipping WhatsApp', {
            orderId,
            clientId: orderData.clientId,
            hadClientPhoneOnOrder: !!orderData.clientPhone,
        });
        return;
    }
    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Missing items or pricing, skipping WhatsApp', {
            orderId,
            hasItems: !!orderData.items,
            hasPricing: !!orderData.pricing,
        });
        return;
    }
    try {
        await sendOrderConfirmationMessage(clientPhone, clientName, orderData.organizationId, orderId, {
            orderNumber: orderData.orderNumber,
            items: orderData.items,
            pricing: orderData.pricing,
            deliveryZone: orderData.deliveryZone,
            advanceAmount: orderData.advanceAmount,
        });
    }
    catch (err) {
        (0, logger_1.logError)('Order/WhatsApp', 'onOrderCreatedSendWhatsapp', 'Failed to send order confirmation WhatsApp', err instanceof Error ? err : undefined, {
            orderId,
            organizationId: orderData.organizationId,
            clientId: orderData.clientId,
        });
        throw err;
    }
});
/**
 * Cloud Function: Triggered when an order is updated
 * Sends WhatsApp notification to client with updated order details
 * Only sends for significant changes (items, pricing, status, delivery zone)
 */
exports.onOrderUpdatedSendWhatsapp = functions
    .region('us-central1')
    .firestore
    .document(`${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}`)
    .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const before = change.before.data();
    const after = change.after.data();
    // Check if significant fields changed
    const itemsChanged = JSON.stringify(before.items) !== JSON.stringify(after.items);
    const pricingChanged = JSON.stringify(before.pricing) !== JSON.stringify(after.pricing);
    const statusChanged = before.status !== after.status;
    const deliveryZoneChanged = JSON.stringify(before.deliveryZone) !== JSON.stringify(after.deliveryZone);
    const advanceAmountChanged = before.advanceAmount !== after.advanceAmount;
    // Only send notification if significant changes occurred
    if (!itemsChanged && !pricingChanged && !statusChanged && !deliveryZoneChanged && !advanceAmountChanged) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No significant changes detected, skipping update notification', {
            orderId,
        });
        return;
    }
    const orderData = after;
    if (!orderData) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No order data in snapshot, skipping', { orderId });
        return;
    }
    // Get client phone number
    let clientPhone = orderData.clientPhone;
    let clientName = orderData.clientName;
    // If phone not in order, fetch from client document
    if (!clientPhone && orderData.clientId) {
        try {
            const clientDoc = await db
                .collection(constants_1.CLIENTS_COLLECTION)
                .doc(orderData.clientId)
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
            (0, logger_1.logError)('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'Error fetching client data', error instanceof Error ? error : undefined, {
                orderId,
                clientId: orderData.clientId,
            });
        }
    }
    if (!clientPhone) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'No client phone, skipping update notification', {
            orderId,
            clientId: orderData.clientId,
        });
        return;
    }
    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
        (0, logger_1.logInfo)('Order/WhatsApp', 'onOrderUpdatedSendWhatsapp', 'Missing items or pricing, skipping', {
            orderId,
            hasItems: !!orderData.items,
            hasPricing: !!orderData.pricing,
        });
        return;
    }
    await sendOrderUpdateMessage(clientPhone, clientName, orderData.organizationId, orderId, {
        orderNumber: orderData.orderNumber,
        items: orderData.items,
        pricing: orderData.pricing,
        deliveryZone: orderData.deliveryZone,
        advanceAmount: orderData.advanceAmount,
        status: orderData.status,
    });
});
//# sourceMappingURL=order-whatsapp.js.map