# Expenses vs Purchase: Navigation Flow & Comparison

## 📍 Navigation Flow for Expenses

### Entry Points
1. **Home Page Quick Action Menu**
   - Location: Floating action button on Home page (bottom-right)
   - Action: "Add Expense" → Navigates to `/expenses`
   - Icon: `Icons.receipt`
   - Visible on: Home page (`currentIndex == 0`) and Pending Orders page (`currentIndex == 1`)

2. **Expenses Page Quick Action Menu**
   - Location: Floating action button on Expenses page (bottom-right)
   - Action: "Add Expense" → Opens `ExpenseFormDialog`
   - Icon: `Icons.add`

3. **Direct Navigation**
   - Route: `/expenses`
   - Can be navigated to from anywhere using `context.go('/expenses')`

### Navigation Structure

```
Home Page
  └─ Quick Action Menu → "Add Expense"
      └─ Navigate to: /expenses
          └─ ExpensesPage
              ├─ Summary Cards (Vendor Payments, Salary Debits, General Expenses)
              ├─ Tab Bar (3 tabs: Vendor Payments, Salary Payments, General Expenses)
              ├─ Search Bar
              ├─ Expenses List (filtered by selected tab)
              └─ Quick Action Menu → "Add Expense"
                  └─ ExpenseFormDialog
                      ├─ Expense Type Selector (Vendor Payment / Salary Debit / General Expense)
                      ├─ Conditional Fields (Vendor/Employee/Sub-Category based on type)
                      ├─ Amount, Payment Account, Date, Description, Reference Number
                      └─ Save → Creates Transaction → Returns to Expenses Page

Expenses Page
  └─ "Manage Sub-Categories" link (for General Expenses)
      └─ Navigate to: /expense-sub-categories
          └─ ExpenseSubCategoriesPage
              ├─ List of Sub-Categories
              ├─ Add/Edit/Delete functionality
              └─ Analytics (transaction count, total amount)
```

### Key Features
- **Unified Dialog**: Single `ExpenseFormDialog` handles all expense types
- **Context-Aware**: Dialog can work with or without `ExpensesCubit` in widget tree
- **Three Expense Types**:
  1. **Vendor Payment**: Pays back vendors (debit on `vendorLedger`)
  2. **Salary Debit**: Pays employees (debit on `employeeLedger`)
  3. **General Expense**: Business expenses (debit on `organizationLedger`)
- **Sub-Categories**: General expenses can be categorized with user-defined sub-categories
- **Tabbed View**: Expenses page shows all three types in separate tabs

---

## 📍 Navigation Flow for Purchase

### Entry Points
1. **Home Page Quick Action Menu**
   - Location: Floating action button on Home page (bottom-right)
   - Action: "Record Purchase" → Navigates to `/record-purchase`
   - Icon: `Icons.shopping_cart`
   - Visible on: Home page (`currentIndex == 0`) and Pending Orders page (`currentIndex == 1`)

2. **Direct Navigation**
   - Route: `/record-purchase` (for recording)
   - Route: `/purchases` (for viewing list)

### Navigation Structure

```
Home Page
  └─ Quick Action Menu → "Record Purchase"
      └─ Navigate to: /record-purchase
          └─ RecordPurchasePage
              ├─ Vendor Type Selector
              ├─ Vendor Selector (filtered by type)
              ├─ Invoice Number
              ├─ Amount
              ├─ Date
              ├─ Description
              ├─ Conditional Fields:
              │   ├─ Raw Materials (for rawMaterial vendors)
              │   │   ├─ Material selection
              │   │   ├─ Quantity per material
              │   │   └─ Price per material
              │   ├─ Vehicle Selection (for fuel vendors)
              │   └─ Unloading Charges (with GST option)
              └─ Save → Creates Transaction → Returns to Home

Purchases Page
  └─ /purchases
      ├─ Date Range Filter
      ├─ Purchases List
      └─ Vendor Name Display
```

### Key Features
- **Vendor Type-Based**: Different fields based on vendor type (rawMaterial, fuel, other)
- **Raw Material Tracking**: Can assign materials with quantities and prices
- **Fuel Tracking**: Can link purchases to specific vehicles
- **Unloading Charges**: Additional charges with GST option
- **List View**: Separate page to view all purchases with date filtering

---

## 🔄 Comparison Table

