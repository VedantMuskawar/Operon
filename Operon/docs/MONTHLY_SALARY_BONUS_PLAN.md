# Monthly Salary and Bonus Page – Plan (Web App, Admin-Only)

This document updates the design for the **Monthly Salary & Bonus** feature with:

1. **Scope: Web app only** – Implementation is in **Operon_Client_web** only. No Android (Operon_Client_android) changes for this feature.
2. **Access: Admin-only** – The page and its entry point are visible and accessible only to users with admin role.

---

## Access control (admin-only)

### Route guard (`/monthly-salary-bonus`)

- In [app_router.dart](Operon/apps/Operon_Client_web/lib/config/app_router.dart), in the route’s `redirect` (or before building the page), require **admin**:
  - Read `OrganizationContextCubit` → `appAccessRole`.
  - If `appAccessRole?.isAdmin != true`, redirect to `/home` (or show an “Access denied” view).
  - Same pattern as other admin-only routes; you can mirror the structure used for routes that pass `isAdmin` (e.g. zones page with `isAdmin: appAccessRole.isAdmin`).

### Home Overview tile

- In [home_page.dart](Operon/apps/Operon_Client_web/lib/presentation/views/home_page.dart), show the **“Monthly Salary & Bonus”** tile only when the user is admin:
  - Use **only** `isAdmin` (e.g. `appAccessRole?.isAdmin ?? false`), **not** `canAccessPage('employees')`.
  - Example: `if (isAdmin) { financialTiles.add(_TileData(..., label: 'Monthly Salary & Bonus', onTap: () => context.go('/monthly-salary-bonus'))); }`

### Settings / sidebar (if you add a link later)

- Any future link to “Monthly Salary & Bonus” from the settings sidebar (e.g. in [section_workspace_layout.dart](Operon/apps/Operon_Client_web/lib/presentation/widgets/section_workspace_layout.dart)) should also be gated by **admin only** (`isAdminRole` / `appAccessRole?.isAdmin`).

---

## Web app scope

- **Implement only in:** `Operon/apps/Operon_Client_web/`
- **Do not add:** Equivalent page, route, or nav in `Operon_Client_android`. The existing Employee Wages flow on Android remains unchanged.
- **Shared packages:** Use existing `core_models`, `core_datasources`, `core_ui`, etc. from packages/ as needed; any new code specific to this page (cubit, repository adapters, datasource for bonus settings) lives under the web app or, if reusable, in a shared package.

---

## Summary of changes from original plan

| Item | Original | Updated |
|------|----------|--------|
| Platform | Implied both web and possibly Android | **Web app only** (Operon_Client_web) |
| Page access | “Admin or employees/financial access” | **Admin only** (`appAccessRole.isAdmin`) |
| Route redirect | Same as employee-wages | **Redirect non-admin to `/home`** |
| Home tile visibility | `canAccessPage('employees')` or admin | **Admin only** |

The rest of the design (UI layout, bonus settings by role, month picker, employees table, single “Record for selected” button, database schema for bonus settings, use of existing `createSalaryTransaction` / `createBonusTransaction`, and Firestore triggers) remains as in the original plan.
