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
exports.onOrderUpdated = exports.onPendingOrderCreated = exports.onOrderDeleted = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const constants_1 = require("../shared/constants");
const financial_year_1 = require("../shared/financial-year");
const firestore_helpers_1 = require("../shared/firestore-helpers");
const function_config_1 = require("../shared/function-config");
const db = (0, firestore_helpers_1.getFirestore)();
const SCHEDULE_TRIPS_COLLECTION = 'SCHEDULE_TRIPS';
/**
 * Helper function to mark trips with orderDeleted flag when order is deleted
 * This is for audit purposes only - trips remain independent and functional
 *
 * @param orderId - The order ID
 * @param deletedBy - User who deleted the order
 * @param tripsSnapshot - Optional pre-fetched trips snapshot (to avoid race conditions)
 */
async function markTripsAsOrderDeleted(orderId, deletedBy, tripsSnapshot) {
    try {
        // Use provided snapshot or fetch new one
        let tripsToMark;
        if (tripsSnapshot) {
            tripsToMark = tripsSnapshot.docs;
        }
        else {
            const fetchedSnapshot = await db
                .collection(SCHEDULE_TRIPS_COLLECTION)
                .where('orderId', '==', orderId)
                .get();
            tripsToMark = fetchedSnapshot.docs;
        }
        if (tripsToMark.length === 0) {
            console.log('[Order Deletion] No trips to mark', { orderId });
            return;
        }
        console.log('[Order Deletion] Marking trips with orderDeleted flag', {
            orderId,
            tripsCount: tripsToMark.length,
        });
        // Mark trips with orderDeleted flag (for audit, not for deletion)
        // Use allSettled to continue even if some updates fail
        const markingPromises = tripsToMark.map(async (doc) => {
            try {
                // Check if trip still exists before updating
                const tripDoc = await doc.ref.get();
                if (!tripDoc.exists) {
                    console.warn('[Order Deletion] Trip no longer exists, skipping', {
                        orderId,
                        tripId: doc.id,
                    });
                    return;
                }
                await doc.ref.update({
                    orderDeleted: true,
                    orderDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
                    orderDeletedBy: deletedBy || 'system',
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log('[Order Deletion] Marked trip', {
                    orderId,
                    tripId: doc.id,
                });
            }
            catch (updateError) {
                console.error('[Order Deletion] Failed to mark individual trip', {
                    orderId,
                    tripId: doc.id,
                    error: updateError,
                });
                // Continue with other trips
            }
        });
        const markingResults = await Promise.allSettled(markingPromises);
        const successfulMarks = markingResults.filter(r => r.status === 'fulfilled').length;
        const failedMarks = markingResults.filter(r => r.status === 'rejected').length;
        console.log('[Order Deletion] Trip marking results', {
            orderId,
            total: tripsToMark.length,
            successful: successfulMarks,
            failed: failedMarks,
        });
    }
    catch (error) {
        console.error('[Order Deletion] Error marking trips', {
            orderId,
            error,
        });
        // Don't throw - trip marking failure shouldn't block order deletion
    }
}
/**
 * Cloud Function: Triggered when an order is deleted
 * Automatically deletes all associated transactions and marks trips for audit
 */
exports.onOrderDeleted = (0, firestore_1.onDocumentDeleted)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    const orderId = event.params.orderId;
    const snapshot = event.data;
    if (!snapshot)
        return;
    const data = snapshot.data();
    const deletedBy = data === null || data === void 0 ? void 0 : data.deletedBy;
    console.log('[Order Deletion] Processing order deletion', {
        orderId,
        deletedBy,
    });
    // First, get trips count and snapshot BEFORE any operations
    // This ensures we have the trip references even if something fails later
    let tripsSnapshot = null;
    let tripsCount = 0;
    try {
        tripsSnapshot = await db
            .collection(SCHEDULE_TRIPS_COLLECTION)
            .where('orderId', '==', orderId)
            .get();
        tripsCount = tripsSnapshot.size;
        if (tripsCount > 0) {
            console.log('[Order Deletion] Order has scheduled trips - trips will remain independent', {
                orderId,
                tripsCount,
            });
        }
    }
    catch (tripError) {
        console.error('[Order Deletion] Error fetching trips', {
            orderId,
            error: tripError,
        });
        // Continue even if trip fetch fails
    }
    // Process transaction deletion
    try {
        // Find all transactions associated with this order
        const transactionsSnapshot = await db
            .collection(constants_1.TRANSACTIONS_COLLECTION)
            .where('orderId', '==', orderId)
            .get();
        if (transactionsSnapshot.empty) {
            console.log('[Order Deletion] No transactions found for order', {
                orderId,
            });
        }
        else {
            console.log('[Order Deletion] Found transactions to delete', {
                orderId,
                transactionCount: transactionsSnapshot.size,
            });
            // Check if trips exist with active status (scheduled, dispatched, delivered, or returned)
            // If trips exist, preserve advance payment transactions
            let shouldPreserveAdvance = false;
            if (tripsCount > 0 && tripsSnapshot) {
                const activeStatuses = ['scheduled', 'dispatched', 'delivered', 'returned'];
                const hasActiveTrip = tripsSnapshot.docs.some((tripDoc) => {
                    const tripData = tripDoc.data();
                    const tripStatus = tripData.tripStatus || '';
                    return activeStatuses.includes(tripStatus.toLowerCase());
                });
                if (hasActiveTrip) {
                    shouldPreserveAdvance = true;
                    console.log('[Order Deletion] Active trips exist - preserving advance payment transactions', {
                        orderId,
                        tripsCount,
                    });
                }
            }
            // Delete all associated transactions with retry logic
            // This will trigger onTransactionDeleted which will properly revert ledger and analytics
            const deletionPromises = transactionsSnapshot.docs.map(async (txDoc) => {
                const txId = txDoc.id;
                const txData = txDoc.data();
                const txType = txData.type;
                // Preserve advance payment transactions if trips exist
                if (shouldPreserveAdvance && txType === 'advance') {
                    console.log('[Order Deletion] Preserving advance payment transaction', {
                        orderId,
                        transactionId: txId,
                        reason: 'Active trips exist',
                    });
                    return; // Skip deletion
                }
                const currentStatus = txData.status;
                // Retry deletion up to 3 times
                let retries = 0;
                const maxRetries = 3;
                while (retries < maxRetries) {
                    try {
                        await txDoc.ref.delete();
                        console.log('[Order Deletion] Deleted transaction', {
                            orderId,
                            transactionId: txId,
                            previousStatus: currentStatus,
                            retries,
                        });
                        return; // Success
                    }
                    catch (error) {
                        retries++;
                        if (retries >= maxRetries) {
                            console.error('[Order Deletion] Failed to delete transaction after retries', {
                                orderId,
                                transactionId: txId,
                                error,
                                retries,
                            });
                            // Mark transaction for manual cleanup
                            try {
                                await txDoc.ref.update({
                                    needsCleanup: true,
                                    cleanupReason: `Order ${orderId} was deleted but transaction deletion failed`,
                                    cleanupRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
                                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                                });
                            }
                            catch (updateError) {
                                console.error('[Order Deletion] Failed to mark transaction for cleanup', {
                                    orderId,
                                    transactionId: txId,
                                    error: updateError,
                                });
                            }
                            // Don't throw - continue with other transactions
                            return;
                        }
                        // Exponential backoff
                        await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
                        console.warn('[Order Deletion] Retrying transaction deletion', {
                            orderId,
                            transactionId: txId,
                            retry: retries,
                            maxRetries,
                        });
                    }
                }
            });
            // Use Promise.allSettled to continue even if some deletions fail
            const deletionResults = await Promise.allSettled(deletionPromises);
            const successfulDeletions = deletionResults.filter(r => r.status === 'fulfilled').length;
            const failedDeletions = deletionResults.filter(r => r.status === 'rejected').length;
            console.log('[Order Deletion] Transaction deletion results', {
                orderId,
                total: transactionsSnapshot.size,
                successful: successfulDeletions,
                failed: failedDeletions,
            });
        }
    }
    catch (transactionError) {
        console.error('[Order Deletion] Error processing transaction deletion', {
            orderId,
            error: transactionError,
        });
        // Continue to trip marking even if transaction deletion fails
    }
    // Mark trips with orderDeleted flag (for audit trail, not for deletion)
    // This happens AFTER transaction deletion, and even if transaction deletion fails
    if (tripsCount > 0 && tripsSnapshot) {
        try {
            await markTripsAsOrderDeleted(orderId, deletedBy, tripsSnapshot);
        }
        catch (tripMarkingError) {
            console.error('[Order Deletion] Error marking trips', {
                orderId,
                error: tripMarkingError,
            });
            // Don't throw - trip marking failure shouldn't block order deletion
        }
    }
    console.log('[Order Deletion] Successfully processed order deletion', {
        orderId,
        tripsMarked: tripsCount,
    });
});
/**
 * Helper function to generate order number
 * Format: ORD-{YYYY}-{NNN} (e.g., ORD-2024-001)
 */
