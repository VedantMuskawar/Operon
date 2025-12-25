# Create Order Page - Pre-Build Checklist

## ✅ What Already Exists

### 1. **Repositories & Data Sources**
- ✅ `ProductsRepository` - Can fetch products
- ✅ `DeliveryZonesRepository` - Can fetch cities and zones
- ✅ `VehiclesRepository` - Can fetch vehicles
- ✅ `ClientsRepository` - Can fetch clients
- ✅ All data sources are implemented

### 2. **Entities/Models**
- ✅ `OrganizationProduct` - Product model exists
- ✅ `DeliveryZone` - Zone model exists
- ✅ `DeliveryCity` - City model exists
- ✅ `Vehicle` - Vehicle model exists (with `vehicleCapacity`, `weeklyCapacity`, `productCapacities`)
- ✅ `ClientRecord` - Client model exists

### 3. **Infrastructure**
- ✅ Firebase setup (Firestore, Auth)
- ✅ Organization context (`OrgContextCubit`)
- ✅ BLoC pattern setup
- ✅ Navigation (GoRouter)
- ✅ UI components (`PageWorkspaceLayout`)

### 4. **Existing Pages**
- ✅ `CreateOrderPage` - Empty placeholder exists
- ✅ `SelectCustomerPage` - For existing customer selection
- ✅ `ContactPage` - For new customer creation

---

## ❌ What Needs to Be Created

### 1. **Order Domain Models** (Priority: HIGH)

**Location:** `lib/domain/entities/`

Create these files:
- [ ] `pending_order.dart` - Main order entity
- [ ] `order_item.dart` - Order line item
- [ ] `order_pricing.dart` - Pricing summary
- [ ] `delivery_zone_selection.dart` - Selected zone info
- [ ] `order_settings.dart` - Organization order settings

**Key Fields to Include:**
- `PaymentType` enum (payLater, payOnDelivery)
- `PaymentMode` enum (cash, upi, bankTransfer, cheque, other)
- `OrderPriority` enum (low, normal, high, urgent)
- `OrderStatus` enum (pending, scheduled, etc.)

### 2. **Order Data Source** (Priority: HIGH)

**Location:** `lib/data/datasources/`

Create:
- [ ] `pending_orders_data_source.dart`
  - Methods needed:
    - `createOrder(String orgId, PendingOrder order)`
    - `fetchPendingOrders(String orgId, {String? zoneId})`
    - `getPendingOrdersByZone(String orgId, String zoneId)`
    - `generateOrderNumber(String orgId)`
    - `calculateEstimatedDelivery(...)` - Complex function

### 3. **Order Repository** (Priority: HIGH)

**Location:** `lib/data/repositories/`

Create:
- [ ] `pending_orders_repository.dart`
  - Wraps `PendingOrdersDataSource`
  - Provides clean interface for BLoC

### 4. **Order Settings Data Source** (Priority: MEDIUM)

**Location:** `lib/data/datasources/`

Create:
- [ ] `order_settings_data_source.dart`
  - `fetchOrderSettings(String orgId)`
  - `updateOrderSettings(String orgId, OrderSettings settings)`

### 5. **Create Order BLoC** (Priority: HIGH)

**Location:** `lib/presentation/blocs/create_order/`

Create:
- [ ] `create_order_cubit.dart`
- [ ] `create_order_state.dart`
- [ ] `create_order_event.dart`

**State should include:**
- Products list
- Selected items
- Cities and zones
- Selected zone
- Pricing
- Payment info
- Priority
- Estimated delivery date
- Loading states

### 6. **Update Product Model** (Priority: HIGH)

**File:** `lib/domain/entities/organization_product.dart`

**Add:**
- [ ] `fixedQuantityPerTripOptions` field (List<int>?)
- [ ] Make `gstPercent` nullable (double?)
- [ ] Update `fromJson` and `toJson` methods

### 7. **Estimated Delivery Service** (Priority: HIGH)

**Location:** `lib/data/services/`

Create:
- [ ] `estimated_delivery_service.dart`
  - Complex function to simulate trip scheduling
  - Needs access to:
    - Pending orders
    - Vehicles
    - Order settings
  - Returns estimated delivery date

### 8. **UI Components** (Priority: MEDIUM)

**Location:** `lib/presentation/views/orders/`

Create:
- [ ] `create_order_page.dart` - Main page (update existing)
- [ ] `product_selection_section.dart` - Section 1
- [ ] `delivery_zone_section.dart` - Section 2
- [ ] `order_summary_section.dart` - Section 3
- [ ] `order_item_tile.dart` - Item in list
- [ ] `trip_quantity_selector.dart` - +/- buttons widget
- [ ] `payment_section.dart` - Payment type and advance
- [ ] `priority_selector.dart` - Priority dropdown
- [ ] `estimated_delivery_display.dart` - Delivery date widget

### 9. **Firebase Collections Setup** (Priority: HIGH)

