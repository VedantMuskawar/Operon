# Pending Orders Schema Reanalysis

## Overview

This document reanalyzes the `PENDING_ORDERS` database schema and Cloud Functions based on the actual implementation of the Create Order page. It identifies gaps, inconsistencies, and recommendations for alignment.

---

## Current UI Implementation Analysis

### Section 1: Product Selection
**Fields Collected:**
- Product ID and Name (from dropdown)
- Fixed Quantity Per Trip (from product-specific or org defaults)
- Number of Trips (user input)
- Total Quantity (calculated: trips × fixedQuantityPerTrip)
- Unit Price (from zone pricing in Section 2)

**State Management:**
- Stored in `CreateOrderCubit.state.selectedItems` (List<OrderItem>)
- Each `OrderItem` includes: productId, productName, estimatedTrips, fixedQuantityPerTrip, unitPrice, gstPercent

### Section 2: Delivery Zone Selection
**Fields Collected:**
- City (from dropdown)
- Region/Zone (from dropdown, depends on city)
- Zone ID (for pricing lookup)
- Unit Prices per Product (from zone pricing, editable but display-only)

**State Management:**
- Stored in `CreateOrderCubit.state.selectedCity`, `selectedZoneId`
- Zone prices stored in `CreateOrderCubit.state.zonePrices` (Map<String, double>)

### Section 3: Order Summary
**Fields Collected:**
1. **Payment Type:**
   - Options: `'pay_later'` or `'pay_on_delivery'`
   - Stored as: `String _paymentType`

2. **Advance Payment:**
   - Checkbox: `bool _hasAdvancePayment`
   - Amount: `TextEditingController _advanceAmountController` (String, needs parsing)
   - Payment Account: `String? _selectedPaymentAccountId`
     - Can be: `'cash'` or a PaymentAccount ID from database
     - **Note:** UI stores PaymentAccount ID, not PaymentMode enum

3. **Priority:**
   - Options: `'normal'` or `'high'` (only 2 options in UI)
   - Stored as: `String _priority`
   - **Note:** Schema supports 4 options: `low`, `normal`, `high`, `urgent`
   - **UI Limitation:** Only shows "Normal" (Silver) and "Priority" (Gold)

4. **GST Inclusion:**
   - Checkbox: `bool _includeGst` (default: true)
   - **Note:** This is a UI toggle that affects calculation display
   - Individual items may or may not have GST based on product settings

5. **Client Information:**
   - Passed to `CreateOrderPage` as `ClientRecord? client`
   - **Need to verify:** What fields from ClientRecord are available?

---

## Schema Comparison & Gaps

### ✅ Fields That Match

| Schema Field | UI Field | Status |
|-------------|----------|--------|
| `items` | `selectedItems` | ✅ Match |
| `deliveryZone.zoneId` | `selectedZoneId` | ✅ Match |
| `deliveryZone.city` | `selectedCity` | ✅ Match |
| `deliveryZone.region` | Region name from zone | ✅ Match |
| `pricing.subtotal` | Calculated from items | ✅ Match |
| `pricing.totalGst` | Calculated (if `_includeGst` is true) | ✅ Match |
| `pricing.totalAmount` | Calculated | ✅ Match |
| `paymentType` | `_paymentType` | ✅ Match (values: `pay_later`, `pay_on_delivery`) |
| `advanceAmount` | `_advanceAmountController.text` | ⚠️ Needs parsing to double |
| `priority` | `_priority` | ⚠️ UI only has 2 options, schema has 4 |

### ⚠️ Fields That Need Adjustment

#### 1. **Advance Payment Mode**

**Current Schema:**
```typescript
advancePaymentMode?: string;  // "cash" | "upi" | "bank_transfer" | "cheque" | "other"
```

**Current UI:**
- Stores: `String? _selectedPaymentAccountId`
- Can be: `'cash'` or a PaymentAccount ID

**Issue:**
- UI stores PaymentAccount ID, but schema expects PaymentMode enum
- Need to map PaymentAccount ID to PaymentMode, or store both

**Recommendation:**
```typescript
// Option 1: Store both (Recommended)
advancePaymentAccountId?: string;  // PaymentAccount ID (if from database)
advancePaymentMode?: string;        // "cash" | "upi" | "bank_transfer" | "cheque" | "other"

// Option 2: Store only PaymentAccount ID and derive mode
advancePaymentAccountId?: string;  // "cash" or PaymentAccount ID
// Derive mode from PaymentAccount.type when reading
```

