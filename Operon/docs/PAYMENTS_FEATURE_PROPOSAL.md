# Payments Feature Proposal

## Overview

Add a "Payments" feature to the Quick Action Menu in both Android and Web apps that allows users to:
1. Record client payments with proof photos
2. View and manage payment history
3. Automatically update client ledger balances

## Feature Requirements

### 1. Quick Action Menu - Payments Button

**Location:** Quick Action Menu (same location as "Create Order" button)
- **Icon:** `Icons.payment` or `Icons.account_balance_wallet`
- **Label:** "Payments"
- **Action:** Opens payment recording dialog/page

**Implementation:**
- Add new `QuickActionItem` to `QuickActionMenu` in both apps
- Should appear alongside "Create Order" button
- Available on Home (index 0) and Pending Orders (index 1) pages

### 2. Payment Recording Flow

**User Flow:**
1. User taps "Payments" button
2. Client selection dialog/page opens
3. User selects a client from list (with search functionality)
4. Payment form shows:
   - **Client Name** (read-only, from selection)
   - **Current Balance** (fetched from Client Ledger - read-only)
   - **Payment Amount** (required, numeric input)
   - **Payment Date** (date picker, default: today)
   - **Receipt Photo** (optional, image picker - camera/gallery)
5. User fills form and submits
6. Transaction is created with:
   - `type`: `TransactionType.payment`
   - `category`: `TransactionCategory.income`
   - `status`: `TransactionStatus.completed`
   - `amount`: User input
   - `transactionDate`: User selected date
   - Receipt photo URL (if uploaded to Firebase Storage)
7. Client Ledger is automatically updated via Cloud Function
8. Success message shown, user returned to previous page

**Form Fields:**
- Client Selection: Dropdown/searchable list (similar to order creation)
- Current Balance: Display only (fetch from Client Ledger)
- Payment Amount: Text input (required, numeric, positive)
- Payment Date: Date picker (required, default: today, max: today)
- Receipt Photo: Image picker button (optional)
  - Preview thumbnail if selected
  - Remove option
  - Upload to Firebase Storage before creating transaction

### 3. Payment History Page

**Purpose:** View and manage recent payment transactions

**Page Naming Options:**

**Page Name: "Transactions"** ✅ **SELECTED**
- Clear, professional, encompasses all payment-related transactions
- Route: `/transactions`
- Consistent terminology with transaction system

**Page Features:**
- List of recent payments (paginated or infinite scroll)
- Each item shows:
  - Client name
  - Payment amount
  - Payment date
  - Receipt thumbnail (if available)
  - Current balance at time of payment
- Filter options:
  - By date range
  - By client (search)
  - By amount range
- Sort options:
  - Date (newest first - default)
  - Amount (highest/lowest)
  - Client name
- Actions per payment:
  - View details (modal/dialog)
  - View receipt (full screen image viewer)
  - Cancel/Delete payment (with confirmation)
- Search functionality

**Navigation:**
- Add to main navigation menu (if applicable)
- Accessible from payment form success message
- Possibly from client detail page (if exists)

### 4. Database Schema

**Transaction Document:**
```typescript
{
  transactionId: string,
  organizationId: string,
  clientId: string,
  type: 'payment',
  category: 'income',
  amount: number,
  status: 'completed',
  financialYear: string,
  transactionDate: Timestamp,
  paymentAccountId?: string,
  paymentAccountType?: string,
  referenceNumber?: string,
  receiptPhotoUrl?: string,  // NEW: Firebase Storage URL
  receiptPhotoPath?: string,  // NEW: Storage path for deletion
  description?: string,
  metadata?: {
    recordedVia?: 'quick-action',  // Track where payment was recorded
    photoUploaded?: boolean,
  },
  createdBy: string,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  balanceBefore?: number,
  balanceAfter?: number,
}
```

**Firebase Storage Structure:**
```
payments/
  {organizationId}/
    {clientId}/
      {transactionId}/
        receipt.{jpg|png}
```

**Client Ledger:**
- Automatically updated via existing Cloud Function `onTransactionCreated`
- No schema changes needed
- Balance calculation: `currentBalance - paymentAmount`

### 5. Implementation Structure

#### Android App

**New Files:**
- `lib/presentation/views/payments/record_payment_page.dart`
  - Client selection dialog/page
  - Payment form with all fields
  - Image picker integration
  - Photo upload to Firebase Storage
  - Transaction creation
  
- `lib/presentation/views/payments/payment_history_page.dart`
  - Payment list view
  - Filters and search
  - Payment detail dialog
  - Receipt image viewer
  
- `lib/presentation/blocs/payments/payments_cubit.dart`
  - State management for payment recording
  - State management for payment history
  - Client balance fetching
  
- `lib/presentation/blocs/payments/payments_state.dart`
  - Payment form state
  - Payment history state

**Modified Files:**
- `lib/presentation/widgets/home_workspace_layout.dart`
  - Add Payments button to QuickActionMenu
  
- `lib/presentation/widgets/quick_action_menu.dart`
  - Already supports multiple actions (no changes needed)

