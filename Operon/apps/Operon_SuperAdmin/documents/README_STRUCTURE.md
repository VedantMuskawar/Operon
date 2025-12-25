# Dash SuperAdmin - App Structure

## Overview
The Dash SuperAdmin app follows a clean architecture pattern with clear separation of concerns across three main layers: **Presentation**, **Domain**, and **Data**.

## Directory Structure

```
apps/dash_superadmin/lib/
├── config/                    # App configuration
│   ├── app_router.dart       # GoRouter route definitions
│   ├── app_theme.dart         # Theme configuration
│   └── firebase_options.dart  # Firebase initialization
│
├── data/                      # Data layer (external data sources)
│   ├── datasources/          # Remote data sources
│   │   ├── firestore_user_checker.dart
│   │   └── organization_remote_data_source.dart
│   └── repositories/         # Repository implementations
│       ├── auth_repository.dart
│       └── organization_repository.dart
│
├── domain/                    # Domain layer (business logic)
│   ├── entities/             # Domain models
│   │   ├── admin_form.dart
│   │   ├── organization_form.dart
│   │   └── organization_summary.dart
│   ├── repositories/         # Repository interfaces (currently empty)
│   └── usecases/             # Business use cases
│       └── register_organization_with_admin.dart
│
├── presentation/              # Presentation layer (UI)
│   ├── app.dart              # Root app widget with providers
│   ├── blocs/                # State management (BLoC pattern)
│   │   ├── auth/
│   │   │   ├── auth_bloc.dart
│   │   │   ├── auth_event.dart
│   │   │   └── auth_state.dart
│   │   ├── create_org/
│   │   │   ├── create_org_bloc.dart
│   │   │   ├── create_org_event.dart
│   │   │   └── create_org_state.dart
│   │   └── organization_list/
│   │       ├── organization_list_bloc.dart
│   │       ├── organization_list_event.dart
│   │       └── organization_list_state.dart
│   ├── views/                # Screen widgets
│   │   ├── dashboard_redirect_logic.dart
│   │   ├── login_page.dart
│   │   ├── otp_verification_page.dart
│   │   └── phone_input_page.dart
│   └── widgets/              # Reusable UI components
│       └── create_organization_dialog.dart
│
├── shared/                    # Shared utilities and widgets
│   ├── utils/
│   └── widgets/
│
└── main.dart                  # App entry point
```

## Architecture Layers

### 1. Presentation Layer
- **BLoC Pattern**: State management using `flutter_bloc`
- **Views**: Screen-level widgets that compose UI
- **Widgets**: Reusable UI components
- **Dependencies**: Uses domain layer entities and use cases

### 2. Domain Layer
- **Entities**: Pure Dart classes representing business models
- **Use Cases**: Encapsulate business logic and orchestrate repository calls
- **Repository Interfaces**: Define contracts (currently implemented directly in data layer)

### 3. Data Layer
- **Data Sources**: Direct Firestore interactions
- **Repositories**: Implement data fetching and persistence logic
- **Dependencies**: `cloud_firestore`, `firebase_auth`

## Key Design Patterns

### BLoC Pattern
- **Events**: User actions (e.g., `PhoneNumberSubmitted`, `CreateOrgSubmitted`)
- **States**: UI state representation (e.g., `AuthState`, `CreateOrgState`)
- **Bloc**: Business logic handler that transforms events to states

### Repository Pattern
- Abstracts data source implementation
- Provides clean interface for domain layer
- Handles data transformation between Firestore and domain models

### Clean Architecture
- **Dependency Rule**: Inner layers don't depend on outer layers
- **Separation of Concerns**: Each layer has a single responsibility
- **Testability**: Clear boundaries enable easy unit testing

## State Management Flow

```
User Action → Event → BLoC → Use Case → Repository → Data Source → Firestore
                                                              ↓
UI Update ← State ← BLoC ← Use Case ← Repository ← Data Source
```

## Navigation

- **Router**: GoRouter configured in `app_router.dart`
- **Routes**:
  - `/` - Phone input page
  - `/otp` - OTP verification page
  - `/dashboard` - Main dashboard

## Dependency Injection

- **RepositoryProvider**: Provides repositories to widget tree
- **BlocProvider**: Provides BLoCs to widget tree
- **Context-based**: Access via `context.read<T>()` or `context.watch<T>()`

## Shared Packages

The app uses shared packages from the monorepo:
- `core_ui`: Reusable UI components (DashCard, DashButton, etc.)
- `core_bloc`: Base BLoC classes and utilities
- `core_models`: Shared domain models (UserProfile, etc.)

