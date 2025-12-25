# Schema Implementation Summary

## ✅ Completed: Entity Classes Created

### 1. AppAccessRole (`lib/domain/entities/app_access_role.dart`)
- **Purpose**: Controls app permissions
- **Collection**: `ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES`
- **Fields**: id, name, description, colorHex, isAdmin, permissions
- **Used by**: OrganizationUser (via `appAccessRoleId`)

### 2. OrganizationJobRole (`lib/domain/entities/organization_job_role.dart`)
- **Purpose**: Job positions/titles
- **Collection**: `ORGANIZATIONS/{orgId}/JOB_ROLES`
- **Fields**: id, title, department, description, colorHex, defaultWageType, sortOrder
- **Used by**: OrganizationEmployee (via `jobRoleIds[]`)

### 3. WageType & EmployeeWage (`lib/domain/entities/wage_type.dart`)
- **WageType Enum**: perMonth, perTrip, perBatch, perHour, perKm, commission, hybrid
- **EmployeeWage Class**: Flexible wage structure with type-specific fields
- **HybridWageStructure**: For base + commission combinations

### 4. EmployeeJobRole (`lib/domain/entities/employee_job_role.dart`)
- **Purpose**: Links employee to job role with metadata
- **Fields**: jobRoleId, jobRoleTitle, assignedAt, isPrimary

### 5. Updated OrganizationEmployee (`lib/domain/entities/organization_employee.dart`)
- ✅ Multiple job roles support (`jobRoleIds[]`, `jobRoles{}`)
- ✅ Per-employee wage structure (`EmployeeWage`)
- ✅ Helper methods: `primaryJobRoleId`, `primaryJobRoleTitle`, `jobRoleTitles`

### 6. Updated OrganizationUser (`lib/domain/entities/organization_user.dart`)
- ✅ Uses `appAccessRoleId` instead of `roleId`/`roleTitle`
- ✅ Always requires `employeeId` (must link to employee)
- ✅ Permission methods delegate to `appAccessRole`

---

## 📋 Next Steps: Still To Do

### Phase 2: Data Sources & Repositories

1. **AppAccessRolesDataSource**
   - Create CRUD operations for `APP_ACCESS_ROLES` collection
   - Path: `ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES/{roleId}`

2. **AppAccessRolesRepository**
   - Business logic wrapper for data source

3. **JobRolesDataSource**
   - Create CRUD operations for `JOB_ROLES` collection
   - Path: `ORGANIZATIONS/{orgId}/JOB_ROLES/{jobRoleId}`

4. **JobRolesRepository**
   - Business logic wrapper for data source

5. **Update EmployeesDataSource**
   - Support new employee schema (jobRoleIds, wage structure)
   - Update create/update methods

6. **Update EmployeesRepository**
   - Handle new employee structure

7. **Update UsersDataSource**
   - Support `app_access_role_id` field
   - Enforce `employee_id` requirement

8. **Update UsersRepository**
   - Handle new user structure

### Phase 3: Business Logic (Cubits/Blocs)

1. **AppAccessRolesCubit**
   - State management for app access roles
   - Create, update, delete, fetch operations

2. **JobRolesCubit**
   - State management for job roles
   - Create, update, delete, fetch operations

3. **Update EmployeesCubit**
   - Handle multiple job roles
   - Handle new wage structure
   - Update create/update logic

4. **Update UsersCubit**
   - Handle app access role assignment
   - Enforce employee linking

5. **Update AccessControlCubit**
   - Work with `AppAccessRole` instead of `OrganizationRole`

### Phase 4: UI Components

1. **App Access Roles Page** (new)
   - Create/manage app access roles
   - Configure permissions
   - Similar to current Roles page but for permissions only

2. **Job Roles Page** (rename current Roles page or create new)
   - Create/manage job roles
   - Set default wage types
   - No permissions here

3. **Update Employee Forms**
   - Multi-select for job roles
   - Primary role selection
   - Wage type selection with conditional fields:
     - perMonth: Fixed salary input
     - perTrip/perBatch: Rate input
     - perHour: Hourly rate input
     - perKm: Per km rate input
     - commission: Commission percentage
     - hybrid: Base amount + commission percentage

