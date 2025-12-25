# Order Flow and Database Schema Design

## Overview

This document outlines the design for the Create Order feature, including the UI flow, database schema, and data models. The design is universal and can work for various industries (bricks manufacturing, retail, distribution, etc.).

### Important: Two-Phase Workflow

**Phase 1: Order Creation (This Document)**
- User creates order with quantities
- Uses trip-equivalent format: "3 Trips × 1,500 = 4,500 units"
- **These are estimated trips for quantity calculation, NOT actual scheduled trips**
- Order stored in `PENDING_ORDERS` collection
- Status: `pending`

**Phase 2: Trip Scheduling (Future Implementation)**
- Orders are later scheduled to actual vehicle trips
- System assigns orders to vehicles based on capacity
- Creates `SCHEDULED_TRIPS` documents
- Updates orders with `scheduledTripIds`
- **Vehicle assignment happens during trip scheduling, not order creation**

**Key Point:** The "trips" input during order creation is just a convenient way to calculate quantities. Actual trip scheduling happens separately when assigning orders to vehicles.

---

## UI Flow Design

### Create Order Page - 3 Sections

```
┌─────────────────────────────────────┐
│  Create Order                      │
├─────────────────────────────────────┤
│                                     │
│  Section 1: Select Product & Trips │
│  ┌───────────────────────────────┐ │
│  │ [Product Dropdown]             │ │
│  │ [Fixed Qty/Trip: 1500 ▼]      │ │
│  │                                 │ │
│  │ Number of Trips:                │ │
│  │ [−]  [  3  ]  [+]               │ │
│  │                                 │ │
│  │ Total: 4,500 units              │ │
│  │                                 │ │
│  │ [+ Add Product]                │ │
│  │                                 │ │
│  │ Product List:                   │ │
│  │ • Red Bricks                    │ │
│  │   3 Trips × 1500 = 4,500 units │ │
│  │ • Fly Ash Bricks                │ │
│  │   2 Trips × 2000 = 4,000 units │ │
│  └───────────────────────────────┘ │
│                                     │
│  Section 2: Select City & Region    │
│  ┌───────────────────────────────┐ │
│  │ [City Dropdown]                │ │
│  │ [Region Dropdown]              │ │
│  │                                 │ │
│  │ Delivery Address:              │ │
│  │ City: Mumbai                   │ │
│  │ Region: Andheri East           │ │
│  └───────────────────────────────┘ │
│                                     │
│  Section 3: Summary                 │
│  ┌───────────────────────────────┐ │
│  │ Red Bricks                     │ │
│  │   3 Trips × 1,500 = 4,500      │ │
│  │   Rate: ₹12.50/unit            │ │
│  │   Subtotal: ₹56,250            │ │
│  │   GST (18%): ₹10,125           │ │
│  │                                 │ │
│  │ Fly Ash Bricks                 │ │
│  │   2 Trips × 2,000 = 4,000      │ │
│  │   Rate: ₹10.00/unit            │ │
│  │   Subtotal: ₹40,000            │ │
│  │   (No GST)                      │ │
│  │                                 │ │
│  │ ─────────────────────────────  │ │
│  │ Subtotal: ₹96,250               │ │
│  │ Total GST: ₹10,125              │ │
│  │ Total Amount: ₹106,375          │ │
│  │                                 │ │
│  │ Payment Type:                   │ │
│  │ ○ Pay Later  ● Pay on Delivery │ │
│  │                                 │ │
│  │ Advance Payment:                │ │
│  │ Amount: [₹________] (Optional)  │ │
│  │ Mode: [Cash ▼]                  │ │
│  │                                 │ │
│  │ Priority:                       │ │
│  │ [Normal ▼]                      │ │
│  │                                 │ │
│  │ Estimated Delivery:             │ │
│  │ 📅 Jan 20, 2024 (3 days)       │ │
│  │                                 │ │
│  │ [Create Order Button]           │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Navigation Flow

1. **Section 1** → User selects products and quantities
2. **Section 2** → User selects delivery city and region (enables zone pricing)
3. **Section 3** → System calculates prices, GST, and total
4. **Create Order** → Order saved to `PENDING_ORDERS` collection

---

## Database Schema

### Collection: `PENDING_ORDERS`

**Location:** `PENDING_ORDERS/{orderId}` (Standalone collection at root level)

**Document Structure:**
```typescript
{
  // Order Identification
  orderId: string;                    // Same as document ID
  orderNumber: string;                 // Human-readable order number (e.g., "ORD-2024-001")
  
  // Client Information
  clientId: string;                    // Reference to CLIENTS collection
  clientName: string;                  // Snapshot of client name at order time
  clientPhone: string;                 // Primary phone number
  
  // Order Items
  items: Array<{
    productId: string;                 // Reference to PRODUCTS collection
    productName: string;               // Snapshot of product name
    // Quantity Input (Trip-Equivalent Format)
    // Note: These are for quantity calculation, NOT actual scheduled trips
    estimatedTrips: number;            // Estimated number of trips (e.g., 3)
    fixedQuantityPerTrip: number;      // Fixed quantity per trip (e.g., 1500)
    totalQuantity: number;             // estimatedTrips * fixedQuantityPerTrip (calculated)
    // Note: Vehicle capacity validation happens during trip scheduling, not order creation
    // Pricing
    unitPrice: number;                 // Price per unit (zone-specific or base)
    gstPercent?: number;                // GST percentage (optional - null if no GST)
    subtotal: number;                  // totalQuantity * unitPrice
    gstAmount: number;                 // subtotal * (gstPercent / 100) or 0 if no GST
    total: number;                     // subtotal + gstAmount
  }>;
  
  // Delivery Information
  deliveryZone: {
    zoneId: string;                    // Reference to DELIVERY_ZONES
    city: string;                      // City name
    region: string;                    // Region name
  };
  deliveryAddress?: string;            // Optional detailed address
  
  // Pricing Summary
  pricing: {
    subtotal: number;                  // Sum of all item subtotals
    totalGst: number;                  // Sum of all GST amounts
    totalAmount: number;               // Final total (subtotal + totalGst)
    currency: string;                  // Default: "INR"
  };
  
  // Order Status
  status: string;                      // "pending" | "confirmed" | "dispatched" | "delivered" | "cancelled"
  
  // Metadata
  organizationId: string;              // Organization reference
  createdBy: string;                   // User ID who created the order
  createdAt: Timestamp;                // Order creation timestamp
  updatedAt: Timestamp;                 // Last update timestamp
  
  // Optional Fields
  notes?: string;                      // Order notes/comments
  expectedDeliveryDate?: Timestamp;    // Expected delivery date (calculated based on other orders)
  
  // Payment Information
  paymentType: string;                 // "pay_later" | "pay_on_delivery"
  advanceAmount?: number;              // Advance payment amount (if any)
  advancePaymentMode?: string;         // "cash" | "upi" | "bank_transfer" | "cheque" | "other"
  remainingAmount?: number;            // Total - advanceAmount (calculated)
  
  // Order Priority
  priority: string;                    // "low" | "normal" | "high" | "urgent"
  
  // Trip Scheduling (added after order creation)
  scheduledTripIds?: string[];        // Array of SCHEDULED_TRIPS IDs this order is assigned to
  scheduledQuantity?: number;          // Total quantity scheduled across all trips
  unscheduledQuantity?: number;        // Remaining quantity not yet scheduled
}
```

### Example Document

```json
{
  "orderId": "ord_abc123",
  "orderNumber": "ORD-2024-001",
  "clientId": "client_xyz789",
  "clientName": "ABC Construction",
  "clientPhone": "+919876543210",
  "items": [
    {
      "productId": "prod_brick_red",
      "productName": "Red Bricks",
      "estimatedTrips": 3,
      "fixedQuantityPerTrip": 1500,
      "totalQuantity": 4500,
      "unitPrice": 12.50,
      "gstPercent": 18.0,
      "subtotal": 56250.00,
      "gstAmount": 10125.00,
      "total": 66375.00
    },
    {
      "productId": "prod_brick_flyash",
      "productName": "Fly Ash Bricks",
      "estimatedTrips": 2,
      "fixedQuantityPerTrip": 2000,
      "totalQuantity": 4000,
      "unitPrice": 10.00,
      "gstPercent": null,
      "subtotal": 40000.00,
      "gstAmount": 0.00,
      "total": 40000.00
    }
  ],
  "deliveryZone": {
    "zoneId": "zone_mumbai_andheri",
    "city": "Mumbai",
    "region": "Andheri East"
  },
  "deliveryAddress": "Building No. 5, Andheri East, Mumbai - 400069",
  "pricing": {
    "subtotal": 96250.00,
    "totalGst": 10125.00,
    "totalAmount": 106375.00,
    "currency": "INR"
  },
  "status": "pending",
  "organizationId": "org_123",
  "createdBy": "user_456",
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "notes": "Deliver before 5 PM",
  "expectedDeliveryDate": "2024-01-20T00:00:00Z"
}
```

---

## Complete Order-to-Delivery Workflow

### Phase 1: Order Creation (Current Focus)
1. User creates order with quantities
2. Uses trip-equivalent format for input: "3 Trips × 1,500 = 4,500 units"
3. Order stored in `PENDING_ORDERS` with status `pending`
4. **Note:** Trips here are estimated/for calculation only, not actual scheduled trips

### Phase 2: Trip Scheduling (Future Implementation)
1. System/admin selects pending orders
2. Groups orders by delivery zone
3. Assigns orders to vehicles based on capacity
4. Creates `SCHEDULED_TRIPS` documents
5. Updates orders with `scheduledTripIds` and status `scheduled`
6. Each trip can contain parts of multiple orders (up to vehicle capacity)

### Phase 3: Trip Execution
1. Trips are dispatched (status: `in_transit`)
2. Trips are delivered (status: `delivered`)
3. Orders are updated when all trips are delivered

### Visual Workflow

```
Order Creation
    ↓
