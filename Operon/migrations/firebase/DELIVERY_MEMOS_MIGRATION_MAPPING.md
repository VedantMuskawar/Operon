# DELIVERY_MEMOS Collection Migration Mapping - From Excel

This document defines the field mapping from **Excel** source file to the target **DELIVERY_MEMOS** collection in Operon.

## Migration Configuration

- **Source System:** Excel File
- **Source Format:** Excel (.xlsx or .xls) or CSV
- **Target Collection:** `DELIVERY_MEMOS`
- **Target Organization ID:** `NlQgs9kADbZr4ddBRkhS` (default, can be overridden)
- **Excel File Path:** Set via `EXCEL_FILE_PATH` environment variable or place file in `data/delivery-memos.xlsx`

## Target DELIVERY_MEMOS Schema

The target DELIVERY_MEMOS collection has the following structure (based on `functions/src/orders/delivery-memo.ts`):

```typescript
{
  // Identity
  dmId: string;                    // Format: "DM/{financialYear}/{dmNumber}"
  dmNumber: number;                // Sequential DM number within financial year
  financialYear: string;           // e.g., "FY2425"
  
  // Links
  tripId: string;                  // Reference to SCHEDULE_TRIPS document ID
  scheduleTripId: string;          // Human-readable schedule trip ID
  organizationId: string;          // Organization reference
  orderId: string;                 // Reference to PENDING_ORDERS
  
  // Client Information
  clientId: string;                // Reference to CLIENTS collection
  clientName: string;              // Client name snapshot
  customerNumber: string;          // Client phone number (E.164 format)
  
  // Trip Information
  scheduledDate: Timestamp;       // Scheduled delivery date
  scheduledDay: string;            // Day of week (e.g., "Monday")
  vehicleId: string;               // Vehicle reference
  vehicleNumber: string;           // Vehicle number/plate
  slot: number;                    // Time slot number (0, 1, 2, etc.)
  slotName: string;                // Slot name (e.g., "Morning", "Afternoon")
  
  // Driver Information
  driverId: string | null;        // Driver reference (optional)
  driverName: string | null;      // Driver name (optional)
  driverPhone: string | null;     // Driver phone (optional)
  
  // Delivery Zone
  deliveryZone: {
    zoneId: string;                // Zone reference
    city: string;                 // City name
    region: string;                // Region name
    // ... other zone fields
  };
  
  // Items and Pricing
  items: Array<{
    productId: string;
    productName: string;
    quantity: number;
    unitPrice: number;
    gstPercent?: number;
    subtotal: number;
    gstAmount: number;
    total: number;
    // ... other item fields
  }>;
  
  pricing: {
    subtotal: number;
    totalGst: number;
    totalAmount: number;
    currency: string;
  };
  
  tripPricing: {
    subtotal: number;
    gstAmount: number;
    total: number;
  } | null;
  
  // Status
  priority: string;                // "normal" | "high" | "low" | "urgent"
  paymentType: string;             // "pay_later" | "pay_on_delivery" | etc.
  tripStatus: string;              // "scheduled" | "completed" | "cancelled" | "rescheduled"
  orderStatus: string;             // "pending" | "delivered" | "cancelled"
  status: string;                  // "active" | "cancelled" | "returned"
  
  // Metadata
  generatedAt: Timestamp;          // When DM was generated
  generatedBy: string;             // User ID who generated DM
  source: string;                  // "dm_generation" | "excel_migration"
  updatedAt: Timestamp;           // Last update timestamp
}
```

## Field Mapping

Fill in the **Excel Column** column with the exact column names from your Excel file.