4. **Update User Forms**
   - App access role dropdown (instead of role dropdown)
   - Employee selection (required)
   - Link user to employee

5. **Update Permission Checks**
   - Update all `PermissionHelper` calls
   - Update navigation guards
   - Update UI visibility checks

---

## Firebase Schema Changes

### New Collections

#### `ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES/{roleId}`
```typescript
{
  roleId: string;
  name: string;                    // "Admin", "Manager", "Operator"
  description?: string;
  colorHex: string;
  isAdmin: boolean;
  permissions: {
    sections: { [sectionKey]: boolean };
    pages: { [pageKey]: PageCrudPermissions };
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### `ORGANIZATIONS/{orgId}/JOB_ROLES/{jobRoleId}`
```typescript
{
  jobRoleId: string;
  title: string;                   // "Delivery Driver", "Manager"
  department?: string;
  description?: string;
  colorHex: string;
  defaultWageType?: string;        // "perMonth", "perTrip", etc.
  sortOrder?: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### Updated Collections

#### `EMPLOYEES/{employeeId}`
```typescript
{
  employeeId: string;
  employeeName: string;
  organizationId: string;
  jobRoleIds: string[];            // ✅ NEW: Array of job role IDs
  jobRoles: {                      // ✅ NEW: Denormalized job role info
    [jobRoleId: string]: {
      jobRoleId: string;
      jobRoleTitle: string;
      assignedAt: Timestamp;
      isPrimary: boolean;
    }
  };
  wage: {                          // ✅ NEW: Per-employee wage structure
    type: string;                  // "perMonth", "perTrip", etc.
    baseAmount?: number;           // For perMonth
    rate?: number;                 // For perTrip, perBatch, etc.
    unit?: string;
    commissionPercent?: number;
    hybridStructure?: {
      baseAmount: number;
      commissionPercent: number;
    };
  };
  openingBalance: number;
  currentBalance: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

#### `ORGANIZATIONS/{orgId}/USERS/{userId}`
```typescript
{
  user_id: string;
  user_name: string;
  phone: string;
  organization_id: string;
  employee_id: string;             // ✅ NEW: Always required
  app_access_role_id?: string;     // ✅ NEW: For permissions (was role_id)
  org_name: string;
  created_at: Timestamp;
  updated_at: Timestamp;
  joined_at: Timestamp;
}
```

---

## Key Design Decisions

1. ✅ **Two Separate Entities**: AppAccessRole and OrganizationJobRole
2. ✅ **No Migration**: Fresh start, no backward compatibility
3. ✅ **No Default Roles**: Organizations create their own
4. ✅ **Always Link User → Employee**: Required relationship
5. ✅ **Per-Employee Wages**: Wage structure stored on employee, not role
6. ✅ **Multiple Job Roles**: Employees can have multiple roles with primary flag

---

## Validation Rules

### Employee
- Must have at least one job role
- Exactly one job role must be marked as primary
- Wage type validation:
  - `perMonth`: `baseAmount` required
  - `perTrip`, `perBatch`, `perHour`, `perKm`: `rate` required
  - `commission`: `commissionPercent` required
  - `hybrid`: `hybridStructure` required

### User
- `employeeId` is always required
- `appAccessRoleId` is optional (user might not need app access)
- If `appAccessRoleId` is provided, it must reference valid `AppAccessRole`

---

## Files Created/Modified

### ✅ Created
- `lib/domain/entities/app_access_role.dart`
- `lib/domain/entities/organization_job_role.dart`
- `lib/domain/entities/wage_type.dart`
- `lib/domain/entities/employee_job_role.dart`
- `ROLE_TYPES_DISCUSSION.md`
- `ROLE_EMPLOYEE_IMPLEMENTATION_PLAN.md`
- `SCHEMA_IMPLEMENTATION_SUMMARY.md`

### ✅ Updated
- `lib/domain/entities/organization_employee.dart`
- `lib/domain/entities/organization_user.dart`

### 📋 Still To Update (Phase 2+)
- Data sources and repositories
- Cubits/Blocs
- UI components
- Permission helpers

---

## Notes

- All new entities are ready for use
- Old `OrganizationRole` class still exists but should be replaced gradually
- Firebase indexes may need updates for new query patterns
- UI components will need significant updates to support new structure
