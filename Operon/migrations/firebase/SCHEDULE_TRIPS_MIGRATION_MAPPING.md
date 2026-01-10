# SCHEDULE_TRIPS Collection Migration Mapping - From Pave

This document defines the field mapping from the **Pave** source system to the target **SCHEDULE_TRIPS** collection in Operon.

## Migration Configuration

- **Source System:** Pave
- **Source Collection:** `SCH_ORDERS`
- **Target Collection:** `SCHEDULE_TRIPS`
- **Target Organization ID:** `NlQgs9kADbZr4ddBRkhS`
- **Date Filter:** Migrate data up to **December 31, 2025** (31.12.25)
- **Document Filter:** Only migrate documents where `deliveryStatus = true`
- **Document Filter:** Only migrate documents where `deliveryStatus = true` and `paySchedule = "POD"` or `paySchedule = "PL"`

## Target SCHEDULE_TRIPS Schema

The target SCHEDULE_TRIPS collection has the following structure:

```typescript
{
  scheduleTripId: string;           // Human-readable ID: ClientID-OrderID-YYYYMMDD-VehicleID-Slot
  orderId: string;                  // Reference to PENDING_ORDERS
  organizationId: string;           // Organization reference
  clientId: string;                 // Client ID reference
  clientName: string;               // Client name (snapshot)
  clientPhone: string;              // Client phone (E.164 format)
  customerNumber: string;           // Customer number/phone
  paymentType: string;              // Payment type (e.g., "cash", "credit", "upi")
  scheduledDate: Timestamp;        // Scheduled date
  scheduledDay: string;             // Day of week (e.g., "Monday", "Tuesday")
  vehicleId: string;                // Vehicle ID reference
  vehicleNumber: string;            // Vehicle number (snapshot)
  driverId?: string;                // Driver employee ID (optional)
  driverName?: string;              // Driver name (optional)
  driverPhone?: string;             // Driver phone (optional, E.164 format)
  slot: number;                     // Slot number (1, 2, 3, etc.)
  slotName: string;                 // Slot name (e.g., "Morning", "Afternoon")
  deliveryZone: {                  // Delivery zone object
    zoneId: string;
    zoneName: string;
    city: string;
    region: string;
    // ... other zone fields
  };
  items: Array<{                    // Trip items with trip-specific pricing
    productId: string;
    productName: string;
    quantity: number;               // Trip quantity (fixedQuantityPerTrip)
    unitPrice: number;
    gstPercent?: number;
    tripSubtotal: number;
    tripGstAmount: number;
    tripTotal: number;
    // ... other item fields
  }>;
  tripPricing: {                    // Trip-specific pricing
    subtotal: number;
    gstAmount: number;
    total: number;
    advanceAmountDeducted?: number; // If advance was deducted from first trip
  };
  pricing?: {                       // Order pricing snapshot (optional)
    subtotal: number;
    totalGst: number;
    totalAmount: number;
    includeGstInTotal: boolean;
  };
  includeGstInTotal: boolean;      // GST inclusion flag
  priority: string;                 // "normal" | "high"
  tripStatus: string;               // "scheduled" | "dispatched" | "delivered" | "completed" | "cancelled"
  createdAt: Timestamp;            // Creation timestamp
  createdBy: string;               // User ID who created
  updatedAt: Timestamp;            // Update timestamp
  // Optional fields:
  rescheduleReason?: string;        // Reason for rescheduling
  dmId?: string;                    // Delivery memo ID reference
  dmNumber?: string;                // Delivery memo number
  completedAt?: Timestamp;          // Completion timestamp
  cancelledAt?: Timestamp;          // Cancellation timestamp
  initialReading?: number;          // Vehicle initial reading (on dispatch)
  finalReading?: number;            // Vehicle final reading (on return)
  distanceTravelled?: number;       // Distance travelled
  deliveryPhotoUrl?: string;        // Delivery photo URL
  dispatchedAt?: Timestamp;         // Dispatch timestamp
  deliveredAt?: Timestamp;          // Delivery timestamp
  returnedAt?: Timestamp;           // Return timestamp
  deliveredBy?: string;             // User who delivered
  deliveredByRole?: string;          // Role of user who delivered
  returnedBy?: string;              // User who returned
  returnedByRole?: string;          // Role of user who returned
  paymentDetails?: Array<{          // Payment details (on return) - Only for POD trips
    amount: number;                 // Calculated: sum of (productQuant * productUnitPrice) from all items
    paidAt: Timestamp;              // Payment timestamp (use createdAt or deliveryDate)
    paidBy: string;                 // User ID who made payment
    paymentAccountId: string;       // Payment account ID (from toAccount lookup)
    paymentAccountName: string;     // Payment account name (from toAccount lookup)
    paymentAccountType: string;     // Payment account type (e.g., "cash", "bank", "upi")
    returnPayment: boolean;          // Always true for POD payments
  }>;
  totalPaidOnReturn?: number;       // Total paid on return
  paymentStatus?: string;           // Payment status
  remainingAmount?: number;         // Remaining amount
  returnTransactions?: string[];     // Transaction IDs
}
```

