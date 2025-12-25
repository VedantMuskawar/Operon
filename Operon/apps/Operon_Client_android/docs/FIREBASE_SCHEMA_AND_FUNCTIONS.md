# Firebase Data Schema and Functions Documentation

## Scheduling/Delivery Data Pipeline (Simplified)

These three collections form a pipeline:
- **PENDING_ORDERS**: source of truth for demand (client snapshot, items/quantities, totals).
- **SCHEDULE_TRIPS**: execution plan for an order (vehicle/slot/day, trip-level items/pricing).
- **DELIVERY_MEMOS**: proof/log for a trip (snapshot from the trip).

Key dependencies:
- Trip creation/deletion **must** update the order’s remaining trips/quantities and scheduledTrips list.
- Delivery memo generation **reads** the trip (client/order/vehicle/slot/items) and writes a snapshot; optionally writes `dmId/dmNumber` back to the trip.
- IDs/joins: `orderId` links trips → orders; `tripId` links DMs → trips. Client data is snapshot-copied at order creation and reused downstream.
- Prevent double-booking: vehicle+slot+date must be unique when creating trips.
- Totals: keep order-level totals as the source of truth; trips/DMs store only trip-level slices (`tripPricing`).

### Lean Schemas (recommended going forward)

**PENDING_ORDERS**
- Identity: `orderId`, `orderNumber`
- Client snapshot: `clientId`, `clientName`, `clientPhone` (E.164)
- Items: `productId`, `productName`, `estimatedTrips`, `fixedQuantityPerTrip`, `totalQuantity`, `unitPrice`, `gstPercent?`, `subtotal`, `gstAmount`, `lineTotal`
- Delivery: `zoneId`, `city`, `region`, optional `deliveryAddress`
- Pricing: `subtotal`, `totalGst`, `totalAmount`, `currency`, `includeGstInTotal`
- Payment: `paymentType`, `advanceAmount?`, `advancePaymentAccountId?`, `advancePaymentMode?`, `remainingAmount?`
- Priority/status: `priority ("normal"/"high")`, `status ("pending"/"confirmed"/"dispatched"/"delivered"/"cancelled")`
- Org/meta: `organizationId`, `createdBy`, `createdAt`, `updatedAt`
- Scheduling counters: `scheduledTrips[] (light refs)`, `totalScheduledTrips`, `scheduledQuantity`, `unscheduledQuantity`
- Optional: `expectedDeliveryDate`, `notes`

**SCHEDULE_TRIPS**
- Identity: doc ID, `scheduleTripId` (human-readable)
- Links: `orderId`, `organizationId`, `clientId`, `clientName`, `clientPhone`
- Timing/vehicle: `scheduledDate`, `scheduledDay`, `vehicleId`, `vehicleNumber`, `slot`, `slotName`
- Driver: `driverId?`, `driverName?`, `driverPhone?`
- Zone: `deliveryZone`
- Items/pricing: trip `items`, `tripPricing` (subtotal, gstAmount, total); keep `pricing` from order only if needed for reference
- Priority/payment: `priority`, `paymentType`
- Status: `tripStatus` (scheduled|completed|cancelled|rescheduled)
- Meta: `createdAt`, `createdBy`, `updatedAt`
- Optional: `rescheduleReason`, `dmId`, `dmNumber`

**DELIVERY_MEMOS**
- Identity: `dmId`, `dmNumber`, `financialYear`
- Links: `scheduleTripId`, `tripId`, `organizationId`, `orderId`
- Client: `clientId`, `clientName`, `clientPhone`
- Trip: `scheduledDate`, `scheduledDay`, `vehicleId`, `vehicleNumber`, `slot`, `slotName`
- Driver: `driverId?`, `driverName?`, `driverPhone?`
- Zone: `deliveryZone`
- Items/pricing: `items`, `tripPricing` (trip subtotal/gst/total), optional `pricing` snapshot
- Status: `orderStatus` (e.g., pending|delivered|cancelled), `status` (active|cancelled)
- Meta: `generatedAt`, `generatedBy`, `updatedAt`

