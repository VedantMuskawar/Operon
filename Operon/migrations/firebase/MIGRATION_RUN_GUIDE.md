# CLIENTS Migration Run Guide

## Quick Start

To run the CLIENTS migration from Pave to Operon:

```bash
cd migrations/firebase
npm run start
```

## Prerequisites Checklist

Before running the migration, ensure:

### 1. Dependencies Installed
```bash
cd migrations/firebase
npm install
```

### 2. Service Account Files
Service account JSON files must be present:
- ✅ `creds/legacy-service-account.json` - Pave Firebase project service account
- ✅ `creds/new-service-account.json` - Operon Firebase project service account

### 3. Organization IDs (Optional - defaults are set)
The script uses these defaults (can be overridden with environment variables):
- **Legacy Org ID:** `K4Q6vPOuTcLPtlcEwdw0` (filters data from Pave)
- **Target Org ID:** `NlQgs9kADbZr4ddBRkhS` (assigns to migrated data)

To override, set environment variables:
```bash
export LEGACY_ORG_ID=your-legacy-org-id
export NEW_ORG_ID=your-target-org-id
npm run start
```

### 4. Firestore Index
The migration query requires a composite index on:
- Collection: `CLIENTS`
- Fields: `orgID` (Ascending), `registeredTime` (Ascending)

If the index doesn't exist, Firestore will provide a link to create it when you run the script.

## What the Migration Does

1. **Deletes existing data:** Removes all CLIENTS with `organizationId: 'NlQgs9kADbZr4ddBRkhS'` from target database
2. **Filters source data:** Queries Pave CLIENTS where:
   - `orgID == 'K4Q6vPOuTcLPtlcEwdw0'`
   - `registeredTime <= 2025-12-31T23:59:59.999Z`
3. **Transforms data:** Maps Pave schema to Operon schema
4. **Migrates data:** Writes to target database, preserving Pave document IDs
5. **Reports results:** Shows count of migrated clients

## Running the Migration

### Basic Run (uses defaults)
```bash
cd migrations/firebase
npm run start
```

### With Environment Variables
```bash
cd migrations/firebase
export LEGACY_ORG_ID=K4Q6vPOuTcLPtlcEwdw0
export NEW_ORG_ID=NlQgs9kADbZr4ddBRkhS
npm run start
```

### With Custom Service Account Paths
```bash
cd migrations/firebase
export LEGACY_SERVICE_ACCOUNT=/path/to/legacy-service-account.json
export NEW_SERVICE_ACCOUNT=/path/to/new-service-account.json
npm run start
```

## Expected Output

```
=== Deleting existing CLIENTS data ===
Target Org ID: NlQgs9kADbZr4ddBRkhS
Found X existing client documents to delete
Deleted X client docs...
Cleanup complete. Total clients deleted: X

=== Migrating CLIENTS from Pave ===
Cutoff date: 2025-12-31T23:59:59.999Z
Legacy Org ID: K4Q6vPOuTcLPtlcEwdw0
Target Org ID: NlQgs9kADbZr4ddBRkhS
Preserving Pave document IDs

Found Y client documents to migrate
Committed 400 client docs...
Committed 800 client docs...
...

=== Migration Complete ===
Total clients processed: Y
```

## Troubleshooting

### Error: Service account files not found
- Ensure service account JSON files are in `creds/` directory
- Or set `LEGACY_SERVICE_ACCOUNT` and `NEW_SERVICE_ACCOUNT` environment variables

### Error: Index not found
- Click the link provided by Firestore to create the composite index
- Wait for index to build (may take a few minutes)
- Re-run the migration

### Error: Permission denied
- Ensure service accounts have Firestore read/write permissions
- For legacy account: needs read access to Pave project
- For new account: needs read/write access to Operon project

## Testing (Recommended First)

Before running the full migration, you may want to:
1. Test with a small date range by modifying the cutoff date in the script
2. Check a few documents manually after migration
3. Verify the data transformation is correct

## Rollback

If something goes wrong:
- The script deletes existing data before migration
- You'll need to restore from backup or re-run from source
- Consider backing up target database before running migration





