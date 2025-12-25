# Role Types Discussion: App Access vs Organization Role

## Problem Statement

Currently, the `OrganizationRole` entity is being used for **two distinct purposes**, which creates confusion and limitations:

1. **App Access Control** - Controls what users can do in the application (permissions)
2. **Organization Job Role** - Describes the actual job/position in the organization (e.g., "Driver", "Manager", "Sales Executive")

### Current Conflation

The `OrganizationRole` class currently mixes both concepts:

```dart
class OrganizationRole {
  final String id;
  final String title;              // ❌ Used for BOTH app access AND job description
  final SalaryType salaryType;     // ❌ Should be per-employee, not per-role
  final String colorHex;           // ✅ UI display
  final RolePermissions permissions; // ✅ App access control
}
```

### Problems with Current Approach

1. ❌ **Salary Type at Role Level**: `salaryType` is stored in the role, but different employees with the same role might have different wage structures
2. ❌ **Permission = Job Role**: Users with the same job (e.g., "Driver") might need different app permissions
3. ❌ **Flexibility Issue**: Can't have employees with job roles that don't need app access
4. ❌ **Clarity Issue**: Is "Admin" a job role or a permission level?

---

## Two Separate Concepts

### 1. **App Access Role** (Permission Role)
**Purpose**: Controls what a user can do in the application

**Characteristics**:
- Defines permissions (sections, pages, CRUD operations)
- Used for access control
- Can be shared across multiple users
- Examples: "Admin", "Manager Access", "Viewer Only", "Operator", "Limited Access"

**Properties**:
- Permissions (sections, pages)
- App access levels
- Navigation visibility
- Feature access

### 2. **Organization Job Role** (Position/Title)
**Purpose**: Describes the employee's position in the organization

**Characteristics**:
- Job title/position description
- NOT related to app permissions
- Used for organizational structure
- Examples: "Delivery Driver", "Operations Manager", "Sales Executive", "Warehouse Loader", "Accountant"

**Properties**:
- Job title
- Department (optional)
- Typical wage type (suggested default, not enforced)
- Organizational hierarchy

---

## Proposed Solution: Separate the Concepts

### Option 1: Two Separate Entities (Recommended)

**Clear separation with dedicated entities for each purpose.**

#### Entity 1: `AppAccessRole` (Permission Role)
```dart
class AppAccessRole {
  final String id;
  final String name;                    // e.g., "Admin", "Manager", "Viewer"
  final String description;             // Optional description
  final String colorHex;                // For UI display
  final RolePermissions permissions;    // App access permissions
  final bool isAdmin;                   // Is this an admin role
  
  // Methods
  bool canAccessSection(String section);
  bool canCreate(String page);
  bool canEdit(String page);
  bool canDelete(String page);
}
```

**Firebase Structure:**
```typescript
ORGANIZATIONS/{orgId}/
  APP_ACCESS_ROLES/{roleId}
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

#### Entity 2: `OrganizationJobRole` (Job Position)
```dart
class OrganizationJobRole {
  final String id;
  final String title;                  // e.g., "Delivery Driver", "Manager"
  final String? department;            // Optional: "Logistics", "Sales", "HR"
  final String? description;           // Job description
  final String colorHex;               // For UI display
  final WageType? defaultWageType;     // Suggested default, not enforced
  final int? sortOrder;                // For display ordering
  
  const OrganizationJobRole({
    required this.id,
    required this.title,
    this.department,
    this.description,
    required this.colorHex,
    this.defaultWageType,
    this.sortOrder,
  });
}
```

**Firebase Structure:**
```typescript
ORGANIZATIONS/{orgId}/
  JOB_ROLES/{jobRoleId}
  {
    jobRoleId: string;
    title: string;                     // "Delivery Driver", "Operations Manager"
    department?: string;               // "Logistics", "Sales", etc.
    description?: string;
    colorHex: string;
    defaultWageType?: string;          // Suggested default: "perMonth", "perTrip", etc.
    sortOrder?: number;                // Display order
    createdAt: Timestamp;
    updatedAt: Timestamp;
  }
```

#### Updated Employee Entity
```dart
class OrganizationEmployee {
  final String id;
  final String organizationId;
  final String name;
  
  // Job Roles (can have multiple)
  final List<String> jobRoleIds;
  final Map<String, OrganizationJobRole> jobRoles;
  
  // Wage Structure (per-employee, not per-role)
  final EmployeeWage wage;
  
  // Financial
  final double openingBalance;
  final double currentBalance;
}
```

#### Updated User Entity
```dart
class OrganizationUser {
  final String id;
  final String name;
  final String phone;
  final String organizationId;
  
  // App Access Role (single - controls permissions)
  final String? appAccessRoleId;
  final AppAccessRole? appAccessRole;
  
