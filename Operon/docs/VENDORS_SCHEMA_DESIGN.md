# Vendors Database Schema Design

## Overview

A comprehensive vendor/supplier management system that tracks vendor information, balances, transactions, and vendor-specific attributes based on vendor type. This system integrates with the existing transaction and ledger infrastructure.

---

## Database Schema

### 1. VENDORS Collection (Top-Level)

**Collection:** `VENDORS`

**Document Structure:**
```typescript
{
  // Identity
  vendorId: string;                      // Same as document ID
  vendorCode: string;                    // Auto-generated code (e.g., "VND-XXXXXX")
  
  // Basic Information (Required)
  name: string;                          // Vendor name
  name_lowercase: string;                // Lowercase for case-insensitive search
  phoneNumber: string;                   // Primary phone number (E.164 format)
  phoneNumberNormalized: string;         // Normalized phone (digits only for search)
  
  // Contact Information
  phones: Array<{                        // All phone numbers
    number: string;                      // E.164 format
    normalized: string;                  // Digits only
    label?: string;                      // "Primary", "Secondary", "Accounts", etc.
  }>;
  phoneIndex: string[];                  // Array of normalized phones for search
  
  // Financial Information (Required)
  openingBalance: number;                // Opening balance - SET ONLY AT CREATION (default: 0, can be negative)
  currentBalance: number;                // Current payable balance (updated via transactions, can be negative)
  
  // Vendor Classification (Required)
  vendorType: string;                    // See VendorType enum below
  vendorSubType?: string;                // Optional sub-categorization within type
  
  // Business Information
  gstNumber?: string;                    // GST registration number
  panNumber?: string;                    // PAN number
  businessName?: string;                 // Legal business name (if different from name)
  contactPerson?: string;                // Primary contact person name
  contactPersonPhone?: string;           // Contact person phone
  
  // Vendor-Specific Attributes (Conditional based on vendorType)
  // See VendorType-Specific Fields section below
  
  // Status & Organization
  status: string;                        // "active" | "inactive" | "suspended" | "blacklisted"
  organizationId: string;                // Organization reference (multi-tenancy)
  
  // Tags & Categorization
  tags: string[];                        // For custom categorization (e.g., "preferred", "urgent", "local")
  notes?: string;                        // General notes about vendor
  
  // Payment Terms (Optional)
  paymentTerms?: {
    creditDays?: number;                 // Credit period in days (e.g., 30, 45, 60) - Optional
    creditLimit?: number;                // Credit limit amount - Optional (not enforced)
    paymentMode?: string;                // Preferred: "cash" | "upi" | "bank_transfer" | "cheque" | "credit"
    bankDetails?: {
      accountNumber?: string;
      ifscCode?: string;
      bankName?: string;
      accountHolderName?: string;
    };
  };
  
  // Audit Trail
  createdBy: string;                     // User ID who created
  createdAt: Timestamp;                  // Creation timestamp
  updatedBy?: string;                    // User ID who last updated
  updatedAt: Timestamp;                  // Last update timestamp
  lastTransactionDate?: Timestamp;       // Date of last transaction
}
```

---

## VendorType Enum & Specific Fields

### VendorType Options

```typescript
enum VendorType {
  RAW_MATERIAL = "raw_material",           // Raw materials suppliers
  VEHICLE = "vehicle",                      // Vehicle purchase/lease vendors
  REPAIR_MAINTENANCE = "repair_maintenance", // Repair & maintenance services
  WELFARE = "welfare",                     // Employee welfare vendors
  FUEL = "fuel",                           // Fuel suppliers
  UTILITIES = "utilities",                 // Electricity, water, internet, etc.
  RENT = "rent",                           // Property/equipment rent
  PROFESSIONAL_SERVICES = "professional_services", // Legal, accounting, consulting
  MARKETING_ADVERTISING = "marketing_advertising", // Marketing & advertising agencies
  INSURANCE = "insurance",                 // Insurance providers
  LOGISTICS = "logistics",                 // Shipping, courier, transportation
  OFFICE_SUPPLIES = "office_supplies",     // Office supplies & equipment
  SECURITY = "security",                   // Security services
  CLEANING = "cleaning",                   // Cleaning & housekeeping services
  TAX_CONSULTANT = "tax_consultant",      // Tax consultants & CA
  BANKING_FINANCIAL = "banking_financial", // Banks & financial institutions
  OTHER = "other"                          // Other vendors
}
```

