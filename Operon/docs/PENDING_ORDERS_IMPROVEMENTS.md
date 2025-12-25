# Pending Orders Handling - Required Changes

## Overview

Based on the comprehensive flow analysis, this document outlines all required changes for Pending Orders Handling, with special attention to the fact that **scheduled trips remain independent when orders are deleted**.

---

## 1. ORDER DELETION (`onOrderDeleted`)

### Current Implementation
- ✅ Deletes all transactions associated with order
- ✅ Transactions properly trigger `onTransactionDeleted` to revert ledger
- ✅ Scheduled trips are NOT deleted (correct behavior - trips are independent)

### Required Changes

#### 1.1 Add Validation for Advance Amount
**Priority:** High  
**Location:** `functions/src/orders/order-handlers.ts` - `onPendingOrderCreated`

**Change:**
```typescript
// Add validation before creating advance transaction
if (advanceAmount > totalAmount) {
  console.error('[Order Created] Advance amount exceeds order total', {
    orderId,
    advanceAmount,
    totalAmount,
  });
  // Mark order with error flag for manual review
  await snapshot.ref.update({
    advanceTransactionError: 'Advance amount exceeds order total',
    advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return; // Don't create transaction
}
```

#### 1.2 Add Trip Audit Marking (Optional but Recommended)
**Priority:** Medium  
**Location:** `functions/src/orders/order-handlers.ts` - `onOrderDeleted`

**Change:**
```typescript
// After deleting transactions, optionally mark trips for audit
try {
  const tripsSnapshot = await db
    .collection('SCHEDULE_TRIPS')
    .where('orderId', '==', orderId)
    .get();

  if (!tripsSnapshot.empty) {
    console.log('[Order Deletion] Marking trips with orderDeleted flag', {
      orderId,
      tripsCount: tripsSnapshot.size,
    });

    // Mark trips with orderDeleted flag (for audit, not for deletion)
    const markingPromises = tripsSnapshot.docs.map(async (doc) => {
      await doc.ref.update({
        orderDeleted: true,
        orderDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
        orderDeletedBy: deletedBy || 'system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await Promise.all(markingPromises);

    console.log('[Order Deletion] Successfully marked trips', {
      orderId,
      tripsMarked: tripsSnapshot.size,
    });
  }
} catch (tripError) {
  console.error('[Order Deletion] Error marking trips', {
    orderId,
    error: tripError,
  });
  // Don't throw - trip marking failure shouldn't block order deletion
}
```

#### 1.3 Add Informational Logging
**Priority:** Low  
**Location:** `functions/src/orders/order-handlers.ts` - `onOrderDeleted`

**Change:**
```typescript
// At the start of onOrderDeleted, check for trips
const tripsCountSnapshot = await db
  .collection('SCHEDULE_TRIPS')
  .where('orderId', '==', orderId)
  .count()
  .get();

const tripsCount = tripsCountSnapshot.data().count;

if (tripsCount > 0) {
  console.log('[Order Deletion] Order has scheduled trips - trips will remain independent', {
    orderId,
    tripsCount,
  });
}
```

#### 1.4 Improve Error Handling for Transaction Deletion
**Priority:** Medium  
**Location:** `functions/src/orders/order-handlers.ts` - `onOrderDeleted`

**Change:**
```typescript
// Add retry logic for transaction deletion
const deletionPromises = transactionsSnapshot.docs.map(async (txDoc) => {
  const txId = txDoc.id;
  const txData = txDoc.data();
  const currentStatus = txData.status as string;

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
    } catch (error) {
      retries++;
      if (retries >= maxRetries) {
        console.error('[Order Deletion] Failed to delete transaction after retries', {
          orderId,
          transactionId: txId,
          error,
          retries,
        });
        // Mark transaction for manual cleanup
        await txDoc.ref.update({
          needsCleanup: true,
          cleanupReason: `Order ${orderId} was deleted but transaction deletion failed`,
          cleanupRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        throw error;
      }
      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));
    }
  }
});
```

