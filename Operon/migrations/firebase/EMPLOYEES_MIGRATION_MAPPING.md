# EMPLOYEES Collection Migration Mapping - From Pave

This document defines the field mapping from the **Pave** source system to the target **EMPLOYEES** collection in Operon.

## Migration Configuration

- **Source System:** Pave
- **Source Collection:** `EMPLOYEES`
- **Target Collection:** `EMPLOYEES`
- **Target Organization ID:** `NlQgs9kADbZr4ddBRkhS`
- **Date Filter:** Migrate data up to **December 31, 2025** (31.12.25)

## Target EMPLOYEES Schema

The target EMPLOYEES collection has the following structure:

```typescript
{
  employeeId: string;             // Same as document ID (auto-generated)
  employeeName: string;            // Employee name
  organizationId: string;          // Organization reference
  roleId: string;                  // Role ID reference
  roleTitle: string;               // Role title
  salaryType: string;              // "salaryMonthly" | "wages"
  salaryAmount?: number;           // Salary amount (optional)
  openingBalance: number;          // Opening balance (default: 0)
  currentBalance: number;          // Current balance (default: 0, set same as openingBalance during migration)
  labourID?: string;               // Legacy document reference (optional)
  createdAt: Timestamp;            // Creation timestamp
  updatedAt: Timestamp;            // Update timestamp (auto-generated)
}
```

## Field Mapping

Fill in the **Pave Source Field** column with the exact field names from the Pave system.

| Target Field | Pave Source Field | Transformation Notes | Required |
|-------------|-------------------|---------------------|----------|
| `employeeId` | `id` | Employee ID. If not available, will use document ID | Yes |
| `employeeName` | `name` | Employee name | Yes |
| `organizationId` | `NlQgs9kADbZr4ddBRkhS` | Organization ID. Set to target org ID during migration | Yes |
| `roleId` | `employeeTags` | Role ID mapped from employeeTags field (see Role Mapping table below) | Yes |
| `roleTitle` | `employeeTags` | Role title mapped from employeeTags field (see Role Mapping table below) | Yes |
| `salaryType` | `salaryTags` | Salary type. Must map to: "salaryMonthly" or "wages". If legacy uses different values, specify mapping below | Yes |
| `salaryAmount` | `salaryValue` | Salary amount (number). Optional field | No |
| `openingBalance` | `openingBalance` | Opening balance from legacy document (default: 0 if not available) | No |
| `currentBalance` | `openingBalance` | Current balance set same as openingBalance during migration | No |
| `labourID` | `id` | Legacy document ID reference (for tracking purposes) | No |
| `createdAt` | `createdAt` | Creation timestamp. Used for date filtering | Yes |
| `updatedAt` | `updatedAt` | Last update timestamp (optional, will use server timestamp if not available) | No |

## Date Filter Field

The migration will filter records where the creation date is **<= December 31, 2025**.

- **Date Filter Field:** `createdAt` (field name from Pave that contains the creation/registration date)

## Salary Type Mapping

The target system uses the following salary types:
- `"salaryMonthly"` - Monthly salary
- `"wages"` - Wages-based payment

If the legacy system uses different values, specify the mapping here:

| Legacy Value | Target Value | Notes |
|------------|--------------|-------|
| `fixed` | `salaryMonthly` | |
| `if perTrip or perBatch use ` | `wages` | |
| `___________` | `salaryMonthly` | (default fallback) |

## Role Mapping

The `roleId` and `roleTitle` are mapped from the `employeeTags` field in the legacy system.

**Approach:** Use predefined role mapping based on `employeeTags` value.

### Role Mapping Table

| Legacy `employeeTags` Value | Target Role ID | Target Role Title |
|----------------------------|---------------|------------------|
| `loader` | `1767517117335` | `Loader` |
| `production` | `1767517127165` | `Production` |
| `staff` | `1767517567211` | `Staff` |
| `driver` | `1766649058877` | `Driver` |

**Note:** If `employeeTags` value doesn't match any of the above, the migration script should handle it (either skip, use default, or log for manual review).

## Special Notes

1. **Document ID:** If you want to preserve Pave document IDs, leave blank. Otherwise, new IDs will be generated.

2. **Opening/Current Balance:** 
   - `openingBalance` is read from the legacy `openingBalance` field
   - `currentBalance` is set to the same value as `openingBalance` during migration
   - If `openingBalance` is not available in legacy, both will default to 0

3. **Role Mapping:** 
   - Roles are mapped from the `employeeTags` field using the predefined mapping table above
   - The `employeeTags` field should contain one of: `loader`, `production`, `staff`, or `driver`
   - If `employeeTags` doesn't match any known value, the migration script should handle it appropriately (log warning, skip, or use default)

4. **Organization Mapping:** The `organizationId` is set to the target organization ID: `NlQgs9kADbZr4ddBRkhS`

5. **Date Format:** The date filter field (`createdAt`) should be a Firestore Timestamp. If it's stored as a string or number, specify the format:
   - Timestamp (default)
   - ISO String: `YYYY-MM-DDTHH:mm:ss.sssZ`
   - Unix timestamp (seconds)
   - Unix timestamp (milliseconds)

6. **Salary Amount:** This is an optional field. If not available in legacy, it can be set to `null` or omitted.

7. **Legacy Collection Structure:** 
   - The legacy `EMPLOYEES` collection has subcollections for financial years
   - The `openingBalance` field should be read from the main employee document, not from financial year subcollections
   - Financial year subcollections are not migrated as part of this employee migration

8. **Legacy Reference Field:** 
   - The `labourID` field is added to preserve the legacy document ID as a reference
   - This helps track which legacy employee record corresponds to the migrated record

## Additional Fields

Additional fields migrated for reference purposes:

| Additional Field | Source Field | Target Field | Notes |
|-----------------|--------------|--------------|-------|
| `labourID` | `id` (document ID) | `labourID` | Legacy document ID reference for tracking purposes |

---

**Instructions:**
1. Fill in all fields marked with `___________`
2. Review the transformation notes
3. Specify salary type mapping if legacy uses different values
4. Specify role mapping approach
5. Update the migration script with the mappings
6. Test with a small subset before full migration