[PENDING_ORDERS] - Status: pending
    ↓
Trip Scheduling (Admin/System)
    ↓
[SCHEDULED_TRIPS] - Status: scheduled
    ↓
Order Updated: scheduledTripIds added, status → scheduled
    ↓
Trip Dispatch
    ↓
[SCHEDULED_TRIPS] - Status: in_transit
    ↓
Trip Delivery
    ↓
[SCHEDULED_TRIPS] - Status: delivered
    ↓
Order Status: delivered (when all trips delivered)
```

---

## Order Creation and Trip Scheduling Workflow

### Two-Phase Process

**Phase 1: Order Creation**
- User creates order with quantities
- Uses "trips × fixedQuantity" as a convenient input method
- **Example:** "3 Trips × 1,500 = 4,500 units"
- This is just a **quantity calculation method**, not actual scheduled trips
- Order is stored in `PENDING_ORDERS` collection

**Phase 2: Trip Scheduling (Later)**
- Orders are scheduled to actual trips based on vehicle capacity
- System assigns orders to vehicles and creates trip schedules
- Each trip is assigned to a specific vehicle
- Trips are stored separately (see "Scheduled Trips" section below)

### Concept
During order creation, users input quantities using **trip-equivalent** format:
- "3 Trips of 1500 bricks" = 3 × 1500 = 4,500 bricks total
- This helps users think in terms of vehicle loads
- The actual trip scheduling happens later when assigning to vehicles

### Product-Specific Fixed Quantities

**Product Schema Enhancement:**
Add to `ORGANIZATIONS/{orgId}/PRODUCTS/{productId}`:
```typescript
{
  // ... existing product fields ...
  fixedQuantityPerTripOptions?: number[];  // [1000, 1500, 2000, 2500, 3000, 4000]
  // If not set, fallback to organization defaults
}
```

**Benefits:**
- Each product can have its own fixed quantity options
- Example: Red Bricks might have [1500, 2000, 2500], while Fly Ash Bricks might have [1000, 2000, 3000]
- More flexible than organization-wide presets
- Falls back to organization defaults if product doesn't specify

### Organization-Level Settings (Fallback)

**Collection:** `ORGANIZATIONS/{orgId}/ORDER_SETTINGS`

**Document Structure:**
```typescript
{
  // Default Fixed Quantity Per Trip Options (used if product doesn't specify)
  defaultFixedQuantityPerTripOptions: number[];  // [1000, 1500, 2000, 2500, 3000, 4000]
  
  // Trip Constraints
  minTrips?: number;                      // Minimum number of trips (default: 1)
  maxTrips?: number;                      // Maximum number of trips per order
  
  // Vehicle Capacity Validation
  enableVehicleCapacityCheck: boolean;    // Validate against vehicle capacity
  defaultVehicleCapacity?: number;        // Default capacity if product-specific not set
  
  // Updated timestamp
  updatedAt: Timestamp;
}
```

### Vehicle Capacity Integration (During Order Creation)

**Important:** During order creation, we don't know which specific vehicle will be assigned. Therefore, vehicle capacity validation is **informational only** and should not block order creation.

**What We Can Show:**
- **General guidance:** "This order may require multiple vehicle trips"
- **Typical capacity info:** Show typical vehicle capacity as reference
- **No specific warnings:** Don't show "exceeds capacity" since vehicle isn't assigned yet

**Vehicle Capacity Sources (For Reference Only):**
1. **Default Organization Capacity:** `ORDER_SETTINGS.defaultVehicleCapacity`
   - Used as general guideline
2. **Product-Specific Typical Capacity:** Average from all vehicles
   - Can be calculated from `Vehicle.productCapacities` across all vehicles
   - But this is just informational

**During Order Creation:**
- **No capacity validation warnings** (vehicle not assigned yet)
- **Show total quantity** clearly
- **Optional:** Show typical vehicle capacity as reference info
- **Allow any quantity** - actual capacity validation happens during trip scheduling

**During Trip Scheduling (Future):**
- **Actual capacity validation** happens here
- System checks specific vehicle capacity
- Assigns orders to trips based on actual vehicle capacity
- Can split orders across multiple trips if needed

**Benefits:**
- Aligns with real-world logistics (truck loads)
- Each organization defines their own fixed quantities per trip
- Supports vehicle capacity validation
- Clear communication: "3 Trips of 1500" is more intuitive than "4500 units"
- Works for any industry with vehicle-based delivery

---

## Data Models (Dart)

### OrderItem Model

```dart
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.trips,
    required this.fixedQuantityPerTrip,
    required this.unitPrice,
    this.gstPercent,                    // Optional - null if no GST
    this.vehicleCapacityWarning = false, // true if exceeds vehicle capacity
    this.vehicleCapacityUsed,            // Capacity used for validation
  });

  final String productId;
  final String productName;
  final int estimatedTrips;             // Estimated trips (for quantity calculation only)
  final int fixedQuantityPerTrip;        // Fixed quantity per trip
  final double unitPrice;
  final double? gstPercent;              // Optional GST percentage
  // Note: Vehicle capacity validation happens during trip scheduling, not order creation

  // Calculated properties
  int get totalQuantity => estimatedTrips * fixedQuantityPerTrip;
  double get subtotal => totalQuantity * unitPrice;
  double get gstAmount => gstPercent != null 
      ? subtotal * (gstPercent! / 100) 
      : 0.0;
  double get total => subtotal + gstAmount;

  // Display helpers
  String get displayText => 
      '$estimatedTrips Trip${estimatedTrips > 1 ? 's' : ''} × $fixedQuantityPerTrip = $totalQuantity units';
  
  bool get hasGst => gstPercent != null && gstPercent! > 0;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'estimatedTrips': estimatedTrips,
      'fixedQuantityPerTrip': fixedQuantityPerTrip,
      'totalQuantity': totalQuantity,
      'unitPrice': unitPrice,
      if (gstPercent != null) 'gstPercent': gstPercent,
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'total': total,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      estimatedTrips: json['estimatedTrips'] as int? ?? json['trips'] as int, // Backward compatibility
      fixedQuantityPerTrip: json['fixedQuantityPerTrip'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      gstPercent: (json['gstPercent'] as num?)?.toDouble(),
    );
  }
  
  OrderItem copyWith({
    String? productId,
    String? productName,
    int? estimatedTrips,
    int? fixedQuantityPerTrip,
    double? unitPrice,
    double? gstPercent,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      estimatedTrips: estimatedTrips ?? this.estimatedTrips,
      fixedQuantityPerTrip: fixedQuantityPerTrip ?? this.fixedQuantityPerTrip,
      unitPrice: unitPrice ?? this.unitPrice,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}
```

### DeliveryZoneSelection Model

```dart
class DeliveryZoneSelection {
  const DeliveryZoneSelection({
    required this.zoneId,
    required this.city,
    required this.region,
  });

  final String zoneId;
  final String city;
  final String region;

  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'city': city,
      'region': region,
    };
  }

  factory DeliveryZoneSelection.fromJson(Map<String, dynamic> json) {
    return DeliveryZoneSelection(
      zoneId: json['zoneId'] as String,
      city: json['city'] as String,
      region: json['region'] as String,
    );
  }
}
```

### OrderPricing Model

```dart
class OrderPricing {
  const OrderPricing({
    required this.subtotal,
    required this.totalGst,
    required this.totalAmount,
    this.currency = 'INR',
  });