**Recommended Schema Update:**
```typescript
{
  advanceAmount?: number;
  advancePaymentAccountId?: string;  // "cash" or PaymentAccount ID
  advancePaymentMode?: string;        // Derived from PaymentAccount.type or "cash"
}
```

#### 2. **Priority Field**

**Current Schema:**
```typescript
priority: string;  // "low" | "normal" | "high" | "urgent"
```

**Current UI:**
- Only 2 options: `'normal'` or `'high'`
- UI labels: "Normal" (Silver) and "Priority" (Gold)

**Issue:**
- Schema supports 4 levels, UI only 2
- UI uses "Priority" label but stores `'high'` value

**Recommendation:**
- **Option A:** Keep UI as-is, default to `'normal'` for low priority, use `'high'` for priority
- **Option B:** Expand UI to support all 4 levels (future enhancement)
- **Current:** Use `'normal'` and `'high'` only, align schema to match UI

**Recommended Schema Update:**
```typescript
priority: string;  // "normal" | "high" (for now, can expand later)
// Or keep 4 options but UI only uses 2
```

#### 3. **GST Inclusion**

**Current Schema:**
- No explicit `includeGst` field
- GST is calculated per item based on `item.gstPercent`

**Current UI:**
- `bool _includeGst` toggle (default: true)
- When unchecked, GST is not included in total calculation

**Issue:**
- UI has a global GST toggle, but schema calculates GST per item
- If user unchecks "Include GST", should we:
  - A) Still store item-level GST but don't include in total?
  - B) Set all item GST to 0/null when unchecked?

**Recommendation:**
```typescript
// Option 1: Store the toggle state (Recommended)
includeGstInTotal: boolean;  // Whether GST is included in total calculation
// Items still have gstPercent, but totalGst = 0 if includeGstInTotal = false

// Option 2: Don't store toggle, always calculate from items
// Remove toggle from schema, handle in UI only
```

**Recommended Schema Update:**
```typescript
{
  // ... other fields ...
  includeGstInTotal: boolean;  // Default: true
  pricing: {
    subtotal: number;
    totalGst: number;  // 0 if includeGstInTotal = false
    totalAmount: number;
  };
}
```

#### 4. **Client Information**

**Current Schema:**
```typescript
clientId: string;
clientName: string;
clientPhone: string;
```

**Current UI:**
- Receives `ClientRecord? client` as parameter
- **Need to verify:** What fields are in ClientRecord?

**Recommendation:**
- Store snapshot of client info at order time
- Include: `clientId`, `clientName`, `clientPhone` (primary phone)
- **Optional:** Store full address if available

---

## Missing Fields Analysis

### Fields in Schema but Not in UI

1. **`orderNumber`** - Human-readable order number
   - **Status:** Not generated in UI
   - **Recommendation:** Generate in Cloud Function or backend
   - **Format:** `ORD-{YYYY}-{NNN}` (e.g., "ORD-2024-001")

2. **`deliveryAddress`** - Optional detailed address
   - **Status:** Not collected in UI
   - **Recommendation:** Add optional text field in Section 2 or 3

3. **`notes`** - Order notes/comments
   - **Status:** Not collected in UI
   - **Recommendation:** Add optional text field in Section 3

4. **`expectedDeliveryDate`** - Estimated delivery date
   - **Status:** Not calculated in UI
   - **Recommendation:** Calculate in Cloud Function based on algorithm (see schema doc)

5. **`remainingAmount`** - Calculated: totalAmount - advanceAmount
   - **Status:** Not calculated in UI
   - **Recommendation:** Calculate in Cloud Function or frontend before saving

### Fields in UI but Not in Schema

1. **`includeGstInTotal`** - GST inclusion toggle
   - **Status:** Exists in UI, not in schema
   - **Recommendation:** Add to schema (see above)

---

## Updated Schema Recommendation

### Collection: `PENDING_ORDERS`

**Location:** `PENDING_ORDERS/{orderId}` (Standalone collection)