| Aspect | Expenses | Purchase |
|--------|----------|----------|
| **Primary Purpose** | Record money going OUT (payments to vendors, employees, general expenses) | Record money going OUT for inventory/raw materials/fuel |
| **Entry Points** | Home Quick Action, Expenses Page Quick Action | Home Quick Action only |
| **Main Page** | `/expenses` - Shows all expenses with tabs | `/purchases` - Shows purchase list |
| **Form Location** | Dialog (`ExpenseFormDialog`) | Full Page (`RecordPurchasePage`) |
| **Form Reusability** | Can be opened from multiple contexts | Only from `/record-purchase` route |
| **Expense Types** | 3 types: Vendor Payment, Salary Debit, General Expense | 1 type: Vendor Purchase |
| **Ledger Impact** | `vendorLedger`, `employeeLedger`, or `organizationLedger` | `vendorLedger` only |
| **Transaction Category** | `vendorPayment`, `salaryDebit`, `generalExpense` | `vendorPurchase` |
| **Categorization** | Sub-categories for General Expenses (user-defined) | Vendor Type-based (rawMaterial, fuel, other) |
| **Linked Entities** | Vendor (for payments), Employee (for salary), Sub-Category (for general) | Vendor, Raw Materials, Vehicle (for fuel) |
| **Material Tracking** | ❌ No | ✅ Yes (for raw material vendors) |
| **Vehicle Tracking** | ❌ No | ✅ Yes (for fuel vendors) |
| **Additional Charges** | ❌ No | ✅ Yes (unloading charges with GST) |
| **Tabbed View** | ✅ Yes (3 tabs for different expense types) | ❌ No |
| **Search Functionality** | ✅ Yes | ❌ No (but has date range filter) |
| **Summary Cards** | ✅ Yes (totals for each expense type) | ❌ No |
| **State Management** | `ExpensesCubit` (with fallback to direct repository access) | Direct Firestore queries |
| **Data Source** | `TransactionsDataSource` via `ExpensesCubit` | Direct `FirebaseFirestore` queries |
| **Navigation After Save** | Stays on Expenses Page | Returns to Home Page |
| **Quick Action Visibility** | Home + Expenses Page | Home Page only |

---

## 🎯 Key Differences

### 1. **Form Presentation**
- **Expenses**: Uses a dialog (`ExpenseFormDialog`) that can be opened from anywhere
- **Purchase**: Uses a full page (`RecordPurchasePage`) that requires navigation

### 2. **Complexity**
- **Expenses**: Simpler form, focuses on amount, payment account, and basic details
- **Purchase**: More complex form with material tracking, vehicle selection, and additional charges

### 3. **Categorization**
- **Expenses**: Uses sub-categories (user-defined) for General Expenses
- **Purchase**: Uses vendor types (system-defined: rawMaterial, fuel, other)

### 4. **Data Model**
- **Expenses**: 
  - `LedgerType`: `vendorLedger`, `employeeLedger`, `organizationLedger`
  - `TransactionCategory`: `vendorPayment`, `salaryDebit`, `generalExpense`
- **Purchase**:
  - `LedgerType`: `vendorLedger` only
  - `TransactionCategory`: `vendorPurchase`

### 5. **User Experience**
- **Expenses**: 
  - Quick access via dialog
  - Can see all expenses in one place with tabs
  - Summary cards show totals
- **Purchase**:
  - Requires full page navigation
  - Separate list page for viewing purchases
  - More detailed form for inventory tracking

### 6. **State Management**
- **Expenses**: Uses BLoC pattern (`ExpensesCubit`) with proper state management
- **Purchase**: Uses direct Firestore queries with local state management

---

## 📊 Use Cases

### When to Use Expenses
- Paying back a vendor for previous purchases
- Paying employee salaries
- Recording general business expenses (rent, utilities, etc.)
- Quick expense entry from anywhere in the app

### When to Use Purchase
- Recording new inventory purchases (raw materials)
- Recording fuel purchases for vehicles
- Recording purchases that need material/quantity tracking
- Recording purchases with additional charges (unloading, etc.)

---

## 🔗 Related Routes

### Expenses Routes
- `/expenses` - Main expenses page
- `/expense-sub-categories` - Manage expense sub-categories

### Purchase Routes
- `/record-purchase` - Record a new purchase
- `/purchases` - View all purchases

---

## 💡 Recommendations

1. **Consistency**: Consider making Purchase form also a dialog for consistency with Expenses
2. **State Management**: Consider implementing BLoC pattern for Purchases similar to Expenses
3. **Search**: Add search functionality to Purchases page similar to Expenses
4. **Summary Cards**: Add summary cards to Purchases page showing total purchases, etc.
5. **Quick Actions**: Consider adding "View Purchases" quick action similar to Expenses