| Target Field | Excel Column | Transformation Notes | Required | Default Value |
|-------------|--------------|----------------------|----------|---------------|
| **Identity Fields** |
| `dmNumber` | `DM_NO` | DM number from Excel. If not provided, will be auto-generated based on financial year | No | Auto-generated |
| `financialYear` | `___________` | Financial year (e.g., "FY2425"). If not provided, will be calculated from scheduledDate | No | Calculated from scheduledDate |
| **Link Fields** |
| `tripId` | `___________` | SCHEDULE_TRIPS document ID. If not available, can be generated or left empty | No | "" | leave empty
| `scheduleTripId` | `___________` | Human-readable schedule trip ID | No | "" | leave empty
| `organizationId` | `___________` | Organization ID. If not provided, uses target org ID from config | No | From config |
| `orderId` | `___________` | PENDING_ORDERS document ID | No | "" | leave empty
| **Client Fields** |
| `clientId` | `___________` | Client document ID | No | "" | leave empty
| `clientName` | `CLIENT` | Client name | Yes | "" |
| `customerNumber` | `___________` | Client phone number. Should be normalized to E.164 format | No | "" | leave empty
| **Trip Fields** |
| `scheduledDate` | `DATE` | Scheduled date. Format: Excel date or ISO string (YYYY-MM-DD) | Yes | - |
| `scheduledDay` | `___________` | Day of week (e.g., "Monday") | No | Calculated from scheduledDate |
| `vehicleId` | `___________` | Vehicle document ID | No | "" |
| `vehicleNumber` | `VehicleNO` | Vehicle number/plate | No | "" |
| `slot` | `___________` | Time slot number (0, 1, 2, etc.) | No | 0 | leave empty
| `slotName` | `___________` | Slot name (e.g., "Morning", "Afternoon") | No | "" | leave empty
| **Driver Fields** |
| `driverId` | `___________` | Driver document ID | No | null | leave emtpy 
| `driverName` | `___________` | Driver name | No | null | leave empty
| `driverPhone` | `___________` | Driver phone number | No | null | leave empty 
| **Zone Fields** |
| `deliveryZone.zoneId` | `___________` | Zone document ID | No | "" | leave empty
| `deliveryZone.city` | `___________` | City name | No | "" | leave empty 
| `deliveryZone.region` | `___________` | Region name | No | "" | leave empty 
| **Items (from Excel columns)** |
| `items[].fixedQuantityPerTrip` | `Quantity` | Quantity per trip | No | 0 |
| `items[].productName` | `Product` | Product name. If Product contains "BRICKS", set to "Bricks" | No | "" |
| `items[].productId` | `Product` | Product ID. If Product contains "BRICKS", set to "1765277893839", otherwise empty | No | "" |
| `items[].unitPrice` | `Unit` | Unit price. If Unit = "1", indicates cancelled DM | No | 0 |
| `items[].subtotal` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 |
| `items[].total` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 | 
| **Pricing Fields (Calculated)** |
| `tripPricing.subtotal` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 |
| `tripPricing.gstAmount` | `___________` | Trip GST amount (defaults to 0) | No | 0 |
| `tripPricing.total` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 |
| `pricing.subtotal` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 |
| `pricing.totalGst` | `___________` | Order total GST (defaults to 0) | No | 0 |
| `pricing.totalAmount` | Calculated | unitPrice * fixedQuantityPerTrip | No | 0 |
| `pricing.currency` | Fixed | Always "INR" | No | "INR" |
| **Status Fields** |
| `priority` | `___________` | Priority level | No | "normal" |
| `paymentType` | `___________` | Payment type | No | "" |
| `tripStatus` | `___________` | Trip status | No | "scheduled" |
| `orderStatus` | `___________` | Order status | No | "pending" |
| `status` | `___________` | DM status | No | "active" |
| **Metadata** |
| `generatedBy` | `___________` | User ID who generated/migrated DM | No | "excel_migration" |
| `source` | `___________` | Source of DM | No | "excel_migration" |

## Excel File Format

### Supported Formats
- Excel: `.xlsx`, `.xls`
- CSV: `.csv`

### File Location
Place the Excel file in one of these locations:
1. `data/delivery-memos.xlsx` (relative to migration script)
2. Set `EXCEL_FILE_PATH` environment variable with full path

### Sheet Selection
- If Excel has multiple sheets, the script will use the first sheet by default
- To specify a sheet, set `EXCEL_SHEET_NAME` environment variable

### Header Row
- The first row should contain column headers
- Column names should match the values you fill in the "Excel Column" column above

## Date Format Handling

The `scheduledDate` field can be provided in various formats:

