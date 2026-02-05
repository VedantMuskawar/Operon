# Transaction Analytics Document: Builders vs UI

This document describes how the **transaction analytics** Firestore document is built (backend) and consumed (UI), and how they stay aligned.

## Document identity

- **Collection:** `ANALYTICS`
- **Document ID:** `transactions_{organizationId}_{financialYear}` (e.g. `transactions_NlQgs9kADbZr4ddBRkhS_FY2526`)

---

## Backend: who writes this document

Two code paths write or merge into this document:

### 1. Incremental updates — `functions/src/transactions/transaction-handlers.ts`

- **When:** On each transaction **create** or **delete** (cancellation).
- **Function:** `updateTransactionAnalytics(organizationId, financialYear, transaction, transactionDate, isCancellation)`.
- **Semantics:**
  - **Income** = `ledgerType === 'clientLedger'` and `type === 'debit'` (money received).
  - **Receivables** = `ledgerType === 'clientLedger'` and `type === 'credit'` (amount owed by client).
- **Fields written:**

| Field | Type | Notes |
|-------|------|--------|
| `source` | string | `"transactions"` |
| `organizationId` | string | |
| `financialYear` | string | e.g. `FY2526` |
| `incomeDaily` | map (date → number) | Last 90 days kept |
| `receivablesDaily` | map (date → number) | Last 90 days kept |
| `incomeWeekly` | map (week → number) | |
| `receivablesWeekly` | map (week → number) | |
| `incomeMonthly` | map (YYYY-MM → number) | |
| `receivablesMonthly` | map (YYYY-MM → number) | |
| `incomeByCategory` | map (category → number) | |
| `receivablesByCategory` | map (category → number) | |
| `byType` | map | Keys: `credit`, `debit`. Each: `count`, `total`, `daily`, `weekly`, `monthly`. |
| `byPaymentAccount` | map | Per-account: `accountId`, `accountName`, `accountType`, `count`, `total`, `daily`, `weekly`, `monthly`. |
| `byPaymentMethodType` | map | e.g. `cash`, `bank`. Each: `count`, `total`, `daily`, `weekly`, `monthly`. |
| `totalIncome` | number | Sum of `incomeMonthly` |
| `totalReceivables` | number | Sum of `receivablesMonthly` |
| `netReceivables` | number | `totalReceivables - totalIncome` |
| `receivableAging` | map | `current`, `days31to60`, `days61to90`, **`over90`** (backend uses this key) |
| `transactionCount` | number | |
| `lastUpdated` | Timestamp | Server timestamp |

### 2. Full rebuild — `functions/src/transactions/transaction-rebuild.ts`

- **When:** Rebuild job (e.g. unified analytics rebuild).
- **Function:** `rebuildTransactionAnalyticsForOrg(organizationId, financialYear)`.
- **Semantics (aligned with handler for Transaction Analytics):**
  - **Income** = `ledgerType === 'clientLedger'` and `type === 'debit'` (same as handler).
  - **Receivables** = `ledgerType === 'clientLedger'` and `type === 'credit'` (same as handler).
  - **Expense** = `category !== 'income'` (for expense-only analytics).
- **Fields written:** Same top-level fields as handler for income/receivables (`incomeDaily`, `receivablesDaily`, `incomeMonthly`, `receivablesMonthly`, `incomeWeekly`, `receivablesWeekly`, `totalIncome`, `totalReceivables`, `netReceivables`, `receivableAging`). **Additionally** writes `expenseDaily`, `expenseWeekly`, `expenseMonthly`, `totalExpense`, `netIncome`, `completedTransactionCount`, `totalPayableToVendors`, fuel-related maps, etc.
- **Receivable aging:** Rebuild writes `receivableAging` with `current: totalReceivables` and other buckets 0 (no per-bucket aging in full rebuild).

---

## UI: how the document is read

### Fetch

- **Repository:** `apps/Operon_Client_web/lib/data/repositories/analytics_repository.dart`
  - `fetchTransactionAnalytics(orgId, fy)` → document ID `transactions_{orgId}_{fy}`.
- **Model:** `packages/core_models/lib/dashboard/transaction_analytics.dart` — `TransactionAnalytics.fromJson(payload)`.

### Fields the UI uses

| UI / Model field | Source in document | Fallback if missing/empty |
|------------------|--------------------|----------------------------|
| `incomeDaily` | `incomeDaily` | `byType.debit.daily` |
| `incomeMonthly` | `incomeMonthly` | `byType.debit.monthly` |
| `totalIncome` | `totalIncome` | `byType.debit.total` |
| `receivablesDaily` | `receivablesDaily` | `byType.credit.daily` |
| `receivablesMonthly` | `receivablesMonthly` | `byType.credit.monthly` |
| `totalReceivables` | `totalReceivables` | `byType.credit.total` (only if current ≤ 0) |
| `netReceivables` | `netReceivables` | (optional) |
| `receivableAging` | `receivableAging` | — |
| `generatedAt` | `generatedAt` **or** `lastUpdated` | — |

### Backend/UI alignment notes

- **Timestamp:** Backend writes `lastUpdated`; UI accepts `generatedAt` or `lastUpdated`. No change needed.
- **Receivable aging key:** Backend uses `over90`; UI reads `daysOver90 ?? over90`. No change needed.
- **After a rebuild:** Top-level `receivables*` and `receivableAging` are not set; UI uses `byType.credit` for receivables series and total. Receivable aging donut may be empty until the next incremental update.

---

## Keeping builders and UI aligned

1. **Handler** is the source of truth for **client-ledger** income/receivables semantics. Any new top-level field the UI needs for Transaction Analytics should be written in `updateTransactionAnalytics` and in **rebuild**.
2. **Rebuild** uses the same rules as the handler for income/receivables (`clientLedger` + debit/credit) and writes `receivables*`, `totalReceivables`, `netReceivables`, and `receivableAging`, so the UI gets a consistent document after either incremental updates or full rebuild.
3. **core_models** `TransactionAnalytics.fromJson` should keep accepting both `lastUpdated`/`generatedAt` and `over90`/`daysOver90`, and the existing byType fallbacks for backward compatibility with older documents.