## Field Mapping

Fill in the **Pave Source Field** column with the exact field names from the Pave system.

| Target Field | Pave Source Field | Transformation Notes | Required |
|-------------|-------------------|---------------------|----------|
| `scheduleTripId` | `___________` | Human-readable trip ID. If not available, use document ID  | Yes |
| `orderId` | `defOrderID` | Order ID reference | Yes |
| `organizationId` | `NlQgs9kADbZr4ddBRkhS` | Organization ID. Set to target org ID during migration | Yes |
| `clientId` | `clientID` | Client ID reference | Yes |
| `clientName` | `clientName` | Client name (snapshot) | Yes |
| `clientPhone` | `clientPhoneNumber` | Client phone number (will be normalized to E.164) | Yes |
| `customerNumber` | `clientPhoneNumber` | Customer number/phone | Yes |
| `paymentType` | `paySchedule` | Payment type. "POD" → "pay_on_delivery", "PL" → "pay_later" | Yes |
| `scheduledDate` | `deliveryDate` | Scheduled date (Timestamp) | Yes |
| `scheduledDay` | `___________` | Day of week (e.g., "Monday", "Tuesday"). Will be derived from scheduledDate | No |
| `vehicleId` | `vehicleNumber` | Vehicle ID reference. Lookup: Remove spaces from vehicleNumber, then find vehicleId in target database by vehicleNumber | Yes |
| `vehicleNumber` | `vehicleNumber` | Vehicle number (snapshot) | Yes |
| `driverId` | `driverName` | Driver employee ID (optional). Lookup: Find driverId in target database by driverName | No |
| `driverName` | `driverName` | Driver name (optional) | No |
| `driverPhone` | `driverPhoneNumber` | Driver phone (optional, will be normalized to E.164) | No |
| `slot` | `dispatchStart`, `dispatchEnd` | Slot number (1, 2, 3, etc.). Calculated based on dispatchStart and dispatchEnd times for trips on the same day. First trip gets slot 1, second gets slot 2, etc. | Yes |
| `slotName` | `dispatchStart`, `dispatchEnd` | Slot name (e.g., "Morning", "Afternoon"). Will be derived from dispatchStart time or slot number | No |
| `deliveryZone` | `city_name`, `region` | Delivery zone object. Structure: `{regionName: city_name, address: region}`. Only these two fields are mapped | Yes |
| `items` | See Items Mapping section | Array of trip items. See Items Mapping section below | Yes |
| `tripPricing` | `___________` | Trip pricing object. Structure: `{subtotal, gstAmount, total}`. Will be calculated from items | No |
| `pricing` | `___________` | Order pricing snapshot (optional). Structure: `{subtotal, totalGst, totalAmount, includeGstInTotal}` | No |
| `includeGstInTotal` | `false` | GST inclusion flag (boolean). Default: false | No |
| `priority` | `___________` | Priority: "normal" | "high". Default: "normal" | No |
| `tripStatus` | `deliveryStatus` | Trip status. If deliveryStatus is true, mark as "returned" and migrate. Otherwise don't migrate (skip document) | Yes |
| `createdAt` | `deliveryDate` | Creation timestamp. Used for date filtering | Yes |
| `createdBy` | `___________` | User ID who created the trip | No |
| `updatedAt` | `___________` | Last update timestamp (optional, will use server timestamp if not available) | No |
| `rescheduleReason` | `___________` | Reason for rescheduling (optional) | No |
| `dmId` | `___________` | Delivery memo ID reference (optional) | No |
| `dmNumber` | `dmNumber` | Delivery memo number (optional) | No |


