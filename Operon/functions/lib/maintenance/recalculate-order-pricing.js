"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.recalculateOrderPricing = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const constants_1 = require("../shared/constants");
const db = (0, firestore_1.getFirestore)();
/**
 * Recalculate order pricing from items
 * Useful after schema changes or data corrections
 */
exports.recalculateOrderPricing = (0, https_1.onCall)(async (request) => {
    var _a;
    const { orderId } = request.data;
    const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        return { success: false, error: 'Order not found' };
    }
    const orderData = orderDoc.data();
    const items = orderData.items || [];
    // Recalculate item pricing
    const updatedItems = items.map((item) => {
        const subtotal = item.estimatedTrips * item.fixedQuantityPerTrip * item.unitPrice;
        let gstAmount;
        if (item.gstPercent && item.gstPercent > 0) {
            gstAmount = subtotal * (item.gstPercent / 100);
        }
        const total = subtotal + (gstAmount || 0);
        const updatedItem = Object.assign(Object.assign({}, item), { subtotal,
            total });
        // Only include GST fields if applicable
        if (gstAmount !== undefined && gstAmount > 0) {
            updatedItem.gstPercent = item.gstPercent;
            updatedItem.gstAmount = gstAmount;
        }
        else {
            // Remove GST fields if not applicable
            delete updatedItem.gstPercent;
            delete updatedItem.gstAmount;
        }
        return updatedItem;
    });
    // Recalculate order pricing
    const subtotal = updatedItems.reduce((sum, item) => sum + item.subtotal, 0);
    const totalGst = updatedItems.reduce((sum, item) => sum + (item.gstAmount || 0), 0);
    const totalAmount = subtotal + totalGst;
    const pricing = {
        subtotal,
        totalAmount,
        currency: ((_a = orderData.pricing) === null || _a === void 0 ? void 0 : _a.currency) || 'INR'
    };
    // Only include totalGst if there's actual GST
    if (totalGst > 0) {
        pricing.totalGst = totalGst;
    }
    // Update order
    await orderRef.update({
        items: updatedItems,
        pricing,
        updatedAt: new Date()
    });
    return {
        success: true,
        orderId,
        pricing,
        itemsUpdated: updatedItems.length
    };
});
//# sourceMappingURL=recalculate-order-pricing.js.map