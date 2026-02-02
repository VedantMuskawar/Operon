# Quick Start Guide - Legacy Database Export & Import

## Overview

This guide helps you export full collections from the Legacy Database (Pave) and import them into the new Operon Database.

## Collections to Export

Export these **4 complete collections** from Legacy Database:

1. ✅ **CLIENTS** - All client documents
2. ✅ **SCH_ORDERS** - All scheduled orders/trips
3. ✅ **TRANSACTIONS** - All transaction records
4. ✅ **DELIVERY_MEMOS** - All delivery memo documents

## Step-by-Step Process

### Step 1: Export from Legacy Database

1. **Connect to Pave Firebase**
   - Get Legacy Firebase service account credentials
   - Place in `creds/legacy-service-account.json`

2. **Create Export Scripts**
   - Export each collection (no filters, all fields)
   - Save as Excel files

3. **Verify Exports**
   - Check document counts
   - Verify all fields are exported

### Step 2: Review Export Formats

Read the format documentation:
- `CLIENT_FORMAT.md` - CLIENTS collection format
- `SCH_ORDERS_FORMAT.md` - SCH_ORDERS collection format
- `TRANSACTIONS_FORMAT.md` - TRANSACTIONS collection format
- `DELIVERY_MEMOS_FORMAT.md` - DELIVERY_MEMOS collection format

### Step 3: Transform Data

1. **Map Field Names** (Legacy → New)
   - `clientID` → `clientId`
   - `orgID` → `organizationId`
   - `vehicleID` → `vehicleId`
   - etc.

2. **Normalize Data Formats**
   - Phone numbers → E.164 format
   - Dates → ISO 8601 format
   - Arrays/Objects → JSON strings

3. **Use Import Templates**
   - Reference templates in `data/` folder
   - Match field names exactly
   - Follow data format requirements

### Step 4: Import into New Database

**Import Order** (Important!):
1. **CLIENTS** first
2. **SCH_ORDERS** (creates SCHEDULE_TRIPS)
3. **DELIVERY_MEMOS**
4. **TRANSACTIONS** last

## Import Templates

### Location
All templates are in: `migrations/firebase/data/`

### Files
- `clients-import-template.csv` - CLIENTS import format
- `sch-orders-import-template.csv` - SCH_ORDERS import format
- `transactions-import-template.csv` - TRANSACTIONS import format
- `delivery-memos-import-template.csv` - DELIVERY_MEMOS import format

### Usage
1. Open CSV template in Excel
2. Compare with your exported data
3. Map Legacy fields to template format
4. Use transformed data for import

**Note**: CSV files can be opened directly in Excel. See `CREATE_EXCEL_TEMPLATES.md` if you need .xlsx files.

## Documentation Files

| File | Purpose |
|------|---------|
| `EXPORT_GUIDE.md` | Master export guide |
| `CLIENT_FORMAT.md` | CLIENTS collection format |
| `SCH_ORDERS_FORMAT.md` | SCH_ORDERS collection format |
| `TRANSACTIONS_FORMAT.md` | TRANSACTIONS collection format |
| `DELIVERY_MEMOS_FORMAT.md` | DELIVERY_MEMOS collection format |
| `IMPORT_TEMPLATES_README.md` | Import templates guide |
| `CREATE_EXCEL_TEMPLATES.md` | How to create Excel files |
| `PAVE_CLIENT_STRUCTURE.md` | Pave structure investigation |

## Key Points

✅ **Export Everything**: No filters, all documents, all fields
✅ **Preserve Field Names**: Keep original Pave field names during export
✅ **Transform Later**: Map to Operon format during import
✅ **Follow Import Order**: CLIENTS → SCH_ORDERS → DELIVERY_MEMOS → TRANSACTIONS
✅ **Use Templates**: Reference import templates for correct format

## Common Field Mappings

| Legacy (Pave) | New (Operon) |
|--------------|--------------|
| `clientID` | `clientId` |
| `orgID` | `organizationId` |
| `vehicleID` | `vehicleId` |
| `driverID` | `driverId` |
| `regionID` | `regionId` |

## Next Steps

1. ✅ Review all format documentation
2. ✅ Check import templates
3. ✅ Create export scripts for Legacy Database
4. ✅ Export all 4 collections
5. ✅ Transform data using templates
6. ✅ Import into new Database

## Support

- Check format documentation for field details
- Review import templates for expected format
- Verify collection names in Legacy Firebase console
