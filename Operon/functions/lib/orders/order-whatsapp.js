"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onOrderUpdatedSendWhatsapp = exports.onOrderCreatedSendWhatsapp = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const logger_1 = require("../shared/logger");
const function_config_1 = require("../shared/function-config");
const whatsapp_message_queue_1 = require("../whatsapp/whatsapp-message-queue");
const db = (0, firestore_helpers_1.getFirestore)();
const MAX_ORDER_ITEMS = 10;
const MAX_ITEM_NAME_CHARS = 60;
const MAX_ITEMS_TEXT_CHARS = 900;
function buildJobId(eventId, fallbackParts) {
    if (eventId)
        return eventId;
    return fallbackParts.filter(Boolean).join('-');
}
function truncateText(value, maxChars) {
    if (value.length <= maxChars)
        return value;
    const suffix = '...';
    const trimmedLength = Math.max(0, maxChars - suffix.length);
    return `${value.slice(0, trimmedLength)}${suffix}`;
}
function formatOrderItems(items, multiline) {
    var _a, _b, _c, _d;
    if (!items || items.length === 0)
        return 'No items';
    const lines = [];
    const itemCount = Math.min(items.length, MAX_ORDER_ITEMS);
    for (let index = 0; index < itemCount; index += 1) {
        const item = items[index];
        const itemNum = index + 1;
        const estimatedTrips = (_a = item.estimatedTrips) !== null && _a !== void 0 ? _a : 0;
        const fixedQtyPerTrip = (_b = item.fixedQuantityPerTrip) !== null && _b !== void 0 ? _b : 1;
        const totalQuantity = (_c = item.totalQuantity) !== null && _c !== void 0 ? _c : (estimatedTrips * fixedQtyPerTrip);
        const total = (_d = item.total) !== null && _d !== void 0 ? _d : 0;
        const productName = truncateText(item.productName, MAX_ITEM_NAME_CHARS);
        if (multiline) {
            lines.push(`${itemNum}. ${productName}\n   Qty: ${totalQuantity} units (${estimatedTrips} trips)\n   Amount: ₹${total.toFixed(2)}`);
        }
        else {
            lines.push(`${itemNum}. ${productName} - Qty: ${totalQuantity} units (${estimatedTrips} trips) - ₹${total.toFixed(2)}`);
        }
    }
    if (items.length > MAX_ORDER_ITEMS) {
        lines.push(`...and ${items.length - MAX_ORDER_ITEMS} more items`);
    }
    const joined = lines.join(multiline ? '\n\n' : '\n');
    return truncateText(joined, MAX_ITEMS_TEXT_CHARS);
}
function didItemsChange(beforeItems, afterItems) {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (!beforeItems && !afterItems)
        return false;
    if (!beforeItems || !afterItems)
        return true;
    if (beforeItems.length !== afterItems.length)
        return true;
    for (let i = 0; i < beforeItems.length; i += 1) {
        const before = beforeItems[i];
        const after = afterItems[i];
        const beforeTrips = (_a = before.estimatedTrips) !== null && _a !== void 0 ? _a : 0;
        const afterTrips = (_b = after.estimatedTrips) !== null && _b !== void 0 ? _b : 0;
        const beforeFixed = (_c = before.fixedQuantityPerTrip) !== null && _c !== void 0 ? _c : 1;
        const afterFixed = (_d = after.fixedQuantityPerTrip) !== null && _d !== void 0 ? _d : 1;
        const beforeTotalQty = (_e = before.totalQuantity) !== null && _e !== void 0 ? _e : (beforeTrips * beforeFixed);
        const afterTotalQty = (_f = after.totalQuantity) !== null && _f !== void 0 ? _f : (afterTrips * afterFixed);
        if ((before.productName || '') !== (after.productName || ''))
            return true;
        if (beforeTrips !== afterTrips)
            return true;
        if (beforeFixed !== afterFixed)
            return true;
        if (beforeTotalQty !== afterTotalQty)
            return true;
        if (((_g = before.total) !== null && _g !== void 0 ? _g : 0) !== ((_h = after.total) !== null && _h !== void 0 ? _h : 0))
            return true;
    }
    return false;
}
function didPricingChange(before, after) {
    var _a, _b;
    if (!before && !after)
        return false;
    if (!before || !after)
        return true;
    return (before.subtotal !== after.subtotal ||
        ((_a = before.totalGst) !== null && _a !== void 0 ? _a : 0) !== ((_b = after.totalGst) !== null && _b !== void 0 ? _b : 0) ||
        before.totalAmount !== after.totalAmount ||
        before.currency !== after.currency);
}
function didDeliveryZoneChange(before, after) {
    if (!before && !after)
        return false;
    if (!before || !after)
        return true;
    return before.city_name !== after.city_name || before.region !== after.region;
}
/**
 * Sends WhatsApp notification to client when an order is created
 */