---

## 2. ORDER CREATION (`onPendingOrderCreated`)

### Current Implementation
- ✅ Creates advance transaction if advance amount > 0
- ✅ Fetches payment account type
- ⚠️ Missing validation
- ⚠️ No retry logic

### Required Changes

#### 2.1 Add Validation
**Priority:** High  
**Location:** `functions/src/orders/order-handlers.ts` - `onPendingOrderCreated`

**Change:**
```typescript
// Add validation after checking advanceAmount > 0
if (advanceAmount > 0) {
  // Validate advance amount doesn't exceed total
  if (totalAmount && advanceAmount > totalAmount) {
    console.error('[Order Created] Advance amount exceeds order total', {
      orderId,
      advanceAmount,
      totalAmount,
    });
    
    // Mark order with error flag
    await snapshot.ref.update({
      advanceTransactionError: 'Advance amount exceeds order total',
      advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return; // Don't create transaction
  }

  // Validate required fields
  if (!organizationId || !clientId) {
    console.error('[Order Created] Missing required fields for advance transaction', {
      orderId,
      organizationId,
      clientId,
    });
    return;
  }

  // Continue with transaction creation...
}
```

#### 2.2 Add Retry Logic for Transaction Creation
**Priority:** Medium  
**Location:** `functions/src/orders/order-handlers.ts` - `onPendingOrderCreated`

**Change:**
```typescript
// Wrap transaction creation in retry logic
let retries = 0;
const maxRetries = 3;
let transactionCreated = false;

while (retries < maxRetries && !transactionCreated) {
  try {
    const transactionRef = db.collection(TRANSACTIONS_COLLECTION).doc();
    await transactionRef.set(transactionData);
    
    transactionCreated = true;
    
    console.log('[Order Created] Successfully created advance transaction', {
      orderId,
      transactionId: transactionRef.id,
      advanceAmount,
      financialYear,
      retries,
    });
  } catch (error) {
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
```

#### 2.3 Add Validation for Payment Account
**Priority:** Medium  
**Location:** `functions/src/orders/order-handlers.ts` - `onPendingOrderCreated`

**Change:**
```typescript
// Validate payment account exists and is active
if (advancePaymentAccountId && advancePaymentAccountId !== 'cash') {
  try {
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
    if (accountData?.isActive === false) {
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
    
    paymentAccountType = (accountData?.type as string) || 'other';
  } catch (error) {
    console.error('[Order Created] Error validating payment account', {
      orderId,
      advancePaymentAccountId,
      error,
    });
    // Mark order with error
    await snapshot.ref.update({
      advanceTransactionError: `Error validating payment account: ${error instanceof Error ? error.message : String(error)}`,
      advanceTransactionErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }
}
```

---

## 3. ORDER UPDATE (`onOrderUpdated`)

### Current Implementation
- ✅ Cleans up auto-schedule data when order is cancelled
- ⚠️ Only handles status change to 'cancelled'
- ⚠️ Doesn't handle order deletion scenario

### Required Changes

#### 3.1 Improve Trip Status Update Handling
**Priority:** Medium  
**Location:** `functions/src/orders/trip-status-update.ts` - `onTripStatusUpdated`

**Change:**
```typescript
// In onTripStatusUpdated, improve handling when order doesn't exist
if (!orderDoc.exists) {
  console.log('[Trip Status Update] Order not found - trip is independent', {
    orderId,
    tripId,
    newStatus: afterStatus,
  });
  
  // Trip can continue independently - this is correct behavior
  // Don't try to update non-existent order
  return;
}
```

#### 3.2 Add Order Status Validation
**Priority:** Low  
**Location:** `functions/src/orders/trip-status-update.ts` - `onTripStatusUpdated`

