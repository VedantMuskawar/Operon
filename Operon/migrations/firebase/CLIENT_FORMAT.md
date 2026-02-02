# CLIENT Export/Import Format

## Overview

This document describes the format for exporting the **full CLIENTS collection** from the Legacy Database (Pave) and importing it into the new Database (Operon).

## Export Requirements

**Export the complete CLIENTS collection:**
- **All documents** from the CLIENTS collection (no filters)
- **All fields** from each client document
- Include **Document ID** as the first column

## Collection Name

The collection name in Pave may be:
- `CLIENTS` (most likely)
- `Clients`
- `clients`

**Verify the exact collection name** in the Legacy Firebase console before exporting.

## Excel/CSV Format

### Export All Fields

**Export ALL fields from each client document.** Common fields to expect:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| **Document ID** | ✅ | String | Firestore document ID | `abc123def456` |
| **clientID** or **clientId** | String | Client ID field (may vary) | `abc123def456` |
| **name** or **clientName** | String | Client name | `John Doe` |
| **name_lc** | String | Lowercase name for search | `john doe` |
| **phone** or **primaryPhone** | String | Primary phone number | `+919876543210` |
| **phones** | Array/JSON | Array of phone objects | `[{"e164": "+919876543210", "label": "main"}]` |
| **phoneIndex** | Array | Array of phone numbers for search | `["+919876543210"]` |
| **tags** | Array/String | Client tags | `["active", "corporate"]` |
| **status** | String | Client status | `active`, `inactive` |
| **organizationId** or **orgID** | String | Organization ID | `org-id-123` |
| **balance** or **currentBalance** | Number | Current balance (if stored in client doc) | `5000.00` |
| **stats** | Object/JSON | Statistics object | `{"orders": 10, "lifetimeAmount": 50000}` |
| **contacts** | Array/JSON | Contact information | `[{...}]` |
| **createdAt** | Timestamp | Creation timestamp | `2024-01-15T10:30:00Z` |
| **updatedAt** | Timestamp | Last update timestamp | `2024-01-20T10:30:00Z` |
| **... (any other fields)** | Various | Any additional fields in Pave | — |

### Notes

1. **Export ALL fields**: Don't filter fields - export everything that exists in the document
2. **Field name variations**: Pave may use different field names (e.g., `clientID` vs `clientId`, `orgID` vs `organizationId`)
3. **Nested objects**: Export nested objects/arrays as JSON strings
4. **Timestamps**: Export as ISO 8601 format strings

### Export Format Guidelines

1. **Document ID**: Always include as first column
2. **All Fields**: Export every field that exists in the document
3. **Nested Data**: Export objects/arrays as JSON strings
4. **Timestamps**: Convert to ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)
5. **Null/Undefined**: Use empty string or "null" for missing values
6. **Field Name Preservation**: Keep original Pave field names (don't rename yet)

## Sample Data

See `data/clients-template.csv` for a sample row with all fields.

## Export Process

1. **Connect to Legacy Database**
   - Use Legacy Firebase service account
   - Initialize Firebase Admin SDK
   - Verify collection name (`CLIENTS`, `Clients`, or `clients`)

2. **Export All Documents**
   - Query entire collection (no filters)
   - Export all fields from each document
   - Include document ID
   - Save to Excel format

3. **Export Script Example**
   ```javascript
   const clientsRef = db.collection('CLIENTS'); // Verify exact name
   const allClients = await clientsRef.get();
   
   const rows = allClients.docs.map(doc => ({
     'Document ID': doc.id,
     ...doc.data() // Export all fields
   }));
   ```

## Import Process (After Export)

1. **Review exported data** - Check field names and structure
2. **Map Pave fields to Operon format** - Transform field names
3. **Normalize data** - Format phones, tags, dates
4. **Import into new Database** - Use import scripts
