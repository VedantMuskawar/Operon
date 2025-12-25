# Auto-Scheduling System Design

## Overview
Auto-scheduling provides delivery date estimates (ETA) for pending orders based on vehicle capacity. It suggests vehicle assignments but does not automatically assign them - users will manually assign in the future.

## Key Requirements
1. ✅ Trigger on every new order created
2. ✅ Use Vehicles collection for capacity model
3. ✅ Vehicle assignments are suggestions only
4. ✅ Display only ETA label on pending order tiles
5. ✅ Delivery zones don't matter for scheduling

---

## Data Model

### Order Document Updates
Add to `PENDING_ORDERS` collection:

```typescript
{
  // ... existing fields ...
  
  // Auto-scheduling fields
  autoSchedule: {
    estimatedDeliveryDate: Timestamp,  // ETA date
    suggestedVehicleId: string,         // Suggested vehicle ID
    suggestedVehicleNumber: string,     // Suggested vehicle number (for display)
    priorityScore: number,              // Calculated priority (higher = more urgent)
    calculatedAt: Timestamp,            // When this was calculated
    totalTripsRequired: number,         // Total trips needed for this order
  }
}
```

### Vehicle Collection Structure
`ORGANIZATIONS/{orgId}/VEHICLES/{vehicleId}`

```typescript
{
  vehicleNumber: string,
  organizationId: string,
  vehicleCapacity: number,              // General capacity (trips per day)
  weeklyCapacity: {                     // Optional: capacity per day
    "monday": number,
    "tuesday": number,
    // ...
  },
  productCapacities: {                  // Optional: capacity per product
    "productId1": number,
    "productId2": number,
  },
  isActive: boolean,
  // ... other fields
}
```

---

## Scheduling Algorithm

### Step 1: Calculate Total Trips Required
For each order:
```typescript
totalTrips = sum of all items[].estimatedTrips
```

### Step 2: Get Available Vehicles
- Fetch all active vehicles for organization
- Filter: `isActive === true`

### Step 3: Calculate Daily Capacity
For each vehicle, determine daily capacity based on order's products:
```typescript
// For each vehicle and order combination
function getVehicleCapacityForOrder(vehicle, order) {
  // Check if order has specific products
  if (order.items.length > 0) {
    // Use product-specific capacity if available
    for (item of order.items) {
      productCapacity = vehicle.productCapacities?[item.productId]
      if (productCapacity) {
        // Use minimum capacity across all products in order
        return Math.min(productCapacity, ...)
      }
    }
  }
  
  // Fallback to general capacity
  return vehicle.weeklyCapacity?[dayOfWeek] || 
         vehicle.vehicleCapacity || 
         DEFAULT_CAPACITY (e.g., 5 trips/day)
}
```

### Step 4: Get Pending Orders
- Fetch all pending orders for organization
- Sort by:
  1. Priority (high first)
  2. Created date (older first)

### Step 5: Allocate Orders to Days
```typescript
// Pseudo-code
currentDate = today
remainingTrips = order.totalTripsRequired
allocatedDays = []

while (remainingTrips > 0) {
  availableCapacity = sum of all vehicles' dailyCapacity for currentDate
  
  if (availableCapacity >= remainingTrips) {
    // Can fit in this day
    allocatedDays.push(currentDate)
    remainingTrips = 0
  } else {
    // Partially allocate
    allocatedDays.push(currentDate)
    remainingTrips -= availableCapacity
    currentDate = nextDay(currentDate)
  }
}

estimatedDeliveryDate = last day in allocatedDays
```

