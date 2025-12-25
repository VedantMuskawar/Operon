# Testing Guide: Pending Orders Handling Improvements

## Overview

This guide provides step-by-step testing procedures for all the improvements made to Pending Orders Handling.

---

## Pre-Testing Setup

### Option 1: Test with Firebase Emulator (Recommended for Local Testing)

```bash
cd functions
npm run serve
```

This will start the Firebase emulators. You can then test Cloud Functions locally.

### Option 2: Deploy to Development/Staging Environment

```bash
cd functions
npm run deploy
```

---

## Test Scenarios

### Test 1: Order Creation with Valid Advance Payment

**Objective:** Verify advance transaction is created successfully with retry logic.

**Steps:**
1. Create a new order with:
   - Items: Any product
   - Advance Payment: ₹1000 (less than order total)
   - Payment Account: Cash or valid payment account
2. Check Firestore:
   - `PENDING_ORDERS/{orderId}` should exist
   - `TRANSACTIONS/{transactionId}` should exist with:
     - `type: 'advance'`
     - `amount: 1000`
     - `orderId: {orderId}`
   - `CLIENT_LEDGERS/{clientId}_{financialYear}` should have:
     - `currentBalance` updated (decreased by 1000)
     - Transaction in subcollection

**Expected Result:**
- ✅ Order created
- ✅ Advance transaction created
- ✅ Ledger updated correctly
- ✅ No error flags on order

**Check Logs:**
```
[Order Created] Successfully created advance transaction
```

---

### Test 2: Order Creation with Invalid Advance Amount

**Objective:** Verify validation prevents advance amount exceeding order total.

**Steps:**
1. Create a new order with:
   - Items: Product with total ₹5000
   - Advance Payment: ₹6000 (exceeds total)
   - Payment Account: Cash
2. Check Firestore:
   - `PENDING_ORDERS/{orderId}` should exist
   - `PENDING_ORDERS/{orderId}` should have:
     - `advanceTransactionError: "Advance amount (6000) exceeds order total (5000)"`
     - `advanceTransactionErrorAt: {timestamp}`
   - `TRANSACTIONS` collection should NOT have a transaction for this order

**Expected Result:**
- ✅ Order created
- ❌ Advance transaction NOT created
- ✅ Order marked with error flag
- ✅ Ledger NOT updated

**Check Logs:**
```
[Order Created] Advance amount exceeds order total
```

---

### Test 3: Order Creation with Invalid Payment Account

**Objective:** Verify validation prevents using non-existent or inactive payment accounts.

**Steps:**
1. Create a new order with:
   - Items: Any product
   - Advance Payment: ₹1000
   - Payment Account: Non-existent account ID (e.g., "invalid-account-123")
2. Check Firestore:
   - `PENDING_ORDERS/{orderId}` should exist
   - `PENDING_ORDERS/{orderId}` should have:
     - `advanceTransactionError: "Payment account invalid-account-123 not found"`
     - `advanceTransactionErrorAt: {timestamp}`
   - `TRANSACTIONS` collection should NOT have a transaction for this order

**Expected Result:**
- ✅ Order created
- ❌ Advance transaction NOT created
- ✅ Order marked with error flag

**Check Logs:**
```
[Order Created] Payment account not found
```

---

### Test 4: Order Creation with Inactive Payment Account

**Objective:** Verify validation prevents using inactive payment accounts.

**Steps:**
1. Create or find a payment account and set `isActive: false`
2. Create a new order with:
   - Items: Any product
   - Advance Payment: ₹1000
   - Payment Account: The inactive account ID
3. Check Firestore:
   - `PENDING_ORDERS/{orderId}` should have:
     - `advanceTransactionError: "Payment account {accountId} is inactive"`
   - `TRANSACTIONS` collection should NOT have a transaction for this order

**Expected Result:**
- ✅ Order created
- ❌ Advance transaction NOT created
- ✅ Order marked with error flag

---

