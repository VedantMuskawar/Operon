# Phase 2 Complete: Data Sources & Repositories

## ✅ Completed

### New Data Sources Created

1. **AppAccessRolesDataSource** (`lib/data/datasources/app_access_roles_data_source.dart`)
   - `fetchAppAccessRoles(orgId)` - Get all app access roles
   - `fetchAppAccessRole(orgId, roleId)` - Get single role
   - `createAppAccessRole(orgId, role)` - Create new role
   - `updateAppAccessRole(orgId, role)` - Update existing role
   - `deleteAppAccessRole(orgId, roleId)` - Delete role
   - Collection: `ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES/{roleId}`

2. **JobRolesDataSource** (`lib/data/datasources/job_roles_data_source.dart`)
   - `fetchJobRoles(orgId)` - Get all job roles
   - `fetchJobRole(orgId, jobRoleId)` - Get single job role
   - `fetchJobRolesByIds(orgId, jobRoleIds)` - Batch fetch by IDs (handles >10 limit)
   - `createJobRole(orgId, jobRole)` - Create new job role
   - `updateJobRole(orgId, jobRole)` - Update existing job role
   - `deleteJobRole(orgId, jobRoleId)` - Delete job role
   - Collection: `ORGANIZATIONS/{orgId}/JOB_ROLES/{jobRoleId}`

### New Repositories Created

3. **AppAccessRolesRepository** (`lib/data/repositories/app_access_roles_repository.dart`)
   - Business logic wrapper for AppAccessRolesDataSource
   - All CRUD operations

4. **JobRolesRepository** (`lib/data/repositories/job_roles_repository.dart`)
   - Business logic wrapper for JobRolesDataSource
   - All CRUD operations + batch fetch

### Updated Data Sources

5. **EmployeesDataSource** (`lib/data/datasources/employees_data_source.dart`)
   - ✅ Updated `updateEmployee()` to use new schema (jobRoleIds, wage structure)
   - ✅ Added `fetchEmployee(employeeId)` - Get single employee
   - ✅ Added `fetchEmployeesByJobRole(orgId, jobRoleId)` - Query employees by job role

6. **EmployeesRepository** (`lib/data/repositories/employees_repository.dart`)
   - ✅ Added `fetchEmployee(employeeId)`
   - ✅ Added `fetchEmployeesByJobRole(orgId, jobRoleId)`

7. **UsersDataSource** (`lib/data/datasources/users_data_source.dart`)
   - ✅ Updated `_ensureOrgMembership()` to use `appAccessRoleName` instead of `roleTitle`
   - ✅ Now supports `app_access_role_id` field (via `user.toMap()`)
   - ✅ Enforces `employee_id` requirement (via updated `OrganizationUser` entity)

8. **UsersRepository** (`lib/data/repositories/users_repository.dart`)
   - ✅ No changes needed (passes through to data source)

---

## Firebase Query Patterns

### App Access Roles
```dart
// Get all app access roles for org
final roles = await appAccessRolesRepo.fetchAppAccessRoles(orgId);

// Get single role
final role = await appAccessRolesRepo.fetchAppAccessRole(orgId, roleId);
```

### Job Roles
```dart
// Get all job roles for org
final jobRoles = await jobRolesRepo.fetchJobRoles(orgId);

// Get job roles by IDs (handles batching for >10)
final jobRoles = await jobRolesRepo.fetchJobRolesByIds(orgId, ['role1', 'role2', ...]);
```

### Employees
```dart
// Get all employees
final employees = await employeesRepo.fetchEmployees(orgId);

// Get employees by job role
final drivers = await employeesRepo.fetchEmployeesByJobRole(orgId, 'driver_role_id');

// Get single employee
final employee = await employeesRepo.fetchEmployee(employeeId);
```

### Users
```dart
// Get all users (app access role loaded separately if needed)
final users = await usersRepo.fetchOrgUsers(orgId);
```

---

## Important Notes

1. **Batch Fetching**: `fetchJobRolesByIds` handles Firestore's 10-item limit for `whereIn` queries by splitting into batches

2. **Denormalized Data**: 
   - Employee `jobRoles` map contains denormalized job role info
   - User `appAccessRole` is loaded separately (not stored in user document)

3. **Employee ID Requirement**: 
   - `OrganizationUser` now requires `employeeId` field
   - Validation should happen at business logic layer

4. **App Access Role Loading**: 
   - Users fetch their `appAccessRoleId`
   - To get full `appAccessRole` object, fetch separately:
   ```dart
   final user = users.first;
   if (user.appAccessRoleId != null) {
     final appRole = await appAccessRolesRepo.fetchAppAccessRole(orgId, user.appAccessRoleId!);
     user = user.copyWith(appAccessRole: appRole);
   }
   ```

---

## Next: Phase 3 - Business Logic (Cubits/Blocs)

Ready to create:
1. AppAccessRolesCubit
2. JobRolesCubit
3. Update EmployeesCubit
4. Update UsersCubit
5. Update AccessControlCubit
