# TRANSACTIONS Export/Import Format

## Overview

This document describes the format for exporting the **full TRANSACTIONS collection** from the Legacy Database (Pave) and importing it into the new Database (Operon).

## Export Requirements

**Export the complete TRANSACTIONS collection:**
- **All documents** from the TRANSACTIONS collection (no filters)
- **All fields** from each transaction document
- Include **Document ID** as the first column

## Collection Name

The collection name in Pave may be:
- `TRANSACTIONS` (most likely)
- `Transactions`
- `transactions`
- `TRANSACTION_HISTORY`

**Verify the exact collection name** in the Legacy Firebase console before exporting.

## Excel/CSV Format

### Export All Fields

**Export ALL fields from each TRANSACTIONS document.** Common fields to expect:

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| **Document ID** | ✅ | String | Firestore document ID | `txn-abc123` |
| **transactionId** | String | Transaction ID | `txn-abc123` |
| **organizationId** or **orgID** | String | Organization ID | `org-id-123` |
| **clientId** or **clientID** | String | Client document ID | `client-456` |
| **clientName** | String | Client name (denormalized) | `ABC Construction` |
| **vendorId** | String | Vendor document ID (if vendor transaction) | `vendor-789` |
| **employeeId** | String | Employee document ID (if employee transaction) | `emp-101` |
| **ledgerType** | String | Ledger type | `clientLedger`, `vendorLedger`, `employeeLedger` |
| **type** | String | Transaction type | `credit`, `debit` |
| **category** | String | Transaction category | `clientPayment`, `clientCredit`, `tripPayment`, `advance`, `expense`, etc. |
| **amount** | Number | Transaction amount | `5000.00` |
| **currency** | String | Currency code | `INR` |
| **paymentAccountId** | String | Payment account document ID | `account-123` |
| **paymentAccountName** | String | Payment account name | `Cash Account` |
| **paymentAccountType** | String | Payment account type | `bank`, `cash`, `upi`, `other` |
| **referenceNumber** | String | Reference number | `REF-12345` |
| **tripId** or **orderId** | String | Trip/Order document ID | `trip-789` |
| **description** | String | Transaction description | `Payment received` |
| **metadata** | Object/JSON | Additional metadata | `{"dmNumber": 12345}` |
| **financialYear** | String | Financial year | `FY2526`, `FY2425` |
| **balanceBefore** | Number | Balance before transaction | `10000.00` |
| **balanceAfter** | Number | Balance after transaction | `15000.00` |
| **createdBy** | String | User ID who created | `user-123` |
| **createdAt** | Timestamp | Creation timestamp | `2026-01-15T10:30:00Z` |
| **updatedAt** | Timestamp | Last update timestamp | `2026-01-15T10:30:00Z` |
| **... (any other fields)** | Various | Any additional fields in Pave | — |

### Notes

1. **Export ALL fields**: Don't filter fields - export everything that exists in the document
2. **Field name variations**: Pave may use different field names (e.g., `clientID` vs `clientId`, `orgID` vs `organizationId`)
3. **Nested objects**: Export nested objects/arrays (like `metadata`) as JSON strings
4. **Timestamps**: Export as ISO 8601 format strings
5. **Ledger Types**: May include `clientLedger`, `vendorLedger`, `employeeLedger`, or other types

### Export Format Guidelines

1. **Document ID**: Always include as first column
2. **All Fields**: Export every field that exists in the document
3. **Nested Data**: Export objects/arrays (like `metadata`) as JSON strings
4. **Timestamps**: Convert to ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)
5. **Null/Undefined**: Use empty string or "null" for missing values
6. **Field Name Preservation**: Keep original Pave field names (don't rename yet)

## Export Process

1. **Connect to Legacy Database**
   - Use Legacy Firebase service account
   - Initialize Firebase Admin SDK
   - Verify collection name (`TRANSACTIONS`, `Transactions`, etc.)

2. **Export All Documents**
   - Query entire collection (no filters)
   - Export all fields from each document
   - Include document ID
   - Save to Excel format

3. **Export Script Example**
   ```javascript
   const transactionsRef = db.collection('TRANSACTIONS'); // Verify exact name
   const allTransactions = await transactionsRef.get();
   
   const rows = allTransactions.docs.map(doc => ({
     'Document ID': doc.id,
     ...doc.data() // Export all fields
   }));
   ```

## Import Process (After Export)

1. **Review exported data** - Check field names and structure
2. **Map Pave fields to Operon format** - Transform field names
3. **Normalize data** - Format dates, amounts, ledger types
4. **Filter by ledger type** - Import clientLedger transactions first
5. **Import into new Database** - Use import scripts

## Transaction Categories (Operon)

Common transaction categories in Operon:
- `advance` - Advance payment
- `clientCredit` - Credit to client (receivable created)
- `clientPayment` - Payment from client
- `tripPayment` - Payment related to trip
- `refund` - Refund to client
- `adjustment` - Balance adjustment
- `expense` - Expense transaction
- `purchase` - Purchase transaction

## Financial Year Format

Financial years are formatted as:
- `FY2526` = Financial Year 2025-26 (April 1, 2025 to March 31, 2026)
- `FY2425` = Financial Year 2024-25 (April 1, 2024 to March 31, 2025)

## Related Collections

- **TRANSACTIONS**: Target collection in new Database
- **CLIENT_LEDGERS**: Updated automatically when client transactions are imported
- **CLIENTS**: Client references must exist
- **SCHEDULE_TRIPS**: Trip references (for tripPayment/clientCredit transactions)