async function generateOrderNumber(organizationId) {
    const year = new Date().getFullYear();
    const prefix = `ORD-${year}-`;
    try {
        // Query for orders with orderNumber starting with prefix
        // Note: This query requires a composite index on (organizationId, orderNumber)
        // If index doesn't exist, we'll use a simpler approach
        const ordersSnapshot = await db
            .collection(constants_1.PENDING_ORDERS_COLLECTION)
            .where('organizationId', '==', organizationId)
            .where('orderNumber', '>=', prefix)
            .where('orderNumber', '<', `${prefix}Z`)
            .orderBy('orderNumber', 'desc')
            .limit(1)
            .get();
        let nextNumber = 1;
        if (!ordersSnapshot.empty) {
            const lastOrder = ordersSnapshot.docs[0];
            const lastOrderNumber = lastOrder.data().orderNumber;
            if (lastOrderNumber && lastOrderNumber.startsWith(prefix)) {
                const parts = lastOrderNumber.split('-');
                if (parts.length === 3 && parts[2]) {
                    const lastSequence = parseInt(parts[2], 10);
                    if (!isNaN(lastSequence) && lastSequence > 0) {
                        nextNumber = lastSequence + 1;
                    }
                }
            }
        }
        return `${prefix}${String(nextNumber).padStart(3, '0')}`;
    }
    catch (error) {
        // If query fails (e.g., missing index), use timestamp-based fallback
        if (error.code === 'failed-precondition') {
            console.warn('[Order Number] Index missing, using timestamp-based fallback', { organizationId });
            const timestamp = Date.now();
            return `${prefix}${String(timestamp % 1000).padStart(3, '0')}`;
        }
        throw error;
    }
}
/**
 * Cloud Function: Triggered when an order is created
 * Generates order number and creates advance transaction if advance payment was provided
 */
