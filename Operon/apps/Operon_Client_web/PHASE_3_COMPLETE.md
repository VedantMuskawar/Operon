# Phase 3 Complete: Business Logic (Cubits/Blocs)

## ✅ Completed

### New Cubits Created

1. **AppAccessRolesCubit** (`lib/presentation/blocs/app_access_roles/app_access_roles_cubit.dart`)
   - State: `AppAccessRolesState` with `List<AppAccessRole> roles`
   - Methods:
     - `load()` - Fetch all app access roles
     - `createAppAccessRole(role)` - Create new role
     - `updateAppAccessRole(role)` - Update existing role
     - `deleteAppAccessRole(roleId)` - Delete role

2. **JobRolesCubit** (`lib/presentation/blocs/job_roles/job_roles_cubit.dart`)
   - State: `JobRolesState` with `List<OrganizationJobRole> jobRoles`
   - Methods:
     - `load()` - Fetch all job roles
     - `createJobRole(jobRole)` - Create new job role
     - `updateJobRole(jobRole)` - Update existing job role
     - `deleteJobRole(jobRoleId)` - Delete job role
     - `fetchJobRolesByIds(jobRoleIds)` - Batch fetch by IDs

### Updated Cubits

3. **EmployeesCubit** (`lib/presentation/blocs/employees/employees_cubit.dart`)
   - ✅ Added `JobRolesRepository` dependency
   - ✅ State now includes `List<OrganizationJobRole> jobRoles`
   - ✅ `loadEmployees()` now loads both employees and job roles in parallel
   - ✅ Added `loadJobRoles()` method for refreshing job roles separately
   - Methods work with new employee schema (multiple roles, wage structure)

4. **UsersCubit** (`lib/presentation/blocs/users/users_cubit.dart`)
   - ✅ Added `AppAccessRolesRepository` dependency
   - ✅ State now includes `List<AppAccessRole> appAccessRoles`
   - ✅ `load()` now loads users and app access roles in parallel
   - ✅ Enriches users with `appAccessRole` objects
   - ✅ Added `loadAppAccessRoles()` method

5. **AccessControlCubit** (`lib/presentation/blocs/access_control/access_control_cubit.dart`)
   - ✅ Changed from `RolesRepository` to `AppAccessRolesRepository`
   - ✅ Changed from `List<OrganizationRole>` to `List<AppAccessRole>`
   - ✅ All permission management now works with `AppAccessRole`
   - ✅ Save/update operations use `AppAccessRole`

---

## Important Notes

### EmployeesCubit Changes
- Now requires `JobRolesRepository` in constructor
- Loads job roles alongside employees for UI dropdowns
- Employees already have `jobRoles` map with denormalized data
- Job roles in state are for selection/display purposes

### UsersCubit Changes
- Now requires `AppAccessRolesRepository` in constructor
- Automatically enriches users with `appAccessRole` objects
- Users must have `employeeId` (enforced by entity)
- App access role is optional (user might not need app access)

### AccessControlCubit Changes
- Works with `AppAccessRole` instead of `OrganizationRole`
- Permission structure remains the same (sections, pages, CRUD)
- All role operations now target app access roles

---

## Next: Phase 4 - UI Components

### Files to Update

1. **Access Control Page** - Already uses `AccessControlCubit` (should work, but may need minor updates)

2. **Roles Page** - Needs to be renamed/split:
   - Option A: Rename to "Job Roles" page (for job positions)
   - Option B: Split into two pages:
     - "App Access Roles" page (for permissions)
     - "Job Roles" page (for positions)

3. **Employee Forms** - Major updates needed:
   - Multi-select for job roles
   - Primary role selection
   - Wage type dropdown with conditional fields
   - Remove old `roleId`/`roleTitle` fields

4. **User Forms** - Updates needed:
   - App access role dropdown (instead of role)
   - Employee selection (required, not optional)
   - Display employee's job roles

5. **Permission Helpers** - Update to work with `AppAccessRole`

6. **OrgContextCubit** - May need updates if it references roles

7. **Router Configuration** - Update provider dependencies

---

## Dependency Injection Updates Needed

All pages that use these cubits need updated constructors:

### EmployeesCubit
```dart
// Old
EmployeesCubit(
  repository: employeesRepo,
  orgId: orgId,
)

// New
EmployeesCubit(
  repository: employeesRepo,
  jobRolesRepository: jobRolesRepo, // ✅ NEW
  orgId: orgId,
)
```

### UsersCubit
```dart
// Old
UsersCubit(
  repository: usersRepo,
  organizationId: orgId,
  organizationName: orgName,
)

// New
UsersCubit(
  repository: usersRepo,
  appAccessRolesRepository: appAccessRolesRepo, // ✅ NEW
  organizationId: orgId,
  organizationName: orgName,
)
```

### AccessControlCubit
```dart
// Old
AccessControlCubit(
  rolesRepository: rolesRepo,
  orgId: orgId,
)

// New
AccessControlCubit(
  appAccessRolesRepository: appAccessRolesRepo, // ✅ CHANGED
  orgId: orgId,
)
```

---

## Files Created/Updated in Phase 3

### ✅ Created
- `lib/presentation/blocs/app_access_roles/app_access_roles_cubit.dart`
- `lib/presentation/blocs/app_access_roles/app_access_roles_state.dart`
- `lib/presentation/blocs/job_roles/job_roles_cubit.dart`
- `lib/presentation/blocs/job_roles/job_roles_state.dart`

### ✅ Updated
- `lib/presentation/blocs/employees/employees_cubit.dart`
- `lib/presentation/blocs/employees/employees_state.dart`
- `lib/presentation/blocs/users/users_cubit.dart`
- `lib/presentation/blocs/access_control/access_control_cubit.dart`

---

## Ready for Phase 4: UI Updates

All business logic is now updated. Next step is updating UI components to use the new schema.
