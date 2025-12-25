# User App Access Role Linking - Design & Implementation

## Current State Analysis

### Current User-Organization Link Structure

**Path 1**: `USERS/{userId}/ORGANIZATIONS/{orgId}`
```typescript
{
  org_id: string
  org_name: string
  user_name: string
  role_in_org: string          // "ADMIN" | "MANAGER" | "STAFF" (title)
  joined_at: Timestamp
}
```

**Path 2**: `ORGANIZATIONS/{orgId}/USERS/{userId}`
```typescript
{
  user_id: string
  org_name: string
  user_name: string
  role_in_org: string          // "ADMIN" | "MANAGER" | "STAFF" (title)
  role_id?: string             // Optional, sometimes present
  joined_at: Timestamp
}
```

### Current App Access Role Resolution

The web app currently:
1. Reads `role_in_org` from user-org document
2. Fetches all App Access Roles for the organization
3. Tries to match by:
   - ID (if `role_in_org` looks like an ID)
   - Name (case-insensitive string match)
   - Falls back to creating a default role

**Problems:**
- ❌ Fragile matching logic
- ❌ No direct link to App Access Role
- ❌ Ambiguous when role names change
- ❌ Performance: Must fetch all roles to find one

## Proposed Solution

### Add `app_access_role_id` Field

Add a new field to both user-org documents:

**Updated Structure**:
```typescript
{
  // ... existing fields ...
  role_in_org: string          // Keep for backward compatibility
  app_access_role_id: string  // NEW: Direct reference to App Access Role
}
```

### Benefits

✅ **Direct Reference**: Clear link to App Access Role document
✅ **Performance**: No need to fetch all roles
✅ **Reliability**: No fuzzy matching needed
✅ **Backward Compatible**: Keep `role_in_org` for existing code
✅ **Future-Proof**: Easy to migrate away from `role_in_org` later

## Implementation Plan

### Phase 1: Update Data Structure

1. **Update SuperAdmin Data Source**
   - Modify `linkUserOrganization()` to accept `appAccessRoleId`
   - Set `app_access_role_id` when linking users

2. **Update User-Org Documents**
   - Add `app_access_role_id` field to both:
     - `USERS/{userId}/ORGANIZATIONS/{orgId}`
     - `ORGANIZATIONS/{orgId}/USERS/{userId}`

### Phase 2: Migration for Existing Users

1. **Migration Script**
   - Find all user-org documents
   - For each document:
     - Read `role_in_org` (e.g., "ADMIN")
     - Find matching App Access Role by name or ID
     - Set `app_access_role_id` to the role's ID
     - Default to "admin" role if no match found

### Phase 3: Update Application Code

1. **Web App**
   - Update `OrganizationMembership` entity to include `appAccessRoleId`
   - Update role resolution to use `app_access_role_id` directly
   - Keep fallback logic for backward compatibility

2. **Android App** (if applicable)
   - Similar updates to use `app_access_role_id`

## Detailed Implementation

### 1. SuperAdmin: Update User Linking

**File**: `apps/Operon_SuperAdmin/lib/data/datasources/organization_remote_data_source.dart`

```dart
Future<void> linkUserOrganization({
  required String userId,
  required String userName,
  required String organizationId,
  required String organizationName,
  required String roleInOrg,
  String? appAccessRoleId,  // NEW parameter
}) async {
  // ... existing code ...
  
  await Future.wait([
    userOrgRef.set({
      'org_id': organizationId,
      'org_name': organizationName,
      'user_name': userName,
      'role_in_org': roleInOrg,
      if (appAccessRoleId != null) 'app_access_role_id': appAccessRoleId,  // NEW
      'joined_at': FieldValue.serverTimestamp(),
    }),
    orgUserRef.set({
      'user_id': userId,
      'org_name': organizationName,
      'user_name': userName,
      'role_in_org': roleInOrg,
      if (appAccessRoleId != null) 'app_access_role_id': appAccessRoleId,  // NEW
      'joined_at': FieldValue.serverTimestamp(),
    }),
  ]);
}
```

### 2. Default Admin Role Assignment

When creating an organization with an admin user:
- Set `app_access_role_id: 'admin'` (the fixed ID of the default admin role)

### 3. Migration Script

Create script to:
1. Fetch all organizations
2. For each org, fetch all user-org documents
3. For each user-org document:
   - If `app_access_role_id` exists, skip
   - Otherwise:
     - Get `role_in_org` value
     - Find matching App Access Role:
       - Try by name (case-insensitive)
       - Try by ID if `role_in_org` looks like an ID
       - Default to "admin" role
     - Update both user-org documents with `app_access_role_id`

## Migration Strategy

### Option A: Gradual Migration (Recommended)
- Add `app_access_role_id` to new user links immediately
- Run migration script for existing users
- Keep `role_in_org` for backward compatibility
- Gradually phase out `role_in_org` usage

### Option B: Complete Migration
- Run migration script first
- Update all code to use `app_access_role_id`
- Remove `role_in_org` field (breaking change)

**Recommendation**: Option A (Gradual) for safety and backward compatibility.

## Database Schema Update

### Before
```typescript
USERS/{userId}/ORGANIZATIONS/{orgId}
{
  org_id: string
  org_name: string
  user_name: string
  role_in_org: string
  joined_at: Timestamp
}
```

### After
```typescript
USERS/{userId}/ORGANIZATIONS/{orgId}
{
  org_id: string
  org_name: string
  user_name: string
  role_in_org: string              // Keep for backward compatibility
  app_access_role_id: string       // NEW: Direct reference
  joined_at: Timestamp
}
```

## Questions to Discuss

1. **Default Role Assignment**
   - When a user is added to an org without specifying a role, what should be the default?
   - Should we create a "Viewer" or "Member" role as default?

2. **Role Name vs ID**
   - Should we keep `role_in_org` as a denormalized name for display?
   - Or should we fetch the role name from App Access Role document?

3. **Migration Timing**
   - Run migration immediately?
   - Or wait for a maintenance window?

4. **Validation**
   - Should we validate that `app_access_role_id` exists in `APP_ACCESS_ROLES`?
   - Add Firestore security rules to enforce this?

5. **Multiple Roles**
   - Current design: One App Access Role per user per org
   - Future: Support multiple roles? (Would require array field)

## Next Steps

1. ✅ Review and approve this design
2. ⏳ Update SuperAdmin code to set `app_access_role_id`
3. ⏳ Create migration script
4. ⏳ Update web app to use `app_access_role_id`
5. ⏳ Test with existing and new organizations
6. ⏳ Monitor for any issues