### VendorType-Specific Fields

These fields are conditionally relevant based on `vendorType`:

#### 1. RAW_MATERIAL
```typescript
rawMaterialDetails?: {
  materialCategories: string[];           // e.g., ["cement", "steel", "sand"]
  unitOfMeasurement?: string;             // "kg", "ton", "bag", etc.
  qualityCertifications?: string[];       // e.g., ["ISO 9001", "BIS Certified"]
  deliveryCapability?: {
    canDeliver: boolean;
    deliveryRadius?: number;              // in km
    minOrderQuantity?: number;
  };
}
```

#### 2. VEHICLE
```typescript
vehicleDetails?: {
  vehicleTypes: string[];                 // ["truck", "car", "bike", "loader"]
  serviceTypes: string[];                 // ["purchase", "lease", "rental"]
  fleetSize?: number;                     // If vendor manages fleet
  insuranceProvider?: boolean;            // If they provide insurance
  maintenanceIncluded?: boolean;           // If maintenance included
}
```

#### 3. REPAIR_MAINTENANCE
```typescript
repairMaintenanceDetails?: {
  serviceCategories: string[];            // ["vehicle_repair", "equipment_repair", "electrical", "plumbing"]
  specialization?: string[];              // ["AC repair", "engine service", etc.]
  responseTime?: string;                  // "same_day", "24_hours", "48_hours"
  warrantyPeriod?: number;                // in days
  serviceRadius?: number;                 // in km
}
```

#### 4. WELFARE
```typescript
welfareDetails?: {
  serviceTypes: string[];                 // ["canteen", "medical", "transport", "accommodation"]
  employeeCapacity?: number;              // Number of employees they can serve
  contractPeriod?: {
    startDate?: Timestamp;
    endDate?: Timestamp;
  };
}
```

#### 5. FUEL
```typescript
fuelDetails?: {
  fuelTypes: string[];                    // ["petrol", "diesel", "CNG", "electric_charging"]
  stationLocation?: string;                // Address of fuel station
  creditLimit?: number;                   // Credit limit for fuel purchases
  discountPercentage?: number;            // Volume discount if applicable
}
```

#### 6. UTILITIES
```typescript
utilitiesDetails?: {
  utilityTypes: string[];                 // ["electricity", "water", "internet", "phone", "gas"]
  accountNumbers: string[];                // Utility account numbers
  billingCycle?: string;                  // "monthly", "quarterly", "annually"
  autoPayEnabled?: boolean;
}
```

#### 7. RENT
```typescript
rentDetails?: {
  propertyType?: string;                  // "office", "warehouse", "equipment", "vehicle"
  monthlyRent?: number;
  securityDeposit?: number;
  leaseStartDate?: Timestamp;
  leaseEndDate?: Timestamp;
  propertyAddress?: string;
}
```

#### 8. PROFESSIONAL_SERVICES
```typescript
professionalServicesDetails?: {
  serviceTypes: string[];                 // ["legal", "accounting", "consulting", "audit"]
  hourlyRate?: number;
  retainerFee?: number;
  licenseNumbers?: string[];              // Professional license numbers
}
```

#### 9. MARKETING_ADVERTISING
```typescript
marketingAdvertisingDetails?: {
  serviceTypes: string[];                 // ["digital_marketing", "print", "outdoor", "events"]
  campaignTypes?: string[];               // ["social_media", "SEO", "content"]
}
```

#### 10. INSURANCE
```typescript
insuranceDetails?: {
  insuranceTypes: string[];                // ["vehicle", "health", "property", "liability"]
  policyNumbers?: string[];
  renewalDate?: Timestamp;
  premiumAmount?: number;
}
```