**Document Structure:**
```typescript
{
  // Order Identification
  orderId: string;                    // Same as document ID
  orderNumber: string;                 // Generated: "ORD-{YYYY}-{NNN}"
  
  // Client Information
  clientId: string;                    // Reference to CLIENTS collection
  clientName: string;                  // Snapshot at order time
  clientPhone: string;                 // Primary phone number
  
  // Order Items
  items: Array<{
    productId: string;
    productName: string;
    estimatedTrips: number;            // User input: number of trips
    fixedQuantityPerTrip: number;      // From product or org defaults
    totalQuantity: number;             // Calculated: estimatedTrips × fixedQuantityPerTrip
    unitPrice: number;                 // From zone pricing
    gstPercent?: number;                // Optional - null if no GST
    subtotal: number;                  // Calculated: totalQuantity × unitPrice
    gstAmount: number;                 // Calculated: subtotal × (gstPercent / 100) or 0
    total: number;                     // Calculated: subtotal + gstAmount
  }>;
  
  // Delivery Information
  deliveryZone: {
    zoneId: string;                    // Reference to DELIVERY_ZONES
    city: string;                      // City name
    region: string;                    // Region name
  };
  deliveryAddress?: string;            // Optional detailed address (not in UI yet)
  
  // Pricing Summary
  pricing: {
    subtotal: number;                  // Sum of all item subtotals
    totalGst: number;                  // Sum of all GST amounts (0 if includeGstInTotal = false)
    totalAmount: number;               // Final total (subtotal + totalGst)
    currency: string;                   // Default: "INR"
  };
  
  // GST Inclusion
  includeGstInTotal: boolean;          // Whether GST is included in total (default: true)
  
  // Payment Information
  paymentType: string;                 // "pay_later" | "pay_on_delivery"
  advanceAmount?: number;              // Advance payment amount (if any)
  advancePaymentAccountId?: string;    // "cash" or PaymentAccount ID
  advancePaymentMode?: string;         // "cash" | "upi" | "bank_transfer" | "cheque" | "other" (derived)
  remainingAmount?: number;            // Calculated: totalAmount - advanceAmount
  
  // Order Priority
  priority: string;                     // "normal" | "high" (UI only supports 2, schema can support 4)
  
  // Order Status
  status: string;                      // "pending" | "confirmed" | "dispatched" | "delivered" | "cancelled"
  
  // Metadata
  organizationId: string;               // Organization reference
  createdBy: string;                    // User ID who created the order
  createdAt: Timestamp;                 // Order creation timestamp
  updatedAt: Timestamp;                 // Last update timestamp
  
  // Optional Fields
  expectedDeliveryDate?: Timestamp;    // Expected delivery date (calculated by Cloud Function)
  
  // Trip Scheduling (added after order creation)
  scheduledTripIds?: string[];          // Array of SCHEDULED_TRIPS IDs
  scheduledQuantity?: number;          // Total quantity scheduled
  unscheduledQuantity?: number;         // Remaining quantity not yet scheduled
}
```

---

## Cloud Functions Recommendations

### 1. **Order Creation Function**

**Function Name:** `onPendingOrderCreated`

**Trigger:** `PENDING_ORDERS` document created

**Responsibilities:**
1. Generate `orderNumber` (format: `ORD-{YYYY}-{NNN}`)
2. Calculate `remainingAmount` = `totalAmount - advanceAmount` (if advance given)
3. Calculate `expectedDeliveryDate` using estimated delivery algorithm
4. Validate required fields
5. Update client analytics (if needed)
6. Send notifications (if needed)

**Example:**
```typescript
exports.onPendingOrderCreated = functions.firestore
  .document('PENDING_ORDERS/{orderId}')
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const { orderId } = context.params;
    const orgId = orderData.organizationId; // Get orgId from document data
    
    // 1. Generate order number
    const orderNumber = await generateOrderNumber(orgId);
    
    // 2. Calculate remaining amount
    const remainingAmount = orderData.pricing.totalAmount - (orderData.advanceAmount || 0);
    
    // 3. Calculate expected delivery date
    const expectedDeliveryDate = await calculateExpectedDeliveryDate(orgId, orderData);
    
    // 4. Derive advance payment mode from account ID
    let advancePaymentMode = null;
    if (orderData.advancePaymentAccountId && orderData.advancePaymentAccountId !== 'cash') {
      const account = await getPaymentAccount(orgId, orderData.advancePaymentAccountId);
      advancePaymentMode = account?.type || 'cash';
    } else if (orderData.advancePaymentAccountId === 'cash') {
      advancePaymentMode = 'cash';
    }
    
    // 5. Update order with calculated fields
    await snap.ref.update({
      orderNumber,
      remainingAmount,
      expectedDeliveryDate,
      advancePaymentMode,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // 6. Update client analytics (optional)
    // await updateClientOrderCount(orgId, orderData.clientId);
    
    return null;
  });
```

### 2. **Order Number Generation**

**Function:** `generateOrderNumber(orgId: string): Promise<string>`

