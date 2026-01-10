# Flexible Wages Calculation System Design

## Problem Statement

Different organizations have different methods for calculating wages for employees. We need a flexible system that can accommodate various wage calculation methods while maintaining consistency with the existing transaction/ledger system.

### Example: Bricks Manufacturing Unit

**1. Production Wages:**
- A batch consists of X employees
- They produce Y bricks
- Z bricks are stacked (Thappi)
- Each employee gets: `(Y × PerBrickProductionPrice + Z × PerBrickThappiPrice) / X`

**2. Loading and Unloading Wages:**
- After a trip is delivered, quantity X bricks were delivered
- Total wages Y for the delivery (based on quantity)
- Y is split 50/50: Y/2 for Loading, Y/2 for Unloading
- Each portion is divided equally among employees who performed that task
- Record which employees loaded and which employees unloaded

---

## Design Overview

### Core Principles

1. **Organization-Specific Configuration**: Each organization can define their own wage calculation methods
2. **Extensibility**: Easy to add new calculation types in the future
3. **Integration**: Uses existing transaction/ledger system for wage credits
4. **Traceability**: All wage calculations link back to source data (batches, trips, etc.)
5. **Flexibility**: Support both automated and manual wage calculation triggers

---

## Architecture

### 1. Wage Calculation Configuration Schema

**Collection:** `ORGANIZATIONS/{orgId}/WAGE_SETTINGS`

```typescript
{
  enabled: boolean;                    // Enable/disable wage calculations
  calculationMethods: {
    [methodId: string]: {
      methodId: string;                // Unique ID for this method
      methodType: 'production' | 'loadingUnloading' | 'dailyRate' | 'custom';
      name: string;                    // Display name (e.g., "Production Wages")
      description?: string;            // Optional description
      enabled: boolean;                // Enable/disable this specific method
      roleIds?: string[];              // Optional: Only applicable to specific roles
      
      // Configuration specific to method type
      config: ProductionWageConfig | LoadingUnloadingConfig | DailyRateConfig | CustomConfig;
      
      createdAt: Timestamp;
      updatedAt: Timestamp;
    }
  };
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

### 2. Production Wage Configuration

```typescript
interface ProductionWageConfig {
  methodType: 'production';
  
  // Pricing configuration
  productionPricePerUnit: number;      // Per brick production price
  stackingPricePerUnit: number;        // Per brick stacking (Thappi) price
  
  // Batch recording
  requiresBatchApproval: boolean;      // Whether batch needs approval before wages calculated
  autoCalculateOnRecord: boolean;      // Auto-calculate wages when batch recorded
  
  // Optional: Product-specific pricing
  productSpecificPricing?: {
    [productId: string]: {
      productionPricePerUnit: number;
      stackingPricePerUnit: number;
    }
  };
}
```

### 3. Loading/Unloading Wage Configuration

```typescript
interface LoadingUnloadingConfig {
  methodType: 'loadingUnloading';
  
  // Wage calculation based on quantity delivered
  wagePerQuantity: {
    [quantityRange: string]: number;   // e.g., "0-1000": 500, "1001-2000": 750
  };
  
  // Or fixed rate per unit
  wagePerUnit?: number;                // Alternative: Fixed rate per unit
  
  // Split configuration
  loadingPercentage: number;           // Default: 50 (50% for loading)
  unloadingPercentage: number;         // Default: 50 (50% for unloading)
  // Note: loadingPercentage + unloadingPercentage should = 100
  