#### 11. LOGISTICS
```typescript
logisticsDetails?: {
  serviceTypes: string[];                 // ["shipping", "courier", "freight", "warehousing"]
  coverageAreas?: string[];                // Cities/regions covered
  vehicleTypes?: string[];                 // Types of vehicles used
  trackingEnabled?: boolean;
}
```

#### 12. OFFICE_SUPPLIES
```typescript
officeSuppliesDetails?: {
  categories: string[];                   // ["stationery", "furniture", "electronics", "consumables"]
  catalogAvailable?: boolean;
  bulkDiscount?: boolean;
}
```

#### 13. SECURITY
```typescript
securityDetails?: {
  serviceTypes: string[];                 // ["guarding", "surveillance", "access_control"]
  numberOfGuards?: number;
  shiftTimings?: string;                  // "24x7", "day", "night"
}
```

#### 14. CLEANING
```typescript
cleaningDetails?: {
  serviceTypes: string[];                 // ["office_cleaning", "deep_cleaning", "sanitization"]
  frequency?: string;                     // "daily", "weekly", "monthly"
  numberOfStaff?: number;
}
```

#### 15. TAX_CONSULTANT
```typescript
taxConsultantDetails?: {
  services: string[];                     // ["GST_filing", "income_tax", "audit", "compliance"]
  caNumber?: string;                      // CA registration number
  firmName?: string;
}
```

#### 16. BANKING_FINANCIAL
```typescript
bankingFinancialDetails?: {
  serviceTypes: string[];                 // ["loan", "credit", "banking", "investment"]
  accountNumbers?: string[];
  creditLimit?: number;
  interestRate?: number;
}
```

---

## Vendor Ledger System

### 2. VENDOR_LEDGERS Collection

**Collection:** `VENDOR_LEDGERS`

**Document Structure:**
```typescript
{
  // Identity
  ledgerId: string;                       // Format: "{vendorId}_{financialYear}" (e.g., "vnd123_FY2425")
  vendorId: string;                        // Reference to VENDORS collection
  organizationId: string;
  financialYear: string;                  // "FY2425"
  
  // Balance Information
  openingBalance: number;                 // Opening balance for this FY (from previous FY's currentBalance)
  currentBalance: number;                  // Current payable balance (we owe them)
  totalPayables: number;                  // Total amount we owe (credit transactions)
  totalPayments: number;                  // Total amount paid (debit transactions)
  
  // Transaction Counts
  transactionCount: number;               // Total number of transactions
  creditCount: number;                    // Number of credit transactions (purchases)
  debitCount: number;                     // Number of debit transactions (payments)
  
  // Transaction References
  transactionIds: string[];               // Array of transaction IDs in this FY
  
  // Metadata
  lastTransactionDate?: Timestamp;        // Date of last transaction
  lastUpdated: Timestamp;                 // Last ledger update timestamp
}
```

**Subcollection:** `VENDOR_LEDGERS/{ledgerId}/TRANSACTIONS/{yearMonth}`

Monthly transaction aggregation (similar to CLIENT_LEDGERS pattern):
```typescript
{
  yearMonth: string;                      // "202404" (YYYYMM format)
  transactions: Array<{
    transactionId: string;
    transactionDate: Timestamp;
    type: string;                         // "credit" | "debit"
    amount: number;
    balanceBefore: number;
    balanceAfter: number;
    description?: string;
    referenceNumber?: string;
    // ... other transaction fields
  }>;
  transactionCount: number;
  totalCredit: number;
  totalDebit: number;
}
```

---

## Transaction Integration

### Transaction Types for Vendors

When creating transactions for vendors:

**Credit Transaction** (Purchase from vendor - we owe them):
- Increases `currentBalance` (payable)
- Example: Purchase raw materials, pay for services

**Debit Transaction** (Payment to vendor - we pay them):
- Decreases `currentBalance` (payable)
- Example: Payment made to vendor

### Transaction Document Structure (Vendor-related)

