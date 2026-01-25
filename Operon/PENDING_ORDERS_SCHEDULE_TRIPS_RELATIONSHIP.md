# Pending Orders and Schedule Trips Relationship

## Overview

The relationship between **Pending Orders** and **Schedule Trips** is a critical part of the order fulfillment system. When trips are scheduled for a pending order, the system maintains bidirectional synchronization between the order document and trip documents.

## Data Structure

### Pending Order Document Structure

```typescript
PENDING_ORDERS {
  id: string
  status: 'pending' | 'fully_scheduled' | 'cancelled'
  items: Array<{
    productId: string
    estimatedTrips: number      // Remaining trips to schedule
    scheduledTrips: number      // Already scheduled trips
    // ... other item fields
  }>
  scheduledTrips: Array<{        // Array of trip references
    tripId: string
    itemIndex: number           // Which item this trip belongs to
    productId: string           // Product reference
    scheduledDate: Timestamp
    scheduledDay: string
    vehicleId: string
    vehicleNumber: string
    driverName: string
    slot: number
    tripStatus: 'scheduled' | 'dispatched' | 'delivered' | 'returned'
    // ... other trip metadata
  }>
  totalScheduledTrips: number   // Total count (should match scheduledTrips.length)
  autoSchedule: {
    totalTripsRequired: number  // Authoritative total trips count
    estimatedDeliveryDate: Timestamp
    // ... other auto-schedule fields
  }
  // ... other order fields
}
```

### Schedule Trip Document Structure

```typescript
SCHEDULE_TRIPS {
  id: string
  orderId: string              // Reference to PENDING_ORDER
  itemIndex: number             // Which item in order this trip belongs to
  productId: string             // Product reference
  scheduledDate: Timestamp
  scheduledDay: string
  vehicleId: string
  vehicleNumber: string
  driverId: string
  driverName: string
  slot: number
  tripStatus: 'scheduled' | 'dispatched' | 'delivered' | 'returned'
  // ... other trip fields
}
```

## Key Relationships

1. **One-to-Many**: One PENDING_ORDER can have multiple SCHEDULE_TRIPS
2. **Item-Level Tracking**: Each trip is associated with a specific item via `itemIndex` and `productId`
3. **Bidirectional Sync**: Changes in trips update the order, and order changes can affect trips
4. **Status Synchronization**: Trip status changes are reflected in the order's `scheduledTrips` array

## Functions That Maintain the Relationship

### 1. **onScheduledTripCreated** (Cloud Function)
**File**: `functions/src/orders/trip-scheduling.ts`

**Trigger**: When a document is created in `SCHEDULE_TRIPS/{tripId}`

**What It Does**:
- Validates trip can be scheduled (checks for slot conflicts, order existence, remaining trips)
- Updates PENDING_ORDER:
  - Adds trip entry to `scheduledTrips` array
  - Increments `totalScheduledTrips` by 1
  - Decrements item's `estimatedTrips` by 1
  - Increments item's `scheduledTrips` by 1
  - Updates order status:
    - If all items have `estimatedTrips === 0`: Sets status to `'fully_scheduled'`
    - Otherwise: Sets status to `'pending'`

**Key Logic**:
```typescript
// Pre-validation checks
- Order must exist
- Order must have items
- itemIndex must be valid
- productId must match (if provided)
- Item must have estimatedTrips > 0
- Item's scheduledTrips < estimatedTrips
- No slot conflicts (same date + vehicle + slot)

// Update order
scheduledTrips: [...existingTrips, newTripEntry]
totalScheduledTrips: totalScheduledTrips + 1
items[itemIndex].estimatedTrips -= 1
items[itemIndex].scheduledTrips += 1

// Status update
if (all items have estimatedTrips === 0) {
  status = 'fully_scheduled'
} else {
  status = 'pending'
}
```

**Error Handling**:
- If validation fails, the trip document is deleted
- Prevents invalid trips from being created

---

### 2. **onScheduledTripDeleted** (Cloud Function)
**File**: `functions/src/orders/trip-scheduling.ts`

**Trigger**: When a document is deleted from `SCHEDULE_TRIPS/{tripId}`

**What It Does**:
- Updates PENDING_ORDER:
  - Removes trip entry from `scheduledTrips` array
  - Decrements `totalScheduledTrips` by 1
  - Increments item's `estimatedTrips` by 1
  - Decrements item's `scheduledTrips` by 1
  - Updates order status:
    - If any item has `estimatedTrips > 0`: Sets status to `'pending'`
    - Otherwise: Keeps status as `'fully_scheduled'`
- Cancels associated credit transaction (if exists)