**Dependencies:**
- `image_picker: ^1.0.7` (already in pubspec.yaml ✅)
- `firebase_storage: ^11.6.0` (already in pubspec.yaml ✅)

#### Web App

**New Files:**
- `lib/presentation/views/payments/record_payment_view.dart`
- `lib/presentation/views/payments/payment_history_view.dart`
- `lib/presentation/blocs/payments/payments_cubit.dart`
- `lib/presentation/blocs/payments/payments_state.dart`

**Modified Files:**
- `lib/presentation/widgets/section_workspace_layout.dart`
  - Add Payments button to QuickActionMenu

### 6. Transaction Creation Flow

**Steps:**
1. User selects client
2. Fetch current balance from Client Ledger:
   ```dart
   final ledger = await clientLedgerRepository.getClientLedger(
     organizationId: orgId,
     clientId: clientId,
     financialYear: currentFinancialYear,
   );
   final currentBalance = ledger?.currentBalance ?? 0.0;
   ```

3. User fills payment form
4. If photo selected:
   - Compress/resize image (optional, for performance)
   - Upload to Firebase Storage
   - Get download URL
   
5. Create Transaction:
   ```dart
   final transaction = Transaction(
     id: '',  // Auto-generated by Firestore
     organizationId: orgId,
     clientId: clientId,
     type: TransactionType.payment,
     category: TransactionCategory.income,
     amount: paymentAmount,
     status: TransactionStatus.completed,
     financialYear: currentFinancialYear,
     transactionDate: paymentDate,
     receiptPhotoUrl: photoUrl,  // If uploaded
     receiptPhotoPath: storagePath,  // For deletion
     metadata: {
       'recordedVia': 'quick-action',
       'photoUploaded': photoUrl != null,
     },
     createdBy: currentUser.uid,
     createdAt: DateTime.now(),
     updatedAt: DateTime.now(),
   );
   
   await transactionsRepository.createTransaction(transaction);
   ```

6. Cloud Function automatically:
   - Updates Client Ledger (`currentBalance` decreases by payment amount)
   - Updates transaction with `balanceBefore` and `balanceAfter`
   - Updates analytics

### 7. Payment History Features

**Data Fetching:**
- Query transactions collection:
  - `type == 'payment'`
  - `organizationId == currentOrgId`
  - Order by `transactionDate` descending
  - Optional filters: date range, client, amount

**Display:**
- Card-based list
- Each card shows:
  - Client name (with link to client detail if exists)
  - Payment amount (large, prominent)
  - Payment date (formatted)
  - Receipt thumbnail (if available, tappable)
  - Balance before/after (if available)
- Empty state: "No payments recorded yet"

**Actions:**
- Tap card: View payment details
- Long press/Swipe: Delete option (with confirmation)
- Tap receipt thumbnail: Full-screen image viewer

### 8. Error Handling

**Scenarios:**
- Client selection fails → Show error, allow retry
- Balance fetch fails → Show error, allow to proceed with warning
- Photo upload fails → Show error, allow to proceed without photo or retry
- Transaction creation fails → Show error, rollback photo upload (if uploaded)
- Network errors → Show retry option

**Validation:**
- Payment amount: Required, > 0, <= current balance (warning, not error)
- Payment date: Required, cannot be future date
- Client: Required

### 9. UI/UX Considerations

**Payment Form:**
- Modal dialog or full page? → **Recommend full page** for better form UX
- Current balance should be prominently displayed
- Payment amount input should have currency formatting
- Date picker should be intuitive (native picker on mobile)
- Photo picker should show preview immediately

**Payment History:**
- Should match existing list styles (Delivery Memos, Orders, etc.)
- Receipt thumbnails should be small but clear
- Infinite scroll or pagination? → **Recommend infinite scroll** for better UX
- Pull to refresh support

### 10. Security Considerations

**Photo Storage:**
- Use Firebase Storage security rules
- Only authenticated users in organization can upload
- Only organization members can view receipts
- Storage path includes organizationId for isolation

**Transaction Creation:**
- Verify user has permission to create transactions
- Validate organization membership
- Server-side validation via Cloud Functions (already exists)

### 11. Testing Considerations

**Test Cases:**
- Payment recording with photo
- Payment recording without photo
- Payment with future date (should be blocked)
- Payment amount validation
- Client balance update verification
- Payment history pagination
- Receipt viewing
- Payment deletion
- Error handling scenarios

## Implementation Priority

1. **Phase 1:** Payment recording (form, client selection, transaction creation)
2. **Phase 2:** Photo upload and storage
3. **Phase 3:** Payment history page
4. **Phase 4:** Filters, search, and advanced features

## Open Questions

1. **Page Name:** Final decision on "Payment History" vs alternatives?
2. **Photo Storage:** Compression/resizing before upload?
3. **Maximum Photo Size:** What's the limit?
4. **Payment Deletion:** Soft delete (mark as cancelled) or hard delete?
5. **Balance Warning:** Show warning if payment > current balance, or block it?
6. **Navigation:** Add to main navigation menu or only accessible from Quick Action?

## Next Steps

1. Confirm page naming preference
2. Review and approve proposal
3. Create implementation tasks
4. Start with Phase 1 (payment recording form)

