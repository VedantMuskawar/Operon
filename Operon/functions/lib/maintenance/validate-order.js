"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateOrder = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const constants_1 = require("../shared/constants");
const db = (0, firestore_1.getFirestore)();
/**
 * Validate order data integrity
 * Checks items, pricing, GST, scheduled trips consistency
 */
exports.validateOrder = (0, https_1.onCall)(async (request) => {
    const { orderId, organizationId } = request.data;
    const orderRef = db.collection(constants_1.PENDING_ORDERS_COLLECTION).doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        return { valid: false, errors: ['Order not found'] };
    }
    const orderData = orderDoc.data();
    const errors = [];
    const warnings = [];
    // Validate items
    const items = orderData.items || [];
    if (items.length === 0) {
        errors.push('Order has no items');
    }
    items.forEach((item, index) => {
        // Validate required fields
        if (!item.productId)
            errors.push(`Item ${index}: missing productId`);
        if (!item.productName)
            warnings.push(`Item ${index}: missing productName`);
        if (item.estimatedTrips < 0)
            errors.push(`Item ${index}: estimatedTrips cannot be negative`);
        if (item.fixedQuantityPerTrip <= 0)
            errors.push(`Item ${index}: fixedQuantityPerTrip must be > 0`);
        if (item.scheduledTrips < 0)
            errors.push(`Item ${index}: scheduledTrips cannot be negative`);
        if (item.scheduledTrips > item.estimatedTrips) {
            errors.push(`Item ${index}: scheduledTrips (${item.scheduledTrips}) > estimatedTrips (${item.estimatedTrips})`);
        }
        // Validate GST fields (conditional storage)
        if (item.gstPercent !== undefined && item.gstPercent <= 0) {
            warnings.push(`Item ${index}: gstPercent should be > 0 or undefined`);
        }
        if (item.gstPercent && !item.gstAmount) {
            errors.push(`Item ${index}: gstPercent exists but gstAmount missing`);
        }
        if (!item.gstPercent && item.gstAmount) {
            warnings.push(`Item ${index}: gstAmount exists but gstPercent missing`);
        }
        // Validate pricing calculations
        const expectedSubtotal = item.estimatedTrips * item.fixedQuantityPerTrip * item.unitPrice;
        if (Math.abs(item.subtotal - expectedSubtotal) > 0.01) {
            errors.push(`Item ${index}: subtotal mismatch. Expected: ${expectedSubtotal}, Got: ${item.subtotal}`);
        }
        const expectedGstAmount = item.gstPercent
            ? item.subtotal * (item.gstPercent / 100)
            : 0;
        if (item.gstAmount !== undefined && Math.abs(item.gstAmount - expectedGstAmount) > 0.01) {
            errors.push(`Item ${index}: gstAmount mismatch. Expected: ${expectedGstAmount}, Got: ${item.gstAmount}`);
        }
        const expectedTotal = item.subtotal + (item.gstAmount || 0);
        if (Math.abs(item.total - expectedTotal) > 0.01) {
            errors.push(`Item ${index}: total mismatch. Expected: ${expectedTotal}, Got: ${item.total}`);
        }
    });
    // Validate pricing summary
    const pricing = orderData.pricing || {};
    const calculatedSubtotal = items.reduce((sum, item) => sum + (item.subtotal || 0), 0);
    if (Math.abs(pricing.subtotal - calculatedSubtotal) > 0.01) {
        errors.push(`Pricing subtotal mismatch. Expected: ${calculatedSubtotal}, Got: ${pricing.subtotal}`);
    }
    const calculatedTotalGst = items.reduce((sum, item) => sum + (item.gstAmount || 0), 0);
    if (pricing.totalGst !== undefined && Math.abs(pricing.totalGst - calculatedTotalGst) > 0.01) {
        errors.push(`Pricing totalGst mismatch. Expected: ${calculatedTotalGst}, Got: ${pricing.totalGst}`);
    }
    if (calculatedTotalGst > 0 && !pricing.totalGst) {
        warnings.push('Items have GST but pricing.totalGst is missing');
    }
    if (calculatedTotalGst === 0 && pricing.totalGst) {
        warnings.push('No items have GST but pricing.totalGst exists');
    }
    const expectedTotalAmount = pricing.subtotal + (pricing.totalGst || 0);
    if (Math.abs(pricing.totalAmount - expectedTotalAmount) > 0.01) {
        errors.push(`Pricing totalAmount mismatch. Expected: ${expectedTotalAmount}, Got: ${pricing.totalAmount}`);
    }
    // Validate scheduled trips
    const scheduledTrips = orderData.scheduledTrips || [];
    const totalScheduledTrips = orderData.totalScheduledTrips || 0;
    if (scheduledTrips.length !== totalScheduledTrips) {
        errors.push(`scheduledTrips array length (${scheduledTrips.length}) != totalScheduledTrips (${totalScheduledTrips})`);
    }
    // Validate trip references exist
    const tripRefs = scheduledTrips.map((trip) => trip.tripId);
    const uniqueTripRefs = [...new Set(tripRefs)];
    if (tripRefs.length !== uniqueTripRefs.length) {
        errors.push('Duplicate tripId in scheduledTrips array');
    }
    // Validate item-level scheduledTrips counts
    items.forEach((item, index) => {
        const itemTrips = scheduledTrips.filter((t) => t.itemIndex === index);
        const itemScheduledTrips = item.scheduledTrips || 0;
        if (itemScheduledTrips !== itemTrips.length) {
            errors.push(`Item ${index}: scheduledTrips count (${itemScheduledTrips}) != actual trips in array (${itemTrips.length})`);
        }
    });
    return {
        valid: errors.length === 0,
        errors,
        warnings,
        orderId,
        organizationId
    };
});
//# sourceMappingURL=validate-order.js.map