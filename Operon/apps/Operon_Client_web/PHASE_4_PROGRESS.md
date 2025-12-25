# Phase 4 Progress: UI Components Update

## ✅ Completed

### 1. Router Configuration ✅
- ✅ Updated `app_router.dart` with new repository imports
- ✅ Updated `AccessControlCubit` provider to use `AppAccessRolesRepository`
- ✅ Updated `EmployeesCubit` provider to include `JobRolesRepository`
- ✅ Updated all `role` references to `appAccessRole` in router

### 2. App Repository Providers ✅
- ✅ Added `AppAccessRolesRepository` provider to `app.dart`
- ✅ Added `JobRolesRepository` provider to `app.dart`
- ✅ Added data source imports

### 3. App Initialization ✅
- ✅ Updated `AppInitializationCubit` to use `AppAccessRolesRepository`
- ✅ Updated role fetching logic to use `AppAccessRole`
- ✅ Updated restore context logic

### 4. Organization Selection Page ✅
- ✅ Updated to use `AppAccessRolesRepository`
- ✅ Changed role fetching to app access roles
- ✅ Updated `setContext` call to use `appAccessRole`

### 5. Access Control Page ✅
- ✅ Already updated in Phase 3 (cubit uses `AppAccessRole`)
- ✅ Should work correctly with new schema

---

## 🔄 In Progress

### 6. Roles Page
**Current Status**: Still uses old `RolesCubit` and `OrganizationRole`
**Needs**: 
- Convert to use `AppAccessRolesCubit` 
- Update UI to work with `AppAccessRole` entity
- Consider: Split into "App Access Roles" and "Job Roles" pages?

---

## ⏳ Pending

### 7. Employee Forms
- Multi-select for job roles
- Primary role selection
- Wage type dropdown with conditional fields
- Remove old `roleId`/`roleTitle` fields
- Update employee creation/editing dialogs

### 8. User Forms
- App access role dropdown (instead of role)
- Employee selection (required, not optional)
- Display employee's job roles
- Update user creation/editing dialogs

### 9. SectionWorkspaceLayout
- Already updated most references in Phase 3
- Need to verify all role references are updated

---

## Notes

- The old `RolesCubit` and `RolesRepository` still exist for backward compatibility
- The "Roles" page currently manages old-style roles - needs conversion
- Job Roles page needs to be created separately (or integrated into Roles page with tabs)
