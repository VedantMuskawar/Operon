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
        const itemNum = index + 1;
        return `${itemNum}. ${item.productName}\n   Qty: ${item.totalQuantity} units (${item.estimatedTrips} trips)\n   Amount: ₹${item.total.toFixed(2)}`;
    })
        .join('\n\n');
    // Format delivery zone
    const deliveryInfo = orderData.deliveryZone
        ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
        : 'To be confirmed';
    // Format pricing summary
    const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
        (orderData.pricing.totalGst > 0
            ? `GST: ₹${orderData.pricing.totalGst.toFixed(2)}\n`
            : '') +
        `Total: ₹${orderData.pricing.totalAmount.toFixed(2)}`;
    // Format advance payment info if applicable
    const advanceText = orderData.advanceAmount && orderData.advanceAmount > 0
        ? `\n\nAdvance Paid: ₹${orderData.advanceAmount.toFixed(2)}\nRemaining: ₹${(orderData.pricing.totalAmount - orderData.advanceAmount).toFixed(2)}`
        : '';
    // Build message body
    const messageBody = `Hello ${displayName}!\n\n` +
        `Your order has been placed successfully!\n\n` +
        `Items:\n${itemsText}\n\n` +
        `Delivery: ${deliveryInfo}\n\n` +
        `Pricing:\n${pricingText}${advanceText}\n\n` +
        `Thank you for your order!`;
    (0, logger_1.logInfo)('Order/WhatsApp', 'sendOrderConfirmationMessage', 'Sending order confirmation', {
        organizationId,
        orderId,
        to: to.substring(0, 4) + '****',
        phoneId: settings.phoneId,
        hasItems: orderData.items.length > 0,
    });
    await (0, whatsapp_service_1.sendWhatsappMessage)(url, settings.token, to, messageBody, 'confirmation', {
        organizationId,
        orderId,
    });
}
/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function sendOrderUpdateMessage(to, clientName, organizationId, orderId, orderData) {
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
        const itemNum = index + 1;
        return `${itemNum}. ${item.productName}\n   Qty: ${item.totalQuantity} units (${item.estimatedTrips} trips)\n   Amount: ₹${item.total.toFixed(2)}`;
    })
        .join('\n\n');
    // Format delivery zone
    const deliveryInfo = orderData.deliveryZone
        ? `${orderData.deliveryZone.city_name}, ${orderData.deliveryZone.region}`
        : 'To be confirmed';
    // Format pricing summary
    const pricingText = `Subtotal: ₹${orderData.pricing.subtotal.toFixed(2)}\n` +
        (orderData.pricing.totalGst > 0
            ? `GST: ₹${orderData.pricing.totalGst.toFixed(2)}\n`
            : '') +
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
        console.log('[WhatsApp Order] No order data found', { orderId });
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
            console.error('[WhatsApp Order] Error fetching client data', {
                orderId,
                clientId: orderData.clientId,
                error,
            });
        }
    }
    if (!clientPhone) {
        console.log('[WhatsApp Order] No phone found for order, skipping notification.', { orderId, clientId: orderData.clientId });
        return;
    }
    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
        console.log('[WhatsApp Order] Missing required order data', {
            orderId,
            hasItems: !!orderData.items,
            hasPricing: !!orderData.pricing,
        });
        return;
    }
    await sendOrderConfirmationMessage(clientPhone, clientName, orderData.organizationId, orderId, {
        orderNumber: orderData.orderNumber,
        items: orderData.items,
        pricing: orderData.pricing,
        deliveryZone: orderData.deliveryZone,
        advanceAmount: orderData.advanceAmount,
    });
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
        console.log('[WhatsApp Order] No order data found', { orderId });
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
            // Error already handled, continue silently
        }
    }
    if (!clientPhone) {
        return;
    }
    // Validate required order data
    if (!orderData.items || !orderData.pricing) {
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