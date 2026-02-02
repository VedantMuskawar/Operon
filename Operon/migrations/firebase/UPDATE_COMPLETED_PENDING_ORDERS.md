# Update completed Pending Orders (hide from UI)

## Why

After migrating data into `PENDING_ORDERS`, all those orders may be fully completed (no trips left to schedule). The UI only shows orders that are **pending** and have **available trips** (`estimatedTrips > scheduledTrips` for at least one item). Orders with no available trips can still appear if their `status` is `null` or `'pending'`, so this script marks or removes them.

## What the script does

- **Finds** every `PENDING_ORDERS` document where **no** item has `estimatedTrips > scheduledTrips` (fully completed).
- **Update mode (default):** Sets `status: 'completed'` and `updatedAt`. They no longer match the UI filter and disappear from Pending Orders.
- **Delete mode:** Deletes the document. The Cloud Function **onOrderDeleted** runs and cleans up related transactions and marks trips with `orderDeleted`.

## Usage

From `migrations/firebase`:

```bash
# Uses TARGET (Operon) service account by default:
#   creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json
# Or set TARGET_SERVICE_ACCOUNT=/path/to/operon-service-account.json

# Dry run – only log what would be updated/deleted
npm run update-completed-pending-orders -- --dry-run

# Update fully completed orders to status 'completed' (default)
npm run update-completed-pending-orders -- --update

# Delete fully completed orders (triggers onOrderDeleted)
npm run update-completed-pending-orders -- --delete
```

## Options

| Option     | Description |
|-----------|-------------|
| `--dry-run` | Do not write; only print which orders would be updated or deleted. |
| `--update`  | Set `status: 'completed'` so they hide from the UI (default). |
| `--delete`  | Delete the document; Cloud Function will clean up. |

## Credentials (target database only)

Same pattern as export scripts: export scripts use **LEGACY_SERVICE_ACCOUNT** / `creds/legacy-service-account.json` for the legacy (Pave) project. This script uses **TARGET** only:

- **TARGET_SERVICE_ACCOUNT**: Path to the TARGET (Operon) Firebase service account JSON.
- Default path: `creds/operonappsuite-firebase-adminsdk-fbsvc-36a27b214e.json`.
- Optional: **TARGET_PROJECT_ID** to override project ID.

## Cloud Function reference

When you **delete** an order document, the function **onOrderDeleted** in `functions/src/orders/order-handlers.ts` runs. It:

- Deletes associated transactions (and ledger/analytics are reverted by existing handlers).
- Marks related schedule trips with `orderDeleted: true` (audit only; trips are not deleted).