```typescript
{
  // ... existing transaction fields ...
  
  ledgerType: "vendorLedger";            // Indicates this affects vendor ledger
  vendorId: string;                       // Reference to VENDORS collection
  vendorName?: string;                    // Snapshot at transaction time
  
  // For credit transactions (purchases)
  purchaseDetails?: {
    invoiceNumber?: string;
    invoiceDate?: Timestamp;
    items?: Array<{
      description: string;
      quantity?: number;
      unitPrice?: number;
      total: number;
    }>;
    gstAmount?: number;
    totalAmount: number;
  };
  
  // For debit transactions (payments)
  paymentDetails?: {
    paymentMode: string;                  // "cash" | "upi" | "bank_transfer" | "cheque"
    paymentAccountId?: string;
    referenceNumber?: string;             // UTR, cheque number, etc.
  };
}
```

---

## Indexes Required

Add to `firestore.indexes.json`:

```json
{
  "collectionGroup": "VENDORS",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "organizationId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "VENDORS",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "organizationId", "order": "ASCENDING" },
    { "fieldPath": "vendorType", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "VENDORS",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "organizationId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "name_lowercase", "order": "ASCENDING" }
  ]
},
{
  "collectionGroup": "VENDOR_LEDGERS",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "organizationId", "order": "ASCENDING" },
    { "fieldPath": "financialYear", "order": "ASCENDING" },
    { "fieldPath": "currentBalance", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "VENDOR_LEDGERS",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "organizationId", "order": "ASCENDING" },
    { "fieldPath": "vendorId", "order": "ASCENDING" },
    { "fieldPath": "financialYear", "order": "ASCENDING" }
  ]
}
```

---

## Validation Rules & Business Logic

### Vendor Creation
1. **vendorCode**: Auto-generated, format `"VND-{YYYY}-{NNN}"`
   - Query last vendor code for organization
   - Increment sequence number
   - Must be unique per organization

2. **openingBalance**: 
   - Required field (default: 0)
   - Can be positive or negative
   - **Cannot be changed after creation**

3. **Required Fields**: name, phoneNumber, vendorType, organizationId

### Vendor Updates
1. **openingBalance**: **READ-ONLY** - Cannot be modified after creation
2. **vendorCode**: **READ-ONLY** - Cannot be modified (auto-generated)
3. **currentBalance**: **READ-ONLY** - Only updated via transactions

### Status Change Restrictions
1. **Cannot DELETE** vendor if `currentBalance !== 0`
   - Error: "Cannot delete vendor with pending balance. Current balance: ₹{amount}"
   - Must settle balance to zero before deletion

2. **Cannot SUSPEND** vendor if `currentBalance !== 0`
   - Error: "Cannot suspend vendor with pending balance. Current balance: ₹{amount}"
   - Must settle balance to zero before suspension

3. **Can set to INACTIVE** regardless of balance
   - Soft delete option
   - Vendor remains in system but hidden from active lists

4. **Can BLACKLIST** regardless of balance
   - Mark vendor as blacklisted
   - Prevents future transactions

### Balance Semantics
1. **Positive Balance**: We owe the vendor money (payable)
2. **Negative Balance**: Vendor owes us money (overpayment/credit) - **ALLOWED**
3. **Zero Balance**: No outstanding amount
4. Balance updates happen automatically via transaction system

### Payment Terms
1. All payment terms are **optional**
2. **creditLimit** is optional and **NOT enforced** (informational only)
3. No validation or blocking based on credit limits
4. Can be added/updated at any time

### GST & Business Information
1. **GST number**: Optional, no validation required
2. **PAN number**: Optional, no validation required
3. No mandatory fields based on vendor type

---

## Key Design Decisions

### 1. Balance Semantics
- **Opening Balance**: 
  - Set ONLY at vendor creation time (not editable after creation)
  - Can be positive (we owe them) or negative (they owe us/credit)
  - Default: 0
  - Used for existing vendors when migrating data
- **Current Balance**: 
  - Represents how much we owe the vendor (payable)
  - Positive balance = we owe them money
  - Negative balance = they owe us money (overpayment/credit) - **ALLOWED**
  - Updated automatically via transaction system (similar to client ledger)
  - Cannot be manually edited after creation

### 2. VendorType-Specific Fields
- Fields are optional and only relevant for specific vendor types
- UI should conditionally show fields based on selected `vendorType`
- Allows flexibility for future vendor types without schema changes