**Key Logic**:
```typescript
// Find trip in scheduledTrips array
const deletedTrip = scheduledTrips.find(trip => trip.tripId === tripId)
const itemIndex = deletedTrip?.itemIndex ?? 0

// Update order
scheduledTrips: scheduledTrips.filter(trip => trip.tripId !== tripId)
totalScheduledTrips: Math.max(0, totalScheduledTrips - 1)
items[itemIndex].estimatedTrips += 1
items[itemIndex].scheduledTrips = Math.max(0, scheduledTrips - 1)

// Status update
if (any item has estimatedTrips > 0) {
  status = 'pending'
}
```

**Error Handling**:
- If order doesn't exist, trip deletion still succeeds (trip is independent)
- Gracefully handles missing itemIndex (falls back to first item)

---

### 3. **onTripStatusUpdated** (Cloud Function)
**File**: `functions/src/orders/trip-status-update.ts`

**Trigger**: When a document in `SCHEDULE_TRIPS/{tripId}` is updated

**What It Does**:
- Updates the corresponding trip entry in PENDING_ORDER's `scheduledTrips` array:
  - Updates `tripStatus` field
  - Updates status-specific fields (dispatchedAt, deliveredAt, returnedAt, etc.)
  - Ensures `itemIndex` and `productId` are set
- Updates DELIVERY_MEMO documents when status changes to 'delivered' or 'returned'
- Cancels credit transactions when status reverts from 'dispatched'

**Key Logic**:
```typescript
// Find trip in scheduledTrips array
const updatedTrips = scheduledTrips.map(trip => {
  if (trip.tripId === tripId) {
    return {
      ...trip,
      tripStatus: newStatus,
      // Add status-specific fields
      ...(newStatus === 'dispatched' && { dispatchedAt, initialReading, ... }),
      ...(newStatus === 'delivered' && { deliveredAt, deliveryPhotoUrl, ... }),
      ...(newStatus === 'returned' && { returnedAt, finalReading, ... })
    }
  }
  return trip
})

// Update order
scheduledTrips: updatedTrips
```

**Status-Specific Actions**:
- **'delivered'**: Updates DELIVERY_MEMO status to 'delivered'
- **'returned'**: Updates DELIVERY_MEMO with return details
- **'dispatched' → other**: Cancels associated credit transaction

---

### 4. **createScheduledTrip** (Client Function)
**Files**: 
- `apps/Operon_Client_android/lib/data/datasources/scheduled_trips_data_source.dart`
- `apps/Operon_Client_web/lib/data/datasources/scheduled_trips_data_source.dart`

**What It Does**:
- Creates a new SCHEDULE_TRIPS document
- Includes `orderId`, `itemIndex`, and `productId` in trip document
- Appends `tripId` to order's `tripIds` array (lightweight reference)
- **Note**: The actual order update (scheduledTrips array, counts) is handled by `onScheduledTripCreated` cloud function

**Key Fields Set**:
```dart
{
  'orderId': orderId,
  'itemIndex': itemIndex,        // Which item this trip belongs to
  'productId': productId,        // Product reference
  'scheduledDate': scheduledDate,
  'scheduledDay': scheduledDay,
  'vehicleId': vehicleId,
  'slot': slot,
  'tripStatus': 'scheduled',
  // ... other fields
}
```

---

### 5. **ScheduleTripModal** (UI Component)
**Files**:
- `apps/Operon_Client_android/lib/presentation/widgets/schedule_trip_modal.dart`
- `apps/Operon_Client_web/lib/presentation/widgets/schedule_trip_modal.dart`

**What It Does**:
- UI for scheduling trips
- Determines `itemIndex` and `productId` from order items
- Calls `createScheduledTrip` with proper item references
- **Note**: Currently defaults to `itemIndex = 0` (first item) - TODO: Add UI to select item for multi-product orders

---

## Trip Calculation Logic

### Total Trips Calculation Priority

The system uses a priority-based approach to calculate total trips:

1. **Priority 1**: `autoSchedule.totalTripsRequired` (authoritative source from backend)
2. **Priority 2**: Sum of all items' `estimatedTrips`
3. **Priority 3**: First item's `estimatedTrips`
4. **Priority 4**: `tripIds.length` (fallback)

**Implementation** (used in tiles and views):
```dart
int totalEstimatedTrips = 0;
if (autoSchedule?['totalTripsRequired'] != null) {
  totalEstimatedTrips = autoSchedule!['totalTripsRequired'];
} else {
  // Sum estimated trips from all items
  for (final item in items) {
    totalEstimatedTrips += (item['estimatedTrips'] as int? ?? 0);
  }
  if (totalEstimatedTrips == 0 && firstItem != null) {
    totalEstimatedTrips = firstItem['estimatedTrips'] ?? 
        (order['tripIds'] as List<dynamic>?)?.length ?? 0;
  }
}

final totalScheduledTrips = order['totalScheduledTrips'] as int? ?? 0;
final estimatedTrips = totalEstimatedTrips - totalScheduledTrips;
final totalTrips = totalEstimatedTrips; // Use totalEstimatedTrips, not sum
```