  // Trigger configuration
  triggerOnTripDelivery: boolean;      // Auto-calculate when trip marked delivered
  requiresEmployeeSelection: boolean;  // Must select employees for loading/unloading
  
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

---

## Data Models

### Production Batch Record

**Collection:** `PRODUCTION_BATCHES`

```typescript
{
  batchId: string;                     // Document ID
  organizationId: string;              // Required: For filtering by organization
  
  // Batch details
  batchDate: Timestamp;
  methodId: string;                    // Reference to wage calculation method
  
  // Production data
  productId?: string;                  // Optional: if product-specific
  productName?: string;
  
  totalBricksProduced: number;         // Y
  totalBricksStacked: number;          // Z
  
  // Employee participation
  employeeIds: string[];               // X employees in the batch
  employeeNames?: string[];            // Denormalized for display
  
  // Calculation results
  totalWages: number;                  // Calculated total wages
  wagePerEmployee: number;             // Calculated wage per employee
  
  // Status
  status: 'recorded' | 'calculated' | 'approved' | 'processed';
  
  // Wage transactions (after processing)
  wageTransactionIds?: string[];       // Links to TRANSACTIONS collection
  
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  
  // Optional metadata
  notes?: string;
  metadata?: Record<string, any>;
}
```

### Trip Loading/Unloading Record

**Collection:** `TRIP_WAGES`

```typescript
{
  tripWageId: string;                  // Document ID
  organizationId: string;              // Required: For filtering by organization
  tripId: string;                      // Reference to SCHEDULE_TRIPS
  
  // Trip details (denormalized for easy access)
  orderId?: string;
  productId?: string;
  productName?: string;
  quantityDelivered: number;           // X bricks delivered
  
  // Wage calculation method
  methodId: string;
  
  // Employee assignments
  loadingEmployeeIds: string[];        // Employees who loaded
  unloadingEmployeeIds: string[];      // Employees who unloaded
  
  // Calculation results
  totalWages: number;                  // Y (total wages for this delivery)
  loadingWages: number;                // Y/2 (total for loading)
  unloadingWages: number;              // Y/2 (total for unloading)
  loadingWagePerEmployee: number;      // (Y/2) / loadingEmployees.length
  unloadingWagePerEmployee: number;    // (Y/2) / unloadingEmployees.length
  
  // Status
  status: 'recorded' | 'calculated' | 'processed';
  
  // Wage transactions (after processing)
  wageTransactionIds?: string[];       // Links to TRANSACTIONS collection
  
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

---

## Transaction Integration

Wages are credited to employees using the existing `TRANSACTIONS` collection with:

```typescript
{
  // Standard transaction fields
  transactionId: string;
  organizationId: string;
  employeeId: string;                  // Individual employee
  ledgerType: 'employeeLedger';
  type: 'credit';
  category: 'wageCredit';              // New category (or use existing)
  amount: number;                      // Wage amount for this employee
  
  // Links to source
  metadata: {
    sourceType: 'productionBatch' | 'tripWage';
    sourceId: string;                  // batchId or tripWageId
    methodId: string;                  // Wage calculation method used
    
    // For production batches
    batchId?: string;
    
    // For trip wages
    tripId?: string;
    taskType?: 'loading' | 'unloading';
  };
  
  description: string;                 // e.g., "Production Batch #12345" or "Trip #T001 - Loading"
  createdAt: Timestamp;
  financialYear: string;
  // ... other transaction fields
}
```

**New Transaction Category:**
- Add `wageCredit` to `TransactionCategory` enum (or use existing `salaryCredit` with metadata distinction)

---

## Workflow

### Production Wages Workflow

1. **Record Production Batch**
   - UI: Production batch recording form
   - Input: Batch date, employees, bricks produced (Y), bricks stacked (Z)
   - System creates `PRODUCTION_BATCHES` document with status `recorded`

2. **Calculate Wages** (automatic if `autoCalculateOnRecord: true`, or manual)
   - System reads wage settings for organization
   - Applies production wage formula:
     ```
     totalWages = (Y × productionPricePerUnit) + (Z × stackingPricePerUnit)
     wagePerEmployee = totalWages / X (number of employees)
     ```
   - Updates batch document with calculations, status → `calculated`

3. **Approve** (if `requiresBatchApproval: true`)
   - Manager reviews and approves batch
   - Status → `approved`

4. **Process Wages** (create transactions)
   - System creates individual credit transactions for each employee
   - Each transaction links to batch via metadata
   - Batch status → `processed`
   - Updates employee ledgers automatically (via existing Cloud Functions)

### Loading/Unloading Wages Workflow

1. **Trip Delivered**
   - Trip marked as "delivered" in `SCHEDULE_TRIPS`
   - Quantity delivered is recorded

2. **Record Loading/Unloading Employees**
   - UI: Trip wage assignment form (can be triggered from trip detail page)
   - Select employees who loaded
   - Select employees who unloaded
   - System creates `TRIP_WAGES` document

3. **Calculate Wages** (automatic if `triggerOnTripDelivery: true`)
   - System reads wage settings
   - Calculates total wages based on quantity delivered:
     ```
     totalWages = getWageForQuantity(quantityDelivered)  // or quantityDelivered × wagePerUnit
     loadingWages = totalWages × (loadingPercentage / 100)
     unloadingWages = totalWages × (unloadingPercentage / 100)
     loadingWagePerEmployee = loadingWages / loadingEmployees.length
     unloadingWagePerEmployee = unloadingWages / unloadingEmployees.length
     ```
   - Updates trip wage document with calculations

4. **Process Wages**
   - System creates credit transactions for each employee
   - Separate transactions for loading vs unloading (or combined with metadata)
   - Updates employee ledgers

---

## UI/UX Considerations

### 1. Wage Settings Page
- Location: Settings → Wages Configuration
- Allow enabling/disabling wage calculations
- List all configured methods
- Add/Edit/Delete wage calculation methods
- Configure method-specific settings

### 2. Production Batch Recording
- New page: "Record Production Batch"
- Form fields:
  - Date
  - Product (optional)
  - Employees (multi-select)
  - Bricks Produced
  - Bricks Stacked
- Show calculated wages preview
- Submit to create batch record

### 3. Trip Wage Assignment
- Option 1: Integrated into Trip Detail page
  - When trip is delivered, show "Assign Wages" button
  - Modal/dialog to select loading/unloading employees
- Option 2: Separate "Trip Wages" page
  - List all delivered trips pending wage assignment
  - Bulk assignment capabilities

### 4. Wage Review/Approval (if enabled)
- Page to review calculated wages before processing
- Show batch/trip details
- Approve/reject individual records
- Process wages after approval

---

## Implementation Phases

### Phase 1: Foundation (MVP)
1. Create wage settings schema
2. Add `wageCredit` transaction category (or use existing with metadata)
3. Create production batch recording (manual entry, manual calculation)
4. Create trip wage assignment (manual entry, manual calculation)
5. Manual wage processing (create transactions)

### Phase 2: Automation
1. Auto-calculation when batches/trips recorded
2. Auto-processing after approval (if enabled)
3. Cloud Functions for automatic wage calculation triggers

### Phase 3: Advanced Features
1. Product-specific pricing
2. Quantity-based wage tiers
3. Wage analytics and reports
4. Bulk operations
5. Wage templates/presets

---

## Database Schema Summary

### New Collections

1. `ORGANIZATIONS/{orgId}/WAGE_SETTINGS`
   - Single document per organization (nested under organization)
   - Contains all wage calculation methods

2. `PRODUCTION_BATCHES`
   - Production batch records (top-level collection)
   - Indexed by: organizationId, batchDate, status, methodId
   - Query pattern: `where('organizationId', '==', orgId)`

3. `TRIP_WAGES`
   - Trip wage records (top-level collection)
   - Indexed by: organizationId, tripId, status, methodId
   - Query pattern: `where('organizationId', '==', orgId)`

### Modified Collections

1. `TRANSACTIONS`
   - Add `wageCredit` category (or enhance metadata)
   - Metadata links to source batch/trip

2. `SCHEDULE_TRIPS`
   - No changes needed (wage records reference trips)
   - Optional: Add `wageProcessed` flag for tracking

---

## Cloud Functions

### New Functions

1. **onProductionBatchCreated**
   - Trigger: `PRODUCTION_BATCHES` document created
   - If `autoCalculateOnRecord: true`, calculate wages immediately

2. **onTripWageCreated**
   - Trigger: `TRIP_WAGES` document created
   - Calculate wages based on trip quantity and configuration

3. **processProductionBatchWages** (manual trigger or scheduled)
   - Creates transactions for all employees in batch
   - Updates batch status to `processed`

4. **processTripWages** (manual trigger or scheduled)
   - Creates transactions for loading/unloading employees
   - Updates trip wage status to `processed`

### Considerations
- Wage calculation should be idempotent
- Prevent duplicate wage processing
- Handle edge cases (zero employees, zero quantity, etc.)
- Validation before processing

---

## Questions to Resolve

1. **Transaction Category**: Should we add `wageCredit` or use existing `salaryCredit` with metadata?
   - Recommendation: Add `wageCredit` for clarity and filtering

2. **Batch Approval**: Should all organizations require approval, or only if configured?
   - Recommendation: Configurable per organization/method

3. **Retroactive Changes**: What happens if batch/trip data is edited after wages processed?
   - Recommendation: Lock processed records, require adjustment transaction if changes needed

4. **Wage Recalculation**: Can wages be recalculated if settings change?
   - Recommendation: Only for unprocessed records; processed records are locked

5. **Integration with Existing Wage System**: How does this integrate with existing manual wage credits?
   - Recommendation: Both coexist; existing system for monthly salaries, new system for production/trip wages

6. **Multi-Product Batches**: Can a batch produce multiple products?
   - Recommendation: Start with single product, extend later if needed

---

## Next Steps

1. **Review and Approve Design**
   - Discuss with stakeholders
   - Clarify requirements
   - Resolve questions above

2. **Phase 1 Implementation**
   - Start with wage settings schema
   - Production batch recording (manual)
   - Trip wage assignment (manual)
   - Manual wage processing

3. **Testing**
   - Test with example bricks manufacturing unit
   - Validate calculations
   - Test edge cases

4. **Iterate**
   - Gather feedback
   - Add automation (Phase 2)
   - Add advanced features (Phase 3)

