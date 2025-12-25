# Employee Data Schema Proposal

## Overview
This document proposes an enhanced employee data schema that supports:
1. **Multiple Roles per Employee** - An employee can have multiple roles
2. **Flexible Wage Types** - Support for perMonth, perTrip, perBatch, and other wage calculation methods
3. **Fixed Salary for Monthly Employees** - Monthly employees can have a fixed salary amount

---

## Current Schema Analysis

### Current Structure (Both Android & Web)
```dart
class OrganizationEmployee {
  final String id;
  final String organizationId;
  final String name;
  final String roleId;              // ❌ Single role only
  final String roleTitle;           // ❌ Denormalized role title
  final double openingBalance;
  final double currentBalance;
  final SalaryType salaryType;      // ❌ Only 2 types: salaryMonthly, wages
  final double? salaryAmount;       // ❌ Only for monthly, single amount
}
```

### Current Firebase Document Structure
```typescript
{
  employeeId: string;
  employeeName: string;
  organizationId: string;
  roleId: string;                   // Single role
  roleTitle: string;                // Denormalized
  openingBalance: number;
  currentBalance: number;
  salaryType: string;               // "salaryMonthly" | "wages"
  salaryAmount?: number;            // Optional, only for monthly
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### Current Limitations
1. ❌ **Single Role Constraint**: Employee can only have one role
2. ❌ **Limited Wage Types**: Only 2 wage types supported
3. ❌ **Inflexible Salary**: Only one `salaryAmount` field
4. ❌ **Type Ambiguity**: "wages" type doesn't specify how it's calculated

---

## Proposed Schema Design

### Option 1: Enhanced Single Document (Recommended for Simplicity)

**Firebase Document Structure:**
```typescript
{
  employeeId: string;                      // Same as document ID
  employeeName: string;
  organizationId: string;
  
  // MULTIPLE ROLES SUPPORT
  roleIds: string[];                       // Array of role IDs
  roles: {                                 // Denormalized role info for quick access
    [roleId: string]: {
      roleId: string;
      roleTitle: string;
      assignedAt: Timestamp;               // When role was assigned
      isPrimary: boolean;                  // Primary role for display purposes
    }
  };
  
  // FLEXIBLE WAGE STRUCTURE
  wages: {
    type: "perMonth" | "perTrip" | "perBatch" | "perHour" | "perKm" | "commission" | "hybrid";
    baseAmount?: number;                   // For perMonth: fixed monthly salary
    rate?: number;                         // For perTrip, perBatch, perHour, perKm
    unit?: string;                         // Unit of measurement (optional)
    commissionPercent?: number;            // For commission-based
    hybridStructure?: {                    // For hybrid wage types
      baseAmount: number;
      commissionPercent: number;
    };
    effectiveFrom?: Timestamp;             // When this wage structure became effective
  };
  
  // EXISTING FIELDS
  openingBalance: number;
  currentBalance: number;
  
  // METADATA
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Dart Entity:**
```dart
enum WageType {
  perMonth,    // Fixed monthly salary
  perTrip,     // Payment per delivery trip
  perBatch,    // Payment per batch/order batch
  perHour,     // Hourly wage
  perKm,       // Payment per kilometer
  commission,  // Commission-based
  hybrid,      // Combination (e.g., base + commission)
}

class EmployeeRole {
  final String roleId;
  final String roleTitle;
  final DateTime assignedAt;
  final bool isPrimary;

  const EmployeeRole({
    required this.roleId,
    required this.roleTitle,
    required this.assignedAt,
    this.isPrimary = false,
  });
}

class EmployeeWage {
  final WageType type;
  final double? baseAmount;        // For perMonth fixed salary
  final double? rate;              // For perTrip, perBatch, perHour, perKm
  final String? unit;              // Unit of measurement
  final double? commissionPercent; // For commission-based
  final HybridWageStructure? hybridStructure;
  final DateTime? effectiveFrom;

  const EmployeeWage({
    required this.type,
    this.baseAmount,
    this.rate,
    this.unit,
    this.commissionPercent,
    this.hybridStructure,
    this.effectiveFrom,
  });
}

class HybridWageStructure {
  final double baseAmount;
  final double commissionPercent;

  const HybridWageStructure({
    required this.baseAmount,
    required this.commissionPercent,
  });
}

class OrganizationEmployee {
  final String id;
  final String organizationId;
  final String name;
  final List<String> roleIds;                    // ✅ Multiple roles
  final Map<String, EmployeeRole> roles;         // ✅ Role details
  final EmployeeWage wage;                       // ✅ Flexible wage structure
  final double openingBalance;
  final double currentBalance;

  // Helper getters for backward compatibility
  String get primaryRoleId => 
    roles.values.firstWhere((r) => r.isPrimary).roleId;
  String get primaryRoleTitle => 
    roles.values.firstWhere((r) => r.isPrimary).roleTitle;
}
```

---

### Option 2: Separate Collections (More Normalized)

This approach uses separate collections but is more complex to query.

**Collections:**
1. `EMPLOYEES` - Core employee data
2. `EMPLOYEE_ROLES` - Many-to-many relationship
3. `EMPLOYEE_WAGES` - Wage history and current structure

**Pros:**
- Better normalization
- Easier to query roles separately
- Wage history tracking

**Cons:**
- Multiple queries needed
- More complex to maintain
- Harder to migrate

---

## Recommended Approach: Option 1 (Enhanced Single Document)

### Benefits
1. ✅ **Simple Queries**: Single document read for employee data
2. ✅ **Backward Compatible**: Can add migration logic to convert old schema
3. ✅ **Flexible**: Easy to add new wage types
4. ✅ **Performant**: All data in one place
5. ✅ **Easy Migration**: Can gradually migrate old documents

### Migration Strategy

**Phase 1: Dual Support**
- Support both old schema (`roleId`, `salaryType`) and new schema (`roleIds`, `wages`)
- Read logic checks for both formats
- Write logic always uses new format

**Phase 2: Migration Script**
- Batch update all employees to new schema
- Keep old fields for rollback safety

**Phase 3: Cleanup**
- Remove old fields after verification

---

## Wage Type Details

### 1. **perMonth** (Fixed Monthly Salary)
```dart
EmployeeWage(
  type: WageType.perMonth,
  baseAmount: 30000.0,  // Fixed monthly salary
)
```

### 2. **perTrip** (Payment per Delivery Trip)
```dart
EmployeeWage(
  type: WageType.perTrip,
  rate: 150.0,          // Amount per trip
  unit: "trip",
)
```

### 3. **perBatch** (Payment per Order Batch)
```dart
EmployeeWage(
  type: WageType.perBatch,
  rate: 500.0,          // Amount per batch
  unit: "batch",
)
```

### 4. **perHour** (Hourly Wage)
```dart
EmployeeWage(
  type: WageType.perHour,
  rate: 250.0,          // Amount per hour
  unit: "hour",
)
```

### 5. **perKm** (Payment per Kilometer)
```dart
EmployeeWage(
  type: WageType.perKm,
  rate: 15.0,           // Amount per kilometer
  unit: "km",
)
```

### 6. **commission** (Commission-Based)
```dart
EmployeeWage(
  type: WageType.commission,
  commissionPercent: 5.0,  // 5% commission
)
```

### 7. **hybrid** (Base + Commission)
```dart
EmployeeWage(
  type: WageType.hybrid,
  hybridStructure: HybridWageStructure(
    baseAmount: 15000.0,      // Fixed base
    commissionPercent: 3.0,   // 3% commission on top
  ),
)
```

---

## Example Use Cases

### Use Case 1: Delivery Driver with Multiple Roles
```json
{
  "employeeId": "emp123",
  "employeeName": "Rajesh Kumar",
  "organizationId": "org456",
  "roleIds": ["role_driver", "role_loader"],
  "roles": {
    "role_driver": {
      "roleId": "role_driver",
      "roleTitle": "Delivery Driver",
      "assignedAt": "2024-01-01T00:00:00Z",
      "isPrimary": true
    },
    "role_loader": {
      "roleId": "role_loader",
      "roleTitle": "Loader",
      "assignedAt": "2024-02-01T00:00:00Z",
      "isPrimary": false
    }
  },
  "wages": {
    "type": "perTrip",
    "rate": 200.0,
    "unit": "trip"
  },
  "openingBalance": 0,
  "currentBalance": 0
}
```

### Use Case 2: Manager with Fixed Salary
```json
{
  "employeeId": "emp456",
  "employeeName": "Priya Sharma",
  "organizationId": "org456",
  "roleIds": ["role_manager"],
  "roles": {
    "role_manager": {
      "roleId": "role_manager",
      "roleTitle": "Operations Manager",
      "assignedAt": "2024-01-01T00:00:00Z",
      "isPrimary": true
    }
  },
  "wages": {
    "type": "perMonth",
    "baseAmount": 50000.0
  },
  "openingBalance": 0,
  "currentBalance": 0
}
```

### Use Case 3: Salesperson with Hybrid Wage
```json
{
  "employeeId": "emp789",
  "employeeName": "Amit Patel",
  "organizationId": "org456",
  "roleIds": ["role_sales"],
  "roles": {
    "role_sales": {
      "roleId": "role_sales",
      "roleTitle": "Sales Executive",
      "assignedAt": "2024-01-01T00:00:00Z",
      "isPrimary": true
    }
  },
  "wages": {
    "type": "hybrid",
    "hybridStructure": {
      "baseAmount": 20000.0,
      "commissionPercent": 5.0
    }
  },
  "openingBalance": 0,
  "currentBalance": 0
}
```

---

## Implementation Considerations

### 1. **Backward Compatibility Helper Methods**
```dart
extension OrganizationEmployeeCompat on OrganizationEmployee {
  // For code still using old single-role pattern
  String get roleId => primaryRoleId;
  String get roleTitle => primaryRoleTitle;
  
  // For code still using old salary pattern
  SalaryType get salaryType {
    switch (wage.type) {
      case WageType.perMonth:
        return SalaryType.salaryMonthly;
      default:
        return SalaryType.wages;
    }
  }
  
  double? get salaryAmount => 
    wage.type == WageType.perMonth ? wage.baseAmount : null;
}
```

### 2. **UI Changes Required**

**Employee Form:**
- Role selection: Multi-select dropdown/checkboxes instead of single select
- Mark primary role checkbox
- Wage type selection with conditional fields:
  - **perMonth**: Show fixed salary input
  - **perTrip/perBatch**: Show rate input
  - **perHour**: Show hourly rate input
  - **perKm**: Show per km rate input
  - **commission**: Show commission percentage input
  - **hybrid**: Show both base amount and commission percentage

### 3. **Query Considerations**

**Get Employees by Role:**
```dart
// Query employees who have a specific role
final employees = await firestore
    .collection('EMPLOYEES')
    .where('roleIds', arrayContains: 'role_driver')
    .get();
```

**Get Employees by Wage Type:**
```dart
// This requires array-contains-any or collection group query
// OR filter in application code after fetching
final allEmployees = await fetchEmployees(orgId);
final monthlyEmployees = allEmployees
    .where((e) => e.wage.type == WageType.perMonth)
    .toList();
```

### 4. **Data Validation**

**Rules:**
- At least one role must be assigned
- Exactly one role must be marked as primary
- For `perMonth`: `baseAmount` is required
- For `perTrip`, `perBatch`, `perHour`, `perKm`: `rate` is required
- For `commission`: `commissionPercent` is required
- For `hybrid`: `hybridStructure` is required

---

## Questions for Discussion

1. **Primary Role**: Should there always be a primary role, or can all roles be equal?
   - ✅ **Recommendation**: Always require one primary role for display/sorting purposes

2. **Wage History**: Do we need to track wage history, or just current wage?
   - ✅ **Recommendation**: Start with current wage only, add history later if needed

3. **Role Priority**: Should roles have priority/order, or just primary flag?
   - ✅ **Recommendation**: Primary flag is sufficient for now

4. **Wage Type Extensibility**: Should we make wage types configurable per organization?
   - ✅ **Recommendation**: Use enum for now, can make configurable later

5. **Migration Timeline**: How aggressive should migration be?
   - ✅ **Recommendation**: Gradual migration with dual support for 2-3 months

6. **Default Wage Type**: What should be default for existing employees during migration?
   - ✅ **Recommendation**: Migrate `salaryMonthly` → `perMonth`, `wages` → `perTrip`

---

## Firebase Security Rules Considerations

```javascript
// Example rules
match /EMPLOYEES/{employeeId} {
  allow read: if request.auth != null && 
    resource.data.organizationId == getOrgId(request.auth.uid);
  
  allow create: if request.auth != null && 
    canCreateEmployee(getOrgId(request.auth.uid));
  
  allow update: if request.auth != null && 
    canEditEmployee(getOrgId(request.auth.uid));
  
  allow delete: if request.auth != null && 
    canDeleteEmployee(getOrgId(request.auth.uid));
}
```

---

## Next Steps

1. **Review & Approve**: Review this proposal and provide feedback
2. **Create Migration Script**: Write script to migrate existing data
3. **Update Entity Classes**: Implement new Dart entities
4. **Update UI Components**: Modify employee forms and displays
5. **Update Business Logic**: Modify wage calculation logic
6. **Testing**: Test with real data scenarios
7. **Deploy**: Gradual rollout with monitoring

---

## Summary

This proposal enhances the employee schema to support:
- ✅ Multiple roles per employee
- ✅ Flexible wage types (7 types supported)
- ✅ Fixed salary for monthly employees
- ✅ Backward compatibility during migration
- ✅ Extensible design for future wage types

The recommended approach uses an enhanced single document structure that maintains simplicity while adding the required flexibility.
