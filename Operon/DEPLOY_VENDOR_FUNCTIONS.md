# Deploy Vendor Functions

## Functions to Deploy

1. `onVendorCreated` - Auto-generates vendor code, creates initial ledger, updates search indexes
2. `onVendorUpdated` - Validates updates, prevents invalid changes (openingBalance, vendorCode, status with balance)

## Deployment Command

```bash
cd functions
npm run build
firebase deploy --only functions:onVendorCreated,functions:onVendorUpdated
```

**Alternative (deploy all functions):**
```bash
cd functions
npm run build
firebase deploy --only functions
```

## What These Functions Do

### `onVendorCreated`
- Auto-generates vendor code in format: `VND-{YYYY}-{NNN}` (e.g., "VND-2024-001")
- Creates initial vendor ledger for current financial year
- Updates search indexes (`name_lowercase`, `phoneIndex`)
- Normalizes phone numbers for search

### `onVendorUpdated`
- Updates search indexes when name or phones change
- **Prevents** `openingBalance` updates (reverts if attempted)
- **Prevents** `vendorCode` updates (reverts if attempted)
- **Validates** status changes - prevents delete/suspend if `currentBalance !== 0`
- Updates `updatedAt` timestamp

## After Deployment - Verify

1. Create a new vendor from the app
2. Check Cloud Functions logs for:
   - `[Vendor] Generated vendor code` - should show generated code
   - `[Vendor Ledger] Created ledger` - should show ledger creation
   - `[Vendor] Vendor created successfully` - confirmation
3. Verify in Firestore:
   - Vendor document should have `vendorCode` set (e.g., "VND-2024-001")
   - `VENDOR_LEDGERS` collection should have a new document with `ledgerId = {vendorId}_{financialYear}`
   - Search indexes (`name_lowercase`, `phoneIndex`) should be populated

## Testing Status Validation

1. Create a vendor with opening balance = 0
2. Try to delete the vendor - should succeed
3. Create a vendor with opening balance = 1000
4. Try to delete the vendor - should fail with error message
5. Make a payment transaction to set balance to 0
6. Try to delete again - should succeed

## Testing Update Validation

1. Create a vendor
2. Try to update `openingBalance` - should be reverted by Cloud Function
3. Try to update `vendorCode` - should be reverted by Cloud Function
4. Try to change status to "deleted" with non-zero balance - should be reverted




