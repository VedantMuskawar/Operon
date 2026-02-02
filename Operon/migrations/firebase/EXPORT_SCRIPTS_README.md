# Export Scripts Usage Guide

## Overview

Export scripts to export complete collections from Legacy Database (Pave) to Excel files.

## Prerequisites

1. **Service Account**: Place Legacy Firebase service account JSON file in `creds/legacy-service-account.json`
2. **Dependencies**: Install with `npm install`

## Available Scripts

### Export All Collections (Recommended)

Exports all 4 collections in one command:

```bash
npm run export-all
```

This will export:
- CLIENTS
- SCH_ORDERS
- TRANSACTIONS
- DELIVERY_MEMOS

**Output**: Files saved in `data/` folder with timestamps:
- `clients-export-{timestamp}.xlsx`
- `sch-orders-export-{timestamp}.xlsx`
- `transactions-export-{timestamp}.xlsx`
- `delivery-memos-export-{timestamp}.xlsx`

### Export Individual Collections

#### Export CLIENTS
```bash
npm run export-clients
```

#### Export SCH_ORDERS
```bash
npm run export-sch-orders
```

#### Export TRANSACTIONS
```bash
npm run export-transactions
```

#### Export DELIVERY_MEMOS
```bash
npm run export-delivery-memos
```

## Environment Variables

You can customize the export using environment variables:

### LEGACY_SERVICE_ACCOUNT
Path to Legacy Firebase service account JSON file (default: `creds/legacy-service-account.json`)

```bash
LEGACY_SERVICE_ACCOUNT=/path/to/service-account.json npm run export-all
```

### LEGACY_PROJECT_ID
Legacy Firebase project ID (optional, auto-detected from service account)

```bash
LEGACY_PROJECT_ID=your-project-id npm run export-all
```

### COLLECTION_NAME
Custom collection name (for individual exports)

```bash
COLLECTION_NAME=Clients npm run export-clients
```

### OUTPUT_PATH
Custom output file path (for individual exports)

```bash
OUTPUT_PATH=/path/to/output.xlsx npm run export-clients
```

### OUTPUT_DIR
Output directory for export-all script

```bash
OUTPUT_DIR=/path/to/output npm run export-all
```

## Examples

### Export All Collections
```bash
cd migrations/firebase
npm run export-all
```

### Export with Custom Service Account
```bash
LEGACY_SERVICE_ACCOUNT=/custom/path/service-account.json npm run export-all
```

### Export to Custom Directory
```bash
OUTPUT_DIR=/path/to/exports npm run export-all
```

### Export Single Collection with Custom Name
```bash
COLLECTION_NAME=CLIENTS OUTPUT_PATH=./my-clients.xlsx npm run export-clients
```

## Output Format

- **Format**: Excel (.xlsx)
- **First Column**: Document ID (Firestore document ID)
- **All Fields**: All fields from each document are exported
- **Nested Data**: Objects and arrays are exported as JSON strings
- **Timestamps**: Converted to ISO 8601 format strings

## Collection Name Variations

If the collection name in Legacy Database is different, you can specify it:

```bash
# Try different collection names
COLLECTION_NAME=Clients npm run export-clients
COLLECTION_NAME=clients npm run export-clients
COLLECTION_NAME=CLIENTS npm run export-clients
```

## Troubleshooting

### Service Account Not Found
```
Error: Service account file not found
```
**Solution**: Place service account JSON file in `creds/legacy-service-account.json` or set `LEGACY_SERVICE_ACCOUNT` environment variable.

### Collection Not Found
```
No documents found in collection: COLLECTION_NAME
```
**Solution**: 
1. Verify collection name in Legacy Firebase console
2. Try different case variations (CLIENTS, Clients, clients)
3. Set `COLLECTION_NAME` environment variable

### Permission Denied
```
Error: Permission denied
```
**Solution**: Ensure service account has read access to Firestore collections.

### Large Collections
For very large collections (>10,000 documents), the export may take time. The script shows progress with batch counts.

## Notes

- **No Filters**: Exports ALL documents (no date ranges, no filters)
- **All Fields**: Exports ALL fields from each document
- **Batch Processing**: Fetches documents in batches of 1000
- **Progress**: Shows batch progress during export
- **Error Handling**: Continues with other collections if one fails (export-all)

## Next Steps

After export:
1. Review exported Excel files
2. Compare with import templates in `data/` folder
3. Transform data to match new Database format
4. Import using import scripts