---

## State Transitions

### Order Status Flow

```
pending → fully_scheduled → (order remains, trips continue)
  ↑              ↓
  └──────────────┘ (if trip cancelled)
```

### Trip Status Flow

```
scheduled → dispatched → delivered
                      ↓
                   returned
```

### Item-Level Trip Counts

```
estimatedTrips: 5, scheduledTrips: 0
  ↓ (schedule trip)
estimatedTrips: 4, scheduledTrips: 1
  ↓ (schedule more trips)
estimatedTrips: 0, scheduledTrips: 5
  ↓ (all items fully scheduled)
Order status: 'fully_scheduled'
```

---

## Validation & Consistency Checks

### Functions That Validate Consistency

1. **checkOrderTripConsistency** (`functions/src/maintenance/check-order-trip-consistency.ts`)
   - Validates `scheduledTrips.length === totalScheduledTrips`
   - Checks item-level counts match actual trips
   - Finds orphaned trips (trips with orderId but not in scheduledTrips array)

2. **validateOrder** (`functions/src/maintenance/validate-order.ts`)
   - Validates item-level trip counts are non-negative
   - Ensures `scheduledTrips <= estimatedTrips` for each item
   - Checks array length matches count

3. **repairOrder** (`functions/src/maintenance/repair-order.ts`)
   - Fixes inconsistencies in scheduledTrips array
   - Syncs counts with actual trip documents
   - Adds missing trips or removes orphaned references

---

## Important Notes

### 1. **Order Never Deleted When Fully Scheduled**
- Previously, orders were deleted when fully scheduled
- Now, orders remain with status `'fully_scheduled'`
- This allows trips to continue independently and be cancelled if needed

### 2. **Item-Level Tracking**
- Each trip is associated with a specific item via `itemIndex` and `productId`
- This supports multi-product orders
- Trip counts are maintained at both order-level and item-level

### 3. **Transaction Safety**
- All order updates use Firestore transactions
- Prevents race conditions when multiple trips are scheduled simultaneously
- Ensures data consistency

### 4. **Error Recovery**
- If trip creation fails validation, trip document is deleted
- If order doesn't exist, trip deletion still succeeds (trip is independent)
- Graceful fallbacks for missing itemIndex (uses first item)

### 5. **Credit Transactions**
- Credit transactions are created when trips are dispatched
- Cancelled when trips are cancelled or dispatch is reverted
- Linked via `creditTransactionId` in trip document

---

## Data Flow Diagram

```
User schedules trip
    ↓
ScheduleTripModal (UI)
    ↓
createScheduledTrip (Client)
    ↓
Create SCHEDULE_TRIPS document
    ↓
onScheduledTripCreated (Cloud Function)
    ↓
Validate trip (order exists, has items, has remaining trips)
    ↓
Update PENDING_ORDER:
  - Add to scheduledTrips array
  - Increment totalScheduledTrips
  - Decrement item.estimatedTrips
  - Increment item.scheduledTrips
  - Update status (pending/fully_scheduled)
    ↓
Trip status changes
    ↓
onTripStatusUpdated (Cloud Function)
    ↓
Update trip entry in scheduledTrips array
    ↓
Update DELIVERY_MEMO (if delivered/returned)
```

---

## Summary

The relationship between Pending Orders and Schedule Trips is maintained through:

1. **Cloud Functions** that automatically sync changes:
   - `onScheduledTripCreated`: Updates order when trip is created
   - `onScheduledTripDeleted`: Updates order when trip is deleted
   - `onTripStatusUpdated`: Updates order when trip status changes

2. **Client Functions** that create trips:
   - `createScheduledTrip`: Creates trip document with proper references

3. **Validation Functions** that ensure consistency:
   - `checkOrderTripConsistency`: Validates counts match
   - `validateOrder`: Validates trip counts are valid
   - `repairOrder`: Fixes inconsistencies

4. **Item-Level Tracking**:
   - Each trip knows which item it belongs to (`itemIndex`, `productId`)
   - Trip counts maintained at both order and item level

5. **Status Management**:
   - Order status reflects trip scheduling state
   - Trip status changes are reflected in order's scheduledTrips array

This architecture ensures data consistency, supports multi-product orders, and allows trips to continue independently even if orders are cancelled.
