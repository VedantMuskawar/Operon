# Running Balance Calculation Guide (Legacy Pave Data)

This guide explains how **current/running balance** for clients was maintained in the legacy app and how to **recalculate it in Excel** using your exports: `clients-export`, `sch-orders-export`, and `transactions-export`.

---

## 1. What the legacy app stored

From the legacy Firebase functions you shared:

- **Client document** held a single running balance and components:
  - `totalBalance` — **current balance** (what the client owes the org)
  - `totalCreditFromOrders` — amount from **delivered Pay Later (PL)** orders
  - `totalCashFromOrders` — cash from **delivered Pay on Delivery (POD)** orders (paid; does **not** add to balance)
  - `totalDebitFromTransactions` — sum of all **DEBIT** transaction amounts (charges to client → increase balance)
  - `totalCreditFromTransactions` — sum of all **CREDIT** transaction amounts (credits to client → decrease balance; stored as negative in effect)

Relationship (conceptually):

```text
totalRevenue = totalCashFromOrders + totalCreditFromOrders
totalBalance = totalCreditFromOrders + totalDebitFromTransactions + totalCreditFromTransactions
```

So:

- **Balance** = what client owes = PL delivered amount + DEBIT transactions − CREDIT transactions.
- POD paid (`totalCashFromOrders`) affects revenue but **not** balance (already paid).

---

## 2. Which data to use from each export

### A. `clients-export-*.xlsx`

Use only for **reference / validation**:

| Column to use | Purpose |
|---------------|--------|
| **Document ID** (or `clientID` / `clientId`) | Client key for linking to orders and transactions |
| **totalBalance** (if present) | Legacy stored running balance — compare with your recalc |
| **name** / **clientName** | Labels in your Excel |

If `totalBalance` exists, it is the “source of truth” the app had; your recalculation should match it (or you track down differences).

---

### B. `transactions-export-*.xlsx`

Use for **all payment/charge/credit movements** that change balance.

| Column to use | Purpose |
|---------------|--------|
| **clientID** or **clientId** | Link to client (match clients export Document ID) |
| **category** or **type** | Legacy used `"DEBIT"` / `"CREDIT"` (check exact casing in your export) |
| **amount** | Numeric amount |

Rules:

- **DEBIT** → client was **charged** (balance **increases**): add `amount`.
- **CREDIT** → client was **credited** (e.g. payment; balance **decreases**): subtract `amount`.

So for each client:

```text
From transactions:
  Balance from transactions = SUM(amount where category = DEBIT)
                           − SUM(amount where category = CREDIT)
```

Note: Legacy code used `data.category == "DEBIT"` / `"CREDIT"`. Your export might use `category` or `type`; use whichever column contains `DEBIT` / `CREDIT`. Filter to rows that belong to **client** (e.g. ignore vendor/employee if present).

---

### C. `sch-orders-export-*.xlsx`

Use for **delivered orders only**; only **Pay Later (PL)** adds to balance.

| Column to use | Purpose |
|---------------|--------|
| **clientID** or **clientId** | Link to client |
| **deliveryStatus** | Only use rows where delivered (e.g. `true` or `"true"`) |
| **paySchedule** | `"PL"` = Pay Later, `"POD"` = Pay on Delivery |
| **productUnitPrice** | Unit price |
| **productQuant** or **productQuantity** | Quantity |

Rule:

- Include only rows with **deliveryStatus = delivered** (true).
- For each such row: **order amount** = `productUnitPrice × productQuant` (use `Math.ceil` if you want to match legacy exactly).
- **Only PL** orders add to balance:
  - **paySchedule = "PL"** → add this order amount to client balance.
  - **paySchedule = "POD"** → do **not** add (already paid; like `totalCashFromOrders`).

So for each client:

```text
From orders:
  Balance from orders = SUM( productUnitPrice × productQuant )
                       over rows where:
                         clientID = this client
                         deliveryStatus = delivered
                         paySchedule = "PL"
```

---

## 3. Formula for current/running balance in Excel

Conceptually:

```text
Running balance (per client) = Balance from orders + Balance from transactions
```

Where:

1. **Balance from orders**  
   Sum of `(productUnitPrice × productQuant)` for that client, **only** delivered **PL** orders.

2. **Balance from transactions**  
   For that client: sum of amounts where **category/type = DEBIT** minus sum of amounts where **category/type = CREDIT**.

So:

```text
Running balance = [Sum of PL delivered order amounts] + [Sum(DEBIT amounts) − Sum(CREDIT amounts)]
```

- **Clients export**: use `Document ID` (or `clientID`/`clientId`) to join.
- **Transactions**: group by client ID; use `category` or `type` and `amount` as above.
- **Sch-orders**: filter delivered + PL, then group by client ID and sum order amount.

---

## 4. Step-by-step in Excel

1. **Transactions sheet**
   - Ensure you have columns: client id, category/type, amount.
   - For each client:
     - Sum `amount` where category/type = **DEBIT** → e.g. `SUMIFS(amount, clientId, client, category, "DEBIT")`.
     - Sum `amount` where category/type = **CREDIT** → e.g. `SUMIFS(amount, clientId, client, category, "CREDIT")`.
     - Balance from transactions = DEBIT sum − CREDIT sum.

2. **Sch-orders sheet**
   - Add a computed column: **order amount** = `productUnitPrice * productQuant` (or `ROUNDUP(...)` if matching legacy).
   - Filter: `deliveryStatus` = delivered and `paySchedule` = `"PL"`.
   - Per client: sum **order amount** → this is “Balance from orders”.

3. **Per-client running balance**
   - For each client (e.g. from clients sheet):
     - Running balance = (Balance from orders for this client) + (Balance from transactions for this client).

4. **Check**
   - If clients export has **totalBalance**, compare your running balance to it; differences mean either missing rows, wrong filters, or a different formula in the app (e.g. `clearBalance` logic).

---

## 5. Important caveats from legacy code

- **clearBalance**  
  Some transactions had `clearBalance == true` and also updated `ANNUAL.totalRevenue`. That does **not** change the main client balance formula above; it only adjusted revenue for a specific year. For **running balance**, you still use: PL delivered orders + DEBIT − CREDIT.

- **Financial year**  
  Legacy used April–March years for ANNUAL. For **current balance** you don’t need to split by year: use all delivered PL orders and all transactions.

- **Field names**  
  Legacy used `clientID`, `category` (DEBIT/CREDIT). Your export might have `clientId`, `type`, or different casing. Use the columns that actually contain client id and DEBIT/CREDIT.

- **POD orders**  
  Delivered POD orders do **not** increase balance (they’re paid). Only **PL** delivered orders do.

---

## 6. Quick reference

| Source | What to use | Effect on balance |
|--------|-------------|--------------------|
| **clients-export** | `totalBalance` (if present) | Reference only; compare with recalc |
| **transactions-export** | `clientID`/`clientId`, `category` or `type`, `amount` | DEBIT → +amount, CREDIT → −amount |
| **sch-orders-export** | `clientID`/`clientId`, `deliveryStatus`, `paySchedule`, `productUnitPrice`, `productQuant` | Only **delivered + PL**: add (productUnitPrice × productQuant) |

**Running balance** = Sum(PL delivered order amounts) + Sum(DEBIT) − Sum(CREDIT), per client.