### 3. Search & Filtering
- `name_lowercase` for case-insensitive name search
- `phoneIndex` array for phone number search
- `tags` array for custom categorization
- `vendorType` for filtering by type

### 4. Multi-Tenancy
- All vendors scoped to `organizationId`
- Queries always filter by `organizationId` first

### 5. Financial Year Tracking
- Separate ledger per financial year (similar to client ledger)
- Opening balance automatically carried from previous FY
- Current balance tracked per FY

### 6. Vendor Code Generation
- **Auto-generated** at vendor creation
- Format: `"VND-{YYYY}-{NNN}"` where:
  - `YYYY` = Current year (4 digits)
  - `NNN` = Sequential number (3 digits, zero-padded)
- Example: `"VND-2024-001"`, `"VND-2024-002"`
- Generated by Cloud Function `onVendorCreated`
- Must be unique per organization

### 7. Status Management Restrictions
- **Cannot delete** vendor if `currentBalance !== 0` (has pending balance)
- **Cannot suspend** vendor if `currentBalance !== 0` (has pending balance)
- **Can change to inactive** regardless of balance (soft delete)
- **Can blacklist** regardless of balance
- Validation enforced in Cloud Functions and UI

---

## Integration Points

### 1. Transaction System
- Extend `transaction-handlers.ts` to support `vendorLedger` type
- Implement `updateVendorLedger()` function (similar to `updateClientLedger()`)
- Handle credit/debit transactions for vendors

### 2. General Ledger
- Vendor payments should create expense entries in General Ledger
- Link vendor transactions to General Ledger entries

### 3. Purchase Orders (Future)
- Link purchase orders to vendors
- Track pending purchases vs. paid purchases

---

## UI Design

### Design Pattern
Following the same UI patterns as **Employees** and **Clients** pages:
- **Layout**: `PageWorkspaceLayout` with navigation
- **State Management**: BLoC/Cubit pattern
- **Styling**: Dark theme with consistent color scheme
- **Components**: Reusable widgets similar to existing pages

---

### 1. Vendors List Page (`/vendors`)

**File:** `lib/presentation/views/vendors_page.dart`

**Layout:**
- Info card with description
- Search bar (name, phone, GST number)
- Filter chips (VendorType, Status)
- Add Vendor button (if `canCreate`)
- Vendor list with tiles showing: Name, Type, Phone, Balance, Status
- Edit/Delete actions (if permissions)

**Vendor Tile:**
- Icon (vendor type specific)
- Name, Type, Phone
- Current Balance (color-coded: orange if positive, green if negative)
- Edit/Delete buttons (if permissions)

**Features:**
- Search by name, phone, or GST number
- Filter by vendor type and status
- Sort by name, balance, last transaction
- Empty state message
- Loading state indicator
- Permission-based UI

---

### 2. Add/Edit Vendor Dialog

**File:** `lib/presentation/views/vendors_page.dart` (as `_VendorDialog`)

**Form Fields:**
- **Required:**
  - Name (TextInput)
  - Phone Number (TextInput, E.164 format)
  - Vendor Type (Dropdown)
  - Opening Balance (TextInput, **disabled if editing**)

- **Optional:**
  - GST Number
  - PAN Number
  - Business Name
  - Contact Person
  - Contact Person Phone
  - Status (Dropdown: Active, Inactive, Suspended, Blacklisted)
  - Tags (Chip input)
  - Notes (TextArea)

- **Payment Terms (Optional):**
  - Credit Days
  - Credit Limit (hint: "Optional, not enforced")
  - Preferred Payment Mode
  - Bank Details (expandable section)

- **Vendor Type Specific Fields:**
  - Conditionally shown based on selected `vendorType`
  - Expandable sections or tabs for better UX

**Validation:**
- Name: Required
- Phone: Required, E.164 format
- Vendor Type: Required
- Opening Balance: Required, valid number (only at creation)
- Status change: Validate balance before delete/suspend

---

### 3. Vendor Detail Page (`/vendors/detail`)

**File:** `lib/presentation/views/vendors_page/vendor_detail_page.dart`

