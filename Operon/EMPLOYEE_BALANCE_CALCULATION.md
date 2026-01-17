# Employee Balance Calculation

This document explains how `currentBalance` is calculated and maintained in both `EMPLOYEES` and `EMPLOYEE_LEDGER` collections.

## Overview

The `currentBalance` represents **how much the organization owes to the employee**:
- **Positive balance** = Organization owes money to employee (salary/bonus credited, payment pending)
- **Negative balance** = Employee owes money to organization (advance/payment made in excess)

## Balance Calculation Flow

### 1. Transaction Creation/Deletion Triggers

When a transaction is created or deleted in the `TRANSACTIONS` collection, Cloud Functions automatically update the balances:

- **`onTransactionCreated`**: Called when a new transaction document is created
- **`onTransactionDeleted`**: Called when a transaction document is deleted (for reverting)

Both call `updateEmployeeLedger()` which handles the balance calculation atomically.

### 2. Ledger Delta Calculation

The balance change is determined by the transaction type and ledger type:

```typescript
// From getLedgerDelta() function (line 210-222)
// For EmployeeLedger:
// - Credit = salary/bonus credited (increases payable/balance) → +amount
// - Debit = payment/advance to employee (decreases payable/balance) → -amount

const delta = type === 'credit' ? amount : -amount;
```

**Examples:**
- Salary payment (credit ₹10,000) → `delta = +10,000` (we owe more)
- Advance payment (debit ₹5,000) → `delta = -5,000` (we owe less)
- Bonus credited (credit ₹2,000) → `delta = +2,000` (we owe more)

### 3. Balance Update Formula

The balance is calculated using this formula:

```typescript
// When creating a transaction:
newBalance = currentBalance + (ledgerDelta * multiplier)
// multiplier = 1 for creation, -1 for deletion/cancellation

// When deleting a transaction (revert):
newBalance = currentBalance - (ledgerDelta * 1)  // Same as: currentBalance + (ledgerDelta * -1)
```

## Implementation Details

### Creating/Updating Balance (First Transaction)

**Location**: `functions/src/transactions/transaction-handlers.ts` - `updateEmployeeLedger()` (lines 950-996)

When the ledger doesn't exist yet:

1. **Get Opening Balance**: 
   - Fetches `currentBalance` from previous financial year's ledger
   - If no previous year exists, defaults to `0`

2. **Calculate New Balance**:
   ```typescript
   openingBalance = await getEmployeeOpeningBalance(...); // e.g., 5,000
   balanceBefore = openingBalance; // 5,000
   currentBalance = openingBalance + (ledgerDelta * multiplier); // 5,000 + 10,000 = 15,000
   balanceAfter = currentBalance; // 15,000
   ```

3. **Create Ledger Document** (`EMPLOYEE_LEDGERS/{employeeId}_{financialYear}`):
   ```typescript
   {
     ledgerId: "emp123_2024-25",
     employeeId: "emp123",
     organizationId: "org456",
     financialYear: "2024-25",
     openingBalance: 5000,
     currentBalance: 15000,  // ✅ Set here
     totalCredited: 10000,
     totalTransactions: 1,
     createdAt: Timestamp,
     updatedAt: Timestamp
   }
   ```

4. **Update Employee Document** (`EMPLOYEES/{employeeId}`):
   ```typescript
   {
     employeeId: "emp123",
     employeeName: "John Doe",
     // ... other fields
     currentBalance: 15000,  // ✅ Synchronized here (line 1078)
     updatedAt: Timestamp
   }
   ```

**Both documents are updated atomically in the same Firestore transaction**, ensuring they always match.

### Updating Existing Balance

**Location**: `functions/src/transactions/transaction-handlers.ts` - `updateEmployeeLedger()` (lines 998-1080)

When the ledger already exists:

1. **Read Current Balance**:
   ```typescript
   balanceBefore = ledgerData.currentBalance; // e.g., 15,000
   ```

2. **Calculate New Balance**:
   ```typescript
   newBalance = balanceBefore + (ledgerDelta * multiplier);
   // Example: 15,000 + (-5,000 * 1) = 10,000 (advance payment)
   ```

3. **Update Both Documents Atomically**:
   - **Ledger Document** (line 1016-1021):
     ```typescript
     tx.update(ledgerRef, {
       currentBalance: newBalance, // ✅ Updated
       totalCredited: updatedTotalCredited,
       totalTransactions: updatedCount,
       updatedAt: now
     });
     ```
   
   - **Employee Document** (line 1076-1080):
     ```typescript
     tx.update(employeeRef, {
       currentBalance: newBalance, // ✅ Synchronized
       updatedAt: now
     });
     ```

