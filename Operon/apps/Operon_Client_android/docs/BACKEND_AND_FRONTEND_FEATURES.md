# Backend and Frontend Features Documentation

This document provides a comprehensive overview of all backend and frontend features implemented in the Dash Mobile application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Authentication & Authorization](#authentication--authorization)
3. [Core Features](#core-features)
4. [Frontend Pages & Views](#frontend-pages--views)
5. [State Management](#state-management)
6. [Navigation & Routing](#navigation--routing)
7. [Services & Repositories](#services--repositories)
8. [UI Components](#ui-components)
9. [Data Flow](#data-flow)

---

## Architecture Overview

### Tech Stack

**Frontend:**
- **Framework:** Flutter (Dart)
- **State Management:** BLoC (Business Logic Component) pattern
- **Navigation:** GoRouter
- **UI:** Material Design with custom theme
- **Dependencies:**
  - `flutter_bloc` - State management
  - `go_router` - Navigation
  - `cloud_firestore` - Firebase Firestore
  - `firebase_auth` - Firebase Authentication
  - `flutter_contacts` - Contact access
  - `qr_flutter` - QR code generation

**Backend:**
- **Database:** Firebase Firestore
- **Functions:** Firebase Cloud Functions (TypeScript)
- **Authentication:** Firebase Phone Authentication
- **Storage:** Firebase Storage (if used)

### Project Structure

```
apps/dash_mobile/
├── lib/
│   ├── config/              # App configuration (router, theme)
│   ├── data/               # Data layer
│   │   ├── datasources/    # Firebase data sources
│   │   ├── repositories/   # Repository implementations
│   │   └── services/       # Business logic services
│   ├── domain/             # Domain layer
│   │   ├── entities/       # Domain models
│   │   └── repositories/   # Repository interfaces
│   └── presentation/       # Presentation layer
│       ├── blocs/          # BLoC state management
│       ├── views/          # UI pages/screens
│       └── widgets/        # Reusable widgets
└── functions/              # Firebase Cloud Functions
    └── src/
        └── index.ts        # Function definitions
```

---

## Authentication & Authorization

### Authentication Flow

1. **Phone Input Page** (`/login`)
   - User enters phone number
   - Validates phone format
   - Navigates to OTP verification

2. **OTP Verification Page** (`/otp`)
   - Receives phone number from query params
   - Sends OTP via Firebase Auth
   - Verifies OTP code
   - Creates/updates user in Firestore
   - Navigates to organization selection

3. **Organization Selection Page** (`/org-selection`)
   - Fetches user's organizations from Firestore
   - Displays list of organizations user belongs to
   - User selects organization
   - Loads organization context (role, permissions)
   - Navigates to home page

### Authorization

**Role-Based Access Control (RBAC):**
- Each user has a role in each organization
- Roles define:
  - Section access (pendingOrders, scheduleOrders, ordersMap, analyticsDashboard)
  - CRUD permissions (create, edit, delete) for resources
  - Page access (vehicles, etc.)
  - Admin status

**Permission Checks:**
- Implemented in `OrganizationRole` entity
- Methods: `canAccessSection()`, `canCreate()`, `canEdit()`, `canDelete()`, `canAccessPage()`
- Enforced at route level and UI level

**Files:**
- `lib/domain/entities/organization_role.dart`
- `lib/presentation/blocs/org_context/org_context_cubit.dart`
- `lib/data/repositories/auth_repository.dart`

---

## Core Features

### 1. Clients Management

**Purpose:** Manage customer/client information.

**Features:**
- Create new clients with name, phone, tags
- Search clients by name or phone
- View recent clients
- Add multiple contacts to a client
- Update primary phone
- Delete clients
- View client details with analytics
- Client analytics dashboard

**Data Model:**
- Collection: `CLIENTS` (global)
- Fields: name, phones, tags, contacts, organizationId

**Backend:**
- `lib/data/services/client_service.dart` - Client CRUD operations
- `lib/data/repositories/clients_repository.dart` - Repository interface
- Firebase Function: `onClientCreated` - Analytics update
- Firebase Function: `onClientCreatedSendWhatsappWelcome` - WhatsApp welcome

**Frontend:**
- `lib/presentation/views/clients_page.dart` - Main clients list
- `lib/presentation/views/clients_page/client_detail_page.dart` - Client details
- `lib/presentation/views/clients_page/client_analytics_page.dart` - Analytics
- `lib/presentation/views/clients_page/contact_page.dart` - Add/edit client
- `lib/presentation/blocs/clients/clients_cubit.dart` - State management

**Key Operations:**
```dart
// Search clients
repository.searchClients(query);

// Stream recent clients
repository.recentClientsStream(limit: 10);

// Create client
service.createClient(
  name: name,
  primaryPhone: phone,
  phones: phones,
  tags: tags,
  organizationId: orgId,
);
```

---

### 2. Products Management

**Purpose:** Manage organization product catalog.

**Features:**
- Create, edit, delete products
- Set product price and GST
- Manage product status (active, paused, archived)
- Track stock quantity
- View products list

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/PRODUCTS`
- Fields: name, unitPrice, gstPercent, status, stock

**Backend:**
- `lib/data/datasources/products_data_source.dart`
- `lib/data/repositories/products_repository.dart`

**Frontend:**
- `lib/presentation/views/products_page.dart`
- `lib/presentation/blocs/products/products_cubit.dart`

**Permissions:**
- `canCreate('products')`
- `canEdit('products')`
- `canDelete('products')`

---

### 3. Employees Management

**Purpose:** Manage organization employees.

**Features:**
- Create, edit, delete employees
- Assign roles to employees
- Set salary type (fixed, commission, hybrid)
- Set salary amount
- Link employees to users

**Data Model:**
- Collection: `EMPLOYEES` (global)
- Fields: employeeName, organizationId, roleId, roleTitle, salaryType, salaryAmount

**Backend:**
- `lib/data/datasources/employees_data_source.dart`
- `lib/data/repositories/employees_repository.dart`

**Frontend:**
- `lib/presentation/views/employees_page.dart`
- `lib/presentation/blocs/employees/employees_cubit.dart`

**Permissions:**
- `canCreate('employees')`
- `canEdit('employees')`
- `canDelete('employees')`

---

### 4. Users Management

**Purpose:** Manage organization users and their roles.

**Features:**
- View organization users
- Add users to organization
- Assign roles to users
- Remove users from organization
- Link users to employees

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/USERS`
- Also updates: `USERS/{userId}/ORGANIZATIONS/{orgId}`

**Backend:**
- `lib/data/datasources/users_data_source.dart`
- `lib/data/repositories/users_repository.dart`

**Frontend:**
- `lib/presentation/views/users_page.dart`
- `lib/presentation/blocs/users/users_cubit.dart`

**Permissions:**
- Admin-only access

---

### 5. Roles Management

**Purpose:** Define and manage organization roles with permissions.

**Features:**
- Create, edit, delete roles
- Configure section access
- Configure CRUD permissions for resources
- Set admin status
- Assign roles to users

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/ROLES`
- Fields: title, isAdmin, permissions (nested object)

**Backend:**
- `lib/data/datasources/roles_data_source.dart`
- `lib/data/repositories/roles_repository.dart`

**Frontend:**
- `lib/presentation/views/roles_page.dart`
- `lib/presentation/blocs/roles/roles_cubit.dart`

**Permissions:**
- Admin-only access

---

### 6. Delivery Zones Management

**Purpose:** Manage delivery zones, cities, and zone-specific pricing.

**Features:**
- Create, edit, delete delivery zones
- Manage delivery cities
- Set zone-specific product prices
- View zones by city and region

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/DELIVERY_ZONES`
- Subcollection: `DELIVERY_ZONES/{zoneId}/PRICES/{productId}`
- Collection: `ORGANIZATIONS/{orgId}/DELIVERY_CITIES`

**Backend:**
- `lib/data/datasources/delivery_zones_data_source.dart`
- `lib/data/repositories/delivery_zones_repository.dart`

**Frontend:**
- `lib/presentation/views/zones_page.dart`
- `lib/presentation/blocs/delivery_zones/delivery_zones_cubit.dart`

**Permissions:**
- `canCreate('zonesCity')`, `canEdit('zonesCity')`, `canDelete('zonesCity')`
- `canCreate('zonesRegion')`, `canEdit('zonesRegion')`, `canDelete('zonesRegion')`
- `canCreate('zonesPrice')`, `canEdit('zonesPrice')`, `canDelete('zonesPrice')`

---

### 7. Payment Accounts Management

**Purpose:** Manage payment accounts (UPI, bank accounts, etc.).

**Features:**
- Create, edit, delete payment accounts
- Set primary payment account
- Generate QR codes for UPI accounts
- View payment accounts list

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/PAYMENT_ACCOUNTS`
- Fields: name, type, details (type-specific), isPrimary

**Backend:**
- `lib/data/datasources/payment_accounts_data_source.dart`
- `lib/data/repositories/payment_accounts_repository.dart`

**Frontend:**
- `lib/presentation/views/payment_accounts_page.dart`
- `lib/presentation/blocs/payment_accounts/payment_accounts_cubit.dart`
- `lib/data/services/qr_code_service.dart` - QR code generation

**Permissions:**
- Admin-only access

---

### 8. Vehicles Management

**Purpose:** Manage organization vehicles.

**Features:**
- Create, edit, delete vehicles
- Assign drivers (employees) to vehicles
- View vehicles list

**Data Model:**
- Collection: `ORGANIZATIONS/{orgId}/VEHICLES`
- Fields: vehicleNumber, vehicleType, driverId, etc.

**Backend:**
- `lib/data/datasources/vehicles_data_source.dart`
- `lib/data/repositories/vehicles_repository.dart`

**Frontend:**
- `lib/presentation/views/vehicles_page.dart`

**Permissions:**
- `canAccessPage('vehicles')`

---

### 9. Analytics Dashboard

**Purpose:** View analytics and metrics for clients and business.

**Features:**
- View active clients over time (line chart)
- View onboarding metrics (monthly)
- Financial year-based analytics
- Summary statistics

**Data Model:**
- Collection: `ANALYTICS`
- Document: `{source}_{financialYear}` (e.g., `clients_FY2425`)

**Backend:**
- Firebase Function: `onClientCreated` - Real-time updates
- Firebase Function: `rebuildClientAnalytics` - Daily rebuild
- `lib/data/repositories/analytics_repository.dart`

**Frontend:**
- `lib/presentation/views/clients_page/client_analytics_page.dart`
- `lib/presentation/views/analytics/analytics_dashboard_body.dart`

**Metrics:**
- Active Clients (cumulative monthly count)
- User Onboarding (new clients per month)

---

### 10. Home Dashboard

**Purpose:** Main dashboard with multiple sections.

**Features:**
- Home Overview
- Pending Orders (placeholder)
- Schedule Orders (placeholder)
- Orders Map (placeholder)
- Analytics Dashboard

**Frontend:**
- `lib/presentation/views/home_page.dart`
- `lib/presentation/widgets/home_workspace_layout.dart`
- `lib/presentation/views/home_sections/` - Section views

**Quick Actions:**
- Quick Action Menu (Samsung-style)
  - Create Order (opens customer type dialog)

**Navigation:**
- Bottom navigation bar (`QuickNavBar`)
- Section-based navigation

---

## Frontend Pages & Views

### Authentication Pages

1. **Phone Input Page** (`/login`)
   - File: `lib/presentation/views/phone_input_page.dart`
   - Purpose: Enter phone number to start authentication

2. **OTP Verification Page** (`/otp`)
   - File: `lib/presentation/views/otp_verification_page.dart`
   - Purpose: Verify OTP code sent to phone

3. **Organization Selection Page** (`/org-selection`)
   - File: `lib/presentation/views/organization_selection_page.dart`
   - Purpose: Select organization to work with

### Main Pages

4. **Home Page** (`/home`)
   - File: `lib/presentation/views/home_page.dart`
   - Purpose: Main dashboard with sections
   - Sections: Overview, Pending Orders, Schedule Orders, Orders Map, Analytics

5. **Clients Page** (`/clients`)
   - File: `lib/presentation/views/clients_page.dart`
   - Purpose: List and search clients
   - Sub-pages: Client Detail, Client Analytics, Contact Page

6. **Products Page** (`/products`)
   - File: `lib/presentation/views/products_page.dart`
   - Purpose: Manage products

7. **Employees Page** (`/employees`)
   - File: `lib/presentation/views/employees_page.dart`
   - Purpose: Manage employees

8. **Users Page** (`/users`)
   - File: `lib/presentation/views/users_page.dart`
   - Purpose: Manage organization users (admin-only)

9. **Roles Page** (`/roles`)
   - File: `lib/presentation/views/roles_page.dart`
   - Purpose: Manage roles and permissions

10. **Zones Page** (`/zones`)
    - File: `lib/presentation/views/zones_page.dart`
    - Purpose: Manage delivery zones and pricing

11. **Payment Accounts Page** (`/payment-accounts`)
    - File: `lib/presentation/views/payment_accounts_page.dart`
    - Purpose: Manage payment accounts (admin-only)

12. **Vehicles Page** (`/vehicles`)
    - File: `lib/presentation/views/vehicles_page.dart`
    - Purpose: Manage vehicles

---

## State Management

### BLoC Pattern

**Architecture:**
- **Events:** User actions/triggers
- **States:** UI state representation
- **Cubit/Bloc:** Business logic handler
- **Repository:** Data access layer

**Key BLoCs:**

1. **AuthBloc** (`packages/core_services`)
   - Handles authentication state
   - Events: `AuthLogin`, `AuthLogout`, `AuthReset`
   - States: `AuthState` (user, loading, error)

2. **OrganizationContextCubit**
   - File: `lib/presentation/blocs/org_context/org_context_cubit.dart`
   - Manages current organization context
   - Provides: organization, role, permissions

3. **ClientsCubit**
   - File: `lib/presentation/blocs/clients/clients_cubit.dart`
   - Manages clients list and search
   - States: loading, success, error

4. **ProductsCubit**
   - File: `lib/presentation/blocs/products/products_cubit.dart`
   - Manages products CRUD

5. **EmployeesCubit**
   - File: `lib/presentation/blocs/employees/employees_cubit.dart`
   - Manages employees CRUD

6. **UsersCubit**
   - File: `lib/presentation/blocs/users/users_cubit.dart`
   - Manages organization users

7. **RolesCubit**
   - File: `lib/presentation/blocs/roles/roles_cubit.dart`
   - Manages roles CRUD

8. **DeliveryZonesCubit**
   - File: `lib/presentation/blocs/delivery_zones/delivery_zones_cubit.dart`
   - Manages zones, cities, and prices

9. **PaymentAccountsCubit**
   - File: `lib/presentation/blocs/payment_accounts/payment_accounts_cubit.dart`
   - Manages payment accounts

---

## Navigation & Routing

### GoRouter Configuration

**File:** `lib/config/app_router.dart`

**Routes:**
- `/login` - Phone input
- `/otp` - OTP verification
- `/org-selection` - Organization selection
- `/home` - Home dashboard
- `/clients` - Clients list
- `/clients/detail` - Client detail
- `/products` - Products
- `/employees` - Employees
- `/users` - Users (admin-only)
- `/roles` - Roles
- `/zones` - Delivery zones
- `/payment-accounts` - Payment accounts (admin-only)
- `/vehicles` - Vehicles

**Page Transitions:**
- Slide from right animation
- Duration: 200ms
- Curve: `Curves.fastOutSlowIn`

**Route Guards:**
- Organization context check
- Role permission checks
- Redirects to appropriate pages if unauthorized

---

## Services & Repositories

### Repository Pattern

**Structure:**
```
DataSource (Firebase) → Repository → BLoC → UI
```

### Key Repositories

1. **ClientsRepository**
   - Interface: `lib/data/repositories/clients_repository.dart`
   - Service: `lib/data/services/client_service.dart`
   - Methods: `fetchRecentClients()`, `searchClients()`, `recentClientsStream()`

2. **ProductsRepository**
   - Interface: `lib/data/repositories/products_repository.dart`
   - DataSource: `lib/data/datasources/products_data_source.dart`
   - Methods: `fetchProducts()`, `createProduct()`, `updateProduct()`, `deleteProduct()`

3. **EmployeesRepository**
   - Interface: `lib/data/repositories/employees_repository.dart`
   - DataSource: `lib/data/datasources/employees_data_source.dart`

4. **UsersRepository**
   - Interface: `lib/data/repositories/users_repository.dart`
   - DataSource: `lib/data/datasources/users_data_source.dart`

5. **RolesRepository**
   - Interface: `lib/data/repositories/roles_repository.dart`
   - DataSource: `lib/data/datasources/roles_data_source.dart`

6. **DeliveryZonesRepository**
   - Interface: `lib/data/repositories/delivery_zones_repository.dart`
   - DataSource: `lib/data/datasources/delivery_zones_data_source.dart`

7. **PaymentAccountsRepository**
   - Interface: `lib/data/repositories/payment_accounts_repository.dart`
   - DataSource: `lib/data/datasources/payment_accounts_data_source.dart`

8. **VehiclesRepository**
   - Interface: `lib/data/repositories/vehicles_repository.dart`
   - DataSource: `lib/data/datasources/vehicles_data_source.dart`

9. **AnalyticsRepository**
   - Interface: `lib/data/repositories/analytics_repository.dart`
   - Service: `lib/data/services/analytics_service.dart`

---

## UI Components

### Custom Widgets

1. **QuickNavBar**
   - File: `lib/presentation/widgets/quick_nav_bar.dart`
   - Purpose: Bottom navigation bar
   - Features: Section-based navigation, role-based visibility

2. **HomeWorkspaceLayout**
   - File: `lib/presentation/widgets/home_workspace_layout.dart`
   - Purpose: Layout wrapper for home sections
   - Features: Profile sidebar, settings sidebar, quick action menu

3. **PageWorkspaceLayout**
   - File: `lib/presentation/widgets/page_workspace_layout.dart`
   - Purpose: Layout wrapper for detail pages
   - Features: Consistent styling, safe area handling

4. **QuickActionMenu**
   - File: `lib/presentation/widgets/quick_action_menu.dart`
   - Purpose: Samsung-style expandable action menu
   - Features: Expandable actions, backdrop, animations

### Shared Packages

- **core_ui:** Design system components (DashButton, DashAppBar, etc.)
- **core_models:** Shared data models (UserProfile, etc.)
- **core_bloc:** Base BLoC classes and utilities

---

## Data Flow

### Typical Data Flow

1. **User Action** → UI triggers event
2. **BLoC Event** → BLoC receives event
3. **Repository Call** → BLoC calls repository method
4. **DataSource Query** → Repository queries Firebase
5. **Firebase Response** → Data returned to repository
6. **Repository Transform** → Repository transforms to domain model
7. **BLoC State Update** → BLoC emits new state
8. **UI Rebuild** → UI updates based on new state

### Example: Creating a Client

```
1. User fills form → ContactPage
2. User taps "Save" → ClientsCubit.createClient(event)
3. ClientsCubit → ClientsRepository.createClient()
4. ClientsRepository → ClientService.createClient()
5. ClientService → Firestore.collection('CLIENTS').add()
6. Firestore Trigger → onClientCreated function
7. Function → Updates ANALYTICS collection
8. Function → Sends WhatsApp welcome (if enabled)
9. ClientService → Returns success
10. ClientsCubit → Emits success state
11. UI → Shows success message, navigates back
```

---

## Key Features Summary

### Implemented Features

✅ Phone-based authentication  
✅ Multi-organization support  
✅ Role-based access control  
✅ Clients management (CRUD, search, analytics)  
✅ Products management  
✅ Employees management  
✅ Users management  
✅ Roles & permissions management  
✅ Delivery zones & pricing  
✅ Payment accounts management  
✅ Vehicles management  
✅ Analytics dashboard  
✅ WhatsApp integration (welcome messages)  
✅ Quick action menu  
✅ Real-time data streams  

### Placeholder Features

🔄 Pending Orders (UI ready, logic pending)  
🔄 Schedule Orders (UI ready, logic pending)  
🔄 Orders Map (UI ready, logic pending)  

---

## Development Guidelines

### Adding a New Feature

1. **Create Data Model** (`lib/domain/entities/`)
2. **Create DataSource** (`lib/data/datasources/`)
3. **Create Repository** (`lib/data/repositories/`)
4. **Create BLoC** (`lib/presentation/blocs/`)
5. **Create UI Page** (`lib/presentation/views/`)
6. **Add Route** (`lib/config/app_router.dart`)
7. **Update Permissions** (if needed in roles)

### Best Practices

1. Always use repositories, not direct data sources in BLoCs
2. Use transactions for multi-document operations
3. Handle loading and error states in BLoCs
4. Validate permissions before showing UI
5. Use streams for real-time data
6. Normalize phone numbers before storing
7. Use server timestamps for all timestamps

---

## Testing

### Unit Tests
- BLoC tests for business logic
- Repository tests for data operations
- Service tests for business rules

### Integration Tests
- Authentication flow
- CRUD operations
- Permission checks

---

## Deployment

### Firebase Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### Flutter App
```bash
flutter build apk --release  # Android
flutter build ios --release   # iOS
```

---

## Support & Resources

- **Firebase Console:** https://console.firebase.google.com
- **Flutter Docs:** https://flutter.dev/docs
- **BLoC Pattern:** https://bloclibrary.dev
- **GoRouter:** https://pub.dev/packages/go_router

---

## Version History

- **v1.0.0** - Initial release with core features
- Current version includes all documented features

---

## Notes for Developers

1. **Organization Context:** Always check `OrganizationContextCubit` for current org and role
2. **Permissions:** Use `role.canCreate()`, `role.canEdit()`, etc. for permission checks
3. **Phone Normalization:** Use `_normalizePhone()` method in ClientService
4. **Real-time Updates:** Use streams (`recentClientsStream()`) for live data
5. **Error Handling:** All BLoCs extend `BaseBloc` with error handling
6. **Navigation:** Use `context.go()` or `context.pushNamed()` for navigation
7. **State Management:** Always use BLoC pattern, avoid setState for business logic

---

## Future Enhancements

- Order management system
- Schedule orders functionality
- Orders map with location tracking
- Push notifications
- Offline support
- Data export/import
- Advanced analytics
- Multi-language support