**Change:**
```typescript
// Check if order is cancelled before updating
const orderStatus = orderData.status as string;
if (orderStatus === 'cancelled') {
  console.log('[Trip Status Update] Order is cancelled - trip is independent', {
    orderId,
    tripId,
    newStatus: afterStatus,
  });
  
  // Trip can continue independently even if order is cancelled
  // Don't update cancelled order
  return;
}
```

---

## 4. TRIP DELETION HANDLING

### Current Implementation
- ✅ Handles missing order gracefully
- ⚠️ Could improve logging

### Required Changes

#### 4.1 Improve Logging When Order Doesn't Exist
**Priority:** Low  
**Location:** `functions/src/orders/trip-scheduling.ts` - `onScheduledTripDeleted`

**Change:**
```typescript
// In onScheduledTripDeleted, improve logging when order doesn't exist
if (!orderDoc.exists) {
  console.log('[Trip Cancellation] Order already deleted - trip is independent', {
    orderId,
    tripId,
  });
  
  // Trip deletion succeeds - this is correct behavior
  // The trip was independent, so no order update needed
  return;
}
```

---

## 5. SUMMARY OF CHANGES

### High Priority (Must Do)
1. ✅ Add validation for advance amount ≤ total amount
2. ✅ Add validation for payment account existence and active status
3. ✅ Add retry logic for transaction creation/deletion

### Medium Priority (Should Do)
4. ✅ Mark trips with `orderDeleted` flag when order is deleted (audit trail)
5. ✅ Improve error handling with retry logic
6. ✅ Add informational logging for trips when order is deleted

### Low Priority (Nice to Have)
7. ✅ Improve logging in trip status updates when order doesn't exist
8. ✅ Add order status validation in trip status updates

---

## 6. IMPLEMENTATION CHECKLIST

- [ ] Add advance amount validation in `onPendingOrderCreated`
- [ ] Add payment account validation in `onPendingOrderCreated`
- [ ] Add retry logic for transaction creation in `onPendingOrderCreated`
- [ ] Add trip marking in `onOrderDeleted` (optional audit trail)
- [ ] Add informational logging in `onOrderDeleted`
- [ ] Add retry logic for transaction deletion in `onOrderDeleted`
- [ ] Improve logging in `onTripStatusUpdated` when order doesn't exist
- [ ] Improve logging in `onScheduledTripDeleted` when order doesn't exist
- [ ] Test order deletion with scheduled trips
- [ ] Test order deletion with dispatched/delivered/returned trips
- [ ] Test advance transaction creation with invalid amounts
- [ ] Test advance transaction creation with invalid payment accounts

---

## 7. TESTING SCENARIOS

### Scenario 1: Order Deletion with Scheduled Trips
1. Create order
2. Schedule trip
3. Delete order
4. **Expected:** Order deleted, transactions deleted, trip remains with `orderDeleted: true` flag

### Scenario 2: Order Deletion with Dispatched Trip
1. Create order
2. Schedule trip
3. Dispatch trip
4. Delete order
5. **Expected:** Order deleted, transactions deleted, trip remains independent and can continue to delivery/return

### Scenario 3: Advance Amount Validation
1. Create order with advance amount > total amount
2. **Expected:** Order created, but advance transaction NOT created, order marked with error flag

### Scenario 4: Invalid Payment Account
1. Create order with non-existent payment account ID
2. **Expected:** Order created, but advance transaction NOT created, order marked with error flag

### Scenario 5: Trip Status Update When Order Deleted
1. Create order
2. Schedule trip
3. Delete order
4. Update trip status to dispatched
5. **Expected:** Trip status updated successfully, order update skipped (order doesn't exist)

---

## 8. NOTES

- **Trips remain independent:** This is correct behavior and should NOT be changed
- **Audit trail:** Marking trips with `orderDeleted` flag is optional but recommended for audit purposes
- **Error handling:** All changes should include proper error handling and logging
- **Non-blocking:** Order deletion should never be blocked by trip-related operations
- **Retry logic:** All external operations (transaction creation/deletion) should have retry logic