**Tabs:**
1. **Overview Tab:**
   - Contact Information
   - Business Information
   - Tags
   - Notes
   - Payment Terms

2. **Financial Tab:**
   - Balance Summary (Opening, Current)
   - Financial Year
   - Transaction Summary
   - Link to Full Ledger

3. **Transactions Tab:**
   - Filter (All, Credit, Debit)
   - Sort (Date, Amount)
   - Transaction list with details

4. **Details Tab:**
   - Vendor Type Specific Information
   - Audit Trail

**Actions:**
- Edit button (if `canEdit`)
- Delete button (if `canDelete`, with balance validation)

---

### 4. Delete Confirmation

**Validation:**
- Check if `currentBalance !== 0`
- Show error dialog if balance is non-zero
- Show confirmation dialog if balance is zero
- Execute delete only after confirmation

---

### 5. State Management

**File:** `lib/presentation/blocs/vendors/vendors_cubit.dart`

**State:**
- `vendors`: List of all vendors
- `filteredVendors`: Filtered/search results
- `searchQuery`: Current search term
- `selectedVendorType`: Active type filter
- `selectedStatus`: Active status filter
- `status`: Loading/Success/Error
- `canCreate`, `canEdit`, `canDelete`: Permissions

**Methods:**
- `loadVendors()`
- `searchVendors(String query)`
- `filterByType(String? vendorType)`
- `filterByStatus(String? status)`
- `createVendor(Vendor vendor)`
- `updateVendor(Vendor vendor)`
- `deleteVendor(String vendorId)`

---

### 6. Data Source & Repository

**Files:**
- `lib/data/datasources/vendors_data_source.dart`
- `lib/data/repositories/vendors_repository.dart`

**Methods:**
- CRUD operations
- Search functionality
- Stream for real-time updates

---

### 7. Navigation Routes

**File:** `lib/config/app_router.dart`

**Routes:**
- `/vendors` - Vendors list page
- `/vendors/detail` - Vendor detail page

---

### 8. Permissions Integration

**Permission Checks:**
- `canCreate('vendors')` - Show/hide Add button
- `canEdit('vendors')` - Show/hide Edit button
- `canDelete('vendors')` - Show/hide Delete button

---

### 9. UI Components & Styling

**Color Scheme:**
- Primary: `Color(0xFF6F4BFF)` (Purple)
- Background: `Color(0xFF11111B)` (Dark)
- Card: `Color(0xFF1A1A2A)` (Darker)
- Text: White variants
- Error: Red
- Success: Green
- Warning: Orange

**Reusable Widgets:**
- `DashButton` - Primary action button
- `PageWorkspaceLayout` - Main page layout
- Consistent input field styling
- Status badges
- Filter chips

---

## Cloud Functions Required

### 1. `onVendorCreated`
**Trigger:** `VENDORS` document created

**Actions:**
1. **Auto-generate vendor code** (format: "VND-{YYYY}-{NNN}")
   - Get current year (YYYY)
   - Query VENDORS collection for organization
   - Find last vendor code matching pattern "VND-{YYYY}-*"
   - Extract highest sequence number (NNN)
   - Increment by 1 (or start at 001 if none exists)
   - Format: `VND-${year}-${sequence.toString().padStart(3, '0')}`
   - Update vendor document with generated code
   - Example: "VND-2024-001", "VND-2024-002", etc.

2. **Create initial ledger** for current financial year
   - Get current financial year (e.g., "FY2425")
   - Create VENDOR_LEDGERS document with ledgerId = `{vendorId}_{financialYear}`
   - Set `openingBalance` from vendor document
   - Initialize `currentBalance` = `openingBalance`
   - Initialize counters (transactionCount, creditCount, debitCount) to 0

3. **Initialize search indexes**
   - Set `name_lowercase` = `name.toLowerCase()`
   - Build `phoneIndex` array from all phone numbers
   - Normalize phone numbers for search

### 2. `onVendorUpdated`
**Trigger:** `VENDORS` document updated

**Actions:**
1. **Update search indexes** (if name or phones changed)
   - Update `name_lowercase` = `name.toLowerCase()`
   - Rebuild `phoneIndex` array from all phone numbers
   - Normalize phone numbers for search