### Reverting Balance (Transaction Deletion)

**Location**: `functions/src/transactions/transaction-handlers.ts` - `onTransactionDeleted()` (lines 1989-2176)

When a transaction is deleted:

1. **Cloud Function Triggered**: `onTransactionDeleted` is automatically called
2. **Route to Ledger Handler**: Calls `updateEmployeeLedger()` with `isCancellation: true`
3. **Calculate Reversal**:
   ```typescript
   multiplier = -1; // Reverse the effect
   newBalance = currentBalance + (ledgerDelta * -1);
   // Same as: newBalance = currentBalance - ledgerDelta
   ```

**Example:**
- Current balance: ₹15,000
- Delete salary transaction (credit ₹10,000):
  - `ledgerDelta = +10,000`
  - `newBalance = 15,000 + (10,000 * -1) = 5,000` ✅ Reverted

## Balance Synchronization

### Key Points:

1. **Atomic Updates**: Both `EMPLOYEE_LEDGERS` and `EMPLOYEES` documents are updated in the **same Firestore transaction** (lines 945-1088), ensuring they always stay in sync.

2. **Transaction Order**:
   - First transaction in a financial year: Uses `openingBalance` from previous year
   - Subsequent transactions: Uses existing `currentBalance`
   - Transaction deletion: Reverses using `multiplier = -1`

3. **Opening Balance**: 
   - Retrieved from previous financial year's ledger `currentBalance`
   - If no previous year, defaults to `0`
   - Function: `getEmployeeOpeningBalance()` (lines 126-151)

4. **Monthly Subcollection**: 
   - Transactions are also stored in `EMPLOYEE_LEDGERS/{id}/TRANSACTIONS/{yearMonth}`
   - This is for reporting/audit, but doesn't affect balance calculation

## Balance Calculation Examples

### Example 1: Initial Salary Payment
```
Opening Balance: ₹0 (new employee)
Transaction: Credit ₹10,000 (salary)
Ledger Delta: +10,000
New Balance: 0 + 10,000 = ₹10,000
```

### Example 2: Advance Payment
```
Current Balance: ₹10,000
Transaction: Debit ₹3,000 (advance)
Ledger Delta: -3,000
New Balance: 10,000 + (-3,000) = ₹7,000
```

### Example 3: Bonus Credit
```
Current Balance: ₹7,000
Transaction: Credit ₹2,000 (bonus)
Ledger Delta: +2,000
New Balance: 7,000 + 2,000 = ₹9,000
```

### Example 4: Delete Salary Transaction (Revert)
```
Current Balance: ₹9,000
Delete: Credit ₹10,000 (salary)
Ledger Delta: +10,000, Multiplier: -1
New Balance: 9,000 + (10,000 * -1) = ₹-1,000
```

## Data Flow Diagram

```
┌─────────────────────┐
│ Transaction Created │
│   or Deleted        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Cloud Function     │
│  onTransaction*     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│  updateEmployeeLedger()                 │
│  - Calculate ledgerDelta                │
│  - Get currentBalance (or opening)      │
│  - Calculate newBalance                 │
└──────────┬──────────────────────────────┘
           │
           │ Atomic Transaction
           ▼
    ┌──────────────┬──────────────┐
    │              │              │
    ▼              ▼              ▼
┌─────────┐  ┌──────────────┐  ┌──────────┐
│EMPLOYEE │  │EMPLOYEE_     │  │TRANSACT. │
│{id}     │  │LEDGER        │  │/Month    │
│         │  │{id}_{FY}     │  │          │
│current  │  │current       │  │Stores    │
│Balance: │◄─┤Balance:      │  │all txn   │
│15,000   │  │15,000        │  │for audit │
└─────────┘  └──────────────┘  └──────────┘
```

## Important Notes

1. **No Client-Side Calculation**: Balance is **never** calculated on the client. It's always maintained server-side by Cloud Functions.

2. **Single Source of Truth**: The `EMPLOYEE_LEDGERS` document is the primary source, and `EMPLOYEES.currentBalance` is kept synchronized.

3. **Financial Year Boundaries**: Each financial year has a separate ledger document (`{employeeId}_{financialYear}`), and the opening balance is carried forward from the previous year.

4. **Transaction Integrity**: All balance updates happen within Firestore transactions, ensuring atomicity and preventing race conditions.

5. **Revert Mechanism**: When deleting a transaction (like when deleting a production batch), the balance is automatically reverted using the same `updateEmployeeLedger()` function with `isCancellation: true`.
