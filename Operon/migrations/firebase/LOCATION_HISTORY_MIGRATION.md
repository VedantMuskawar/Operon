# Location History Migration Guide

This script migrates location history data from old schema formats to the new standardized format.

## New Schema Format

**Path:** `SCHEDULE_TRIPS/{tripId}/history/{historyDocId}`

**Document Structure:**
```json
{
  "locations": [
    {
      "lat": 20.5937,
      "lng": 78.9629,
      "bearing": 45.0,
      "speed": 30.5,
      "status": "active",
      "timestamp": 1234567890
    }
    // ... more locations (up to 100 per document)
  ],
  "createdAt": "2024-01-19T10:00:00Z"
}
```

## Supported Old Schema Formats

The migration script handles the following old formats:

### 1. Old Path: `trips/{tripId}/history`
- Migrates from `trips` collection to `SCHEDULE_TRIPS` collection
- Handles both array and single-location formats

### 2. Inline in Trip Document: `locationHistory` field
- Extracts `locationHistory` array from trip document
- Moves to `history` subcollection
- Removes old field after migration

### 3. Field Name Variations
The script normalizes various field names:
- `lat` / `latitude`
- `lng` / `longitude`
- `bearing` / `heading`
- `timestamp` (supports both seconds and milliseconds)
- `status` / `state`

## Prerequisites

1. **Service Account Key:**
   - Download service account JSON from Google Cloud Console
   - Place in `creds/new-service-account.json`
   - Or set `SERVICE_ACCOUNT` or `NEW_SERVICE_ACCOUNT` environment variable

2. **Firestore Indexes:**
   - Ensure indexes exist for queries (usually auto-created)

## Usage

### Dry Run (Recommended First)

Test the migration without writing data:

```bash
cd migrations/firebase
DRY_RUN=true npm run migrate-location-history
```

### Migrate All Organizations

```bash
npm run migrate-location-history
```

### Migrate Specific Organization

```bash
ORGANIZATION_ID=your-org-id npm run migrate-location-history
```

### Custom Configuration

```bash
NEW_SERVICE_ACCOUNT=/path/to/new-service-account.json \
PROJECT_ID=your-project-id \
ORGANIZATION_ID=your-org-id \
BATCH_SIZE=20 \
DRY_RUN=false \
npm run migrate-location-history
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERVICE_ACCOUNT` or `NEW_SERVICE_ACCOUNT` | Path to service account JSON | `creds/new-service-account.json` |
| `PROJECT_ID` | Firebase project ID | From service account |
| `ORGANIZATION_ID` | Filter by organization (optional) | All organizations |
| `DRY_RUN` | If `true`, only logs changes | `false` |
| `BATCH_SIZE` | Number of trips to process at once | `10` |

## Migration Process

1. **Fetches all trips** from `SCHEDULE_TRIPS` collection
2. **For each trip:**
   - Checks if history already exists in new format
   - Looks for old history in `trips/{tripId}/history`
   - Looks for `locationHistory` in trip document
   - Normalizes location data to new format
   - Groups locations into batches of 100
   - Writes to `SCHEDULE_TRIPS/{tripId}/history`
3. **Reports statistics** on completion

## Customization

If your old schema differs, edit `migrate-location-history.ts`:

1. **Add new old schema detection** in `migrateTripHistory()`
2. **Update normalization logic** in `normalizeLocation()` if field names differ
3. **Adjust batch size** if needed (default: 100 locations per document)

## Safety Features

- ✅ **Dry run mode** - Test before migrating
- ✅ **Skips already migrated** - Won't duplicate data
- ✅ **Error handling** - Continues on individual trip errors
- ✅ **Batch processing** - Processes in small batches to avoid rate limits
- ✅ **Progress reporting** - Shows real-time progress

## Troubleshooting

### "No old history found"
- Check if your old data is in a different path/format
- Add custom detection logic in the script

### "Service account not found"
- Ensure service account JSON file exists
- Check file path is correct
- Verify file has read permissions

### Rate Limiting Errors
- Reduce `BATCH_SIZE` environment variable
- Add longer delays between batches

### Data Format Errors
- Check console logs for specific errors
- Update `normalizeLocation()` function for your format

## Example Output

```
🚀 Starting Location History Migration

📥 Fetching trips...
✅ Found 150 trips to process

📦 Processing batch 1 (10 trips)...

  Processing trip: abc123
  📦 Found 5 old history documents for trip abc123
  ✅ Migrated 342 locations for trip abc123

  Processing trip: def456
  ✓ Trip def456 already has new format history, skipping

  Progress: 10/150 trips processed

==================================================
📊 Migration Summary:
  ✅ Locations migrated: 5,234
  ⏭️  Trips skipped: 45
  ❌ Errors: 2
==================================================
```