2. **Validate field changes**:
   - **Reject `openingBalance` updates**: If openingBalance changed, reject update
     - Error: "Opening balance cannot be modified after vendor creation"
   - **Reject `vendorCode` updates**: If vendorCode changed, reject update
     - Error: "Vendor code cannot be modified (auto-generated)"

3. **Validate status changes**:
   - If status changed to "deleted":
     - Check if `currentBalance !== 0`
     - If non-zero: **REJECT** update with error
     - Error: "Cannot delete vendor with pending balance. Current balance: ₹{currentBalance}. Please settle the balance first."
   - If status changed to "suspended":
     - Check if `currentBalance !== 0`
     - If non-zero: **REJECT** update with error
     - Error: "Cannot suspend vendor with pending balance. Current balance: ₹{currentBalance}. Please settle the balance first."
   - If status changed to "inactive" or "blacklisted":
     - **ALLOW** regardless of balance
     - Update related records if needed

4. **Update metadata**:
   - Set `updatedBy` = user ID
   - Set `updatedAt` = current timestamp

### 3. `onVendorTransactionCreated` (in transaction-handlers)
- Update vendor ledger balance
- Update currentBalance in VENDORS document
- Update lastTransactionDate

### 4. `onFinancialYearChanged`
- Create new ledger for new FY
- Carry forward opening balance from previous FY

---

## Migration Considerations

### Existing Vendors
If you have existing vendor data:
1. Create VENDORS documents with required fields
2. Set `openingBalance` based on historical data
3. Create initial ledger for current FY
4. Backfill transactions if needed

### Data Validation
- Phone numbers must be in E.164 format
- Opening balance can be negative (if vendor owes us/credit) - **ALLOWED**
- Opening balance is **read-only after creation** (cannot be edited)
- VendorType must be from enum
- organizationId is required
- vendorCode is auto-generated (cannot be manually set)
- **Status change restrictions**:
  - Cannot delete if `currentBalance !== 0`
  - Cannot suspend if `currentBalance !== 0`
- GST number is optional (no validation required)
- Payment terms are optional (including credit limits)

---

## Future Enhancements

1. **Vendor Performance Metrics**
   - Average payment time
   - On-time delivery rate
   - Quality ratings

2. **Purchase Order Integration**
   - Link POs to vendors
   - Track pending vs. received orders

3. **Vendor Contracts**
   - Store contract documents
   - Track contract expiry dates
   - Renewal reminders

4. **Vendor Ratings & Reviews**
   - Rating system
   - Review comments
   - Performance history

5. **Bulk Operations**
   - Bulk import vendors
   - Bulk update status
   - Bulk payment processing

6. **Vendor Portal** (Future)
   - Self-service portal for vendors
   - View invoices and payments
   - Submit invoices

---

## Design Decisions Summary

### ✅ Decided

1. **Opening Balance**: 
   - ✅ Set ONLY at creation time (not editable after)
   - ✅ Can be negative (vendor owes us/credit)

2. **Negative Balance**: 
   - ✅ **ALLOWED** - Negative current balance means vendor owes us money (overpayment/credit)

3. **Vendor Code**: 
   - ✅ **Auto-generated** at creation
   - ✅ Format: `"VND-{YYYY}-{NNN}"` (e.g., "VND-2024-001")

4. **Status Management**: 
   - ✅ **RESTRICTED** - Cannot delete/suspend if `currentBalance !== 0`
   - ✅ Can set to inactive/blacklist regardless of balance

5. **Payment Terms**: 
   - ✅ **Optional** - All payment terms are optional
   - ✅ Credit limits are optional and **not enforced** (informational only)

6. **GST Integration**: 
   - ✅ GST number is **optional** (not required)
   - ✅ **No validation** required for GST numbers

### 🔄 Future Considerations

1. **VendorType Expansion**: Can add more types as needed (schema supports it)

2. **Transaction Limits**: Approval workflows for large payments (future enhancement)

3. **Credit Limit Enforcement**: Currently optional/informational, can add enforcement later if needed

