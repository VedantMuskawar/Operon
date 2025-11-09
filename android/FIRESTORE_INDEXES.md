# Firestore Structure & Indexes

This document captures the canonical Firestore layout used by Operon across the
Flutter web and Android clients, along with the composite indexes required to
keep critical queries fast. Create the collections, subcollections, and indexes
described below in the Firebase console before enabling new features.

---

## Employees Directory

### Collections & Fields

- **Collection**: `EMPLOYEES` (top-level)
  - `organizationId` (**string**, required) – parent organization document ID.
  - `employeeId` (**string**, required) – duplicated doc ID for convenience.
  - `name` (**string**, required) – legal display name.
  - `nameLowercase` (**string**, required) – `name.toLowerCase()` for search.
  - `roleId` (**string**, required) – reference to `ORGANIZATIONS/{orgId}/ROLES/{roleId}`.
  - `startDate` (**timestamp**, required) – employment start date.
  - `openingBalance` (**number**, required) – starting ledger balance.
  - `openingBalanceCurrency` (**string**, default `INR`) – ISO 4217 code.
  - `status` (**string**, default `active`) – one of `active`, `inactive`, `invited`.
  - `contactEmail` (**string**, optional) – notification email.
  - `contactPhone` (**string**, optional) – E.164 formatted phone.
  - `notes` (**string**, optional) – internal remarks (<= 500 chars).
  - `createdAt` (**timestamp**, required) – audit timestamp.
  - `updatedAt` (**timestamp**, required) – audit timestamp.

- **Subcollection**: `LEDGER` (under `EMPLOYEES/{employeeId}`)
  - Tracks balance adjustments. Each document stores `amount`, `type`,
    `referenceId`, `createdAt`, and `createdBy`. Keep this optional but reserved
    for future financial reconciliations.

- **Subcollection**: `ORGANIZATIONS/{orgId}/ROLES`
  - `roleId` (**string**, required) – duplicated doc ID.
  - `name` (**string**, required) – display label, unique per org.
  - `description` (**string**, optional) – role summary.
  - `permissions` (**array<string>**, optional) – capability flags.
  - `isSystem` (**bool**, default `false`) – locks system-defined roles.
  - `priority` (**number**, optional) – sort order (lower = higher).
  - `wageType` (**string**, required) – one of `hourly`, `quantity`, `monthly`.
  - `quantity` (**number**, optional) – default production quantity for quantity-based wages.
  - `wagePerQuantity` (**number**, optional) – payout per quantity unit.
  - `monthlySalary` (**number**, optional) – base salary for monthly wage roles.
  - `monthlyBonus` (**number**, optional) – default bonus allocation.
  - `compensationFrequency` (**string**, default `monthly`) – payout cadence (`monthly`, `biweekly`, `weekly`, `per_shift`).
  - `createdAt` / `updatedAt` (**timestamp**, required).

### Composite Indexes

Create the following indexes. All fields are in ascending order unless noted.

1. **Employees by organization (default list)**
   - Collection: `EMPLOYEES`
   - Fields: `organizationId`, `nameLowercase`
   - Purpose: supports alphabetical listing with pagination.

2. **Employees filtered by status**
   - Collection: `EMPLOYEES`
   - Fields: `organizationId`, `status`, `nameLowercase`
   - Purpose: enables status filters combined with name sort/search.

3. **Employees filtered by role**
   - Collection: `EMPLOYEES`
   - Fields: `organizationId`, `roleId`, `nameLowercase`
   - Purpose: powers role tabs/filters.

4. **Employees ordered by start date**
   - Collection: `EMPLOYEES`
   - Fields: `organizationId`, `startDate` (Descending)
   - Purpose: supports timeline reports and new-hire insights.

5. **Roles ordered by priority**
   - Collection: `ORGANIZATIONS/{orgId}/ROLES`
   - Fields: `priority`, `name`
   - Purpose: keeps role tables sorted by explicit priority and name fallback.

### Single-Field Indexes (Enable in Console)

- `nameLowercase` (collection-level)
- `status`
- `roleId`
- `startDate`
- `organizationId`

> Tip: In the Firebase console, open **Firestore Database → Indexes → Add
> Index**, then supply the collection and field order exactly as listed. Re-run
> the Flutter app after publishing the index to verify the queries execute
> without warnings.

---

## Existing Composite Indexes

Retain the legacy indexes that power Android-specific queries:

1. **Clients directory**
   - Collection: `CLIENTS`
   - Fields: `organizationId` (Ascending), `name` (Ascending)
   - Purpose: supports paginated client list lookups ordered by `name`.

2. **Pending orders by client**
   - Collection: `ORDERS`
   - Fields: `organizationId` (Ascending), `clientId` (Ascending),
     `createdAt` (Descending)
   - Purpose: backs `watchOrdersByClient` / `getOrdersByClient` which filter by
     organization + client and order by newest first.

3. **Pending orders by status**
   - Collection: `ORDERS`
   - Fields: `organizationId` (Ascending), `status` (Ascending),
     `createdAt` (Descending)
   - Purpose: supports pending-order dashboards scoped to an organization.