### Test 5: Order Deletion with Scheduled Trips

**Objective:** Verify trips are marked with `orderDeleted` flag but remain functional.

**Steps:**
1. Create an order
2. Schedule a trip for that order
3. Delete the order
4. Check Firestore:
   - `PENDING_ORDERS/{orderId}` should NOT exist (deleted)
   - `SCHEDULE_TRIPS/{tripId}` should exist with:
     - `orderDeleted: true`
     - `orderDeletedAt: {timestamp}`
     - `orderDeletedBy: {userId or 'system'}`
   - Trip should still be functional (can be dispatched, delivered, returned)

**Expected Result:**
- ✅ Order deleted
- ✅ Trip marked with `orderDeleted: true`
- ✅ Trip remains functional
- ✅ Trip can continue through dispatch → delivery → return flow

**Check Logs:**
```
[Order Deletion] Order has scheduled trips - trips will remain independent
[Order Deletion] Marking trips with orderDeleted flag
[Order Deletion] Successfully marked trips
```

---

### Test 6: Order Deletion with Transactions

**Objective:** Verify transactions are deleted with retry logic.

**Steps:**
1. Create an order with advance payment (creates advance transaction)
2. Delete the order
3. Check Firestore:
   - `TRANSACTIONS/{transactionId}` should NOT exist (deleted)
   - `CLIENT_LEDGERS/{clientId}_{financialYear}` should have:
     - `currentBalance` reverted (increased by advance amount)
     - Transaction removed from subcollection
   - Check logs for retry attempts if deletion fails

**Expected Result:**
- ✅ Order deleted
- ✅ Transactions deleted
- ✅ Ledger reverted correctly
- ✅ Analytics reverted correctly

**Check Logs:**
```
[Order Deletion] Deleted transaction
[Transaction] Successfully processed transaction deletion
```

---

### Test 7: Order Deletion with Dispatched Trip

**Objective:** Verify dispatched trips remain functional when order is deleted.

**Steps:**
1. Create an order
2. Schedule a trip
3. Dispatch the trip (enter initial reading)
4. Delete the order
5. Verify:
   - Trip still exists with `orderDeleted: true`
   - Trip status is still `dispatched`
   - Trip can continue to delivery → return

**Expected Result:**
- ✅ Order deleted
- ✅ Trip marked with `orderDeleted: true`
- ✅ Trip remains in dispatched status
- ✅ Trip can proceed to delivery and return

---

### Test 8: Trip Status Update When Order Deleted

**Objective:** Verify trip status updates work when order doesn't exist.

**Steps:**
1. Create an order
2. Schedule a trip
3. Delete the order
4. Update trip status to `dispatched` (enter initial reading)
5. Check logs:
   - Should log: `[Trip Status Update] Order not found - trip is independent`
   - Trip status should update successfully
   - Order's `scheduledTrips` array should NOT be updated (order doesn't exist)

**Expected Result:**
- ✅ Trip status updated successfully
- ✅ No errors thrown
- ✅ Trip continues independently

**Check Logs:**
```
[Trip Status Update] Order not found - trip is independent
```

---

### Test 9: Trip Status Update When Order Cancelled

**Objective:** Verify trip status updates work when order is cancelled.

**Steps:**
1. Create an order
2. Schedule a trip
3. Cancel the order (set status to 'cancelled')
4. Update trip status to `dispatched`
5. Check logs:
   - Should log: `[Trip Status Update] Order is cancelled - trip is independent`
   - Trip status should update successfully

**Expected Result:**
- ✅ Trip status updated successfully
- ✅ No errors thrown
- ✅ Trip continues independently

---

### Test 10: Trip Deletion When Order Deleted

**Objective:** Verify trip deletion works when order doesn't exist.

**Steps:**
1. Create an order
2. Schedule a trip
3. Delete the order
4. Delete the trip
5. Check logs:
   - Should log: `[Trip Cancellation] Order already deleted - trip is independent`
   - Trip should be deleted successfully
   - Credit transaction should be deleted (if exists)