exports.onPendingOrderCreated = (0, firestore_1.onDocumentCreated)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.STANDARD_TRIGGER_OPTS), async (event) => {
    var _a;
    const snapshot = event.data;
    if (!snapshot)
        return;
    const orderId = event.params.orderId;
    const orderData = snapshot.data();
    const organizationId = orderData.organizationId;
    // Idempotency: skip if advance transaction already created for this order
    const existingAdvance = await db
        .collection(constants_1.TRANSACTIONS_COLLECTION)
        .where('orderId', '==', orderId)
        .where('category', '==', 'advance')
        .limit(1)
        .get();
    if (!existingAdvance.empty) {
        console.log('[Order Created] Advance transaction already exists, skipping', { orderId });
        return;
    }
    // Generate order number if not already set
    let orderNumber = orderData.orderNumber;
    if (!orderNumber || orderNumber.trim() === '') {
        try {
            orderNumber = await generateOrderNumber(organizationId);
            await snapshot.ref.update({
                orderNumber: orderNumber,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log('[Order Created] Generated order number', {
                orderId,
                orderNumber,
            });
        }
        catch (error) {
            console.error('[Order Created] Failed to generate order number', {
                orderId,
                error,
            });
            // Continue execution even if order number generation fails
        }
    }
    else {
        orderNumber = orderData.orderNumber;
    }
    const advanceAmount = orderData.advanceAmount || 0;
    // Only create transaction if advance amount > 0
    if (!advanceAmount || advanceAmount <= 0) {
        console.log('[Order Created] No advance payment, skipping transaction creation', {
            orderId,
            orderNumber,
        });
        return;
    }
    const clientId = orderData.clientId;
    const totalAmount = (_a = orderData.pricing) === null || _a === void 0 ? void 0 : _a.totalAmount;
    const remainingAmount = orderData.remainingAmount ||
        (totalAmount ? totalAmount - advanceAmount : undefined);
    const advancePaymentAccountId = orderData.advancePaymentAccountId || 'cash';
    const createdBy = orderData.createdBy || 'system';
    // Validate required fields
    if (!organizationId || !clientId) {
        console.error('[Order Created] Missing required fields for advance transaction', {
            orderId,
            organizationId,
            clientId,
        });
        // Mark order with error flag
        await snapshot.ref.update({
            advanceTransactionError: 'Missing required fields: organizationId or clientId',
            advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
    }
    // Validate advance amount doesn't exceed total
    if (totalAmount && advanceAmount > totalAmount) {
        console.error('[Order Created] Advance amount exceeds order total', {
            orderId,
            advanceAmount,
            totalAmount,
        });
        // Mark order with error flag
        await snapshot.ref.update({
            advanceTransactionError: `Advance amount (${advanceAmount}) exceeds order total (${totalAmount})`,
            advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
    }
    try {
        // Get payment account type if payment account ID is provided
        let paymentAccountType = 'cash';
        if (advancePaymentAccountId && advancePaymentAccountId !== 'cash') {
            try {
                // Fetch payment account details from ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS
                const accountRef = db
                    .collection('ORGANIZATIONS')
                    .doc(organizationId)
                    .collection('PAYMENT_ACCOUNTS')
                    .doc(advancePaymentAccountId);
                const accountDoc = await accountRef.get();
                if (!accountDoc.exists) {
                    console.error('[Order Created] Payment account not found', {
                        orderId,
                        advancePaymentAccountId,
                    });
                    await snapshot.ref.update({
                        advanceTransactionError: `Payment account ${advancePaymentAccountId} not found`,
                        advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    return;
                }
                const accountData = accountDoc.data();
                // Validate account is active
                if ((accountData === null || accountData === void 0 ? void 0 : accountData.isActive) === false) {
                    console.error('[Order Created] Payment account is inactive', {
                        orderId,
                        advancePaymentAccountId,
                    });
                    await snapshot.ref.update({
                        advanceTransactionError: `Payment account ${advancePaymentAccountId} is inactive`,
                        advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    return;
                }
                paymentAccountType = (accountData === null || accountData === void 0 ? void 0 : accountData.type) || 'other';
            }
            catch (error) {
                console.error('[Order Created] Error validating payment account', {
                    orderId,
                    advancePaymentAccountId,
                    error,
                });
                await snapshot.ref.update({
                    advanceTransactionError: `Error validating payment account: ${error instanceof Error ? error.message : String(error)}`,
                    advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                return;
            }
        }
        // Calculate financial year
        const now = new Date();
        const { fyLabel: financialYear } = (0, financial_year_1.getFinancialContext)(now);
        // Create advance transaction with retry logic
        let retries = 0;
        const maxRetries = 3;
        let transactionCreated = false;
        let transactionRef = null;
        const transactionData = {
            organizationId,
            clientId,
            ledgerType: 'clientLedger',
            type: 'debit', // Debit = client paid upfront (decreases receivable)
            category: 'advance', // Advance payment on order
            amount: advanceAmount,
            paymentAccountId: advancePaymentAccountId,
            paymentAccountType: paymentAccountType,
            orderId: orderId,
            description: `Advance payment for order ${orderNumber || orderId}`,
            metadata: {
                orderTotal: totalAmount || 0,
                advanceAmount,
                remainingAmount: remainingAmount || 0,
            },
            createdBy: createdBy,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            financialYear: financialYear,
        };
        while (retries < maxRetries && !transactionCreated) {
            try {
                transactionRef = db.collection(constants_1.TRANSACTIONS_COLLECTION).doc();
                await transactionRef.set(transactionData);
                transactionCreated = true;
                console.log('[Order Created] Successfully created advance transaction', {
                    orderId,
                    transactionId: transactionRef.id,
                    advanceAmount,
                    financialYear,
                    retries,
                });
            }
            catch (error) {
                retries++;
                if (retries >= maxRetries) {
                    console.error('[Order Created] Failed to create advance transaction after retries', {
                        orderId,
                        error,
                        retries,
                    });
                    // Mark order with error flag for manual retry
                    await snapshot.ref.update({
                        advanceTransactionFailed: true,
                        advanceTransactionError: error instanceof Error ? error.message : String(error),
                        advanceTransactionRetries: retries,
                        advanceTransactionFailedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                    break;
                }
                // Exponential backoff
                await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
                console.warn('[Order Created] Retrying advance transaction creation', {
                    orderId,
                    retry: retries,
                    maxRetries,
                });
            }
        }
    }
    catch (error) {
        console.error('[Order Created] Error creating advance transaction', {
            orderId,
            error,
        });
        // Mark order with error flag
        try {
            await snapshot.ref.update({
                advanceTransactionFailed: true,
                advanceTransactionError: error instanceof Error ? error.message : String(error),
                advanceTransactionFailedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (updateError) {
            console.error('[Order Created] Failed to mark order with error flag', {
                orderId,
                error: updateError,
            });
        }
        // Don't throw - we don't want to block order creation if transaction creation fails
        // The transaction can be created manually if needed
    }
});
/**
 * Cloud Function: Triggered when an order is updated
 * Cleans up auto-schedule data if order is cancelled
 */
exports.onOrderUpdated = (0, firestore_1.onDocumentUpdated)(Object.assign({ document: `${constants_1.PENDING_ORDERS_COLLECTION}/{orderId}` }, function_config_1.LIGHT_TRIGGER_OPTS), async (event) => {
    var _a, _b, _c;
    const orderId = event.params.orderId;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const afterRef = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after.ref;
    if (!before || !after || !afterRef)
        return;
    const beforeStatus = before.status || 'pending';
    const afterStatus = after.status || 'pending';
    // Only process if status changed to cancelled
    if (beforeStatus !== 'cancelled' && afterStatus === 'cancelled') {
        console.log('[Order Update] Order cancelled, cleaning up auto-schedule data', {
            orderId,
            previousStatus: beforeStatus,
        });
        try {
            await afterRef.update({
                autoSchedule: admin.firestore.FieldValue.delete(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log('[Order Update] Successfully cleaned up auto-schedule data', {
                orderId,
            });
        }
        catch (error) {
            console.error('[Order Update] Error cleaning up auto-schedule data', {
                orderId,
                error,
            });
        }
    }
});
//# sourceMappingURL=order-handlers.js.map