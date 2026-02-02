# SCH_ORDERS Export/Import Format

## Overview

This document describes the format for exporting the **full SCH_ORDERS collection** from the Legacy Database (Pave) and importing it into the new Database (Operon) as SCHEDULE_TRIPS.

## Export Requirements

**Export the complete SCH_ORDERS collection:**
- **All documents** from the SCH_ORDERS collection (no filters, no date ranges)
- **All fields** from each document
- Include **Document ID** as the first column

## Collection Name

The collection name in Pave may be:
- `SCH_ORDERS` (most likely)
- `SCH_Orders`
- `sch_orders`
- `SCHEDULE_ORDERS`

**Verify the exact collection name** in the Legacy Firebase console before exporting.

## Excel/CSV Format

### Export All Fields

**Export ALL fields from each SCH_ORDERS document.** Common fields to expect:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| **Document ID** | ✅ | String | Firestore document ID | `trip-abc123` |
| **orderId** or **Order ID** | String | Order reference | `order-123` |
| **clientID** or **clientId** | String | Client document ID | `client-456` |
| **clientName** or **Client Name** | String | Client name | `ABC Construction` |
| **clientPhoneNumber** or **Client Phone Number** | String | Client phone | `+919876543210` |
| **deliveryDate** or **Delivery Date** | Timestamp | Delivery date | `2026-01-15T00:00:00Z` |
| **scheduledDate** | Timestamp | Scheduled date | `2026-01-15T00:00:00Z` |
| **scheduledDay** | String | Day of week | `Monday` |
| **vehicleID** or **vehicleId** | String | Vehicle document ID | `vehicle-789` |
| **vehicleNumber** or **Vehicle Number** | String | Vehicle registration | `KA-01-AB-1234` |
| **driverID** or **driverId** | String | Driver document ID | `driver-101` |
| **driverName** or **Driver Name** | String | Driver name | `John Driver` |
| **driverPhoneNumber** | String | Driver phone | `+919876543211` |
| **slot** | Number | Time slot | `1` |
| **slotName** | String | Slot name | `Morning` |
| **cityName** or **City Name** | String | Delivery city | `Mumbai` |
| **region** or **Region** | String | Region/state | `Maharashtra` |
| **regionID** or **regionId** | String | Region document ID | `region-001` |
| **regionName** | String | Region name | `Mumbai Region` |
| **productName** or **Product Name** | String | Product name | `BRICKS` |
| **productQuant** or **productQuantity** | Number | Quantity | `1000` |
| **productUnitPrice** | Number | Unit price | `5.50` |
| **paymentType** | String | Payment type | `pay_on_delivery` |
| **paySchedule** | String | Payment schedule | `POD` |
| **toAccount** | String | Payment account | `pay_on_delivery` |
| **tripStatus** | String | Trip status | `scheduled` |
| **deliveryStatus** | Boolean/String | Delivery status | `true` |
| **dispatchStart** | String | Dispatch start | `08:00` |
| **dispatchEnd** | String | Dispatch end | `12:00` |
| **dmNumber** | Number | DM number | `12345` |
| **orgID** or **organizationId** | String | Organization ID | `org-id-123` |
| **items** | Array/JSON | Items array | `[{...}]` |
| **address** | String | Delivery address | `123 Main St` |
| **deliveredTime** | Timestamp | Delivered timestamp | `2026-01-15T12:00:00Z` |
| **dispatchedTime** | Timestamp | Dispatched timestamp | `2026-01-15T08:00:00Z` |
| **... (any other fields)** | Various | Any additional fields | — |

### Notes

1. **Export ALL fields**: Don't filter fields - export everything
2. **Field name variations**: Pave may use different field names (e.g., `clientID` vs `clientId`, `orgID` vs `organizationId`)
3. **Nested objects**: Export nested objects/arrays (like `items`) as JSON strings
4. **Timestamps**: Export as ISO 8601 format strings

### Export Format Guidelines

1. **Document ID**: Always include as first column
2. **All Fields**: Export every field that exists in the document
3. **Nested Data**: Export objects/arrays (like `items`) as JSON strings
4. **Timestamps**: Convert to ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)
5. **Null/Undefined**: Use empty string or "null" for missing values
6. **Field Name Preservation**: Keep original Pave field names (don't rename yet)

## Sample Data

See `data/sch-orders-template.csv` for a sample row with all fields.

## Export Process

1. **Connect to Legacy Database**
   - Use Legacy Firebase service account
   - Initialize Firebase Admin SDK
   - Verify collection name (`SCH_ORDERS`, `SCH_Orders`, etc.)

2. **Export All Documents**
   - Query entire collection (no filters, no date ranges)
   - Export all fields from each document
   - Include document ID
   - Save to Excel format

3. **Export Script Example**
   ```javascript
   const schOrdersRef = db.collection('SCH_ORDERS'); // Verify exact name
   const allOrders = await schOrdersRef.get();
   
   const rows = allOrders.docs.map(doc => ({
     'Document ID': doc.id,
     ...doc.data() // Export all fields
   }));
   ```

## Import Process (After Export)

1. **Review exported data** - Check field names and structure
2. **Map Pave fields to Operon format** - Transform field names
3. **Normalize data** - Format dates, statuses, payment types
4. **Import into new Database** - Use import scripts to create SCHEDULE_TRIPS
