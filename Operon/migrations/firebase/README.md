# Dash Data Migrations

This workspace hosts one-off scripts for copying data from the legacy Firebase project into the new Dash Firebase project. The scripts run outside of Cloud Functions so they can talk to two Firestore instances in the same process.

## Prerequisites

1. Install dependencies:
   ```bash
   cd migrations/firebase
   npm install
   ```
2. Create service-account JSON files for both projects:
   - `creds/legacy-service-account.json`
   - `creds/new-service-account.json`

   > Add the `creds/` directory to `.gitignore` so secrets never enter source control.

3. Copy `.env.example` to `.env` and update the paths if you prefer environment variables over hard-coded paths.

## Running the sample clients migration

```bash
npm run start
```

The default script `src/migrate-clients.ts`:
- Reads every document under `CLIENTS` in the legacy project
- Applies an optional transform hook (update fields, remap org IDs, etc.)
- Batches writes into the new project (merge mode)
- Logs a short summary when complete

Feel free to add additional scripts (e.g. `migrate-orders.ts`) and wire them up via new npm scripts.
