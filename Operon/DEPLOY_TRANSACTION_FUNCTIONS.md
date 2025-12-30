# Deploy Transaction Functions - URGENT FIX

## Issue
Credit transactions are calculating balance incorrectly: `balanceAfter = -25000` when it should be `0` for a credit of `12500` with `balanceBefore = -12500`.

## Functions to Deploy

1. `onTransactionCreated` - Handles transaction creation and updates client ledger/analytics
2. `onTransactionDeleted` - Handles transaction deletion (cancellations) and reverses ledger/analytics

## Deployment Command

```bash
cd functions
npm run build
firebase deploy --only functions:onTransactionCreated,functions:onTransactionDeleted
```

**IMPORTANT**: Make sure the deployment completes successfully. Check the deployment logs.

## What Changed

### Added Debug Logging:
1. Added detailed logging in `getLedgerDelta()` to track calculation
2. Added detailed logging in `onTransactionCreated` to track balance calculation

### Code Logic (should be correct):
- `getLedgerDelta("clientLedger", "credit", amount)` returns `+amount` (increment)
- `getLedgerDelta("clientLedger", "debit", amount)` returns `-amount` (decrement)
- `balanceAfter = balanceBefore + ledgerDelta`

## After Deployment - Check Logs

1. Generate a new DM from web app
2. Check Cloud Functions logs for:
   - `[Transaction] getLedgerDelta calculation` - should show `delta: 12500` for credit
   - `[Transaction] Balance calculation debug` - should show correct calculation
3. Verify in Firestore:
   - Transaction document `balanceAfter` should be correct
   - Client ledger `currentBalance` should match

## Expected Calculation

For the example:
- `amount`: 12500
- `type`: "credit"
- `ledgerType`: "clientLedger"
- `balanceBefore`: -12500

Expected:
- `ledgerDelta` = `+12500` (credit = increment)
- `balanceAfter` = `-12500 + 12500` = `0`

If still showing `-25000`, the logs will show what `getLedgerDelta` is actually returning.



