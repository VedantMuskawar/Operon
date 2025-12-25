# Permissions Database Schema

## Overview
Permissions are stored within each Role document in Firestore. The Access Control page manages these permissions, which are then stored back to the role documents.

## Firestore Collection Structure

```
ORGANIZATIONS/
  {organizationId}/
    ROLES/
      {roleId}/
        {
          roleId: string,
          title: string,
          salaryType: "salaryMonthly" | "wages",
          colorHex: string,
          permissions: {
            sections: {
              "pendingOrders": boolean,
              "scheduleOrders": boolean,
              "ordersMap": boolean,
              "analyticsDashboard": boolean
            },
            pages: {
              "pendingOrders": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "scheduleOrders": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "products": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "employees": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "users": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "clients": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "zonesCity": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "zonesRegion": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "zonesPrice": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "vehicles": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "paymentAccounts": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "roles": {
                create: boolean,
                edit: boolean,
                delete: boolean
              },
              "accessControl": {
                create: boolean,
                edit: boolean,
                delete: boolean
              }
            }
          },
          createdAt: Timestamp,
          updatedAt: Timestamp
        }
```

## Example Document

```json
{
  "roleId": "manager_123",
  "title": "Manager",
  "salaryType": "salaryMonthly",
  "colorHex": "#6F4BFF",
  "permissions": {
    "sections": {
      "pendingOrders": true,
      "scheduleOrders": true,
      "ordersMap": false,
      "analyticsDashboard": false
    },
    "pages": {
      "pendingOrders": {
        "create": true,
        "edit": true,
        "delete": false
      },
      "scheduleOrders": {
        "create": true,
        "edit": true,
        "delete": true
      },
      "products": {
        "create": true,
        "edit": true,
        "delete": false
      },
      "employees": {
        "create": false,
        "edit": true,
        "delete": false
      }
    }
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-20T14:45:00Z"
}
```

## Data Flow

### 1. **Loading Permissions**
- Access Control page loads all roles from `ORGANIZATIONS/{orgId}/ROLES`
- Extracts `permissions` object from each role
- Separates into:
  - `sections`: Map<String, Map<String, bool>> (sectionKey -> roleId -> hasAccess)
  - `pages`: Map<String, Map<String, PageCrudPermissions>> (pageKey -> roleId -> permissions)

### 2. **Updating Permissions**
- User modifies permissions in Access Control UI
- Changes are tracked in local state
- On "Save Changes":
  - For each role, rebuilds the `permissions` object
  - Updates the role document in Firestore: `ORGANIZATIONS/{orgId}/ROLES/{roleId}`
  - Updates only the `permissions` field and `updatedAt` timestamp

### 3. **Reading Permissions**
- When a user logs in, their role is loaded from `ORGANIZATIONS/{orgId}/USERS/{userId}`
- The role document is fetched from `ORGANIZATIONS/{orgId}/ROLES/{roleId}`
- Permissions are checked using:
  - `role.canAccessSection(sectionKey)` - for navigation sections
  - `role.canCreate(pageKey)` - for create operations
  - `role.canEdit(pageKey)` - for edit operations
  - `role.canDelete(pageKey)` - for delete operations
  - `role.canAccessPage(pageKey)` - for page access

## Special Cases

### Admin Role
- If `title.toUpperCase() == "ADMIN"`, the role has full access
- Admin permissions are not stored in the database
- All permission checks return `true` for admin roles
- Admin roles still have a `permissions` object in the database (for consistency), but it's ignored

### Missing Permissions
- If a page key doesn't exist in `permissions.pages`, the user cannot access that page
- If a section key doesn't exist in `permissions.sections` or is `false`, the section is hidden
- Default values:
  - Sections: `false` (no access)
  - Pages: `{ create: false, edit: false, delete: false }` (no permissions)

## Code References

- **Entity**: `apps/dash_mobile/lib/domain/entities/organization_role.dart`
- **Data Source**: `apps/dash_mobile/lib/data/datasources/roles_data_source.dart`
- **Repository**: `apps/dash_mobile/lib/data/repositories/roles_repository.dart`
- **Access Control Cubit**: `apps/dash_mobile/lib/presentation/blocs/access_control/access_control_cubit.dart`

## Notes

- Permissions are **role-based**, not user-based
- All users with the same role share the same permissions
- Permissions are stored **within each role document**, not in a separate collection
- The Access Control page provides a **page-centric view** for easier management
- Changes require **explicit save** - they don't auto-save
- Admin roles bypass all permission checks at the application level

