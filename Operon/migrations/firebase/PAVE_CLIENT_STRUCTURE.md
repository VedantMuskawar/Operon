# Pave Legacy Database - Client Data Structure Investigation

## Purpose

Before exporting client data from Pave (Legacy Database), we need to understand how Pave stored client information, especially:
1. **Collection name** - What collection did Pave use for clients?
2. **Balance storage** - Where did Pave store client balance/currentBalance?
3. **Field naming** - What field names did Pave use?

## Key Questions to Answer

### 1. Collection Name
- Did Pave use `CLIENTS`, `Clients`, `clients`, or a different collection name?
- Check the Firestore console or export scripts to confirm.

### 2. Balance Storage Location

**Option A: Balance in Client Document**
- Did Pave store balance directly in the client document?
- Field names to check:
  - `balance`
  - `currentBalance`
  - `current_balance`
  - `balanceAmount`
  - `outstandingBalance`
  - `receivables`
  - `amountDue`

**Option B: Separate Ledger Collection**
- Did Pave use a separate collection for balances?
- Possible collection names:
  - `CLIENT_LEDGERS`
  - `ClientLedgers`
  - `client_ledgers`
  - `BALANCES`
  - `ClientBalances`
  - `ACCOUNTS_RECEIVABLE`

**Option C: Balance in Transactions**
- Did Pave calculate balance from transactions?
- Check if there's a `TRANSACTIONS` or `TRANSACTION_HISTORY` collection
- Balance might need to be calculated by summing transactions

### 3. Field Naming Conventions

Based on the SCH_ORDERS export script, Pave used mixed naming:
- `clientID` (camelCase with capital ID)
- `clientId` (camelCase)
- `orgID` (camelCase with capital ID)
- `organizationId` (camelCase)

**Client fields to check:**
- `clientID` vs `clientId` vs `client_id`
- `name` vs `clientName` vs `Name`
- `phone` vs `phoneNumber` vs `primaryPhone` vs `Phone`
- `orgID` vs `organizationId` vs `org_id`
- `status` vs `Status` vs `clientStatus`
- `tags` vs `Tags` vs `clientTags`

### 4. Phone Number Format

- How did Pave store phone numbers?
  - Single field: `phone`, `phoneNumber`, `primaryPhone`
  - Array: `phones[]`
  - Object: `phones: [{number, type}]`
- Format: E.164, local format, or other?

### 5. Financial Year Handling

- Did Pave track balances by financial year?
- If yes, how?
  - Separate documents per FY: `{clientId}_FY2526`
  - Array of balances: `balances: [{year, amount}]`
  - Single balance field (current only)

## Investigation Steps

### Step 1: Connect to Pave Firebase Project
1. Get Pave Firebase service account credentials
2. Initialize Firebase Admin SDK with Pave project
3. List available collections

### Step 2: Inspect Client Collection
```javascript
// Sample inspection script
const clientsRef = db.collection('CLIENTS'); // Try different names
const sampleClient = await clientsRef.limit(1).get();
console.log('Sample client document:', sampleClient.docs[0]?.data());
console.log('Document ID:', sampleClient.docs[0]?.id);
```

### Step 3: Check for Balance Fields
- Inspect a few client documents
- Look for any balance-related fields
- Note field names and data types

### Step 4: Check for Ledger Collection
- Try querying different ledger collection names
- Check if balances are stored separately

### Step 5: Check Transaction History
- Look for transaction collections
- See if balance can be calculated from transactions

## Expected Findings

Based on the current Operon system structure:

### Current Operon Structure:
- **Collection**: `CLIENTS`
- **Balance Location**: `CLIENT_LEDGERS` collection
- **Ledger Document ID**: `{clientId}_FY2526` (format: `{clientId}_FY{startYear}{endYear}`)
- **Balance Field**: `currentBalance` (number)
- **Client Fields**: 
  - `clientId` (string)
  - `name` (string)
  - `name_lc` (string, lowercase for search)
  - `primaryPhone` (string, E.164)
  - `phones` (array of objects: `[{e164, label}]`)
  - `phoneIndex` (array of strings)
  - `tags` (array of strings)
  - `status` (string)
  - `organizationId` (string)
  - `stats` (object: `{orders, lifetimeAmount}`)
  - `contacts` (array)
  - `createdAt`, `updatedAt` (timestamps)

### Possible Pave Differences:
1. **Field naming**: `clientID` instead of `clientId`
2. **Balance in client doc**: May have `balance` or `currentBalance` directly in client document
3. **No financial year separation**: Single balance field instead of FY-based ledgers
4. **Different phone format**: May use single `phone` field instead of `phones` array
5. **Collection name**: May use different case or name

## Action Items

1. **Connect to Pave Firebase** and inspect actual client documents
2. **Document the exact field names** used in Pave
3. **Determine balance storage method** (in client doc vs separate collection)
4. **Create mapping** between Pave fields and Operon fields
5. **Update CLIENT_FORMAT.md** with Pave-specific export instructions

## Next Steps After Investigation

Once we understand Pave's structure:
1. Create export script that reads from Pave's actual structure
2. Map Pave fields to Operon format
3. Handle balance extraction (from client doc or ledger collection)
4. Create import script that transforms Pave data to Operon format
