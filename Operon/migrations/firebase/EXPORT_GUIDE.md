# Legacy Database Export Guide

## Overview

This guide describes how to export **full collections** from the Legacy Database (Pave) for migration to the new Database (Operon).

## Export Strategy

Export **complete collections** with all documents and all fields:
1. **CLIENTS** - Full collection export
2. **SCH_ORDERS** - Full collection export  
3. **TRANSACTIONS** - Full collection export

## Collections to Export

### 1. CLIENTS Collection
- **Source**: Legacy Database `CLIENTS` collection (or `Clients`, `clients` - verify exact name)
- **Export**: All documents with all fields
- **Format**: See `CLIENT_FORMAT.md` and `data/clients-template.csv`
- **Sample Excel**: `data/clients-import-template.xlsx`

### 2. SCH_ORDERS Collection
- **Source**: Legacy Database `SCH_ORDERS` collection (or `SCH_Orders`, `sch_orders` - verify exact name)
- **Export**: All documents with all fields
- **Format**: See `SCH_ORDERS_FORMAT.md` and `data/sch-orders-template.csv`
- **Sample Excel**: `data/sch-orders-import-template.xlsx`

### 3. TRANSACTIONS Collection
- **Source**: Legacy Database `TRANSACTIONS` collection (or `Transactions`, `transactions` - verify exact name)
- **Export**: All documents with all fields
- **Format**: See `TRANSACTIONS_FORMAT.md` and `data/transactions-template.csv`
- **Sample Excel**: `data/transactions-import-template.xlsx`

### 4. DELIVERY_MEMOS Collection
- **Source**: Legacy Database `DELIVERY_MEMOS` collection (or `Delivery_Memos`, `delivery_memos` - verify exact name)
- **Export**: All documents with all fields
- **Format**: See `DELIVERY_MEMOS_FORMAT.md` and `data/delivery-memos-template.csv`
- **Sample Excel**: `data/delivery-memos-import-template.xlsx`

## Export Process

### Step 1: Connect to Legacy Database
1. Get Legacy Firebase service account credentials
2. Initialize Firebase Admin SDK
3. Verify collection names exist

### Step 2: Export Each Collection
For each collection:
1. Query all documents (no filters, no date ranges)
2. Export all fields from each document
3. Include document ID as first column
4. Save to Excel/CSV format

### Step 3: Verify Exports
- Check document counts match
- Verify all fields are exported
- Check for any missing data

## Export Scripts

Create export scripts that:
- Connect to Legacy Firebase project
- Query entire collections (no filters)
- Export all fields from all documents
- Save to Excel format with proper formatting

## File Naming Convention

### Export Files (from Legacy Database)
- `clients-export-{timestamp}.xlsx` - Full CLIENTS collection
- `sch-orders-export-{timestamp}.xlsx` - Full SCH_ORDERS collection
- `transactions-export-{timestamp}.xlsx` - Full TRANSACTIONS collection
- `delivery-memos-export-{timestamp}.xlsx` - Full DELIVERY_MEMOS collection

### Import Templates (for New Database)
- `clients-import-template.xlsx` - Template for importing clients
- `sch-orders-import-template.xlsx` - Template for importing schedule trips
- `transactions-import-template.xlsx` - Template for importing transactions
- `delivery-memos-import-template.xlsx` - Template for importing delivery memos

## Next Steps After Export

1. Review exported data
2. Map Legacy field names to Operon format
3. Transform data as needed
4. Import into new Database using import scripts