### Step 6: Suggest Vehicle (Best Fit Algorithm)
```typescript
// For product-specific capacity
if (order has productId) {
  // Get product capacity for each vehicle
  eligibleVehicles = vehicles
    .filter(v => v.isActive)
    .filter(v => {
      productCapacity = v.productCapacities?[productId] || v.vehicleCapacity
      return productCapacity >= order.totalTripsRequired
    })
    .map(v => ({
      vehicle: v,
      capacity: v.productCapacities?[productId] || v.vehicleCapacity
    }))
  
  // Sort by capacity (ascending) - smallest that can handle
  eligibleVehicles.sort((a, b) => a.capacity - b.capacity)
  
  // Pick smallest vehicle that can handle the order
  suggestedVehicle = eligibleVehicles[0]?.vehicle
}

// Fallback: Use general vehicle capacity
if (!suggestedVehicle) {
  eligibleVehicles = vehicles
    .filter(v => v.isActive && v.vehicleCapacity >= order.totalTripsRequired)
    .sort((a, b) => a.vehicleCapacity - b.vehicleCapacity)
  
  suggestedVehicle = eligibleVehicles[0]
}

// If still no vehicle, pick largest (will need multiple days)
if (!suggestedVehicle) {
  suggestedVehicle = vehicles
    .filter(v => v.isActive)
    .sort((a, b) => b.vehicleCapacity - a.vehicleCapacity)[0]
}
```

**Key Point:** Always pick the **smallest capacity vehicle** that can handle the order. This ensures efficient capacity utilization and leaves larger vehicles for bigger orders.

### Step 7: Calculate Priority Score
```typescript
priorityScore = 
  (priority === 'high' ? 100 : 50) +
  (daysSinceCreated * 10) +
  (totalTripsRequired * 5)
```

---

## Example Scenario

### Setup
**Organization:** ABC Logistics
**Vehicles:**
- Vehicle 1: 
  - `vehicleCapacity: 8 trips/day`
  - `productCapacities: { "productX": 2000, "productY": 2000 }`
  - `isActive: true`
- Vehicle 2: 
  - `vehicleCapacity: 6 trips/day`
  - `productCapacities: { "productX": 4000, "productY": 4000 }`
  - `isActive: true`
- Vehicle 3: `vehicleCapacity: 5 trips/day`, `isActive: false` (inactive)

**Existing Pending Orders:**
1. Order A: 5 trips, priority: high, created: 2 days ago
2. Order B: 3 trips, priority: normal, created: 1 day ago
3. Order C: 4 trips, priority: normal, created: today

**Total Daily Capacity:** 8 + 6 = 14 trips/day

### New Order Created
**Order D:**
- Items: Product X (1500 units), Product Y (1000 units)
- Product X: 1500 units (needs vehicle with capacity >= 1500)
- Total trips: 5
- Priority: normal
- Created: just now

### Scheduling Process

**Step 1:** Calculate order requirements
- Product X: 1500 units
- Product Y: 1000 units
- Total trips: 5

**Step 2:** Get vehicles = [Vehicle 1, Vehicle 2] (Vehicle 3 inactive)

**Step 3:** Daily capacity = 14 trips/day

**Step 4:** Get all pending orders (sorted):
1. Order A (5 trips, high priority, 2 days old)
2. Order B (3 trips, normal, 1 day old)
3. Order C (4 trips, normal, today)
4. Order D (5 trips, normal, just now) ← NEW

**Step 5:** Allocate to days

**Today's Schedule:**
- Order A: 5 trips (high priority, oldest)
- Order B: 3 trips
- Order C: 4 trips
- **Total: 12 trips** (within 14 capacity)
- **Remaining capacity: 2 trips**

**Order D Allocation:**
- Needs 5 trips
- Today has 2 trips capacity left → can't fit
- **Tomorrow:**
  - Order D: 5 trips
  - **ETA: Tomorrow**

**Step 6:** Suggest Vehicle (Best Fit - Product Capacity)
- Order D needs 1500 units of Product X
- Check Product X capacity for each vehicle:
  - Vehicle 1: `productCapacities["productX"] = 2000` ✅ (can handle: 2000 >= 1500)
  - Vehicle 2: `productCapacities["productX"] = 4000` ✅ (can handle: 4000 >= 1500)
- **Eligible vehicles:** Both can handle
- **Sort by capacity (ascending - smallest first):**
  - Vehicle 1: 2000
  - Vehicle 2: 4000
- **Selected: Vehicle 1** (2000 - smallest capacity that can handle)
- **Reason:** 
  - Vehicle 1 (2000) is sufficient for 1500 units
  - Vehicle 2 (4000) is overkill - better saved for larger orders (e.g., 3000+ units)
  - **Best fit algorithm:** Always pick smallest capacity that can handle the order

