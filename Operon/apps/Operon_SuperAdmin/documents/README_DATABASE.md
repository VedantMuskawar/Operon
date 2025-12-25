# Dash SuperAdmin - Database Schema

## Overview
The app uses **Firebase Firestore** as the database. The schema follows a document-based structure with subcollections for bidirectional relationships between users and organizations.

## Collections

### 1. USERS Collection
**Path**: `USERS/{userId}`

**Document Fields**:
```typescript
{
  id: string                    // Document ID (userId)
  name: string                  // User's full name
  phone: string                 // Phone number (e.g., "+919022933919")
  created_at: Timestamp        // Account creation timestamp
  updated_at?: Timestamp       // Last update timestamp (optional)
  superadmin: boolean          // true for SuperAdmin users, false for regular admins
  uid?: string                 // Firebase Auth UID (linked after OTP verification)
}
```

**Subcollection**: `USERS/{userId}/ORGANIZATIONS/{orgId}`
- Links a user to their organizations
- Each document represents a user's membership in an organization

**Subcollection Document Fields**:
```typescript
{
  org_id: string               // Organization document ID
  org_name: string             // Organization name (denormalized)
  user_name: string            // User name (denormalized)
  role_in_org: string          // "ADMIN" | "MANAGER" | "STAFF"
  joined_at: Timestamp         // When user joined the organization
}
```

### 2. ORGANIZATIONS Collection
**Path**: `ORGANIZATIONS/{orgId}`

**Document Fields**:
```typescript
{
  org_id: string               // Document ID (same as doc ID)
  org_code: string             // Auto-generated code (e.g., "ORG-XXXXXX")
  org_name: string             // Organization name
  industry: string             // Industry type
  gst_or_business_id?: string // Optional GST/Business ID
  created_at: Timestamp        // Organization creation timestamp
  created_by_user: string      // User ID of the SuperAdmin who created it
}
```

**Subcollection**: `ORGANIZATIONS/{orgId}/USERS/{userId}`
- Links an organization to its users
- Each document represents a user's membership in the organization

**Subcollection Document Fields**:
```typescript
{
  user_id: string              // User document ID
  org_name: string             // Organization name (denormalized)
  user_name: string            // User name (denormalized)
  role_in_org: string          // "ADMIN" | "MANAGER" | "STAFF"
  joined_at: Timestamp         // When user joined the organization
}
```

## Relationships

### Bidirectional Linking
The app maintains **bidirectional relationships** between users and organizations:

1. **User → Organization**: `USERS/{userId}/ORGANIZATIONS/{orgId}`
2. **Organization → User**: `ORGANIZATIONS/{orgId}/USERS/{userId}`

Both subcollections store the same relationship data for efficient querying from either direction.

### Denormalization
To avoid multiple queries, the schema denormalizes:
- `org_name` and `user_name` are stored in both subcollections
- This allows displaying organization/user names without additional lookups

## Data Operations

### Creating an Organization
1. Create `ORGANIZATIONS/{orgId}` document
2. Create or update `USERS/{userId}` document (if admin doesn't exist)
3. Create `USERS/{userId}/ORGANIZATIONS/{orgId}` subcollection document
4. Create `ORGANIZATIONS/{orgId}/USERS/{userId}` subcollection document

### Deleting an Organization (Cascade Delete)
1. Read all users from `ORGANIZATIONS/{orgId}/USERS`
2. For each user:
   - Delete `USERS/{userId}/ORGANIZATIONS/{orgId}`
   - Delete `ORGANIZATIONS/{orgId}/USERS/{userId}`
   - Delete `USERS/{userId}` document
3. Delete `ORGANIZATIONS/{orgId}` document

All operations use Firestore **batched writes** for atomicity.

### Querying Organizations
- **Stream**: `ORGANIZATIONS` collection ordered by `created_at` descending
- **Real-time**: Uses Firestore snapshots for live updates

## Indexes

Currently, the app uses simple queries that don't require composite indexes:
- `USERS` collection: Query by `phone` field (single field index)
- `ORGANIZATIONS` collection: Order by `created_at` (single field index)

## Security Rules

**Note**: The app requires Firestore security rules to be configured. Example rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated SuperAdmins full access
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

For production, implement proper role-based access control based on the `superadmin` field.

## Data Consistency

- **Atomic Operations**: Batched writes ensure all-or-nothing operations
- **Denormalization**: Names are duplicated in subcollections for performance
- **Timestamps**: Server timestamps ensure consistent time across clients

## Future Considerations

- Add indexes for complex queries (e.g., filtering by industry)
- Implement soft deletes instead of hard deletes
- Add audit logging for organization/user changes
- Consider adding organization settings/metadata subcollection

