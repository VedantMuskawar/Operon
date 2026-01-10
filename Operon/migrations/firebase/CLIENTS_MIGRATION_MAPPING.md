# CLIENTS Collection Migration Mapping - From Pave

This document defines the field mapping from the **Pave** source system to the target **CLIENTS** collection in Operon.

## Migration Configuration

- **Source System:** Pave
- **Source Collection:** `CLIENTS` (or specify if different)
- **Target Collection:** `CLIENTS`
- **Date Filter:** Migrate data up to **December 31, 2025** (31.12.25)

## Target CLIENTS Schema

The target CLIENTS collection has the following structure:

```typescript
{
  clientId: string;                // Same as document ID (auto-generated)
  name: string;                    // Client name
  name_lowercase: string;          // Lowercase for case-insensitive search (auto-generated)
  primaryPhone: string;            // Primary phone number
  primaryPhoneNormalized: string;  // Normalized phone (e164 format)
  phones: Array<{                  // All phone numbers
    e164: string;                  // Normalized phone in e164 format
    label: string;                 // 'main' or 'alt'
  }>;
  phoneIndex: string[];            // Array of normalized phones for search (auto-generated)
  tags: string[];                  // Client tags (e.g., "Individual", "Distributor", "Corporate")
  contacts: Array<{                // Additional contacts
    name: string;
    phone: string;
    normalized: string;
    description?: string;
  }>;
  organizationId: string;          // Organization ID
  status: string;                  // 'active' (default)
  stats: {                         // Statistics
    orders: number;                // Default: 0
    lifetimeAmount: number;        // Default: 0
  };
  createdAt: Timestamp;            // Creation timestamp
  updatedAt: Timestamp;            // Update timestamp (auto-generated)
}
```

## Field Mapping

Fill in the **Pave Source Field** column with the exact field names from the Pave system.

| Target Field | Pave Source Field | Transformation Notes | Required |
|-------------|-------------------|---------------------|----------|
| `name` | `name` | Client name | Yes |
| `primaryPhone` | `phoneNumber` | Primary phone number | Yes |
| `phones` | `phoneList` | Array of phone numbers. If single field, list it. If multiple fields, list them separated by comma. | Yes |
| `tags` | `___________` | Array of tags/categories. If not available, will default based on phone count. | No |
| `contacts` | `___________` | Array of contact objects. Format: `[{name, phone, description?}]` | No |
| `organizationId` | `NlQgs9kADbZr4ddBRkhS` | Organization ID (will be mapped to target org) | Yes |
| `status` | `___________` | Client status. If not available, defaults to 'active' | No |
| `stats.orders` | `___________` | Total orders count. Defaults to 0 if not available | No |
| `stats.lifetimeAmount` | `___________` | Lifetime amount/transaction value. Defaults to 0 if not available | No |
| `createdAt` | `registeredTime` | Creation/registration timestamp. Used for date filtering | Yes |
| `updatedAt` | `` | Last update timestamp (optional, will use server timestamp if not available) | No |

## Date Filter Field

The migration will filter records where the creation date is **<= December 31, 2025**.

- **Date Filter Field:** `registeredTime` (field name from Pave that contains the creation/registration date)

## Phone Number Format

Phone numbers will be normalized to E.164 format:
- Format: `+[country code][number]` (e.g., `+919876543210`)
- Indian numbers: 10-digit numbers will be prefixed with `+91`
- The `phones` array will use `e164` format with `label: 'main'` for primary and `label: 'alt'` for others

## Special Notes

1. **Document ID:** If you want to preserve Pave document IDs, leave blank. Otherwise, new IDs will be generated.

2. **Tags Default Logic:** If tags are not provided:
   - 1 phone number → `['Individual']`
   - Multiple phone numbers → `['Distributor']`

3. **Contacts:** If the source has nested contact information, specify the structure here:
   ```
   Example: contacts array structure from Pave:
   - Contact Name Field: ___________
   - Contact Phone Field: ___________
   - Contact Description Field: ___________
   ```

4. **Organization Mapping:** The `organizationId` will be mapped from the legacy org ID to the target org ID during migration.

5. **Date Format:** The date filter field should be a Firestore Timestamp. If it's stored as a string or number, specify the format:
   - Timestamp (default)
   - ISO String: `YYYY-MM-DDTHH:mm:ss.sssZ`
   - Unix timestamp (seconds)
   - Unix timestamp (milliseconds)
   - Other: `___________`

## Additional Fields

If there are additional fields in Pave that need to be migrated but are not in the standard schema, list them here:

| Additional Field | Source Field | Target Field | Notes |
|-----------------|--------------|--------------|-------|
| | | | |

---

**Instructions:**
1. Fill in all fields marked with `___________`
2. Review the transformation notes
3. Update the migration script with the mappings
4. Test with a small subset before full migration