## Date Filter Field

The migration will filter records where the creation date is **<= December 31, 2025**.

- **Date Filter Field:** `___________` (field name from Pave that contains the creation/registration date)

## Trip Status Mapping and Document Filtering

**IMPORTANT:** Only migrate documents where `deliveryStatus = true`. Skip all documents where `deliveryStatus` is false or not set.

The target system uses the following trip statuses:
- `"scheduled"` - Trip is scheduled
- `"dispatched"` - Trip has been dispatched
- `"delivered"` - Trip has been delivered
- `"completed"` - Trip is completed
- `"cancelled"` - Trip is cancelled
- `"returned"` - Trip has been returned

**Mapping from Legacy:**
- If `deliveryStatus` is `true` → Set `tripStatus` to `"returned"` and migrate the document
- If `deliveryStatus` is `false` or not set → Skip document (do not migrate)

## Priority Mapping

The target system uses the following priority values:
- `"normal"` - Normal priority
- `"high"` - High priority

If the legacy system uses different values, specify the mapping here:

| Legacy Value | Target Value | Notes |
|------------|--------------|-------|
| `___________` | `normal` | |
| `___________` | `high` | |
| `___________` | `normal` | (default fallback) |

## Payment Type Mapping

**Mapping from Legacy `paySchedule` field:**
- `"POD"` → `"pay_on_delivery"` (migrate document)
- `"PL"` → `"pay_later"` (migrate document)
- Any other value → Use as-is or default to `"cash"`

## Payment Details for POD Trips

**Note:** Payment details are only created for trips with `paySchedule = "POD"`. For "PL" or other payment types, `paymentDetails` will be empty/omitted.

For trips with `paySchedule = "POD"`, create a `paymentDetails` array with the following structure:

| Target Field | Legacy Source | Transformation Notes |
|-------------|---------------|---------------------|
| `amount` | `productQuant`, `productUnitPrice` | Calculate: Sum of (productQuant * productUnitPrice) from all items in the trip |
| `paidAt` | `deliveryDate` or `createdAt` | Payment timestamp (use deliveryDate or createdAt) |
| `paidBy` | `___________` | User ID who made payment (if available, otherwise use default) |
| `paymentAccountId` | `toAccount` | Lookup: Normalize `toAccount`, find in target `ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS` by `name`, get `accountId` |
| `paymentAccountName` | `toAccount` | Lookup: Normalize `toAccount`, find in target database, get `name` |
| `paymentAccountType` | `toAccount` | Lookup: Normalize `toAccount`, find in target database, get `type` |
| `returnPayment` | `true` | Always set to `true` for POD payments |

**Payment Account Lookup:**
- Use `toAccount` field from legacy document
- Normalize `toAccount` (trim, lowercase for matching)
- Lookup in target database: `ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS` collection
- Match by `name` field (case-insensitive)
- Extract: `accountId` (document ID), `name`, `type`
- If not found, log warning and skip paymentDetails or use defaults