  // Optional link to employee
  final String? employeeId;
}
```

---

### Option 2: Keep Single Entity with Type Field

**Add a type discriminator to distinguish usage.**

```dart
enum RoleType {
  appAccess,      // For app permissions
  jobPosition,    // For organizational structure
}

class OrganizationRole {
  final String id;
  final RoleType type;                // ✅ NEW: Type discriminator
  final String title;
  final String colorHex;
  
  // App Access specific
  final RolePermissions? permissions;  // Only for appAccess type
  
  // Job Position specific
  final WageType? defaultWageType;     // Only for jobPosition type
  final String? department;
  
  const OrganizationRole({
    required this.id,
    required this.type,
    required this.title,
    required this.colorHex,
    this.permissions,
    this.defaultWageType,
    this.department,
  });
}
```

**Pros:**
- Single entity, easier migration
- Shared UI components

**Cons:**
- Still somewhat conflated
- Nullable fields for different types
- Less clear separation

---

### Option 3: Keep Current Structure, Separate in Usage

**Keep single entity but use it differently:**

- **For App Access**: Only use roles that have permissions configured
- **For Employees**: Create separate "Job Positions" but use same structure (without permissions)
- **Naming Convention**: 
  - App roles: "Admin", "Manager", "Operator"
  - Job roles: "Driver", "Loader", "Accountant"

**Pros:**
- Minimal code changes
- Reuses existing structure

**Cons:**
- Confusing conceptually
- Still have salaryType in role (wrong place)
- Hard to enforce separation

---

## Recommended Approach: Option 1 (Two Separate Entities)

### Benefits

1. ✅ **Clear Separation**: No confusion about purpose
2. ✅ **Flexible Permissions**: Users can have app access independent of job role
3. ✅ **Flexible Wages**: Employees can have different wages regardless of job role
4. ✅ **Better Scalability**: Easy to add features specific to each type
5. ✅ **Clearer Code**: Type system enforces correct usage

### Example Scenarios

#### Scenario 1: Driver with App Access
- **Job Role**: "Delivery Driver" (organizational position)
- **App Access Role**: "Operator" (can view orders, update status)
- **Employee Wage**: `perTrip` with rate ₹150/trip

#### Scenario 2: Manager with Full Access
- **Job Role**: "Operations Manager" (organizational position)
- **App Access Role**: "Manager" (can access all sections, full CRUD)
- **Employee Wage**: `perMonth` with ₹50,000/month

#### Scenario 3: Loader without App Access
- **Job Role**: "Warehouse Loader" (organizational position)
- **App Access Role**: `null` (no app access needed)
- **Employee Wage**: `perHour` with ₹250/hour

#### Scenario 4: Part-time Driver
- **Job Role**: "Delivery Driver" (same as Scenario 1)
- **App Access Role**: "Viewer" (can only view, limited access)
- **Employee Wage**: `perTrip` with rate ₹120/trip (different from Scenario 1)

---

## Migration Strategy

### Phase 1: Add New Entities (No Breaking Changes)

1. Create `AppAccessRole` entity
2. Create `OrganizationJobRole` entity
3. Update `OrganizationUser` to use `appAccessRoleId`
4. Update `OrganizationEmployee` to use `jobRoleIds`

### Phase 2: Dual Support

1. Support both old and new schema
2. Migration script to create `AppAccessRole` and `OrganizationJobRole` from existing `OrganizationRole`
3. Migration logic:
   - If role has permissions → Create as `AppAccessRole`
   - Also create as `OrganizationJobRole` for employees
   - Update users to reference `AppAccessRole`
   - Update employees to reference `OrganizationJobRole`

### Phase 3: Cleanup

1. Remove old `OrganizationRole` references
2. Update all UI to use new entities
3. Remove old `salaryType` from roles (move to employees)

---

## Firebase Schema Changes

### Current Structure
```
ORGANIZATIONS/{orgId}/
  ROLES/{roleId}
  {
    roleId, title, salaryType, colorHex, permissions
  }
```

### New Structure
```
ORGANIZATIONS/{orgId}/
  APP_ACCESS_ROLES/{roleId}
  {
    roleId, name, description, colorHex, isAdmin, permissions
  }
  
  JOB_ROLES/{jobRoleId}
  {
    jobRoleId, title, department, description, colorHex, defaultWageType
  }
```

### Updated Collections
```
EMPLOYEES/{employeeId}
{
  employeeId, employeeName, organizationId,
  jobRoleIds: string[],           // ✅ NEW
  jobRoles: { ... },              // ✅ NEW (denormalized)
  wages: { type, baseAmount, ... }, // ✅ NEW (moved from role)
  // ... existing fields
}

