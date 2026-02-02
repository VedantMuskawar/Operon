# Import Templates for New Database

## Overview

This directory contains Excel import templates for importing data into the new Operon Database. These templates show the expected format and field names that the import scripts expect.

## Template Files

### 1. `clients-import-template.xlsx`
**Purpose**: Import CLIENTS collection into new Database

**Key Fields**:
- `Document ID` - Firestore document ID (optional, auto-generated if not provided)
- `clientId` - Client ID (should match Document ID)
- `name` - Client name (required)
- `primaryPhone` - Primary phone number in E.164 format (required)
- `phones` - JSON array of phone objects
- `phoneIndex` - Array of phone numbers for search
- `tags` - Array of tags
- `status` - Client status (required)
- `organizationId` - Organization ID (required)

**See**: `CLIENT_FORMAT.md` for complete field list

### 2. `sch-orders-import-template.xlsx`
**Purpose**: Import SCH_ORDERS from Legacy as SCHEDULE_TRIPS in new Database

**Key Fields**:
- `Document ID` - Firestore document ID (optional)
- `orderId` - Order reference (required)
- `clientId` - Client document ID (required)
- `scheduledDate` - Scheduled date (required)
- `vehicleId` - Vehicle document ID
- `driverId` - Driver document ID
- `items` - JSON array of items
- `tripPricing` - JSON object with pricing
- `organizationId` - Organization ID (required)

**See**: `SCH_ORDERS_FORMAT.md` for complete field list

### 3. `transactions-import-template.xlsx`
**Purpose**: Import TRANSACTIONS collection into new Database

**Key Fields**:
- `Document ID` - Firestore document ID (optional)
- `transactionId` - Transaction ID (used as doc ID if provided)
- `organizationId` - Organization ID (required)
- `clientId` - Client document ID (required for clientLedger)
- `ledgerType` - Ledger type: `clientLedger`, `vendorLedger`, `employeeLedger` (required)
- `type` - Transaction type: `credit` or `debit` (required)
- `category` - Transaction category (required)
- `amount` - Transaction amount (required)
- `financialYear` - Financial year: `FY2526`, `FY2425`, etc. (required)
- `createdAt` - Creation timestamp (required)
- `createdBy` - User ID who created (required)

**See**: `TRANSACTIONS_FORMAT.md` for complete field list

### 4. `delivery-memos-import-template.xlsx`
**Purpose**: Import DELIVERY_MEMOS collection into new Database

**Key Fields**:
- `Document ID` - Firestore document ID (optional)
- `dmId` - Delivery Memo ID
- `dmNumber` - DM number (sequential)
- `tripId` - Schedule Trip document ID (required)
- `orderId` - Order document ID
- `clientId` - Client document ID (required)
- `scheduledDate` - Scheduled delivery date (required)
- `items` - JSON array of items
- `tripPricing` - JSON object with pricing
- `status` - DM status: `active`, `delivered`, `cancelled`
- `organizationId` - Organization ID (required)

**See**: `DELIVERY_MEMOS_FORMAT.md` for complete field list

## How to Use Templates

### Step 1: Export from Legacy Database
1. Export full collections from Pave (Legacy Database)
2. Save as Excel files with all fields

### Step 2: Transform Data
1. Open the exported Excel file
2. Compare with the import template
3. Map Legacy field names to new format:
   - `clientID` → `clientId`
   - `orgID` → `organizationId`
   - `vehicleID` → `vehicleId`
   - etc.
4. Normalize data formats:
   - Phone numbers to E.164 format
   - Dates to ISO 8601 format
   - Arrays/objects to JSON strings

### Step 3: Import into New Database
1. Use the import scripts with transformed Excel files
2. Follow import order:
   - CLIENTS first
   - SCH_ORDERS (SCHEDULE_TRIPS) second
   - DELIVERY_MEMOS third
   - TRANSACTIONS last

## Field Mapping Guide

### Common Field Name Mappings

| Legacy (Pave) | New (Operon) | Notes |
|--------------|--------------|-------|
| `clientID` | `clientId` | camelCase |
| `orgID` | `organizationId` | camelCase |
| `vehicleID` | `vehicleId` | camelCase |
| `driverID` | `driverId` | camelCase |
| `regionID` | `regionId` | camelCase |
| `productQuant` | `quantity` | May need to map to items array |
| `productUnitPrice` | `unitPrice` | May need to map to items array |

### Data Format Conversions

1. **Phone Numbers**: Convert to E.164 format (`+919876543210`)
2. **Dates**: Convert to ISO 8601 (`2026-01-15T00:00:00Z`)
3. **Arrays**: Convert to JSON strings (`["tag1", "tag2"]`)
4. **Objects**: Convert to JSON strings (`{"key": "value"}`)
5. **Booleans**: Convert to strings (`true`/`false` or `"true"`/`"false"`)

## Notes

- **Required Fields**: Make sure all required fields are present
- **Field Names**: Use exact field names as shown in templates
- **Data Types**: Ensure data types match (numbers as numbers, strings as strings)
- **Nested Data**: Export nested objects/arrays as JSON strings
- **Null Values**: Use empty strings or omit fields for null values

## Sample Data

Each template includes sample rows showing:
- Expected data formats
- Required vs optional fields
- JSON format for nested data
- Date/time formats
