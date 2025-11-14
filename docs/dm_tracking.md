# Delivery Memo (DM) Tracking

## Overview
Delivery Memos are generated per scheduled order and increment sequentially within an organization for each financial year (April 1 – March 31, IST). DM numbers reset to `1` at the start of every new financial year.

## Firestore Schema
- `ORGANIZATIONS/{orgId}/DM_TRACKING/{financialYearId}`
  - `startDmNumber`: integer (default `1`)
  - `currentDmNumber`: integer (latest assigned DM)
  - `lastDmNumber`: integer (previous assigned DM)
  - `lastAssignedOrderId`: string (schedule id that received the most recent DM)
  - `lastOrderId`: string (underlying order id)
  - `lastAssignedAt`: timestamp
  - `updatedAt`: timestamp
  - `createdAt`: timestamp (populated when the FY document is first created)

The `financialYearId` is formatted as `YYYY-YYYY` (e.g., `2024-2025`).

## Generation Flow
1. Clients invoke the callable function `generateDmNumber` with `{ organizationId, scheduleId, orderId? }`.
2. The function runs a Firestore transaction that:
   - Seeds the financial-year tracking document with `startDmNumber = 1` if it does not exist (new FY rollover happens automatically on the first DM request after April 1).
   - Increments `currentDmNumber` and moves the previous value into `lastDmNumber`.
   - Updates the scheduled order (`SCH_ORDERS/{scheduleId}`) with `dmNumber`, `dmFinancialYearId`, and `dmGeneratedAt`.
3. If a DM already exists on the schedule the function short-circuits and returns the existing number.

All updates happen atomically to mitigate race conditions during high-volume generation.

## Client Integration
- Both Operon apps expose a **Generate DM** button against every scheduled order.
- While the callable is executing, the UI shows a loading indicator and disables duplicate submissions.
- Once the function completes, the updated `ScheduledOrder` is reloaded and DM metadata is displayed inline (DM number and generated timestamp).
- Every generation writes a ledger document at `DM_LEDGER/{dmNumber}` with `{ scheduleId, orderId, status: 'active', generatedAt }`.
- If the schedule remains in `scheduled` status, operators can trigger **Cancel DM**, which calls `cancelDmNumber`, clears DM metadata from the schedule, and updates the ledger entry to `status: 'cancelled'` (the numeric sequence is never reused; future DMs simply increment).

## Financial Year Helpers
`FinancialYearUtils` centralizes computations for:
- `financialYearId([date])`
- `startOfFinancialYear([date])`
- `endOfFinancialYear([date])`

Unit tests cover edge cases around March 31 / April 1 to guard against regressions.

## DM Template Designer & Printing
- Organization admins design the standard Delivery Memo layout from the **DM Template Designer** (Web → Organization Management).
- Templates are stored per organisation at `ORGANIZATIONS/{orgId}/DM_TEMPLATES/default`; the designer manages a single A5 landscape preset.
- The layout exposes schedule-order fields (client, address, vehicle, DM number, line items, totals, payment type, etc.), static blocks (signatures, payment QR) and optional watermark/logo positioning.
- Duplicate printing supports colour inversion as a per-template toggle.
- Scheduled Orders surface the generated DM badge as a print action. Clicking it opens the preview page with order data injected into the saved template and offers print/download for original and duplicate variants.

