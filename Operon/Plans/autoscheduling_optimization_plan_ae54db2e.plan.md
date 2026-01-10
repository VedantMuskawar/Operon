---
name: Autoscheduling Optimization Plan
overview: Analyze current autoscheduling implementation, identify performance and accuracy issues, and propose optimizations for better ETA accuracy, performance, and scalability.
todos: []
---

# Autoscheduling Function Analysis & Optimization Plan

## Current Implementation Overview

The autoscheduling function (`onOrderCreatedAutoSchedule`) runs when a new order is created and calculates:

- Estimated delivery date (ETA) based on vehicle capacity and pending orders
- Suggested vehicle assignment using best-fit algorithm
- Priority score for scheduling

**Location**: `functions/src/orders/order-scheduling.ts`

## Key Enhancement: Delivery Operations Analytics

**NEW FEATURE**: This plan includes comprehensive analytics tracking in the `ANALYTICS` collection to compare and monitor delivery operations efficiency. Analytics will track:

- **ETA Accuracy**: Compare estimated vs actual delivery dates to measure algorithm precision
- **Capacity Utilization**: Monitor vehicle capacity usage to identify bottlenecks
- **Scheduling Efficiency**: Track how often auto-suggestions are accepted vs manually adjusted
- **Algorithm Performance**: Monitor execution time and query efficiency
- **Delivery Time Performance**: Track actual delivery times for trend analysis
- **Bottleneck Detection**: Identify capacity constraints and overbooked periods

These analytics enable data-driven optimization of the scheduling algorithm and operational decision-making.

## Critical Issues Identified

### 1. **Missing Scheduled Trips Consideration** (P0 - Critical)

**Problem**: The algorithm only considers pending orders, ignoring already scheduled trips that consume vehicle capacity.

**Impact**:

