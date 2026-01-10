# DELIVERY_MEMOS Migration Run Guide

## Quick Start

To run the DELIVERY_MEMOS migration from Excel to Operon:

```bash
cd migrations/firebase
npm install  # Install xlsx library
npm run migrate-delivery-memos
```

## Prerequisites Checklist

Before running the migration, ensure:

### 1. Dependencies Installed
```bash
cd migrations/firebase
npm install
```

This will install the `xlsx` library for reading Excel files.

### 2. Excel File Prepared
- Excel file should have column headers in the first row
- Column names should match the mappings in `DELIVERY_MEMOS_MIGRATION_MAPPING.md`
- Place file at: `data/delivery-memos.xlsx` (relative to migration script)
- Or set `EXCEL_FILE_PATH` environment variable with full path

### 3. Service Account File
Service account JSON file must be present:
- ✅ `creds/new-service-account.json` - Operon Firebase project service account

### 4. Column Mappings Updated
- Review `DELIVERY_MEMOS_MIGRATION_MAPPING.md` and fill in Excel column names
- Update `transformRow()` function in `migrate-delivery-memos.ts` with your column mappings

### 5. Organization ID (Optional - default is set)
The script uses this default (can be overridden with environment variable):
- **Target Org ID:** `NlQgs9kADbZr4ddBRkhS`

To override, set environment variable:
```bash
export TARGET_ORG_ID=your-target-org-id
npm run migrate-delivery-memos
```

## What the Migration Does

1. **Deletes existing data:** Removes all DELIVERY_MEMOS with `organizationId` matching target org ID from target database
2. **Reads Excel file:** Parses Excel/CSV file and extracts rows
3. **Validates data:** Checks for required fields (scheduledDate, clientName)
4. **Calculates financial year:** Determines FY from scheduledDate
5. **Generates DM numbers:** Auto-generates DM numbers if not provided in Excel
6. **Creates FY documents:** Creates `ORGANIZATIONS/{orgId}/DM/{FY}` documents if needed
7. **Creates DM documents:** Writes to `DELIVERY_MEMOS` collection
8. **Updates FY counters:** Updates `currentDMNumber` in FY documents
9. **Reports results:** Shows count of migrated DMs

## Running the Migration

### Basic Run (uses defaults)
```bash
cd migrations/firebase
npm install
npm run migrate-delivery-memos
```

### With Environment Variables
```bash
cd migrations/firebase
export EXCEL_FILE_PATH=/path/to/your/delivery-memos.xlsx
export EXCEL_SHEET_NAME=Sheet1  # Optional: specify sheet name
export TARGET_ORG_ID=NlQgs9kADbZr4ddBRkhS
export OVERWRITE_EXISTING=false  # Set to true to overwrite existing DMs
export SKIP_INVALID_ROWS=true   # Set to false to stop on invalid rows
npm run migrate-delivery-memos
```

### With Custom Service Account Path
```bash
cd migrations/firebase
export NEW_SERVICE_ACCOUNT=/path/to/new-service-account.json
export EXCEL_FILE_PATH=/path/to/delivery-memos.xlsx
npm run migrate-delivery-memos
```

## Excel File Format

### Supported Formats
- Excel: `.xlsx`, `.xls`
- CSV: `.csv` (rename to `.xlsx` or use CSV reading library)

### Required Columns
Based on the mapping document, ensure these columns exist (or update the script):
- `DATE` (required) - Scheduled date
- `CLIENT` (required) - Client name

### Special Handling: Cancelled DMs

The migration script will create a cancelled DM if either condition is met:

1. **CLIENT column contains "CANCAL D M"** (case-insensitive)
2. **Unit column equals "1"**

When a cancelled DM is detected:
- Create a DeliveryMemo with `status: 'cancelled'`
- Set `clientName` to "Cancelled DM" (if cancelled by CLIENT column)
- Add `cancelledAt`, `cancelledBy`, and `cancellationReason` fields
- Still generate DM number and create the document (for record-keeping)
- Still calculate pricing based on Unit and Quantity values

This allows you to migrate cancelled DMs from Excel while maintaining their cancelled status.

### Items and Pricing Calculation

Items are automatically parsed from Excel columns:
- **Product**: Product name. If contains "BRICKS", productName = "Bricks" and productId = "1765277893839"
- **Quantity**: Maps to `fixedQuantityPerTrip` in items array
- **Unit**: Maps to `unitPrice` in items array. If Unit = "1", also marks DM as cancelled