## Slot Calculation Logic

Slots are calculated based on `dispatchStart` and `dispatchEnd` times for trips on the same day:

1. **Group trips by date**: All trips with the same `deliveryDate` (same day) are grouped together
2. **Sort by dispatchStart time**: Trips are sorted by `dispatchStart` time in ascending order
3. **Assign slot numbers**: 
   - First trip (earliest dispatchStart) → Slot 1
   - Second trip (next dispatchStart) → Slot 2
   - Third trip → Slot 3
   - And so on...

**Example:**
- Trip 1: dispatchStart = 6:00 AM, dispatchEnd = 9:00 AM → Slot 1
- Trip 2: dispatchStart = 9:00 AM, dispatchEnd = 3:00 PM → Slot 2
- Trip 3: dispatchStart = 3:00 PM, dispatchEnd = 6:00 PM → Slot 3

**Slot Name Derivation:**
- Slot names can be derived from `dispatchStart` time:
  - 6:00 AM - 12:00 PM → "Morning"
  - 12:00 PM - 5:00 PM → "Afternoon"
  - 5:00 PM - 9:00 PM → "Evening"
  - 9:00 PM - 6:00 AM → "Night"
- Or use generic names: "Slot 1", "Slot 2", etc.

## Special Notes

1. **Document ID:** If you want to preserve Pave document IDs, leave blank. Otherwise, new IDs will be generated.

2. **scheduleTripId Generation:** 
   - Format: `ClientID-OrderID-YYYYMMDD-VehicleID-Slot`
   - Example: `CLIENT123-ORDER456-20240115-VEH001-1`
   - If not available in legacy, will be auto-generated during migration

3. **scheduledDay Derivation:** 
   - Will be derived from `scheduledDate` (deliveryDate)
   - Format: Full day name (e.g., "Monday", "Tuesday")

4. **Slot Calculation:** 
   - Slots are calculated based on `dispatchStart` and `dispatchEnd` times
   - For each day, trips are sorted by `dispatchStart` time
   - First trip gets slot 1, second gets slot 2, etc.
   - See "Slot Calculation Logic" section above for details

5. **slotName Derivation:** 
   - Can be derived from `dispatchStart` time:
     - Morning (6 AM - 12 PM)
     - Afternoon (12 PM - 5 PM)
     - Evening (5 PM - 9 PM)
     - Night (9 PM - 6 AM)
   - Or use generic names: "Slot 1", "Slot 2", etc.

5. **Phone Number Format:** 
   - Phone numbers will be normalized to E.164 format
   - Format: `+[country code][number]` (e.g., `+919876543210`)
   - Indian numbers: 10-digit numbers will be prefixed with `+91`

6. **Items Array:** 
   - Each item is mapped from legacy fields:
     - `productName` → `productName` (direct)
     - `productQuant` → `quantity` (fixedQuantityPerTrip)
     - `productUnitPrice` → `unitPrice`
     - `productId` is looked up by normalizing `productName` and finding in target database
   - Trip-specific pricing fields are calculated:
     - `tripSubtotal`: `quantity * unitPrice`
     - `tripGstAmount`: `tripSubtotal * (gstPercent / 100)` (if gstPercent available)
     - `tripTotal`: `tripSubtotal + tripGstAmount`

7. **tripPricing Calculation:** 
   - If `tripPricing` is not available, it will be calculated from the `items` array
   - Sum of all `tripSubtotal` → `subtotal`
   - Sum of all `tripGstAmount` → `gstAmount`
   - Sum of all `tripTotal` → `total`

8. **deliveryZone Structure:** 
   - Only two fields are mapped:
     - `city_name` → `regionName`
     - `region` → `address`
   - Other fields (`zoneId`, `zoneName`, `city`, `region`) will be empty or default values

