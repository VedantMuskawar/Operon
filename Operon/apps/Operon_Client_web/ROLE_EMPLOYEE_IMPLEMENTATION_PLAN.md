# Implementation Plan: Role Types & Employee Schema

## Decisions Made

1. ✅ **Option 1**: Two separate entities (`AppAccessRole` and `OrganizationJobRole`)
2. ✅ **No Migration**: Start fresh with new structure (no backward compatibility needed)
3. ✅ **No Default Roles**: Organizations create their own roles
4. ✅ **Always Link User → Employee**: Every user must be linked to an employee

---

## Implementation Phases

### Phase 1: Create New Entity Classes
1. Create `AppAccessRole` entity (for permissions)
2. Create `OrganizationJobRole` entity (for job positions)
3. Update `WageType` enum (enhanced wage types)
4. Create `EmployeeWage` class
5. Update `OrganizationEmployee` entity
6. Update `OrganizationUser` entity

### Phase 2: Update Data Sources & Repositories
1. Create `AppAccessRolesDataSource`
2. Create `AppAccessRolesRepository`
3. Create `JobRolesDataSource`
4. Create `JobRolesRepository`
5. Update `EmployeesDataSource` and `EmployeesRepository`
6. Update `UsersDataSource` and `UsersRepository`

### Phase 3: Update Business Logic (Cubits/Blocs)
1. Create `AppAccessRolesCubit`
2. Create `JobRolesCubit`
3. Update `EmployeesCubit`
4. Update `UsersCubit`
5. Update `AccessControlCubit` (use AppAccessRole)

### Phase 4: Update UI Components
1. Create/Update Access Control page (AppAccessRole management)
2. Create/Update Job Roles page (OrganizationJobRole management)
3. Update Employee forms (multi-select job roles, wage configuration)
4. Update User forms (app access role, employee link)
5. Update navigation and permission checks

---

## Entity Structures

### AppAccessRole
- Purpose: App permissions
- Collection: `ORGANIZATIONS/{orgId}/APP_ACCESS_ROLES`
- Used by: Users (via `appAccessRoleId`)

### OrganizationJobRole
- Purpose: Job positions/titles
- Collection: `ORGANIZATIONS/{orgId}/JOB_ROLES`
- Used by: Employees (via `jobRoleIds[]`)

### Employee
- Has: Multiple job roles, per-employee wage structure
- Collection: `EMPLOYEES` (global)

### User
- Has: Single app access role, always linked to employee
- Collection: `ORGANIZATIONS/{orgId}/USERS`

---

## Next Steps

Starting implementation with Phase 1...