### Recommended constraints & checks
- On trip create: enforce uniqueness of `(scheduledDate, vehicleId, slot)`; block if order has no remaining trips/quantity.
- On trip delete/reschedule: increment remaining counts on the order; remove trip ref.
- On DM generate: ensure trip exists; write `dmId/dmNumber` back to the trip for reference.
- Normalize all phones to E.164.
- Use consistent enums for `priority`, `status`, `tripStatus`, `paymentType`.
- Indexes to keep:
  - Pending orders: `organizationId + createdAt desc`; optionally `status + organizationId + createdAt`.
  - Scheduled trips: `organizationId + scheduledDate + vehicleId + slot`; `organizationId + scheduledDate`; `organizationId + vehicleId + scheduledDate`.
  - Delivery memos: `organizationId + createdAt`; `financialYear + dmNumber` if querying by FY/sequence.

This document provides a comprehensive overview of the Firebase Firestore data schema and Cloud Functions used in the Dash Mobile application.

## Table of Contents

1. [Firestore Collections](#firestore-collections)
2. [Data Models](#data-models)
3. [Cloud Functions](#cloud-functions)
4. [Indexes and Queries](#indexes-and-queries)
5. [Security Rules](#security-rules)

---

## Firestore Collections

### Top-Level Collections

#### 1. `USERS`
Global user collection storing user profile information.

**Document Structure:**
```typescript
{
  name: string;                    // User's display name
  phone: string;                   // Phone number (E.164 format)
  uid?: string;                    // Firebase Auth UID (linked after authentication)
  superadmin?: boolean;            // Super admin flag
  createdAt: Timestamp;            // Creation timestamp
  updatedAt: Timestamp;            // Last update timestamp
  employee_id?: string;            // Optional employee ID reference
}
```

**Subcollections:**
- `ORGANIZATIONS/{orgId}` - User's organization memberships
  ```typescript
  {
    org_id: string;
    org_name: string;
    role_in_org: string;          // Role title (e.g., "Admin", "Manager")
    user_name: string;
    joined_at: Timestamp;
  }
  ```

**Key Queries:**
- Find user by phone: `where('phone', '==', phoneNumber)`
- Find user by employee ID: `where('employee_id', '==', employeeId)`

---

#### 2. `ORGANIZATIONS`
Organization/company master collection.

**Document Structure:**
```typescript
{
  org_id: string;                 // Same as document ID
  org_code: string;               // Unique organization code
  org_name: string;               // Organization name
  industry: string;               // Industry type
  gst_or_business_id?: string;    // Optional GST/Business ID
  created_at: Timestamp;
  created_by_user: string;         // User ID who created
}
```

**Subcollections:**
- `USERS` - Organization users
- `PRODUCTS` - Organization products
- `ROLES` - Organization roles
- `DELIVERY_ZONES` - Delivery zones
- `DELIVERY_CITIES` - Delivery cities
- `PAYMENT_ACCOUNTS` - Payment accounts
- `VEHICLES` - Organization vehicles

---

#### 3. `CLIENTS`
Global client/customer collection (shared across organizations).

**Document Structure:**
```typescript
{
  clientId: string;                // Same as document ID
  name: string;                   // Client name
  name_lowercase: string;         // Lowercase for case-insensitive search
  primaryPhone: string;            // Primary phone number
  primaryPhoneNormalized: string;  // Normalized phone (digits only)
  phones: Array<{                  // All phone numbers
    number: string;
    normalized: string;
  }>;
  phoneIndex: string[];           // Array of normalized phones for search
  tags: string[];                 // Client tags (e.g., "corporate")
  contacts: Array<{                // Additional contacts
    name: string;
    phone: string;
    normalized: string;
    description?: string;
  }>;
  organizationId?: string;         // Optional organization association
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- Search by name: `orderBy('name_lowercase').startAt(query).endAt(query + '\uf8ff')`
- Search by phone: `where('phoneIndex', 'array-contains', normalizedPhone)`
- Recent clients: `orderBy('createdAt', 'desc')`

**Required Indexes:**
- `name_lowercase` (ascending)
- `createdAt` (descending)
- `phoneIndex` (array-contains)
- `primaryPhoneNormalized` (equality)

---

#### 4. `EMPLOYEES`
Global employee collection.

**Document Structure:**
```typescript
{
  employeeId: string;             // Same as document ID
  employeeName: string;            // Employee name
  organizationId: string;           // Organization reference
  roleId: string;                  // Role ID reference
  roleTitle: string;               // Role title
  salaryType: string;              // "fixed" | "commission" | "hybrid"
  salaryAmount: number;            // Salary amount
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- By organization: `where('organizationId', '==', orgId).orderBy('employeeName')`

**Required Indexes:**
- `organizationId` (ascending) + `employeeName` (ascending)

---

#### 5. `ANALYTICS`
Analytics data collection for various metrics.

**Document Structure:**
```typescript
{
  source: string;                  // Source identifier (e.g., "clients")
  financialYear: string;           // FY label (e.g., "FY2425")
  generatedAt: Timestamp;         // Last generation timestamp
  metadata: {
    sourceCollections: string[];  // Source collections used
  };
  metrics: {
    activeClients: {
      type: "monthly";
      unit: "count";
      values: {                    // Key: "YYYY-MM", Value: number
        "2024-04": 10,
        "2024-05": 15,
        // ...
      };
    };
    userOnboarding: {
      type: "monthly";
      unit: "count";
      values: {                    // Key: "YYYY-MM", Value: number
        "2024-04": 5,
        "2024-05": 8,
        // ...
      };
    };
  };
}
```

**Document ID Format:** `{source}_{financialYear}` (e.g., `clients_FY2425`)

---

#### 6. `WHATSAPP_SETTINGS`
Organization-specific WhatsApp integration settings.

**Document Structure:**
```typescript
{
  enabled: boolean;                // Whether WhatsApp is enabled
  token: string;                   // WhatsApp API token
  phoneId: string;                 // WhatsApp Phone Number ID
  welcomeTemplateId?: string;      // Welcome message template ID
  languageCode?: string;           // Language code (default: "en")
}
```

**Document ID:** Organization ID

---

### Organization Subcollections

All organization subcollections are under `ORGANIZATIONS/{orgId}/...`

#### 1. `USERS`
Organization-specific user data.

**Document Structure:**
```typescript
{
  user_id: string;                 // Reference to USERS collection
  user_name: string;               // User name
  phone: string;                   // Phone number
  role_title: string;              // Role in organization
  role_id?: string;                // Role ID reference
  employee_id?: string;            // Employee ID reference
  org_name: string;                // Organization name
  created_at: Timestamp;
  updated_at: Timestamp;
  joined_at: Timestamp;
}
```

**Key Queries:**
- By name: `orderBy('user_name')`
- By employee ID: `where('employee_id', '==', employeeId)`

---

#### 2. `PRODUCTS`
Organization products catalog.

**Document Structure:**
```typescript
{
  productId: string;               // Same as document ID
  name: string;                    // Product name
  unitPrice: number;               // Unit price
  gstPercent: number;              // GST percentage
  status: string;                  // "active" | "paused" | "archived"
  stock: number;                   // Stock quantity
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- By name: `orderBy('name')`

---

#### 3. `ROLES`
Organization roles/permissions.

**Document Structure:**
```typescript
{
  roleId: string;                  // Same as document ID
  title: string;                   // Role title
  isAdmin: boolean;                // Admin flag
  permissions: {
    // Section access
    canAccessSection: {
      pendingOrders: boolean;
      scheduleOrders: boolean;
      ordersMap: boolean;
      analyticsDashboard: boolean;
    };
    // CRUD permissions
    canCreate: {
      products: boolean;
      employees: boolean;
      users: boolean;
      zonesCity: boolean;
      zonesRegion: boolean;
      zonesPrice: boolean;
    };
    canEdit: {
      products: boolean;
      employees: boolean;
      users: boolean;
      zonesCity: boolean;
      zonesRegion: boolean;
      zonesPrice: boolean;
    };
    canDelete: {
      products: boolean;
      employees: boolean;
      users: boolean;
      zonesCity: boolean;
      zonesRegion: boolean;
      zonesPrice: boolean;
    };
    // Page access
    canAccessPage: {
      vehicles: boolean;
    };
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- By title: `orderBy('title')`

---

#### 4. `DELIVERY_ZONES`
Delivery zones for the organization.

**Document Structure:**
```typescript
{
  zoneId: string;                  // Same as document ID
  city: string;                    // City name
  region: string;                  // Region/area name
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Subcollections:**
- `PRICES/{productId}` - Zone-specific product prices
  ```typescript
  {
    productId: string;             // Product ID
    price: number;                 // Price for this zone
  }
  ```

**Key Queries:**
- By city and region: `orderBy('city').orderBy('region')`

**Required Indexes:**
- `city` (ascending) + `region` (ascending)

---

#### 5. `DELIVERY_CITIES`
Cities available for delivery.

**Document Structure:**
```typescript
{
  name: string;                    // City name
  createdAt: Timestamp;
}
```

**Key Queries:**
- By name: `orderBy('name')`

---

#### 6. `PAYMENT_ACCOUNTS`
Payment accounts (UPI, bank accounts, etc.).

**Document Structure:**
```typescript
{
  accountId: string;               // Same as document ID
  name: string;                    // Account name
  type: string;                    // Account type (e.g., "UPI", "Bank")
  details: {
    upiId?: string;                // UPI ID
    accountNumber?: string;        // Bank account number
    ifscCode?: string;             // IFSC code
    bankName?: string;             // Bank name
    // ... other type-specific fields
  };
  isPrimary: boolean;              // Primary account flag
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- By name: `orderBy('name')`

---

#### 7. `VEHICLES`
Organization vehicles.

**Document Structure:**
```typescript
{
  vehicleId: string;               // Same as document ID
  vehicleNumber: string;           // Vehicle registration number
  vehicleType?: string;            // Vehicle type
  driverId?: string;               // Driver employee ID
  // ... other vehicle fields
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Key Queries:**
- By vehicle number: `orderBy('vehicleNumber')`

---

## Cloud Functions

### 1. `onClientCreated`
**Type:** Firestore Trigger (onCreate)  
**Path:** `CLIENTS/{clientId}`  
**Purpose:** Automatically updates analytics when a new client is created.

**Functionality:**
- Calculates financial year context (FY starts in April)
- Creates or updates analytics document for the financial year
- Increments `activeClients` and `userOnboarding` metrics for the creation month
- Uses month key format: `YYYY-MM`

**Code Location:** `functions/src/index.ts`

---

### 2. `rebuildClientAnalytics`
**Type:** Scheduled Function (Pub/Sub)  
**Schedule:** Every 24 hours (UTC)  
**Purpose:** Rebuilds client analytics data to ensure accuracy.

**Functionality:**
- Fetches all clients from `CLIENTS` collection
- Calculates active clients count per month (cumulative)
- Calculates onboarding count per month (new clients)
- Updates analytics document with complete metrics

**Code Location:** `functions/src/index.ts`

---

### 3. `onClientCreatedSendWhatsappWelcome`
**Type:** Firestore Trigger (onCreate)  
**Path:** `CLIENTS/{clientId}`  
**Purpose:** Sends WhatsApp welcome message to new clients.

**Functionality:**
- Loads WhatsApp settings from `WHATSAPP_SETTINGS/{organizationId}`
- Falls back to global config if org-specific settings not found
- Sends WhatsApp template message via Meta Graph API
- Uses welcome template with client name parameter
- Handles errors gracefully (logs but doesn't fail)

**Settings Loading:**
1. First checks `WHATSAPP_SETTINGS/{organizationId}`
2. Falls back to Firebase Functions config (`functions.config().whatsapp`)
3. Requires `enabled: true`, `token`, and `phoneId`

**API Endpoint:** `https://graph.facebook.com/v19.0/{phoneId}/messages`

**Code Location:** `functions/src/index.ts`

---

## Indexes and Queries

### Required Composite Indexes

1. **CLIENTS Collection:**
   - `name_lowercase` (Ascending)
   - `createdAt` (Descending)
   - `phoneIndex` (Array-contains)
   - `primaryPhoneNormalized` (Equality)

2. **EMPLOYEES Collection:**
   - `organizationId` (Ascending) + `employeeName` (Ascending)

3. **DELIVERY_ZONES Collection:**
   - `city` (Ascending) + `region` (Ascending)

### Query Patterns

**Client Search:**
```dart
// By name (prefix search)
.collection('CLIENTS')
.orderBy('name_lowercase')
.startAt([query.toLowerCase()])
.endAt(['${query.toLowerCase()}\uf8ff'])

// By phone
.collection('CLIENTS')
.where('phoneIndex', arrayContains: normalizedPhone)
```

**Organization Users:**
```dart
.collection('ORGANIZATIONS')
.doc(orgId)
.collection('USERS')
.orderBy('user_name')
```

---

## Security Rules

> **Note:** Security rules are not documented in the codebase. Ensure proper Firestore security rules are configured in Firebase Console.

**Recommended Rules:**
- Users can only read/write data for their organization
- Clients collection may need organization-based access control
- Analytics should be read-only for most users
- WhatsApp settings should be admin-only

---

## Data Relationships

```
USERS
  └── ORGANIZATIONS/{orgId} (memberships)
      └── USERS (org users)
      └── PRODUCTS
      └── ROLES
      └── DELIVERY_ZONES
          └── PRICES/{productId}
      └── DELIVERY_CITIES
      └── PAYMENT_ACCOUNTS
      └── VEHICLES

CLIENTS (global, may have organizationId)
EMPLOYEES (global, has organizationId)
ANALYTICS (global, source-based)
WHATSAPP_SETTINGS (org-specific)
```

---

## Financial Year Context

The app uses a financial year that starts in **April** (month index 3).

**Calculation:**
- If current month >= April: FY starts in current year
- If current month < April: FY starts in previous year
- FY Label format: `FY{YY}{YY}` (e.g., `FY2425` for April 2024 - March 2025)

**Month Key Format:** `YYYY-MM` (e.g., `2024-04`)

---

## Phone Number Normalization

Phone numbers are normalized by removing all non-digit characters except `+`:
- Input: `+91 98765 43210`
- Normalized: `+919876543210`

This normalization is used for:
- Phone search indexing
- Duplicate detection
- WhatsApp message sending

---

## Timestamps

All timestamps use `FieldValue.serverTimestamp()` to ensure:
- Consistent server-side time
- No client-side time manipulation
- Proper timezone handling

---

## Best Practices

1. **Always use transactions** for operations that modify multiple documents or check conditions
2. **Normalize phone numbers** before storing or querying
3. **Use composite indexes** for multi-field queries
4. **Handle array-contains queries** with fallback to equality queries if index is missing
5. **Use server timestamps** for all `createdAt`/`updatedAt` fields
6. **Validate organization context** before accessing org-specific data

---

## Migration Notes

If migrating existing data:
1. Ensure all phone numbers are normalized
2. Create required composite indexes
3. Run `rebuildClientAnalytics` function to populate analytics
4. Verify WhatsApp settings for each organization

---

## Support

For questions or issues related to Firebase schema or functions, refer to:
- Firebase Console: https://console.firebase.google.com
- Functions logs: `firebase functions:log`
- Firestore indexes: Firebase Console > Firestore > Indexes

