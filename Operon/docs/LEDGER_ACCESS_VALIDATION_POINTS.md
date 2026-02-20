# Ledger Access Validation Points (Driver + Multi-Identity)

This rollout keeps existing users working while enabling stricter ledger access over time.

## Implemented in this change

1. **User schema (backward-compatible)**
   - `trackingEmployeeId`: employee ID used for trip tracking/assignment identity.
   - `ledgerEmployeeIds`: list of employee IDs whose ledgers can be viewed by this user.
   - `defaultLedgerEmployeeId`: preferred default in Driver ledger selector.
   - Legacy `employee_id` remains supported.

2. **Backend validation callable**
   - Function: `validateLedgerAccess`
   - Location: `functions/src/employees/validate-ledger-access.ts`
   - Validates `organizationId + ledgerEmployeeId` for authenticated user.
   - Accepts admin override (`role_in_org`/`role_id`/`roleTitle` == `admin`).
   - Uses fallback user resolution to avoid breakage:
     1. `ORGANIZATIONS/{orgId}/USERS/{auth.uid}`
     2. query by `uid`
     3. query by `phone`

3. **Driver UI selector support**
   - Driver ledger table now resolves selectable ledger IDs from:
     - `ledgerEmployeeIds`
     - `defaultLedgerEmployeeId`
     - `trackingEmployeeId`
     - legacy `employee_id`
   - If multiple ledgers exist, UI shows a selector.

## Firestore Rules hardening strategy (staged)

Current rules remain unchanged for compatibility (`EMPLOYEE_LEDGERS` read allowed for signed-in users).

Recommended production hardening phases:

1. **Phase 1 (now): Observe + audit**
   - Keep current rules.
   - Use `validateLedgerAccess` in app before showing ledger data.
   - Log denied attempts (callable response `allowed=false`).

2. **Phase 2: Add rules helper gates (optional shadow checks)**
   - Add helper functions for org user lookup and allowed ledger IDs.
   - Keep permissive read while collecting false-positive/negative telemetry.

3. **Phase 3: Enforce per-user ledger reads**
   - Restrict `/EMPLOYEE_LEDGERS/{ledgerId}` reads to:
     - org admins, or
     - users where `ledgerId` is in `ledgerEmployeeIds` / equals legacy `employee_id` / equals `trackingEmployeeId`.

4. **Phase 4: Remove legacy fallback**
   - After migration completion, drop dependence on `employee_id`.

## Migration checklist for org USERS docs

- For each driver/loader user document under `ORGANIZATIONS/{orgId}/USERS/{userDocId}`:
  - Set `trackingEmployeeId` (trip execution identity).
  - Set `ledgerEmployeeIds` array (all ledgers user can access).
  - Set `defaultLedgerEmployeeId` (preferred default in UI).
  - Keep `employee_id` during transition.
