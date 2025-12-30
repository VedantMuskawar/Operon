# Balance Calculation Issue

## Problem
For a credit transaction of 12500, `currentBalance` is `-12500` instead of `+12500`.

## Expected Calculation
- Transaction: `type = "credit"`, `amount = 12500`, `ledgerType = "clientLedger"`
- `getLedgerDelta("clientLedger", "credit", 12500)` should return `+12500`
- `currentBalance = openingBalance + (ledgerDelta * multiplier) = 0 + (12500 * 1) = 12500`

## Actual Result
- `currentBalance = -12500` (wrong!)
- This suggests `ledgerDelta = -12500` (wrong!)

## Debug Steps

1. **Check Cloud Functions logs** for the transaction ID `mGyyxpGgAc088866qxKt`:
   - Look for `[Transaction] getLedgerDelta calculation` log
   - It should show: `delta: 12500` for credit
   - If it shows `delta: -12500`, the deployed code is still wrong

2. **Verify the deployed code** matches the source:
   ```bash
   cd functions
   npm run build
   # Check lib/transactions/transaction-handlers.js around line 126
   # Should show: return type === 'credit' ? amount : -amount;
   ```

3. **If logs show correct delta but balance is wrong**, check:
   - Line 241: `currentBalance = openingBalance + (ledgerDelta * multiplier)`
   - `multiplier` should be `1` for creation (not cancellation)
   - Verify `ledgerDelta` is actually being used, not `-amount` directly

## Next Steps
1. Deploy again with explicit logging
2. Check logs immediately after generating a DM
3. Share the log output showing the delta calculation