**Verify/Setup in Firebase Console:**
- [ ] `ORGANIZATIONS/{orgId}/PENDING_ORDERS` collection
- [ ] `ORGANIZATIONS/{orgId}/ORDER_SETTINGS` document
- [ ] Firestore indexes:
  - `organizationId` + `status` + `createdAt`
  - `organizationId` + `deliveryZone.zoneId` + `status`
  - `organizationId` + `clientId` + `createdAt`

### 10. **Product Schema Update** (Priority: MEDIUM)

**In Firebase:**
- [ ] Verify products can have `fixedQuantityPerTripOptions` field
- [ ] Verify `gstPercent` can be null
- [ ] Add sample data if needed

### 11. **Order Settings Document** (Priority: MEDIUM)

**Create in Firebase:**
- [ ] `ORGANIZATIONS/{orgId}/ORDER_SETTINGS` document
  - `defaultFixedQuantityPerTripOptions: [1000, 1500, 2000, 2500, 3000, 4000]`
  - `minTrips: 1`
  - `maxTrips: 100`
  - `enableVehicleCapacityCheck: true`
  - `defaultVehicleCapacity: 3000`

### 12. **Dependencies Check** (Priority: LOW)

**Verify in `pubspec.yaml`:**
- ✅ `flutter_bloc` - Already installed
- ✅ `cloud_firestore` - Already installed
- ✅ `go_router` - Already installed
- ✅ All core packages - Already installed

### 13. **Navigation Setup** (Priority: MEDIUM)

**File:** `lib/config/app_router.dart`

- [ ] Verify `CreateOrderPage` route exists
- [ ] Ensure route accepts `ClientRecord?` parameter
- [ ] Test navigation from:
  - `SelectCustomerPage` → `CreateOrderPage`
  - `ContactPage` → `CreateOrderPage`

### 14. **Organization Context** (Priority: HIGH)

**Verify:**
- [ ] `OrgContextCubit` provides current `organizationId`
- [ ] Can access organization context in Create Order page
- [ ] User ID is accessible for `createdBy` field

---

## 🔍 Things to Verify Before Building

### 1. **Product Data Structure**
- [ ] Check if products in Firebase have the new fields
- [ ] Verify product fetching works
- [ ] Test with products that have/don't have `fixedQuantityPerTripOptions`

### 2. **Delivery Zones**
- [ ] Verify zones exist in Firebase
- [ ] Check zone pricing structure
- [ ] Test zone filtering by city

### 3. **Vehicles**
- [ ] Verify vehicles exist with capacity data
- [ ] Check `weeklyCapacity` structure (Map<String, double>)
- [ ] Verify `productCapacities` structure

### 4. **Client Selection Flow**
- [ ] Test `SelectCustomerPage` navigation
- [ ] Verify client data is passed correctly
- [ ] Test new client creation flow

### 5. **Order Number Generation**
- [ ] Design order number format (e.g., `ORD-2024-001`)
- [ ] Implement generation logic
- [ ] Handle year rollover

---

## 📋 Implementation Order (Recommended)

1. **Phase 1: Domain Models** (Day 1)
   - Create all entity models
   - Update `OrganizationProduct` model
   - Test model serialization

2. **Phase 2: Data Layer** (Day 1-2)
   - Create data sources
   - Create repositories
   - Implement estimated delivery service
   - Test Firebase operations

3. **Phase 3: BLoC** (Day 2)
   - Create `CreateOrderCubit`
   - Implement state management
   - Test business logic

4. **Phase 4: UI Components** (Day 3-4)
   - Build Section 1 (Products)
   - Build Section 2 (Delivery)
   - Build Section 3 (Summary)
   - Integrate with BLoC

5. **Phase 5: Integration** (Day 4-5)
   - Connect all sections
   - Test complete flow
   - Handle edge cases
   - Add error handling

6. **Phase 6: Polish** (Day 5)
   - UI/UX improvements
   - Loading states
   - Error messages
   - Validation

---

## 🚨 Critical Dependencies

Before starting, ensure:
1. ✅ Firebase project is configured
2. ✅ Organization context is working
3. ✅ User authentication is working
4. ✅ At least one organization exists
5. ✅ At least one product exists
6. ✅ At least one delivery zone exists
7. ✅ At least one vehicle exists (for delivery estimation)

---

## 📝 Notes

- The estimated delivery calculation is complex - consider implementing it incrementally
- Start with simple quantity-based estimation, then add trip scheduling simulation
- Test with real data from Firebase
- Consider adding unit tests for business logic
- Document any deviations from the design document

---

## ✅ Ready to Build Checklist

Before starting implementation, ensure:
- [ ] All domain models are created
- [ ] Data sources are implemented
- [ ] Repositories are set up
- [ ] BLoC structure is ready
- [ ] Firebase collections are configured
- [ ] Test data exists in Firebase
- [ ] Organization context is accessible
- [ ] Navigation routes are set up

---

**Last Updated:** Based on design document `ORDER_FLOW_AND_SCHEMA_DESIGN.md`

