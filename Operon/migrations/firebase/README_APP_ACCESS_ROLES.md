# Migrate App Access Roles - Add Default Admin Role

This migration script adds a default "Admin" App Access Role to all existing organizations that don't have one.

## What it does

- Fetches all organizations from Firestore
- For each organization, checks if an Admin App Access Role exists
- If not, creates a default Admin role with:
  - ID: `admin` (fixed ID)
  - Name: "Admin"
  - Full access (`isAdmin: true`)
  - Red color (`#FF6B6B`)
  - Empty permissions object (since `isAdmin` grants full access)

## Prerequisites

1. Install dependencies:
   ```bash
   cd migrations/firebase
   npm install
   ```

2. Create service account JSON file:
   - Download service account JSON from Google Cloud Console
   - Place it in `creds/service-account.json`
   - Or set `SERVICE_ACCOUNT` environment variable with full path

3. (Optional) Set `PROJECT_ID` environment variable if not in service account JSON

## Running the migration

```bash
npm run migrate-app-access-roles
```

Or with environment variables:

```bash
SERVICE_ACCOUNT=/path/to/service-account.json PROJECT_ID=your-project-id npm run migrate-app-access-roles
```

## Output

The script will:
- Show progress for each organization
- Display a summary at the end with:
  - Total organizations
  - Number processed
  - Number created
  - Number skipped (already exists)
  - Number of errors

## Safety

- **Idempotent**: Safe to run multiple times - it checks if the admin role exists before creating
- **Non-destructive**: Only creates missing roles, never modifies or deletes existing data
- **Dry-run friendly**: You can review the code and test on a single org first

## Testing on a single organization

To test on a single organization first, you can modify the script to filter:

```typescript
// In migrateAppAccessRoles function, add:
const testOrgId = 'YOUR_ORG_ID_HERE';
const orgsSnapshot = await db
  .collection('ORGANIZATIONS')
  .where(admin.firestore.FieldPath.documentId(), '==', testOrgId)
  .get();
```