  final double subtotal;
  final double totalGst;
  final double totalAmount;
  final String currency;

  Map<String, dynamic> toJson() {
    return {
      'subtotal': subtotal,
      'totalGst': totalGst,
      'totalAmount': totalAmount,
      'currency': currency,
    };
  }

  factory OrderPricing.fromJson(Map<String, dynamic> json) {
    return OrderPricing(
      subtotal: (json['subtotal'] as num).toDouble(),
      totalGst: (json['totalGst'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}
```

### PendingOrder Model

```dart
enum OrderStatus {
  pending,              // Order created, not yet scheduled
  partially_scheduled,  // Some quantity scheduled to trips
  scheduled,           // Fully scheduled to trips
  confirmed,           // Trips confirmed
  in_transit,          // Trips in transit
  delivered,           // All trips delivered
  cancelled,           // Order cancelled
}

class PendingOrder {
  const PendingOrder({
    required this.id,
    required this.orderNumber,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.items,
    required this.deliveryZone,
    required this.pricing,
    required this.status,
    required this.organizationId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryAddress,
    this.notes,
    this.expectedDeliveryDate,
    required this.paymentType,
    this.advanceAmount,
    this.remainingAmount,
    this.priority = OrderPriority.normal,
    this.scheduledTripIds,
    this.scheduledQuantity,
    this.unscheduledQuantity,
  });

  final String id;
  final String orderNumber;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final List<OrderItem> items;
  final DeliveryZoneSelection deliveryZone;
  final OrderPricing pricing;
  final OrderStatus status;
  final String organizationId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryAddress;
  final String? notes;
  final DateTime? expectedDeliveryDate;
  final PaymentType paymentType;        // Payment type
  final double? advanceAmount;          // Advance payment (if any)
  final PaymentMode? advancePaymentMode; // Payment mode for advance (if advance given)
  final double? remainingAmount;        // Remaining amount (calculated)
  final OrderPriority priority;         // Order priority
  final List<String>? scheduledTripIds;  // Trips this order is assigned to
  final int? scheduledQuantity;         // Quantity already scheduled
  final int? unscheduledQuantity;        // Quantity remaining to schedule

  Map<String, dynamic> toJson() {
    return {
      'orderId': id,
      'orderNumber': orderNumber,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'deliveryZone': deliveryZone.toJson(),
      'pricing': pricing.toJson(),
      'status': status.name,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (notes != null) 'notes': notes,
      if (expectedDeliveryDate != null)
        'expectedDeliveryDate': Timestamp.fromDate(expectedDeliveryDate!),
      'paymentType': paymentType.name,
      if (advanceAmount != null && advanceAmount! > 0) 'advanceAmount': advanceAmount,
      if (advancePaymentMode != null) 'advancePaymentMode': advancePaymentMode!.name,
      if (remainingAmount != null) 'remainingAmount': remainingAmount,
      'priority': priority.name,
      if (scheduledTripIds != null && scheduledTripIds!.isNotEmpty)
        'scheduledTripIds': scheduledTripIds,
      if (scheduledQuantity != null) 'scheduledQuantity': scheduledQuantity,
      if (unscheduledQuantity != null) 'unscheduledQuantity': unscheduledQuantity,
    };
  }

  factory PendingOrder.fromJson(Map<String, dynamic> json, String docId) {
    return PendingOrder(
      id: json['orderId'] as String? ?? docId,
      orderNumber: json['orderNumber'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      clientPhone: json['clientPhone'] as String,
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      deliveryZone: DeliveryZoneSelection.fromJson(
        json['deliveryZone'] as Map<String, dynamic>,
      ),
      pricing: OrderPricing.fromJson(
        json['pricing'] as Map<String, dynamic>,
      ),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      organizationId: json['organizationId'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      deliveryAddress: json['deliveryAddress'] as String?,
      notes: json['notes'] as String?,
      expectedDeliveryDate: json['expectedDeliveryDate'] != null
          ? (json['expectedDeliveryDate'] as Timestamp).toDate()
          : null,
      paymentType: PaymentType.values.firstWhere(
        (p) => p.name == json['paymentType'],
        orElse: () => PaymentType.payOnDelivery,
      ),
      advanceAmount: (json['advanceAmount'] as num?)?.toDouble(),
      advancePaymentMode: json['advancePaymentMode'] != null
          ? PaymentMode.values.firstWhere(
              (p) => p.name == json['advancePaymentMode'],
              orElse: () => PaymentMode.cash,
            )
          : null,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
      priority: OrderPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => OrderPriority.normal,
      ),
      scheduledTripIds: json['scheduledTripIds'] != null
          ? List<String>.from(json['scheduledTripIds'] as List)
          : null,
      scheduledQuantity: json['scheduledQuantity'] as int?,
      unscheduledQuantity: json['unscheduledQuantity'] as int?,
    );
  }
}
```

---

## Pricing Calculation Logic

### Step-by-Step Calculation

1. **Get Base Product Price**
   - From `ORGANIZATIONS/{orgId}/PRODUCTS/{productId}`
   - Field: `unitPrice`

2. **Check Zone-Specific Pricing**
   - Query: `ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}/PRICES/{productId}`
   - If exists and `deliverable == true`, use `unitPrice` from zone pricing
   - Otherwise, use base product price

3. **Get GST Percentage (Optional)**
   - From `ORGANIZATIONS/{orgId}/PRODUCTS/{productId}`
   - Field: `gstPercent` (can be null/0 if no GST)

4. **Calculate Item Pricing (Trip-Based)**
   ```
   totalQuantity = trips × fixedQuantityPerTrip
   subtotal = totalQuantity × unitPrice
   gstAmount = gstPercent != null 
       ? subtotal × (gstPercent / 100) 
       : 0
   itemTotal = subtotal + gstAmount
   ```

5. **Calculate Order Totals**
   ```
   orderSubtotal = sum of all item subtotals
   orderTotalGst = sum of all item GST amounts (only items with GST)
   orderTotal = orderSubtotal + orderTotalGst
   ```

### Example Calculation

**Product:** Red Bricks
- Base Price: ₹10/unit
- Zone Price (Mumbai-Andheri): ₹12.50/unit
- GST: 18%
- **Trips:** 3
- **Fixed Quantity Per Trip:** 1500 units

**Calculation:**
```
Total Quantity: 3 × 1500 = 4,500 units
Unit Price: ₹12.50 (zone-specific)
Subtotal: 4,500 × 12.50 = ₹56,250
GST (18%): 56,250 × 0.18 = ₹10,125
Item Total: ₹66,375
```

**Product:** Fly Ash Bricks (No GST)
- Zone Price: ₹10.00/unit
- GST: null (no GST)
- **Trips:** 2
- **Fixed Quantity Per Trip:** 2000 units

**Calculation:**
```
Total Quantity: 2 × 2000 = 4,000 units
Unit Price: ₹10.00
Subtotal: 4,000 × 10.00 = ₹40,000
GST: 0 (no GST applicable)
Item Total: ₹40,000
```

**Order Total:**
```
Subtotal: ₹56,250 + ₹40,000 = ₹96,250
Total GST: ₹10,125 + ₹0 = ₹10,125
Total Amount: ₹106,375
```

---

## Order Number Generation

### Format: `ORD-{YYYY}-{NNN}`

**Example:** `ORD-2024-001`, `ORD-2024-002`

**Implementation:**
1. Query `PENDING_ORDERS` for orders created in current year
2. Get highest order number
3. Increment by 1
4. Format: `ORD-{year}-{3-digit-number}`

**Alternative:** Use Firestore auto-increment or timestamp-based numbering

---

## Indexes Required

### Firestore Indexes

1. **By Organization and Status**
   - Collection: `PENDING_ORDERS`
   - Fields: `organizationId` (Ascending), `status` (Ascending), `createdAt` (Descending)

2. **By Organization and Client**
   - Collection: `PENDING_ORDERS`
   - Fields: `organizationId` (Ascending), `clientId` (Ascending), `createdAt` (Descending)

3. **By Organization and Date Range**
   - Collection: `PENDING_ORDERS`
   - Fields: `organizationId` (Ascending), `createdAt` (Descending)

---

## State Management Flow

### CreateOrderCubit States

```dart
class CreateOrderState {
  // Section 1: Products (Trip-Based)
  final List<OrderItem> selectedItems;
  final List<OrganizationProduct> availableProducts;
  final Map<String, List<int>> productFixedQuantityOptions; // productId -> [1000, 1500, etc.]
  final List<int> defaultFixedQuantityOptions;              // Fallback options
  final Map<String, double> vehicleCapacities;              // productId -> capacity
  final int minTrips;
  final int maxTrips;
  
  // Section 2: Delivery
  final List<DeliveryCity> cities;
  final List<DeliveryZone> zones;
  final DeliveryZoneSelection? selectedZone;
  
  // Section 3: Summary
  final OrderPricing? pricing;
  final PaymentType paymentType;
  final double? advanceAmount;
  final PaymentMode? advancePaymentMode;
  final double? remainingAmount;
  final OrderPriority priority;
  final DateTime? estimatedDeliveryDate;  // Calculated based on other orders
  final int? estimatedDeliveryDays;        // Days until delivery
  
  // Client
  final ClientRecord? client;
  
  // Status
  final ViewStatus status;
  final String? message;
  final bool isCreating;
  final bool isLoadingProducts;
  final bool isLoadingZones;
  final bool isCalculatingDelivery;
}
```

### CreateOrderCubit Events

```dart
// Section 1: Trip-Equivalent Quantity Input
class LoadProducts extends CreateOrderEvent {}
class LoadVehicleCapacities extends CreateOrderEvent {}
class AddProductItem extends CreateOrderEvent {
  final OrganizationProduct product;
  final int estimatedTrips;        // Estimated trips (for quantity calculation)
  final int fixedQuantityPerTrip;
}
class RemoveProductItem extends CreateOrderEvent {
  final String productId;
}
class IncrementItemTrips extends CreateOrderEvent {
  final String productId;
}
class DecrementItemTrips extends CreateOrderEvent {
  final String productId;
}
class UpdateItemTrips extends CreateOrderEvent {
  final String productId;
  final int estimatedTrips;
}
class UpdateItemFixedQuantity extends CreateOrderEvent {
  final String productId;
  final int fixedQuantityPerTrip;
}
// Note: Vehicle capacity validation happens during trip scheduling, not order creation

// Section 2
class LoadCities extends CreateOrderEvent {}
class SelectCity extends CreateOrderEvent {
  final String cityName;
}
class SelectZone extends CreateOrderEvent {
  final DeliveryZone zone;
}

// Section 3
class CalculatePricing extends CreateOrderEvent {}

// Create Order
class CreateOrder extends CreateOrderEvent {
  final String? notes;
  final String? deliveryAddress;
  final PaymentType paymentType;
  final double? advanceAmount;
  final PaymentMode? advancePaymentMode;
  final OrderPriority priority;
}
```

---

## UI Components Structure

```
CreateOrderPage
├── Section 1: ProductSelectionSection
│   ├── ProductDropdown
│   ├── FixedQuantityPerTripDropdown
│   │   └── Options from: Product.fixedQuantityPerTripOptions
│   │       OR fallback to: ORDER_SETTINGS.defaultFixedQuantityPerTripOptions
│   │
│   ├── NumberOfTripsSelector
│   │   └── [−] [  3  ] [+]  ← Increment/Decrement buttons
│   │       Min: 1, Max: configurable (default: 100)
│   │
│   ├── TotalQuantityDisplay
│   │   └── "Total: 4,500 units" (trips × fixedQuantity)
│   │
│   ├── VehicleCapacityWarning (if applicable)
│   │   └── ⚠️ "Exceeds vehicle capacity (3,000 units)"
│   │       (Soft validation - doesn't block order)
│   │
│   ├── AddProductButton
│   │
│   └── OrderItemsList
│       └── Each item shows:
│           - Product name
│           - "3 Trips × 1,500 = 4,500 units"
│           - [Edit] [Remove] buttons
│           - Note: No capacity warnings (vehicle not assigned yet)
│
├── Section 2: DeliveryZoneSection
│   ├── CityDropdown
│   ├── RegionDropdown (filtered by selected city)
│   └── DeliveryAddressInput (optional)
│
└── Section 3: OrderSummarySection
    ├── ItemsBreakdown
    │   └── Each item shows:
    │       - Product name
    │       - "3 Trips × 1,500 = 4,500 units"
    │       - Rate per unit
    │       - Subtotal
    │       - GST (if applicable) or "(No GST)"
    │       - Item total
    │
    ├── PricingSummary
    │   ├── Subtotal
    │   ├── Total GST (only if any items have GST)
    │   └── Total Amount
    │
    └── CreateOrderButton
        └── Disabled if no items or no delivery zone selected
```

---

## Benefits of This Design

### 1. **Trip-Based Ordering (Vehicle-Aligned)**
   - Orders placed in trips/loads (matches real-world logistics)
   - Clear communication: "3 Trips of 1500" vs "4500 units"
   - Vehicle capacity validation support
   - Organization-specific fixed quantities per trip

### 2. **Universal & Flexible**
   - Works for any industry (bricks, retail, wholesale, etc.)
   - Fixed quantity options are organization-specific
   - Supports different trip quantities per product
   - Optional GST (works for GST and non-GST products)

### 3. **Scalable**
   - Multiple products per order
   - Zone-based pricing
   - Extensible with optional fields
   - Vehicle capacity integration ready

### 4. **Accurate Pricing**
   - Zone-specific pricing
   - Per-product GST calculation (optional)
   - Handles products with and without GST in same order
   - Snapshot of prices at order time

### 5. **Traceable**
   - Order number for reference
   - Client snapshot
   - Product snapshot
   - Trip breakdown preserved
   - Timestamps for audit

### 6. **Future-Proof**
   - Status tracking for workflow
   - Vehicle/driver assignment ready
   - Expected delivery date support
   - Notes/comments field
   - Vehicle capacity validation ready

---

## Next Steps

1. **Create Data Models** (`lib/domain/entities/`)
   - `pending_order.dart`
   - `order_item.dart`
   - `order_pricing.dart`
   - `delivery_zone_selection.dart`

2. **Create Data Sources** (`lib/data/datasources/`)
   - `pending_orders_data_source.dart`

3. **Create Repository** (`lib/data/repositories/`)
   - `pending_orders_repository.dart`

4. **Create BLoC** (`lib/presentation/blocs/`)
   - `create_order_cubit.dart`

5. **Create UI Components** (`lib/presentation/views/orders/`)
   - `create_order_page.dart` (main page)
   - `product_selection_section.dart`
   - `delivery_zone_section.dart`
   - `order_summary_section.dart`

6. **Create Settings Management**
   - `order_settings_data_source.dart` (for quantity presets)

---

## Detailed Design Discussion

### Product Schema Enhancement

**Current Product Schema:**
```dart
class OrganizationProduct {
  final String id;
  final String name;
  final double unitPrice;
  final double gstPercent;  // Currently required, should be optional
  final ProductStatus status;
  final int stock;
}
```

**Proposed Enhancement:**
```dart
class OrganizationProduct {
  final String id;
  final String name;
  final double unitPrice;
  final double? gstPercent;              // Make optional
  final ProductStatus status;
  final int stock;
  final List<int>? fixedQuantityPerTripOptions;  // NEW: Product-specific options
}
```

**Firestore Schema Update:**
```typescript
// ORGANIZATIONS/{orgId}/PRODUCTS/{productId}
{
  productId: string;
  name: string;
  unitPrice: number;
  gstPercent?: number;                    // Optional (can be null)
  status: string;
  stock: number;
  fixedQuantityPerTripOptions?: number[]; // NEW: [1500, 2000, 2500]
}
```

**Fallback Logic:**
1. If product has `fixedQuantityPerTripOptions` → Use product options
2. Else → Use `ORDER_SETTINGS.defaultFixedQuantityPerTripOptions`
3. If neither exists → Use default [1000, 1500, 2000, 2500, 3000, 4000]

### Vehicle Capacity Validation Flow

**Step-by-Step Validation:**

1. **User selects product, fixed quantity, and trips**
   ```
   Product: Red Bricks
   Fixed Qty/Trip: 1500
   Trips: 3
   Total: 4,500 units
   ```

2. **System fetches vehicle capacity (priority order):**
   ```dart
   double? getVehicleCapacity(String productId) {
     // Priority 1: Product-specific vehicle capacity
     final productCapacity = vehicle.productCapacities?[productId];
     if (productCapacity != null) return productCapacity;
     
     // Priority 2: General vehicle capacity
     if (vehicle.vehicleCapacity != null) return vehicle.vehicleCapacity;
     
     // Priority 3: Default organization capacity
     return orderSettings.defaultVehicleCapacity;
   }
   ```

3. **Calculate quantity:**
   ```dart
   final totalQuantity = estimatedTrips * fixedQuantityPerTrip;
   // No capacity validation during order creation
   // Capacity validation happens during trip scheduling
   ```

### Trip Input UI Design

**Increment/Decrement Buttons:**
```
┌─────────────────────────────┐
│ Number of Trips             │
│                             │
│  ┌──┐      ┌───┐      ┌──┐ │
│  │ − │      │ 3 │      │ + │ │
│  └──┘      └───┘      └──┘ │
│                             │
│  Total: 4,500 units         │
└─────────────────────────────┘
```

**Behavior:**
- `[−]` button: Decrement estimated trips (min: 1)
- `[+]` button: Increment estimated trips (max: configurable, default: 100)
- Disable `[−]` when estimated trips = 1
- Disable `[+]` when estimated trips = max
- Real-time calculation of total quantity
- **No capacity warnings** (vehicle not assigned yet)
- **Note:** These are estimated trips for quantity calculation, not actual scheduled trips

### Multiple Fixed Quantities Per Product

**Scenario:** Same product, different trip sizes in one order

**Example Order:**
```
Item 1: Red Bricks
  - 2 Trips × 1,500 = 3,000 units
  - For immediate delivery

Item 2: Red Bricks (same product)
  - 1 Trip × 2,500 = 2,500 units
  - For next week delivery
```

**Implementation:**
- Allow adding same product multiple times
- Each instance can have different:
  - Fixed quantity per trip
  - Number of trips
- Treated as separate line items
- Can be edited/removed independently

**Use Cases:**
- Different delivery dates
- Different vehicle assignments
- Different pricing (if zone changes)
- Partial orders

## Questions to Consider

1. **Order Number Format:** Do you prefer `ORD-2024-001` or another format?
2. **Trip Input:** Increment/decrement buttons (as discussed) ✅
3. **Vehicle Capacity Validation:** Soft validation (warning only) ✅
4. **Product-Specific Fixed Quantities:** Yes, stored in product schema ✅
5. **Multiple Fixed Quantities Per Product:** Yes, can add same product multiple times ✅
6. **Multiple Zones:** Can an order have items delivered to different zones?
7. **Order Editing:** Should pending orders be editable after creation?
8. **Payment Tracking:** Do you need payment status/amount fields?

---

## Estimated Delivery Date Calculation

### Function: Calculate Estimated Delivery

**Purpose:** When an order is placed, simulate trip scheduling to estimate delivery date based on:
1. Other pending orders in the same delivery zone
2. Vehicle capacity and weekly capacity constraints
3. Order priority (affects scheduling order)
4. Trip-based distribution across vehicles and days

### Algorithm: Simulated Trip Scheduling

**Concept:** Instead of simple quantity-based calculation, we simulate how trips would actually be scheduled across vehicles and days, considering:
- Vehicle capacity matching order trip sizes
- Weekly capacity limits per vehicle per day
- Priority-based scheduling order
- Trip distribution logic

```dart
Future<DateTime> calculateEstimatedDelivery({
  required String organizationId,
  required String zoneId,
  required OrderPriority priority,
  required List<OrderItem> items,  // Changed: need trip details, not just quantity
  required DateTime orderDate,
}) async {
  // 1. Get all pending orders in the same zone (including this new order)
  final pendingOrders = await getPendingOrdersByZone(
    organizationId: organizationId,
    zoneId: zoneId,
    status: OrderStatus.pending,
  );
  
  // 2. Convert orders to trip-based structure
  final orderTrips = <OrderTrip>[];
  for (final order in pendingOrders) {
    for (final item in order.items) {
      // Create individual trips for each item
      for (int tripNum = 1; tripNum <= item.estimatedTrips; tripNum++) {
        orderTrips.add(OrderTrip(
          orderId: order.id,
          orderPriority: order.priority,
          orderCreatedAt: order.createdAt,
          productId: item.productId,
          tripQuantity: item.fixedQuantityPerTrip,
          tripNumber: tripNum,
        ));
      }
    }
  }
  
  // 3. Sort trips by priority and creation date
  orderTrips.sort((a, b) {
    final priorityOrder = {
      OrderPriority.urgent: 0,
      OrderPriority.high: 1,
      OrderPriority.normal: 2,
      OrderPriority.low: 3,
    };
    final priorityDiff = priorityOrder[a.orderPriority]! - priorityOrder[b.orderPriority]!;
    if (priorityDiff != 0) return priorityDiff;
    return a.orderCreatedAt.compareTo(b.orderCreatedAt);
  });
  
  // 4. Get available active vehicles for the zone
  final availableVehicles = await getActiveVehiclesForZone(
    organizationId: organizationId,
    zoneId: zoneId,
  );
  
  if (availableVehicles.isEmpty) {
    // No vehicles available - return default estimate
    return orderDate.add(const Duration(days: 7));
  }
  
  // 5. Calculate effective vehicle capacity
  // Priority: product-specific capacity > general capacity
  double getEffectiveCapacity(Vehicle vehicle, String? productId) {
    if (productId != null && vehicle.productCapacities != null) {
      final productCapacity = vehicle.productCapacities![productId];
      if (productCapacity != null) return productCapacity;
    }
    return vehicle.vehicleCapacity ?? 3000; // Default: 3000 units
  }
  
  // 6. Simulate trip scheduling day by day
  final schedule = <String, Map<String, List<OrderTrip>>>{}; // day -> vehicleId -> trips
  int currentDayOffset = 0;
  DateTime currentDate = orderDate;
  
  // Find which trip index this new order starts at
  int newOrderStartIndex = -1;
  for (int i = 0; i < orderTrips.length; i++) {
    if (orderTrips[i].orderCreatedAt.isAfter(orderDate.subtract(const Duration(seconds: 1)))) {
      newOrderStartIndex = i;
      break;
    }
  }
  
  // 7. Schedule trips day by day
  int tripIndex = 0;
  while (tripIndex < orderTrips.length) {
    final dayKey = _formatDate(currentDate);
    schedule[dayKey] = {};
    
    // Initialize schedule for each vehicle for this day
    for (final vehicle in availableVehicles) {
      schedule[dayKey]![vehicle.id] = [];
    }
    
    // Schedule trips for this day
    for (final vehicle in availableVehicles) {
      final dayOfWeek = currentDate.weekday; // 1 = Monday, 7 = Sunday
      final weeklyCapacity = vehicle.weeklyCapacity?[dayOfWeek.toString()];
      final maxTripsForDay = weeklyCapacity?.toInt() ?? 999; // No limit if not specified
      
      final vehicleTrips = schedule[dayKey]![vehicle.id]!;
      final vehicleCapacity = getEffectiveCapacity(vehicle, null);
      
      // Fill vehicle for this day up to weekly capacity limit
      while (vehicleTrips.length < maxTripsForDay && tripIndex < orderTrips.length) {
        final trip = orderTrips[tripIndex];
        final tripQuantity = trip.tripQuantity;
        
        // Check if this trip can fit in this vehicle
        // For estimation, we check if trip quantity <= vehicle capacity
        if (tripQuantity <= vehicleCapacity) {
          vehicleTrips.add(trip);
          tripIndex++;
          
          // If this is the new order's trip, track when it gets scheduled
          if (tripIndex - 1 == newOrderStartIndex) {
            // This is the first trip of the new order
            // Continue scheduling to find when all trips are scheduled
          }
        } else {
          // Trip too large for this vehicle, try next vehicle
          break;
        }
      }
    }
    
    // Move to next day if there are unscheduled trips
    if (tripIndex < orderTrips.length) {
      currentDayOffset++;
      currentDate = orderDate.add(Duration(days: currentDayOffset));
    } else {
      break;
    }
  }
  
  // 8. Find when the new order's last trip is scheduled
  DateTime? lastTripDate;
  for (final dayEntry in schedule.entries) {
    final dayDate = _parseDate(dayEntry.key);
    for (final vehicleTrips in dayEntry.value.values) {
      for (final trip in vehicleTrips) {
        if (trip.orderCreatedAt.isAfter(orderDate.subtract(const Duration(seconds: 1)))) {
          if (lastTripDate == null || dayDate.isAfter(lastTripDate)) {
            lastTripDate = dayDate;
          }
        }
      }
    }
  }
  
  // 9. Add delivery time (typically same day or next day)
  final deliveryDays = lastTripDate != null 
      ? lastTripDate.difference(orderDate).inDays + 1
      : 7; // Default fallback
  
  return orderDate.add(Duration(days: deliveryDays));
}

// Helper class for trip simulation
class OrderTrip {
  final String orderId;
  final OrderPriority orderPriority;
  final DateTime orderCreatedAt;
  final String productId;
  final int tripQuantity;
  final int tripNumber;
  
  OrderTrip({
    required this.orderId,
    required this.orderPriority,
    required this.orderCreatedAt,
    required this.productId,
    required this.tripQuantity,
    required this.tripNumber,
  });
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _parseDate(String dateStr) {
  final parts = dateStr.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}
```

### Implementation Details

**Collection Queries:**
```dart
// Get pending orders in same zone
Future<List<PendingOrder>> getPendingOrdersByZone({
  required String organizationId,
  required String zoneId,
  required OrderStatus status,
}) async {
  return await firestore
      .collection('ORGANIZATIONS')
      .doc(organizationId)
      .collection('PENDING_ORDERS')
      .where('deliveryZone.zoneId', isEqualTo: zoneId)
      .where('status', isEqualTo: status.name)
      .orderBy('createdAt', descending: false)
      .get()
      .then((snapshot) => snapshot.docs
          .map((doc) => PendingOrder.fromJson(doc.data(), doc.id))
          .toList());
}
```

**Zone Settings (Optional):**
```typescript
// ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}
{
  // ... existing zone fields ...
  typicalDeliveryDays?: number;        // Typical days per trip for this zone
  averageVehicleCapacity?: number;     // Average vehicle capacity for this zone
}
```

### UI Display

**In Create Order Page:**
```
Estimated Delivery:
📅 Jan 20, 2024 (3 days)

Based on:
• 5 pending orders in this zone
• Normal priority
• Average 1 day per trip
```

**Real-time Updates:**
- Updates when priority changes
- Updates when zone changes
- Shows calculation details on tap (optional)

---

## Summary

This design provides:
- ✅ **Trip-equivalent quantity input** (convenient way to calculate quantities)
- ✅ **Two-phase workflow** (Order Creation → Trip Scheduling)
- ✅ **Universal order system** (works for any industry)
- ✅ **Product-specific fixed quantities** (stored in product schema)
- ✅ **Optional GST** (supports products with and without GST)
- ✅ **Zone-based pricing** (different prices per delivery zone)
- ✅ **Accurate pricing calculation** (per-product GST, trip-based quantities)
- ✅ **Multi-product support** (multiple products per order)
- ✅ **Vehicle capacity validation** (soft validation with warnings)
- ✅ **Scheduled trips collection** (ready for trip scheduling feature)
- ✅ **Extensible schema** (optional fields for future features)
- ✅ **Clear 3-section UI flow** (Products → Delivery → Summary)

### Key Features:

1. **Trip-Equivalent Input Format:**
   - "3 Trips × 1,500 = 4,500 units" (for quantity calculation)
   - Uses +/- buttons for trip input
   - Not actual scheduled trips (those come later)

2. **Order Creation Phase:**
   - User creates order with quantities
   - Order stored in `PENDING_ORDERS` with status `pending`
   - No vehicle assignment at this stage

3. **Trip Scheduling Phase (Future):**
   - Orders are scheduled to actual vehicle trips
   - Trips stored in `SCHEDULED_TRIPS` collection
   - Orders linked to trips via `scheduledTripIds`
   - Vehicle assignment happens at trip level, not order level

4. **Product-Specific Fixed Quantities:**
   - Each product can define its own `fixedQuantityPerTripOptions`
   - Falls back to organization defaults if not specified

5. **Optional GST:**
   - Products can have GST or not
   - Mixed orders supported (some items with GST, some without)

6. **Vehicle Capacity Validation:**
   - Soft validation (warnings only)
   - Doesn't block order creation
   - Helps users understand capacity constraints

### Workflow Clarification:

**Order Creation:**
- Input: "3 Trips × 1,500" → Calculates: 4,500 units
- Stores: `estimatedTrips: 3`, `fixedQuantityPerTrip: 1500`, `totalQuantity: 4500`
- Status: `pending`
- **No vehicle assignment yet**

**Trip Scheduling (Later):**
- System/admin selects pending orders
- Groups by zone and assigns to vehicles
- Creates actual `SCHEDULED_TRIPS` documents
- Updates orders with `scheduledTripIds`
- **Vehicle assignment happens here**

The schema is ready for implementation and can be extended as needed for future requirements.

