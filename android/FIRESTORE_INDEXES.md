# Firestore Indexes for Android Client

The Android client issues a handful of compound queries that require indexes on
Firestore. Create the following composite indexes in the Firebase console to
prevent runtime index errors and keep queries fast:

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

> Tip: In the Firebase console, open **Firestore Database → Indexes → Add
> Index**, then supply the collection and field order exactly as listed. Re-run
> the Flutter app after publishing the index to verify the queries execute
> without warnings.