9. **Vehicle ID Lookup:** 
   - Use `vehicleNumber` from legacy
   - Remove all spaces from vehicleNumber
   - Lookup in target database `VEHICLES` collection by `vehicleNumber` field
   - Get the `vehicleId` (document ID) from the matching vehicle

10. **Driver ID Lookup:** 
   - Use `driverName` from legacy
   - Lookup in target database `EMPLOYEES` collection by `employeeName` field
   - Get the `employeeId` (document ID) from the matching employee
   - If not found, leave `driverId` as null/empty

11. **Product ID Lookup:** 
   - Use `productName` from legacy item
   - Normalize productName (lowercase, trim)
   - Lookup in target database `ORGANIZATIONS/{orgId}/PRODUCTS` collection by `name` field (case-insensitive)
   - Get the `productId` (document ID) from the matching product
   - If not found, log warning and leave `productId` as empty

12. **Payment Account Lookup (for POD trips):** 
   - Use `toAccount` field from legacy document
   - Normalize `toAccount` (trim, lowercase for matching)
   - Lookup in target database `ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS` collection by `name` field (case-insensitive)
   - Get: `accountId` (document ID), `name`, `type` from the matching payment account
   - If not found, log warning and skip paymentDetails or use defaults

13. **Payment Details Amount Calculation:** 
   - For POD trips, calculate payment amount from items:
   - Sum of: `productQuant * productUnitPrice` for all items in the trip
   - This total amount goes into `paymentDetails[0].amount`

14. **Payment Details Creation:** 
   - **ONLY create `paymentDetails` for trips where `paySchedule = "POD"`**
   - For "PL" or other payment types, omit `paymentDetails` field
   - Payment details include amount calculation and payment account lookup (see section above)

15. **Organization Mapping:** The `organizationId` is set to the target organization ID: `NlQgs9kADbZr4ddBRkhS`

16. **Date Format:** The date filter field should be a Firestore Timestamp. If it's stored as a string or number, specify the format:
    - Timestamp (default)
    - ISO String: `YYYY-MM-DDTHH:mm:ss.sssZ`
    - Unix timestamp (seconds)
    - Unix timestamp (milliseconds)

## Items Mapping

Each item in the `items` array is mapped as follows:

| Target Field | Legacy Field | Transformation Notes |
|-------------|--------------|---------------------|
| `productName` | `productName` | Product name (direct mapping) |
| `productId` | `productName` | Product ID. Lookup: Normalize productName, then find productId in target database by normalized productName |
| `quantity` | `productQuant` | Quantity for this trip (maps to fixedQuantityPerTrip) |
| `unitPrice` | `productUnitPrice` | Unit price |
| `gstPercent` | `___________` | GST percentage (if available) |
| `tripSubtotal` | `___________` | Calculated: quantity * unitPrice |
| `tripGstAmount` | `___________` | Calculated: tripSubtotal * (gstPercent / 100) |
| `tripTotal` | `___________` | Calculated: tripSubtotal + tripGstAmount |

## Delivery Zone Mapping

The delivery zone object only maps two fields:

| Target Field | Legacy Field | Notes |
|-------------|--------------|-------|
| `regionName` | `city_name` | City name maps to regionName |
| `address` | `region` | Region maps to address |
| `zoneId` | (not mapped) | Will be empty or default value |
| `zoneName` | (not mapped) | Will be empty or default value |
| `city` | (not mapped) | Will be empty or default value |
| `region` | (not mapped) | Will be empty or default value |

## Additional Fields

If there are additional fields in Pave that need to be migrated but are not in the standard schema, list them here:

| Additional Field | Source Field | Target Field | Notes |
|-----------------|--------------|--------------|-------|
| | | | |

---

**Instructions:**
1. Fill in all fields marked with `___________`
2. Review the transformation notes
3. Specify status, priority, and payment type mappings if legacy uses different values
4. Specify slot name mapping if needed
5. Review delivery zone structure mapping
6. Update the migration script with the mappings
7. Test with a small subset before full migration

