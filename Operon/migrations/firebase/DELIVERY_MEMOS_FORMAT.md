# DELIVERY_MEMOS Export/Import Format

## Overview

This document describes the format for exporting the **full DELIVERY_MEMOS collection** from the Legacy Database (Pave) and importing it into the new Database (Operon).

## Export Requirements

**Export the complete DELIVERY_MEMOS collection:**
- **All documents** from the DELIVERY_MEMOS collection (no filters)
- **All fields** from each delivery memo document
- Include **Document ID** as the first column

## Collection Name

The collection name in Pave may be:
- `DELIVERY_MEMOS` (most likely)
- `Delivery_Memos`
- `delivery_memos`
- `DELIVERYMEMOS`
- `DM`

**Verify the exact collection name** in the Legacy Firebase console before exporting.

## Excel/CSV Format

### Export All Fields

**Export ALL fields from each DELIVERY_MEMOS document.** Common fields to expect:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| **Document ID** | ✅ | String | Firestore document ID | `dm-abc123` |
| **dmId** | String | Delivery Memo ID | `dm-abc123` |
| **dmNumber** | Number | DM number (sequential) | `12345` |
| **tripId** | String | Schedule Trip document ID | `trip-789` |
| **scheduleTripId** | String | Schedule Trip ID | `ST-123` |
| **orderId** | String | Order document ID | `order-456` |
| **itemIndex** | Number | Item index in order | `0` |
| **productId** | String | Product document ID | `product-bricks` |
| **financialYear** | String | Financial year | `FY2526` |
| **organizationId** or **orgID** | String | Organization ID | `org-id-123` |
| **clientId** or **clientID** | String | Client document ID | `client-456` |
| **clientName** | String | Client name | `ABC Construction` |
| **customerNumber** | String | Customer phone number | `+919876543210` |
| **scheduledDate** | Timestamp | Scheduled delivery date | `2026-01-15T00:00:00Z` |
| **scheduledDay** | String | Day of week | `Monday` |
| **vehicleId** or **vehicleID** | String | Vehicle document ID | `vehicle-789` |
| **vehicleNumber** | String | Vehicle registration | `KA-01-AB-1234` |
| **slot** | Number | Time slot | `1` |
| **slotName** | String | Slot name | `Morning` |
| **driverId** or **driverID** | String | Driver document ID | `driver-101` |
| **driverName** | String | Driver name | `John Driver` |
| **driverPhone** | String | Driver phone | `+919876543211` |
| **deliveryZone** | Object/JSON | Delivery zone info | `{"city": "Mumbai", "region": "Maharashtra"}` |
| **items** | Array/JSON | Items array | `[{"productName": "BRICKS", "quantity": 1000}]` |
| **tripPricing** | Object/JSON | Trip pricing details | `{"subtotal": 5500, "total": 5500}` |
| **priority** | String | Priority level | `normal`, `high`, `urgent` |
| **paymentType** | String | Payment type | `pay_on_delivery`, `pay_later`, `cash` |
| **tripStatus** | String | Trip status | `scheduled`, `dispatched`, `delivered`, `returned` |
| **orderStatus** | String | Order status | `pending`, `fully_scheduled` |
| **status** | String | DM status | `active`, `delivered`, `cancelled`, `returned` |
| **generatedAt** | Timestamp | DM generation timestamp | `2026-01-15T08:00:00Z` |
| **generatedBy** | String | User ID who generated | `user-123` |
| **source** | String | Source of DM | `dm_generation`, `trip_return_trigger` |
| **deliveredAt** | Timestamp | Delivery timestamp | `2026-01-15T12:00:00Z` |
| **deliveryPhotoUrl** | String | Delivery photo URL | `https://...` |
| **deliveredBy** | String | User ID who delivered | `user-123` |
| **deliveredByRole** | String | Role of deliverer | `driver`, `admin` |
| **updatedAt** | Timestamp | Last update timestamp | `2026-01-15T12:00:00Z` |
| **... (any other fields)** | Various | Any additional fields in Pave | — |

### Notes

1. **Export ALL fields**: Don't filter fields - export everything that exists in the document
2. **Field name variations**: Pave may use different field names (e.g., `clientID` vs `clientId`, `orgID` vs `organizationId`)
3. **Nested objects**: Export nested objects/arrays (like `items`, `tripPricing`, `deliveryZone`) as JSON strings
4. **Timestamps**: Export as ISO 8601 format strings
5. **DM Number**: This is typically a sequential number used for printing/reference

### Export Format Guidelines

1. **Document ID**: Always include as first column
2. **All Fields**: Export every field that exists in the document
3. **Nested Data**: Export objects/arrays (like `items`, `tripPricing`) as JSON strings
4. **Timestamps**: Convert to ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)
5. **Null/Undefined**: Use empty string or "null" for missing values
6. **Field Name Preservation**: Keep original Pave field names (don't rename yet)

## Export Process

1. **Connect to Legacy Database**
   - Use Legacy Firebase service account
   - Initialize Firebase Admin SDK
   - Verify collection name (`DELIVERY_MEMOS`, `Delivery_Memos`, etc.)

2. **Export All Documents**
   - Query entire collection (no filters)
   - Export all fields from each document
   - Include document ID
   - Save to Excel format

3. **Export Script Example**
   ```javascript
   const deliveryMemosRef = db.collection('DELIVERY_MEMOS'); // Verify exact name
   const allDMs = await deliveryMemosRef.get();
   
   const rows = allDMs.docs.map(doc => ({
     'Document ID': doc.id,
     ...doc.data() // Export all fields
   }));
   ```

## Import Process (After Export)

1. **Review exported data** - Check field names and structure
2. **Map Pave fields to Operon format** - Transform field names
3. **Normalize data** - Format dates, statuses, nested objects
4. **Import into new Database** - Use import scripts to create DELIVERY_MEMOS

## Related Collections

- **DELIVERY_MEMOS**: Target collection in new Database
- **SCHEDULE_TRIPS**: Trip references must exist (via `tripId`)
- **CLIENTS**: Client references must exist
- **PENDING_ORDERS**: Order references (via `orderId`)

## DM Status Values

- `active` - Active delivery memo
- `delivered` - Delivery completed
- `cancelled` - Delivery cancelled
- `returned` - Delivery returned

## Source Values

- `dm_generation` - Generated from scheduled trip
- `trip_return_trigger` - Generated when trip is returned