Pricing is automatically calculated:
- `tripPricing.subtotal` = unitPrice × fixedQuantityPerTrip
- `tripPricing.total` = unitPrice × fixedQuantityPerTrip
- `pricing.subtotal` = unitPrice × fixedQuantityPerTrip
- `pricing.totalAmount` = unitPrice × fixedQuantityPerTrip
- `pricing.currency` = "INR" (fixed)

### Example Excel Structure
```
| DATE       | CLIENT    | DM_NO | VehicleNO | Product | Quantity | Unit | ...
|------------|-----------|-------|-----------|---------|----------|------|----
| 2024-01-15 | ABC Corp  | 1     | MH12AB1234| BRICKS  | 100      | 50   | ...
| 2024-01-16 | XYZ Ltd   | 2     | MH12AB1235| BRICKS  | 150      | 45   | ...
| 2024-01-17 | CANCAL D M| 3     | MH12AB1236| BRICKS  | 200      | 1    | ... (cancelled)
```

## Expected Output

```
=== Migrating DELIVERY_MEMOS from Excel ===
Excel file: /path/to/delivery-memos.xlsx
Sheet: First sheet
Target Org ID: NlQgs9kADbZr4ddBRkhS
Overwrite existing: false
Skip invalid rows: true

Reading Excel file...
Found 150 rows in Excel file

Committed 400 delivery memo docs...
Committed 800 delivery memo docs...

Updating financial year documents...
Updated FY2425: currentDMNumber = 150

=== Migration Complete ===
Total rows processed: 150
Skipped 0 invalid rows
Skipped 0 existing DMs (use OVERWRITE_EXISTING=true to overwrite)
```

## Troubleshooting

### Error: Excel file not found
- Ensure Excel file is at `data/delivery-memos.xlsx`
- Or set `EXCEL_FILE_PATH` environment variable with full path
- Check file permissions

### Error: Service account file not found
- Ensure service account JSON file is in `creds/new-service-account.json`
- Or set `NEW_SERVICE_ACCOUNT` environment variable
- Verify file has Firestore read/write permissions

### Error: Column not found
- Check that Excel column names match the mappings in the script
- Update `transformRow()` function with your actual column names
- Column names are case-sensitive

### Error: Invalid date format
- Ensure dates are in a recognizable format (Excel date, ISO string, DD/MM/YYYY, etc.)
- Check date parsing logic in `parseDate()` function
- Update date format handling if needed

### Warning: Missing required fields
- Check that `scheduledDate` and `clientName` columns exist
- Set `SKIP_INVALID_ROWS=true` to skip invalid rows
- Review skipped rows in the output

### DM numbers not sequential
- If Excel has DM numbers, they will be used as-is
- If not provided, script auto-generates based on financial year
- Check that FY documents are being updated correctly

## Customization

### Update Column Mappings

Edit the `transformRow()` function in `migrate-delivery-memos.ts`:

```typescript
// Example: Update column name
const clientName = row['Your Column Name'] || row['Another Name'] || '';
```

### Custom Date Format

If your dates are in a specific format, update `parseDate()` function:

```typescript
// Add custom parsing logic
if (typeof value === 'string' && value.match(/your-custom-format/)) {
  // Parse your format
}
```

### Custom Items Parsing

If items are in a specific format, update `parseItems()` function:

```typescript
// Example: Parse from multiple columns
const items = [];
for (let i = 1; i <= 10; i++) {
  if (row[`Item${i}_Product`]) {
    items.push({
      productName: row[`Item${i}_Product`],
      quantity: row[`Item${i}_Quantity`],
      // ...
    });
  }
}
```

## Testing (Recommended First)

Before running the full migration:

1. **Test with small file:** Create a test Excel with 5-10 rows
2. **Verify mappings:** Check that columns are mapped correctly
3. **Check output:** Verify a few documents in Firestore console
4. **Validate DM numbers:** Ensure DM numbers are correct
5. **Check FY documents:** Verify FY documents are created/updated

## Rollback

If something goes wrong:

- The script doesn't delete existing data by default
- You can manually delete migrated documents using Firestore console
- Or create a cleanup script to delete by `source: 'excel_migration'`
- Consider backing up before migration if overwriting existing DMs

## Next Steps After Migration

1. **Verify data:** Check a few documents in Firestore console
2. **Check DM numbers:** Ensure sequential numbering within financial years
3. **Verify FY documents:** Check `ORGANIZATIONS/{orgId}/DM/{FY}` documents
4. **Link to trips:** If `tripId` is provided, verify links to `SCHEDULE_TRIPS`
5. **Test DM generation:** Try generating a new DM to ensure numbering continues correctly