**Logic:**
1. Get current year
2. Query `PENDING_ORDERS` for orders in current year
3. Find highest order number sequence
4. Generate next number: `ORD-{YYYY}-{NNN}` (e.g., "ORD-2024-001")

**Example:**
```typescript
async function generateOrderNumber(orgId: string): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `ORD-${year}-`;
  
  const ordersRef = admin.firestore()
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('PENDING_ORDERS');
  
  const snapshot = await ordersRef
    .where('orderNumber', '>=', prefix)
    .where('orderNumber', '<', prefix.replace(/\d+$/, 'Z'))
    .orderBy('orderNumber', 'desc')
    .limit(1)
    .get();
  
  let nextNumber = 1;
  if (!snapshot.empty) {
    const lastOrderNumber = snapshot.docs[0].data().orderNumber;
    const lastSequence = parseInt(lastOrderNumber.split('-')[2], 10);
    nextNumber = lastSequence + 1;
  }
  
  return `${prefix}${String(nextNumber).padStart(3, '0')}`;
}
```

### 3. **Expected Delivery Date Calculation**

**Function:** `calculateExpectedDeliveryDate(orgId: string, orderData: any): Promise<Timestamp>`

**Logic:**
- Use the algorithm described in `ORDER_FLOW_AND_SCHEMA_DESIGN.md`
- Simulate trip scheduling based on:
  - Existing pending orders
  - Order priority
  - Vehicle capacities
  - Weekly capacity constraints

**Note:** This is a complex algorithm - see the detailed algorithm in the schema document.

---

## Data Model Updates (Dart)

### Updated PendingOrder Model

```dart
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
    this.advancePaymentAccountId,  // NEW: Store account ID
    this.advancePaymentMode,        // Derived from account
    this.remainingAmount,
    this.includeGstInTotal = true,  // NEW: GST inclusion toggle
    this.priority = OrderPriority.normal,
    this.scheduledTripIds,
    this.scheduledQuantity,
    this.unscheduledQuantity,
  });

  // ... existing fields ...
  
  final String? advancePaymentAccountId;  // NEW
  final String? advancePaymentMode;        // Derived
  final bool includeGstInTotal;           // NEW

  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'includeGstInTotal': includeGstInTotal,
      if (advancePaymentAccountId != null) 
        'advancePaymentAccountId': advancePaymentAccountId,
      if (advancePaymentMode != null) 
        'advancePaymentMode': advancePaymentMode,
      // ... rest of fields ...
    };
  }
}
```

---

## Action Items

### Immediate (Before Order Creation Implementation)

1. ✅ **Update Schema Document** - Add `includeGstInTotal` and `advancePaymentAccountId` fields
2. ✅ **Update PendingOrder Model** - Add new fields to Dart model
3. ✅ **Create Order Creation Function** - Implement `onPendingOrderCreated` Cloud Function
4. ✅ **Implement Order Number Generation** - Add function to generate order numbers
5. ⚠️ **Priority Field Alignment** - Decide: keep 4 options in schema or align to 2 in UI

### Future Enhancements

1. **Add Delivery Address Field** - Optional text field in Section 2 or 3
2. **Add Notes Field** - Optional text field in Section 3
3. **Expand Priority Options** - Add "Low" and "Urgent" to UI if needed
4. **Expected Delivery Date** - Implement calculation algorithm in Cloud Function
5. **Client Analytics** - Update client order count and analytics on order creation

---

## Summary

### Key Changes Needed:

1. **Add `includeGstInTotal` field** - To track GST inclusion toggle state
2. **Add `advancePaymentAccountId` field** - To store PaymentAccount ID or "cash"
3. **Keep `advancePaymentMode`** - Derived from PaymentAccount.type or "cash"
4. **Align Priority** - UI uses 2 options, schema can support 4 (keep flexibility)
5. **Generate `orderNumber`** - In Cloud Function, not frontend
6. **Calculate `remainingAmount`** - In Cloud Function or frontend before save
7. **Calculate `expectedDeliveryDate`** - In Cloud Function using algorithm

### Schema is Mostly Aligned:

- ✅ Product items structure matches
- ✅ Delivery zone structure matches
- ✅ Pricing structure matches
- ✅ Payment type matches
- ✅ Client information matches
- ✅ Status and metadata fields match

The main gaps are:
- GST inclusion toggle (needs schema field)
- Advance payment account ID (needs schema field)
- Order number generation (needs Cloud Function)
- Remaining amount calculation (needs Cloud Function)
- Expected delivery date calculation (needs Cloud Function)