**Expected Result:**
- ✅ Trip deleted successfully
- ✅ No errors thrown
- ✅ Credit transaction deleted (if exists)

**Check Logs:**
```
[Trip Cancellation] Order already deleted - trip is independent
```

---

### Test 11: Retry Logic for Transaction Creation

**Objective:** Verify retry logic works when transaction creation fails temporarily.

**Note:** This is difficult to test manually. You can simulate by:
1. Temporarily breaking Firestore permissions
2. Creating an order with advance payment
3. Check logs for retry attempts
4. Restore permissions
5. Verify transaction is created on retry

**Expected Result:**
- ✅ Retry attempts logged
- ✅ Transaction created after successful retry
- ✅ Order marked with error if all retries fail

**Check Logs:**
```
[Order Created] Retrying advance transaction creation
[Order Created] Successfully created advance transaction (retries: 1)
```

---

### Test 12: Retry Logic for Transaction Deletion

**Objective:** Verify retry logic works when transaction deletion fails temporarily.

**Note:** Similar to Test 11, difficult to test manually.

**Expected Result:**
- ✅ Retry attempts logged
- ✅ Transaction deleted after successful retry
- ✅ Transaction marked with `needsCleanup: true` if all retries fail

---

## Manual Testing Checklist

### Order Creation
- [ ] Order with valid advance → transaction created
- [ ] Order with advance > total → error flag set
- [ ] Order with invalid payment account → error flag set
- [ ] Order with inactive payment account → error flag set
- [ ] Order without advance → no transaction created

### Order Deletion
- [ ] Order with transactions → transactions deleted
- [ ] Order with scheduled trips → trips marked with `orderDeleted: true`
- [ ] Order with dispatched trips → trips remain functional
- [ ] Order with delivered trips → trips remain functional
- [ ] Order with returned trips → trips remain functional

### Trip Operations When Order Deleted
- [ ] Trip status update → works independently
- [ ] Trip deletion → works independently
- [ ] Trip dispatch → works independently
- [ ] Trip delivery → works independently
- [ ] Trip return → works independently

### Error Handling
- [ ] Invalid advance amount → order marked with error
- [ ] Invalid payment account → order marked with error
- [ ] Transaction creation failure → order marked with error
- [ ] Transaction deletion failure → transaction marked for cleanup

---

## Verification Queries

### Check Orders with Error Flags
```javascript
// In Firestore Console
db.collection('PENDING_ORDERS')
  .where('advanceTransactionError', '!=', null)
  .get()
```

### Check Trips with Order Deleted Flag
```javascript
// In Firestore Console
db.collection('SCHEDULE_TRIPS')
  .where('orderDeleted', '==', true)
  .get()
```

### Check Transactions Needing Cleanup
```javascript
// In Firestore Console
db.collection('TRANSACTIONS')
  .where('needsCleanup', '==', true)
  .get()
```

### Verify Ledger Balance
```javascript
// In Firestore Console
// Check CLIENT_LEDGERS/{clientId}_{financialYear}
// Verify currentBalance matches sum of transactions
```

---

## Common Issues and Solutions

### Issue: Transaction not created
**Check:**
1. Order document for `advanceTransactionError` field
2. Cloud Function logs for errors
3. Payment account exists and is active

### Issue: Trip not marked with orderDeleted
**Check:**
1. Cloud Function logs for errors
2. Trip query is correct
3. Permissions allow trip updates

### Issue: Ledger balance incorrect
**Check:**
1. All transactions are created/deleted correctly
2. Transaction types are correct
3. Ledger delta calculation is correct

---

## Next Steps After Testing

1. **If all tests pass:** Deploy to production
2. **If tests fail:** Check logs, fix issues, retest
3. **Monitor:** Watch Cloud Function logs for errors
4. **Cleanup:** Periodically check for transactions with `needsCleanup: true`