- Inaccurate ETAs (underestimates delivery dates)
- Over-allocates capacity (doesn't account for trips already on schedule)
- Vehicle suggestions may be incorrect

**Current Code** (`calculateEstimatedDeliveryDate`):

```199:276:functions/src/orders/order-scheduling.ts
async function calculateEstimatedDeliveryDate(
  organizationId: string,
  newOrder: PendingOrder,
  vehicles: Vehicle[],
): Promise<Date> {
  // ... fetches pending orders only, no scheduled trips query
  // Allocates based on theoretical capacity, not actual availability
}
```

**Fix Required**: Query `SCHEDULE_TRIPS` collection to get already scheduled trips per vehicle per day and subtract from available capacity.

---

### 2. **Duplicate Firestore Queries** (P1 - Performance)

**Problem**: Pending orders are fetched multiple times:

- Once in `calculateEstimatedDeliveryDate` (line 210-215)
- Again in `findBestFitVehicle` (line 116-120)
- Third time in `autoScheduleOrder` (line 555-559)

**Impact**: 3x unnecessary reads, slower execution, higher Firestore costs

**Fix Required**: Fetch once and pass as parameter to helper functions.

---

### 3. **Inefficient Greedy Algorithm** (P1 - Accuracy)

**Problem**: Simple first-come-first-served allocation that doesn't optimize:

- Doesn't consider order priority when allocating
- Doesn't batch orders efficiently
- Doesn't consider multi-day order optimization

**Current Logic** (`calculateEstimatedDeliveryDate`):

```253:289:functions/src/orders/order-scheduling.ts
// Simple greedy: allocate orders in creation order
// Doesn't optimize for priority or efficiency
```

**Fix Required**: Implement priority-aware allocation with batching optimization.

---

### 4. **No Recalculation on Changes** (P1 - Staleness)

**Problem**: AutoSchedule only runs on order creation. Changes to:

- Vehicle capacity (added/removed/updated)
- Scheduled trips (cancelled/rescheduled)
- Order priority changes
- Order item updates

...don't trigger recalculation of existing pending orders' ETAs.

**Impact**: ETAs become stale and inaccurate over time

**Fix Required**:

- Add scheduled function to recalculate all pending orders periodically
- Add triggers for vehicle capacity changes
- Optionally trigger recalculation when trips are cancelled

---

### 5. **Incomplete Multi-Product Handling** (P2 - Accuracy)

**Problem**: Vehicle selection only considers first product in order:

```548:551:functions/src/orders/order-scheduling.ts
const primaryProduct = order.items[0];
const productCapacityTotal = primaryProduct
  ? getVehicleCapacityForProduct(suggestedVehicle, primaryProduct.productId)
  : suggestedVehicle.vehicleCapacity || DEFAULT_CAPACITY;
```

**Impact**:

- Orders with multiple products may get suboptimal vehicle suggestions
- Doesn't account for products requiring different vehicle types

**Fix Required**: Consider all products in order when selecting vehicle (minimum capacity across all products, or handle separately).

---

### 6. **No Historical Learning** (P2 - Accuracy)

**Problem**: Algorithm uses static capacity values, doesn't learn from:

- Actual delivery times vs estimated
- Historical vehicle utilization patterns
- Seasonal/daily capacity variations

**Current**: Has `updateEstimatedDeliveryDateReference` but only stores averages, doesn't use them in calculations.

**Fix Required**: Incorporate historical data into capacity calculations (e.g., use 80th percentile of historical delivery times instead of theoretical capacity).

---

### 7. **Missing Order Status Filter** (P2 - Bug)

**Problem**: Queries for pending orders but doesn't filter out orders that might be:

- Fully scheduled (`status: 'fully_scheduled'`)
- Partially scheduled (some items have `estimatedTrips === 0`)

**Impact**: Includes orders that shouldn't consume capacity in calculation

**Fix Required**: Filter by actual remaining trips: `estimatedTrips > 0` for at least one item.

---

### 8. **Inefficient Date Iteration** (P2 - Performance)

**Problem**: Loops through days one by one without bounds checking:

```254:289:functions/src/orders/order-scheduling.ts
while (remainingTrips > 0) {
  // No maximum days limit
  // Could loop indefinitely if capacity is very low
}
```

**Impact**:

- Could calculate ETAs months in advance (wasteful)
- No early exit if capacity is exhausted
- No maximum ETA cap

**Fix Required**: Add maximum ETA limit (e.g., 30 days), early exit conditions.

---

## Proposed Optimizations

### Phase 1: Critical Fixes (P0-P1)

1. **Add Scheduled Trips to Capacity Calculation**

   - Query `SCHEDULE_TRIPS` collection grouped by vehicle and date
   - Calculate actual remaining capacity = theoretical capacity - scheduled trips
   - Update `calculateEstimatedDeliveryDate` to use actual capacity

2. **Eliminate Duplicate Queries**

   - Refactor to fetch pending orders once
   - Pass data as parameters to helper functions
   - Cache vehicle data within function execution

3. **Add Recalculation Triggers**

   - Create scheduled function to run **every 6 hours** to recalculate all pending orders
   - Add trigger on vehicle capacity updates
   - **Recalculate ALL pending orders when a trip is cancelled** (to ensure accuracy after capacity is freed up)
   - Integration: Add trigger in `onScheduledTripDeleted` function

### Phase 2: Algorithm Improvements (P1-P2)

4. **Priority-Aware Allocation**

   - Sort pending orders by priority score
   - Allocate high-priority orders first
   - Optimize batching (fit more orders in same day when possible)

5. **Multi-Product Vehicle Selection**

   - Calculate required capacity for each product in order
   - Select vehicle that can handle all products (min capacity across all)
   - Or suggest multiple vehicles for different products

6. **Add Order Status Filtering**

   - Filter orders by actual remaining trips per item
   - Exclude fully scheduled orders from capacity calculations
   - Account for partially scheduled orders correctly

### Phase 3: Advanced Optimizations (P2-P3)

7. **Historical Learning Integration**

   - Use `estimatedDeliveryDates` reference data in calculations
   - Apply historical delivery time percentiles instead of theoretical capacity
   - Adjust capacity estimates based on actual vs estimated performance

8. **Performance Optimizations**

   - Add maximum ETA cap (e.g., 30 days)
   - Implement batch processing for large order volumes
   - Add caching layer for vehicle/scheduled trip data
   - Use Firestore composite indexes for efficient queries

9. **Delivery Operations Analytics Tracking** (NEW)

   - Record analytics documents in ANALYTICS collection for delivery efficiency comparison
   - Track ETA accuracy metrics (estimated vs actual delivery dates)
   - Monitor vehicle capacity utilization per organization
   - Track order scheduling efficiency and bottleneck detection
   - Record algorithm performance metrics (execution time, query counts)
   - Historical trend analysis for delivery operations

---

## Implementation Strategy

### Step 1: Fix Critical Issues (Week 1)

- [ ] Add scheduled trips query to capacity calculation
- [ ] Refactor to eliminate duplicate queries
- [ ] Add proper order status filtering

### Step 2: Add Recalculation (Week 2)

- [ ] Create scheduled recalculation function (runs every 6 hours using `functions.pubsub.schedule`)
- [ ] Add vehicle capacity change triggers (on vehicle document update)
- [ ] Add trigger in `onScheduledTripDeleted` to recalculate ALL pending orders when trip is cancelled
- [ ] Create helper function `recalculateAllPendingOrders` for organization
- [ ] Test recalculation accuracy

### Step 3: Algorithm Improvements (Week 3)

- [ ] Implement priority-aware allocation
- [ ] Improve multi-product handling
- [ ] Add ETA bounds and early exits

### Step 4: Analytics Implementation (Week 4)

- [ ] Create delivery analytics document structure (simplified: overall + vehicle efficiency)
- [ ] Implement efficiency score calculation functions
- [ ] Record analytics on order creation (track vehicle suggestion)
- [ ] Record analytics on trip scheduling (track suggestion acceptance)
- [ ] Record analytics on trip completion (compare actual vs estimated, update efficiency scores)
- [ ] Create monthly scheduled function to rebuild/aggregate analytics and recalculate efficiency scores

### Step 5: Advanced Features (Week 5+)

- [ ] Integrate historical learning from analytics data
- [ ] Performance optimizations
- [ ] Analytics dashboard integration

---

## Data Model Changes Required

### Add to Vehicle Document (optional)

```typescript
{
  // ... existing fields ...
  historicalUtilization: {
    averageTripsPerDay: number,
    utilizationPercentiles: {
      p50: number,
      p80: number,
      p95: number
    }
  }
}
```

### Add to Order autoSchedule (enhancement)

```typescript
{
  autoSchedule: {
    // ... existing fields ...
    calculatedFromScheduledTrips: boolean,  // Whether scheduled trips were considered
    actualCapacityUsed: number,             // Actual capacity used on delivery date
    confidence: number,                      // Confidence score (0-1) based on historical accuracy
  }
}
```

### Add Delivery Analytics Document Structure

**Collection**: `ANALYTICS`

**Document ID Format**: `delivery_{organizationId}_{financialYear}` (e.g., `delivery_org123_FY2425`)

**Simplified Structure** - Focus on overall delivery efficiency and vehicle efficiency:

```typescript
{
  source: 'delivery',                    // Source identifier
  organizationId: string,                // Organization reference
  financialYear: string,                 // FY label (e.g., "FY2425")
  generatedAt: Timestamp,                // Last generation timestamp
  metadata: {
    sourceCollections: ['PENDING_ORDERS', 'SCHEDULE_TRIPS', 'VEHICLES'],
    lastCalculatedAt: Timestamp,
  },
  metrics: {
    // Overall Delivery Efficiency (monthly)
    deliveryEfficiency: {
      type: 'monthly',
      unit: 'percentage',
      values: {
        '2024-04': {
          // Overall efficiency score (0-100%)
          efficiencyScore: 82,            // Calculated from multiple factors
          
          // ETA Accuracy Component
          onTimeDeliveryRate: 85,         // % delivered on or before ETA
          averageDaysDiff: 0.2,           // Average days difference (actual - estimated)
          
          // Scheduling Efficiency Component
          autoScheduleAcceptanceRate: 90, // % of auto-suggestions accepted
          averageDaysToSchedule: 2.5,     // Average days from order creation to first trip
          
          // Capacity Utilization Component
          averageCapacityUtilization: 75, // Average % of vehicle capacity used
          
          // Delivery Speed Component
          averageDeliveryTime: 3.2,       // Average days from order to delivery
          
          // Supporting data
          totalOrders: 200,
          totalDeliveries: 180,
          totalTrips: 450,
        },
        // ... more months
      }
    },
    
    // Vehicle Efficiency (monthly per vehicle)
    vehicleEfficiency: {
      type: 'monthly',
      unit: 'percentage',
      values: {
        '2024-04': {
          'vehicle1': {
            // Vehicle efficiency score (0-100%)
            efficiencyScore: 88,
            
            // Capacity Utilization
            averageUtilization: 80,       // Average % of capacity used
            peakUtilization: 95,          // Peak utilization for the month
            tripsCompleted: 45,           // Total trips completed
            
            // Suggestion Accuracy
            suggestedOrders: 38,          // Orders suggested to this vehicle
            acceptedSuggestions: 35,      // Orders actually assigned
            suggestionAccuracy: 92,       // % of suggestions accepted
            
            // Delivery Performance
            onTimeDeliveryRate: 90,       // % of trips delivered on-time
            averageTripsPerDay: 1.5,      // Average trips per day
          },
          'vehicle2': {
            efficiencyScore: 75,
            averageUtilization: 65,
            peakUtilization: 85,
            tripsCompleted: 30,
            suggestedOrders: 35,
            acceptedSuggestions: 28,
            suggestionAccuracy: 80,
            onTimeDeliveryRate: 85,
            averageTripsPerDay: 1.0,
          },
          // ... more vehicles
        },
      }
    },
  }
}
```

**Efficiency Score Calculation**:

- **Overall Delivery Efficiency** = Weighted average of:
  - 40% ETA Accuracy (on-time delivery rate)
  - 25% Scheduling Efficiency (auto-acceptance rate)
  - 20% Capacity Utilization (how well capacity is used)
  - 15% Delivery Speed (average delivery time, lower is better)

- **Vehicle Efficiency** = Weighted average of:
  - 35% Capacity Utilization (how well vehicle capacity is used)
  - 30% Suggestion Accuracy (how often suggestions are accepted)
  - 25% Delivery Performance (on-time delivery rate)
  - 10% Trip Frequency (trips per day, normalized)

---

## Testing Strategy

1. **Unit Tests**: Test algorithm logic with mock data
2. **Integration Tests**: Test with real Firestore data
3. **Accuracy Tests**: Compare estimated vs actual delivery dates over time
4. **Performance Tests**: Measure query counts and execution time
5. **Load Tests**: Test with large numbers of pending orders and scheduled trips

---

## Success Metrics

- **ETA Accuracy**: 80%+ of orders delivered within ±1 day of estimate
- **Performance**: < 2 seconds execution time, < 10 Firestore reads per order
- **Capacity Utilization**: Better vehicle capacity utilization (reduce over/under-allocation)
- **User Satisfaction**: Fewer manual adjustments needed

---

## Analytics Implementation Details

### When to Record Analytics

1. **On Order Creation** (ETA Calculation):

   - Record vehicle suggestion for tracking acceptance rate (used in vehicle efficiency)
   - Track when ETA was calculated (used for scheduling efficiency)

2. **On Trip Scheduling** (Scheduling Efficiency):

   - Track if suggested vehicle was actually used (updates vehicle efficiency - suggestion accuracy)
   - Record scheduling date to calculate averageDaysToSchedule (updates delivery efficiency)

3. **On Trip Completion** (Actual vs Estimated):

   - Compare actual delivery date with estimated date
   - Update overall delivery efficiency (ETA accuracy component)
   - Update vehicle efficiency for assigned vehicle (delivery performance component)

4. **Monthly Rebuild** (Efficiency Score Calculation):

   - Recalculate delivery efficiency score for organization
   - Recalculate vehicle efficiency scores for all vehicles
   - Aggregate all component metrics (on-time rate, utilization, etc.)
   - Ensure data consistency

### Analytics Functions to Create

1. **`recordETACalculationAnalytics`**: Called after ETA calculation

   - Records vehicle suggestion (tracks which vehicle was suggested for the order)
   - Stores order creation timestamp and ETA date (for calculating scheduling efficiency)

2. **`recordTripSchedulingAnalytics`**: Called when trip is scheduled

   - Tracks if suggested vehicle was actually used (updates vehicle suggestion accuracy)
   - Records scheduling date (for calculating averageDaysToSchedule)

3. **`recordDeliveryCompletionAnalytics`**: Called when order/trip is delivered

   - Compares actual delivery date with estimated date
   - Updates on-time delivery rate (component of delivery efficiency)
   - Updates vehicle delivery performance (component of vehicle efficiency)

4. **`calculateVehicleEfficiency`**: Helper function

   - Calculates vehicle efficiency score (0-100%) for a given vehicle in a month
   - Aggregates: capacity utilization (35%), suggestion accuracy (30%), delivery performance (25%), trip frequency (10%)
   - Called during monthly rebuild

5. **`calculateDeliveryEfficiency`**: Helper function

   - Calculates overall delivery efficiency score (0-100%) for organization in a month
   - Aggregates: ETA accuracy (40%), scheduling efficiency (25%), capacity utilization (20%), delivery speed (15%)
   - Called during monthly rebuild

6. **`rebuildDeliveryAnalytics`**: Scheduled function (monthly)

   - Rebuilds analytics from source data for all organizations
   - Recalculates all efficiency scores
   - Aggregates component metrics
   - Ensures data consistency

### Integration Points

- **Order Creation**: After `autoScheduleOrder` completes, call `recordETACalculationAnalytics` (track vehicle suggestion and ETA)
- **Trip Scheduling**: When trip is scheduled (in `onScheduledTripCreated`), call `recordTripSchedulingAnalytics` (track if suggested vehicle was used, record scheduling date)
- **Trip Completion**: When trip status changes to 'delivered' (in `onTripStatusUpdated`), call `recordDeliveryCompletionAnalytics` (compare actual vs estimated, update efficiency components)
- **Trip Cancellation**: After trip is cancelled (in `onScheduledTripDeleted`), trigger recalculation of ALL pending orders' ETAs
- **Monthly Scheduled**: Run `rebuildDeliveryAnalytics` to recalculate all efficiency scores and aggregate component metrics

---

## Resolved Questions

1. ✅ **Recalculate ALL pending orders when a trip is cancelled** - Yes, recalculate all to ensure accuracy
2. ✅ **Scheduled recalculation frequency** - Run every 6 hours
3. ✅ **Analytics scope** - Focus on two key metrics:

   - Overall delivery efficiency (organization-level)
   - Vehicle efficiency (per-vehicle)

## Remaining Questions to Resolve

1. What's the maximum acceptable ETA? (30 days? 60 days?)
2. Should we consider vehicle maintenance/off-days in capacity calculations?
3. Should we support manual ETA override with a flag to prevent recalculation?
4. For analytics rebuild: How often should we run it? (daily? monthly?) - **Recommendation: Monthly**
5. Should efficiency scores be calculated in real-time or only during rebuild?

---

## Files to Modify

- `functions/src/orders/order-scheduling.ts` - Main algorithm improvements + analytics recording on order creation
- `functions/src/orders/trip-scheduling.ts` - Add analytics recording on trip scheduling + trigger recalculation on trip deletion
- `functions/src/orders/trip-status-update.ts` - Add analytics recording on trip delivery
- `functions/src/index.ts` - Add new scheduled functions (recalculation every 6 hours + monthly analytics rebuild)
- `functions/src/shared/constants.ts` - Add `DELIVERY_SOURCE_KEY = 'delivery'`
- `AUTO_SCHEDULING_DESIGN.md` - Update documentation with analytics section

## New Files to Create

- `functions/src/orders/recalculate-auto-schedule.ts` - Scheduled recalculation function
- `functions/src/orders/vehicle-capacity-monitor.ts` - Vehicle capacity change handlers
- `functions/src/orders/delivery-analytics.ts` - Delivery analytics tracking and recording
- `functions/src/shared/delivery-analytics-helpers.ts` - Helper functions for analytics calculations