**Step 7:** Priority Score
```
priorityScore = 
  50 (normal priority) +
  0 (days since created) +
  25 (5 trips * 5) 
  = 75
```

### Result
```typescript
{
  autoSchedule: {
    estimatedDeliveryDate: Timestamp(tomorrow),
    suggestedVehicleId: "vehicle1_id",  // Vehicle 1 (2000 capacity - best fit)
    suggestedVehicleNumber: "VH-001",
    priorityScore: 75,
    calculatedAt: Timestamp(now),
    totalTripsRequired: 5,
    productCapacityUsed: 2000,  // Product X capacity used from Vehicle 1
    productCapacityTotal: 2000  // Total Product X capacity of Vehicle 1
  }
}
```

**Key Learning:** When using product capacities, always pick the **smallest vehicle capacity** that can handle the order. This ensures:
- ✅ Efficient capacity utilization (2000 vs 4000)
- ✅ Larger vehicles available for bigger orders
- ✅ Better resource allocation
- ✅ Example: Order needs 1500 → Pick 2000 vehicle, not 4000 vehicle

### Display on Tile
**ETA Label:** "Est. delivery: Tomorrow" or "Est. delivery: Dec 5"

---

## Cloud Function Implementation

### Function: `onOrderCreatedAutoSchedule`

**Trigger:** `PENDING_ORDERS/{orderId}` onCreate

**Process:**
1. Fetch order data
2. Calculate total trips required
3. Fetch all active vehicles for organization
4. Fetch all pending orders (including new one)
5. Run scheduling algorithm
6. Update order with `autoSchedule` data

**Error Handling:**
- If no vehicles: Set ETA to null, log warning
- If calculation fails: Set ETA to null, don't block order creation

---

## UI Integration

### Pending Order Tile
Add ETA label below client name or in a badge:

```dart
// In _OrderTile widget
if (order['autoSchedule'] != null) {
  final eta = order['autoSchedule']['estimatedDeliveryDate'];
  final etaDate = (eta as Timestamp).toDate();
  final now = DateTime.now();
  final daysDiff = etaDate.difference(now).inDays;
  
  String etaText;
  if (daysDiff == 0) {
    etaText = 'Est. delivery: Today';
  } else if (daysDiff == 1) {
    etaText = 'Est. delivery: Tomorrow';
  } else {
    etaText = 'Est. delivery: ${_formatDate(etaDate)}';
  }
  
  // Display as badge or text
  Chip(
    label: Text(etaText),
    backgroundColor: _getETAColor(daysDiff),
  )
}
```

**Color Coding:**
- Today/Tomorrow: Green
- 2-3 days: Yellow
- 4+ days: Orange
- Overdue: Red

---

## Edge Cases

### 1. No Active Vehicles
- Set `autoSchedule.estimatedDeliveryDate: null`
- Log warning
- Display: "ETA: TBD"

### 2. Order Requires More Trips Than Daily Capacity
- Allocate across multiple days
- ETA = last day needed

### 3. High Priority Order
- Always schedule before normal priority
- May push other orders back

### 4. Vehicle Capacity Changes
- Recalculate on next order creation
- Or add scheduled function to recalculate all

### 5. Order Updated (Trips Changed)
- Could trigger recalculation
- Or wait for next order creation

---

## Future Enhancements

1. **Recalculation Function**
   - Scheduled function to recalculate all pending orders
   - Runs daily or on vehicle capacity changes

2. **Manual Override**
   - Allow users to manually set delivery date
   - Mark as `manuallyScheduled: true`

3. **Vehicle Assignment UI**
   - Show suggested vehicle in order tile
   - "Assign to Vehicle 1" button

4. **Capacity Warnings**
   - Alert when capacity is nearly full
   - Suggest adding more vehicles

5. **Historical Data**
   - Track actual vs estimated delivery
   - Improve algorithm accuracy

---

## Implementation Checklist

- [ ] Create Cloud Function `onOrderCreatedAutoSchedule`
- [ ] Implement scheduling algorithm
- [ ] Add `autoSchedule` fields to order schema
- [ ] Update pending order tile UI to show ETA
- [ ] Test with various scenarios
- [ ] Handle edge cases
- [ ] Add error logging
- [ ] Document for team

