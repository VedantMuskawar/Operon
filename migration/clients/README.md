# Client Migration from PaveBoard to OPERON

This script migrates clients from PaveBoard's Firebase project to OPERON's Firebase project.

## Overview

- **Source**: PaveBoard (`apex-21cd0`) → `CLIENTS` collection
- **Destination**: OPERON (`operanapp`) → `CLIENTS` collection
- **Filter**: Migrates only clients with `orgID == "K4Q6vPOuTcLPtlcEwdw0"`
- **Date Filter**: Only migrates clients registered on or before **November 1, 2025** (`registeredTime <= 2025-11-01`)
- **Organization**: Sets `organizationId` to `"wuqC6llSwDSME9lwf8fL"` in OPERON

## Field Mappings

| PaveBoard Field | OPERON Field | Notes |
|----------------|--------------|-------|
| `name` | `name` | Capitalized (first letter of each word) |
| `registeredTime` | `createdAt` | Timestamp conversion |
| `contactInfo.primaryPhone` | `phoneNumber` | Normalized (last 10 digits) |
| - | `phoneList` | New array: `[primaryPhone, secondaryPhone, supervisor.primaryPhone]` |
| - | `clientId` | Auto-generated (Firestore document ID) |
| - | `organizationId` | Set to `"wuqC6llSwDSME9lwf8fL"` |
| - | `status` | Default: `"active"` |
| - | `updatedAt` | Current timestamp |

## Prerequisites

1. **Node.js** (v14 or higher)
2. **Firebase Service Account Keys** for both projects:
   - PaveBoard service account JSON
   - OPERON service account JSON

## Setup

1. **Install dependencies:**
   ```bash
   cd migration
   npm install
   ```

2. **Run setup helper (creates required directories):**
   ```bash
   npm run setup
   ```

3. **Download service account keys from Firebase Console:**
   
   **Location**: Service account files should be placed in:
   ```
   C:\Vedant\OPERON\migration\service-accounts\
   ```
   
   **For PaveBoard (`apex-21cd0`):**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project: `apex-21cd0`
   - Navigate to: Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the downloaded JSON file (it will have a name like `apex-21cd0-firebase-adminsdk-xxxxx-xxxxx.json`)
   - Place it in: `C:\Vedant\OPERON\migration\service-accounts\`
   - **Expected filename**: `apex-21cd0-firebase-adminsdk-f7hnl-3371c464e2.json`

   **For OPERON (`operanapp`):**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project: `operanapp`
   - Navigate to: Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the downloaded JSON file (it will have a name like `operanapp-firebase-adminsdk-xxxxx-xxxxx.json`)
   - Place it in: `C:\Vedant\OPERON\migration\service-accounts\`
   - **Expected filename**: `operanapp-firebase-adminsdk-fbsvc-090c355102.json`

4. **Verify service account files:**
   - Check that both JSON files exist in `C:\Vedant\OPERON\migration\service-accounts\` folder:
     - `apex-21cd0-firebase-adminsdk-f7hnl-3371c464e2.json`
     - `operanapp-firebase-adminsdk-fbsvc-090c355102.json`
   - Ensure they have Firestore read/write permissions
   
   **Note**: If your service account files have different names, update the paths in `config.js` or set environment variables
   
   **Alternative locations**: If you place files elsewhere, update paths in `config.js` or set environment variables:
   ```env
   PAVEBOARD_SERVICE_ACCOUNT_PATH=./your-custom-path/paveboard-service-account.json
   OPERON_SERVICE_ACCOUNT_PATH=./your-custom-path/operon-service-account.json
   ```

## Configuration

### Date Filter

By default, the migration only includes clients registered on or before **November 1, 2025**.

To change the date filter:

1. **Update `config.js`:**
   ```javascript
   registeredBeforeDate: new Date('2025-11-01T23:59:59.999Z')
   ```

2. **Or use environment variable:**
   ```env
   REGISTERED_BEFORE_DATE=2025-11-01
   ```

3. **To disable date filtering:**
   ```javascript
   registeredBeforeDate: null
   ```

The date filter compares against the `registeredTime` field in PaveBoard clients.

## Usage

### Dry Run (Recommended First)

Test the migration without making any changes:

```bash
npm run migrate-clients:dry-run
```

### Live Migration

Run the actual migration:

```bash
npm run migrate-clients
```

Or directly:

```bash
node clients/migrate-clients.js
```

## Phone Number Normalization

The script normalizes phone numbers using OPERON's logic:
- Removes all non-digit characters (except leading `+`)
- Removes country code prefix (`+`)
- Removes leading zeros
- Keeps last 10 digits if number is longer

## Duplicate Handling

If a client with the same normalized phone number already exists in OPERON:
- **Existing record is updated** with new data from PaveBoard
- Original `clientId` is preserved

## Phone List Array

The `phoneList` field contains an array of normalized phone numbers:
- Primary phone (from `contactInfo.primaryPhone`)
- Secondary phone (from `contactInfo.secondaryPhone`, if exists)
- Supervisor phone (from `supervisor.primaryPhone`, if exists)

Empty/null values are filtered out, and duplicates are removed.

## Output

The script generates:

1. **Console Output**: Real-time progress and summary
2. **Migration Report**: JSON file with detailed statistics
   - Location: `migration-report-{timestamp}.json`
   - Includes: statistics, errors, configuration

## Error Handling

- Individual record failures don't stop the migration
- All errors are logged to the report file
- Failed records are tracked in statistics

## Migration Statistics

The report includes:
- **Total**: Total clients processed
- **Migrated**: New clients created
- **Updated**: Existing clients updated (duplicates)
- **Failed**: Clients that failed to process
- **Skipped**: Clients skipped (e.g., no valid phone number)

## Security Notes

- Never commit service account JSON files to version control
- Add `service-accounts/` to `.gitignore`
- Add `.env` to `.gitignore`
- Service account keys should have minimal required permissions

## Troubleshooting

### "Service account key not found"
- Verify service account JSON files exist at specified paths
- Check file paths in `config.js` or `.env`

### "Permission denied"
- Ensure service account has Firestore read/write permissions
- Check service account roles in Firebase Console

### "No clients found"
- Verify `orgID` filter in `config.js` matches PaveBoard data
- Check Firebase project connection

## Example Output

```
🚀 Starting Client Migration
   Mode: LIVE

✅ Firebase Admin SDKs initialized successfully
   Source: apex-21cd0
   Destination: operanapp

📋 Fetching existing OPERON clients...
   Found 150 existing clients

📥 Fetching PaveBoard clients with orgID: K4Q6vPOuTcLPtlcEwdw0...
   Found 200 clients to migrate

🔄 Processing 200 clients in 1 batch(es)...

📦 Batch 1/1 (200 clients)...
   ✓ Migrated: John Doe (9876543210)
   ✓ Updated: Jane Smith (9876543211)
   ...

📊 Migration report saved to: migration-report-1234567890.json

============================================================
📈 MIGRATION SUMMARY
============================================================
Mode: LIVE
Total clients processed: 200
✅ Successfully migrated: 150
🔄 Updated (duplicates): 45
❌ Failed: 3
⏭️  Skipped: 2
============================================================

✅ Migration completed!
```