ORGANIZATIONS/{orgId}/USERS/{userId}
{
  user_id, user_name, phone,
  app_access_role_id: string,     // ✅ NEW (was role_id)
  employee_id?: string,
  // ... existing fields
}
```

---

## UI/UX Impact

### Access Control Page
- **Current**: Shows roles with permissions
- **New**: Shows `AppAccessRole` entities only
- **Change**: Rename to "App Access Roles" or "Permission Roles"

### Roles Management Page
- **Current**: Shows all roles
- **New**: Shows `OrganizationJobRole` entities (job positions)
- **Change**: Rename to "Job Roles" or "Positions"

### Employee Form
- **Current**: Single role dropdown
- **New**: 
  - Multi-select for Job Roles
  - Wage configuration (independent of role)
  - No app access configuration here

### User Form
- **Current**: Role dropdown (for permissions)
- **New**: 
  - App Access Role dropdown (for permissions)
  - Optional link to Employee (for job role display)

---

## Questions for Discussion

1. **Naming Convention**:
   - App Access Roles: "Admin", "Manager", "Operator", "Viewer"?
   - Job Roles: "Delivery Driver", "Operations Manager", "Sales Executive"?
   - ✅ **Recommendation**: Clear naming that reflects purpose

2. **Can a User have No App Access Role?**
   - ✅ **Recommendation**: Yes, for employees who don't need app access

3. **Can an Employee have No Job Role?**
   - ✅ **Recommendation**: No, every employee should have at least one job role

4. **Should Job Roles have Default Wage Types?**
   - ✅ **Recommendation**: Yes, as a suggestion/default, but employees can override

5. **Should We Link User → Employee → Job Roles?**
   - ✅ **Recommendation**: Optional link, for display purposes only

6. **Migration Strategy:**
   - Gradual (dual support) or immediate (breaking change)?
   - ✅ **Recommendation**: Gradual with dual support for safety

7. **Default App Access Roles:**
   - Should we pre-create: "Admin", "Manager", "Operator", "Viewer"?
   - ✅ **Recommendation**: Yes, with Admin having full access

8. **Can Same Title Exist in Both Types?**
   - e.g., Can we have "Manager" as both App Access Role AND Job Role?
   - ✅ **Recommendation**: Yes, they're separate namespaces

---

## Implementation Considerations

### 1. Backward Compatibility
- Keep old `OrganizationRole` during migration
- Provide helper methods to convert old → new

### 2. Access Control Logic
```dart
// Old way
final role = user.role;
if (role.canCreate('products')) { ... }

// New way
final appRole = user.appAccessRole;
if (appRole?.canCreate('products') ?? false) { ... }
```

### 3. Employee Display
```dart
// Old way
employee.roleTitle  // "Driver"

// New way
employee.jobRoles.values.map((r) => r.title).join(', ')  // "Driver, Loader"
employee.primaryJobRole.title  // "Driver"
```

### 4. Query Considerations

**Get Users by App Access:**
```dart
final users = await firestore
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('USERS')
    .where('app_access_role_id', isEqualTo: 'admin_role_id')
    .get();
```

**Get Employees by Job Role:**
```dart
final employees = await firestore
    .collection('EMPLOYEES')
    .where('organizationId', isEqualTo: orgId)
    .where('jobRoleIds', arrayContains: 'driver_role_id')
    .get();
```

---

## Summary

### Recommended Approach: **Option 1 - Two Separate Entities**

**Benefits:**
- ✅ Clear conceptual separation
- ✅ Flexible permissions independent of job roles
- ✅ Flexible wages independent of job roles
- ✅ Better code maintainability
- ✅ Scalable for future features

**Changes Required:**
1. Create `AppAccessRole` entity (for permissions)
2. Create `OrganizationJobRole` entity (for job positions)
3. Update `OrganizationUser` to use `appAccessRoleId`
4. Update `OrganizationEmployee` to use `jobRoleIds` + per-employee wages
5. Migrate existing data
6. Update UI components

**Migration Effort:** Medium (requires careful data migration)

---

## Next Steps

1. **Review & Discuss**: Review this proposal and provide feedback
2. **Decide on Approach**: Choose Option 1, 2, or 3
3. **Create Implementation Plan**: Break down into phases
4. **Implement Entities**: Create new entity classes
5. **Create Migration Scripts**: Safely migrate existing data
6. **Update UI**: Modify all role-related UI components
7. **Update Business Logic**: Update permission checks and employee management
8. **Test Thoroughly**: Test with real-world scenarios

---

## Your Input Needed

Please review and answer:

1. **Which option do you prefer?** (Option 1, 2, or 3)
2. **Naming preferences** for the two role types?
3. **Migration timeline** - Gradual or immediate?
4. **Default roles** - Should we pre-create standard roles?
5. **User-Employee linking** - Should users always link to employees, or optional?

Let's discuss before implementing! 🚀