| Excel Format | Example | Notes |
|-------------|---------|-------|
| Excel Date Number | `44927` | Excel serial date number |
| ISO String | `2024-01-15` or `2024-01-15T10:30:00Z` | ISO date string |
| DD/MM/YYYY | `15/01/2024` | Common date format |
| MM/DD/YYYY | `01/15/2024` | US date format |
| DD-MM-YYYY | `15-01-2024` | Alternative format |

The script will attempt to parse dates automatically. If parsing fails, specify the date format in the script.

## Financial Year Calculation

If `financialYear` is not provided in Excel, it will be calculated from `scheduledDate`:
- Financial year format: `FY2425` (April 2024 - March 2025)
- Financial year starts on April 1st

## DM Number Generation

If `dmNumber` is not provided in Excel:
1. The script will calculate the financial year from `scheduledDate`
2. Check if `ORGANIZATIONS/{orgId}/DM/{financialYear}` document exists
3. If exists, use `currentDMNumber + 1`
4. If not exists, start from 1
5. Update the FY document with new `currentDMNumber`

## Items Array Handling

Items can be provided in two ways:

### Option 1: JSON String Column
- Excel column contains JSON string: `[{"productId": "prod1", "productName": "Product 1", "quantity": 10, ...}]`
- Script will parse JSON directly

### Option 2: Separate Columns (Future Enhancement)
- Multiple columns like `item1_productId`, `item1_productName`, `item1_quantity`, etc.
- Script will combine into items array

## Special Notes

1. **Document ID:** New document IDs will be auto-generated by Firestore

2. **DM ID Format:** `dmId` will be generated as `DM/{financialYear}/{dmNumber}`

3. **Phone Number Normalization:** 
   - `customerNumber` and `driverPhone` should be normalized to E.164 format
   - Example: `+919876543210` (India)
   - Script will attempt to normalize if not in E.164 format

4. **Missing Fields:** 
   - Optional fields can be omitted from Excel
   - Script will use default values as specified in the table above

5. **Validation:** 
   - Script will validate required fields before migration
   - Invalid rows will be skipped and logged

6. **Batch Processing:** 
   - Script processes rows in batches of 400 (Firestore batch limit)
   - Progress is logged during migration

7. **Duplicate Prevention:** 
   - If `dmNumber` and `financialYear` combination already exists, the script will skip that row
   - Set `OVERWRITE_EXISTING=true` to overwrite existing DMs

## Environment Variables

```bash
# Excel file path (required)
export EXCEL_FILE_PATH=/path/to/delivery-memos.xlsx

# Excel sheet name (optional, defaults to first sheet)
export EXCEL_SHEET_NAME=Sheet1

# Target organization ID (optional, defaults to NlQgs9kADbZr4ddBRkhS)
export TARGET_ORG_ID=NlQgs9kADbZr4ddBRkhS

# Service account for target Firebase (required)
export NEW_SERVICE_ACCOUNT=creds/new-service-account.json

# Overwrite existing DMs (optional, defaults to false)
export OVERWRITE_EXISTING=false

# Skip rows with missing required fields (optional, defaults to true)
export SKIP_INVALID_ROWS=true
```

## Instructions

1. **Prepare Excel File:**
   - Ensure first row contains column headers
   - Fill in data rows
   - Save as `.xlsx` or `.csv`

2. **Fill Mapping:**
   - Fill in all "Excel Column" fields marked with `___________`
   - Review transformation notes
   - Specify date format if needed

3. **Update Script:**
   - Update `migrate-delivery-memos.ts` with column mappings
   - Adjust date parsing if needed
   - Test with a small subset first

4. **Run Migration:**
   ```bash
   cd migrations/firebase
   npm install
   npm run migrate-delivery-memos
   ```

5. **Verify Results:**
   - Check Firestore console for migrated documents
   - Verify DM numbers are sequential within financial years
   - Check that FY documents in `ORGANIZATIONS/{orgId}/DM/` are updated correctly

---

**Next Steps:**
1. Fill in all `___________` placeholders with actual Excel column names
2. Place Excel file in `data/delivery-memos.xlsx` or set `EXCEL_FILE_PATH`
3. Review and update the migration script with your mappings
4. Test with a small subset before full migration