async function enqueueOrderConfirmationMessage(to, clientName, organizationId, orderId, orderData, jobId) {
    var _a;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format order items for template parameter 2
    const itemsText = formatOrderItems(orderData.items, false);
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
    (0, logger_1.logInfo)('Order/WhatsApp', 'enqueueOrderConfirmationMessage', 'Enqueuing order confirmation', {
        organizationId,
        orderId,
        to: to.substring(0, 4) + '****',
        hasItems: orderData.items.length > 0,
    });
    await (0, whatsapp_message_queue_1.enqueueWhatsappMessage)(jobId, {
        type: 'order-confirmation',
        to,
        organizationId,
        parameters,
        context: {
            organizationId,
            orderId,
        },
    });
}
/**
 * Sends WhatsApp notification to client when an order is updated
 */
async function enqueueOrderUpdateMessage(to, clientName, organizationId, orderId, orderData, jobId) {
    var _a;
    const displayName = clientName && clientName.trim().length > 0
        ? clientName.trim()
        : 'there';
    // Format order items for message
    const itemsText = formatOrderItems(orderData.items, true);
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
    (0, logger_1.logInfo)('Order/WhatsApp', 'enqueueOrderUpdateMessage', 'Enqueuing order update', {
        organizationId,
        orderId,
        to: to.substring(0, 4) + '****',
        hasItems: orderData.items.length > 0,
        status: orderData.status,
    });
    await (0, whatsapp_message_queue_1.enqueueWhatsappMessage)(jobId, {
        type: 'order-update',
        to,
        organizationId,
        messageBody,
        context: {
            organizationId,
            orderId,
        },
    });
}
/**
 * Cloud Function: Triggered when an order is created
 * Sends WhatsApp notification to client with order details
 */
exports.onOrderCreatedSendWhatsapp = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const orderId = event.params.orderId;
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
        const jobId = buildJobId(event.id, [orderId, 'order-created']);
        await enqueueOrderConfirmationMessage(clientPhone, clientName, orderData.organizationId, orderId, {
            orderNumber: orderData.orderNumber,
            items: orderData.items,
            pricing: orderData.pricing,
            deliveryZone: orderData.deliveryZone,
            advanceAmount: orderData.advanceAmount,
        }, jobId);
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
exports.onOrderUpdatedSendWhatsapp = (0, firestore_1.onDocumentUpdated)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b;
    const orderId = event.params.orderId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    if (!before || !after)
        return;
    // Check if significant fields changed
    const itemsChanged = didItemsChange(before.items, after.items);
    const pricingChanged = didPricingChange(before.pricing, after.pricing);
    const statusChanged = before.status !== after.status;
    const deliveryZoneChanged = didDeliveryZoneChange(before.deliveryZone, after.deliveryZone);
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
    const jobId = buildJobId(event.id, [orderId, 'order-updated']);
    await enqueueOrderUpdateMessage(clientPhone, clientName, orderData.organizationId, orderId, {
        orderNumber: orderData.orderNumber,
        items: orderData.items,
        pricing: orderData.pricing,
        deliveryZone: orderData.deliveryZone,
        advanceAmount: orderData.advanceAmount,
        status: orderData.status,
    }, jobId);
});
//# sourceMappingURL=order-whatsapp.js.map