# OPERON - Organization Management System

A comprehensive Flutter web application for Super Admin organization management with Firebase backend integration. OPERON provides a complete platform for managing multiple organizations, users, subscriptions, products, locations, vehicles, and more.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Firebase Configuration](#firebase-configuration)
- [Project Structure](#project-structure)
- [Key Features](#key-features)
- [Authentication](#authentication)
- [Database Schema](#database-schema)
- [Firebase Cloud Functions](#firebase-cloud-functions)
- [Deployment](#deployment)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Version History](#version-history)

## 🎯 Overview

OPERON is a modern web-based organization management system designed for Super Admins to:

- **Manage Organizations**: Create, edit, monitor, and configure multiple organizations
- **User Management**: Handle user roles and permissions across organizations with role-based access control
- **Subscription Management**: Track and manage subscription tiers, billing cycles, and user limits
- **Product Management**: Manage products, pricing, and product-location associations
- **Location & Pricing**: Configure location-based pricing and delivery zones
- **Vehicle Management**: Track and manage vehicle fleets for organizations
- **Payment Accounts**: Manage payment methods and accounts for organizations
- **Address Management**: Handle delivery addresses and location data
- **Analytics Dashboard**: View comprehensive metrics, reports, and real-time statistics
- **System Configuration**: Configure system-wide settings and preferences

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter Web   │    │   Firebase      │    │   Firebase      │
│   Frontend      │◄──►│   Authentication│    │   Firestore     │
│   (BLoC)        │    │   (Phone OTP)   │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │   Firebase      │              │
         └──────────────►│   Storage       │◄─────────────┘
                        │   (Files)       │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Firebase      │
                        │   Functions     │
                        │   (Backend)     │
                        └─────────────────┘
```

### Architecture Components

1. **Frontend (Flutter Web)**
   - BLoC pattern for state management
   - Repository pattern for data access
   - Material Design 3 with custom dark theme
   - Responsive design for all screen sizes

2. **Backend (Firebase)**
   - **Authentication**: Phone OTP-based authentication
   - **Firestore**: NoSQL document database
   - **Storage**: File storage for images and documents
   - **Functions**: Cloud Functions for server-side logic

3. **Data Flow**
   - User actions trigger BLoC events
   - BLoC calls repositories
   - Repositories interact with Firebase services
   - State changes update UI

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.9.2+ (Web)
- **State Management**: BLoC Pattern (flutter_bloc)
- **UI**: Material Design 3 with custom dark theme
- **Responsive**: Mobile-first responsive design
- **Charts**: fl_chart for analytics visualization
- **Animations**: Flutter animations and transitions

### Backend & Services
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (Phone OTP)
- **Storage**: Firebase Storage
- **Functions**: Firebase Cloud Functions (Node.js 22)
- **Analytics**: Firebase Analytics (optional)

### Development Tools
- **IDE**: VS Code / Android Studio
- **Version Control**: Git
- **Package Manager**: Pub (Flutter)
- **Build Tool**: Flutter Web
- **Deployment**: Firebase Hosting

### Key Dependencies
```yaml
flutter_bloc: ^9.1.1          # State management
firebase_core: ^4.2.0         # Firebase core
cloud_firestore: ^6.0.3       # Firestore database
firebase_auth: ^6.1.1         # Authentication
firebase_storage: ^13.0.3      # File storage
cloud_functions: ^6.0.3       # Cloud Functions
fl_chart: ^1.1.1              # Charts and graphs
image_picker: ^1.2.0          # Image selection
file_picker: ^10.3.3          # File selection
uuid: ^4.5.1                  # UUID generation
provider: ^6.1.2              # Dependency injection
```

## 📋 Prerequisites

### Required Software
- **Flutter SDK**: 3.9.2 or higher (with web support)
  ```bash
  flutter --version  # Verify version
  flutter doctor     # Check installation
  ```
- **Node.js**: 16.0+ (for Firebase Functions)
  ```bash
  node --version     # Verify version
  npm --version      # Verify npm
  ```
- **Firebase CLI**: Latest version
  ```bash
  npm install -g firebase-tools
  firebase --version
  ```
- **Git**: Latest version
- **Chrome/Edge**: For web development and testing

### Required Accounts
- **Firebase Account**: With billing enabled (Blaze plan required for Cloud Functions)
- **Google Cloud Platform**: For Firebase services
- **GitHub/GitLab**: For version control (optional)

### System Requirements
- **OS**: Windows 10+, macOS 10.14+, or Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 10GB free space
- **Internet**: Stable connection for Firebase services

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd OPERON
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

This will install all required packages listed in `pubspec.yaml`.

### 3. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 4. Login to Firebase
```bash
firebase login
```

Follow the authentication flow in your browser.

### 5. Install Node.js Dependencies (for Functions)
```bash
cd functions
npm install
cd ..
```

### 6. Configure Firebase Project
```bash
firebase use <your-project-id>
# or
firebase use --add
```

If you need to create a new Firebase project:
```bash
firebase projects:create <project-id>
firebase use <project-id>
```

### 7. Initialize Flutter Firebase
```bash
flutterfire configure
```

This will generate `lib/firebase_options.dart` with your Firebase configuration.

### 8. Verify Setup
```bash
flutter doctor
flutter pub get
flutter analyze
```

## 🔥 Firebase Configuration

### 1. Firebase Project Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: `operanapp` (or your preferred name)
3. Enable Google Analytics (optional but recommended)

#### Enable Required Services

**Authentication**
1. Go to **Authentication** → **Sign-in method**
2. Enable **Phone** authentication
3. Configure reCAPTCHA for web domain
4. Add test phone numbers for development

**Firestore Database**
1. Go to **Firestore Database** → **Create database**
2. Start in **production mode** (rules will be deployed separately)
3. Choose location (preferably close to your users)

**Storage**
1. Go to **Storage** → **Get started**
2. Start in **production mode**
3. Configure storage rules

**Functions**
1. Go to **Functions** → **Get started**
2. Upgrade to **Blaze plan** (required for Cloud Functions)
3. Enable billing if prompted

### 2. Authentication Configuration

#### Phone Authentication Setup
- **Test Phone Number**: `+919876543210`
- **Test OTP**: `123456` (only works in development)
- **reCAPTCHA**: Configured automatically for web domain

#### Authorized Numbers
```dart
// lib/core/constants/app_constants.dart
static const String superAdminPhoneNumber = '+919876543210';
```

Update this constant with your SuperAdmin phone number.

### 3. Firestore Security Rules

Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

Rules are defined in `firestore.rules`. Key points:
- Super Admin access control via phone number
- Role-based access for different user types
- Organization-level data isolation

### 4. Storage Security Rules

Deploy storage rules:
```bash
firebase deploy --only storage
```

Rules are defined in `storage.rules`. Key points:
- Authenticated users can upload files
- Organization-specific folder structure
- File type and size restrictions

### 5. Firestore Indexes

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

Indexes are defined in `firestore.indexes.json`. Required indexes include:
- Organizations by status and created date
- Users by status and created date
- Phone number lookups
- Organization-user relationships

### 6. Firebase Cloud Functions

Deploy functions:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Functions include:
- Organization management
- User onboarding
- System metadata updates
- Notification triggers
- Subscription management

See [Firebase Cloud Functions](#firebase-cloud-functions) section for details.

## 📁 Project Structure

```
OPERON/
├── lib/
│   ├── contexts/
│   │   └── organization_context.dart          # Organization context provider
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart            # App-wide constants
│   │   ├── models/
│   │   │   ├── organization.dart             # Organization data model
│   │   │   ├── user.dart                     # User data model
│   │   │   ├── subscription.dart             # Subscription model
│   │   │   ├── organization_role.dart        # User role in org
│   │   │   ├── superadmin_config.dart        # Super Admin config
│   │   │   └── system_metadata.dart          # System metadata
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart          # Authentication logic
│   │   │   ├── organization_repository.dart  # Organization CRUD
│   │   │   ├── user_repository.dart          # User management
│   │   │   ├── user_organization_repository.dart  # User-Org relations
│   │   │   └── config_repository.dart        # Configuration management
│   │   ├── theme/
│   │   │   └── app_theme.dart                # Dark theme configuration
│   │   ├── utils/
│   │   │   ├── init_superadmin.dart          # SuperAdmin initialization
│   │   │   └── storage_utils.dart             # Firebase Storage utilities
│   │   └── widgets/
│   │       ├── animated_background.dart       # Background animations
│   │       ├── custom_button.dart            # Reusable button widget
│   │       ├── custom_dropdown.dart          # Custom dropdown
│   │       ├── custom_snackbar.dart          # Notification system
│   │       ├── custom_text_field.dart        # Text input widget
│   │       ├── dashboard_section_card.dart   # Dashboard cards
│   │       ├── dashboard_tile.dart           # Dashboard tiles
│   │       ├── error_widget.dart             # Error handling UI
│   │       ├── form_container.dart           # Form wrapper
│   │       ├── gradient_card.dart            # Gradient card widget
│   │       ├── loading_overlay.dart          # Loading states
│   │       ├── navigation_pills.dart         # Navigation UI
│   │       ├── page_container.dart           # Page layout wrapper
│   │       ├── page_header.dart              # Page headers
│   │       └── profile_dropdown.dart         # Profile menu
│   ├── features/
│   │   ├── addresses/
│   │   │   ├── bloc/                         # Address state management
│   │   │   ├── models/                       # Address data model
│   │   │   ├── presentation/                 # Address UI
│   │   │   └── repositories/                 # Address data access
│   │   ├── auth/
│   │   │   ├── bloc/                         # Authentication BLoC
│   │   │   ├── presentation/                 # Login UI
│   │   │   └── repository/                   # Auth repository
│   │   ├── dashboard/
│   │   │   └── presentation/                 # Dashboard UI
│   │   │       ├── pages/
│   │   │       │   └── super_admin_dashboard.dart
│   │   │       └── widgets/
│   │   │           ├── dashboard_header.dart
│   │   │           ├── dashboard_sidebar.dart
│   │   │           ├── metrics_cards.dart
│   │   │           ├── organizations_list.dart
│   │   │           └── subscription_analytics_chart.dart
│   │   ├── location_pricing/
│   │   │   ├── bloc/                         # Location pricing state
│   │   │   ├── models/                       # Location pricing model
│   │   │   ├── presentation/                 # Location pricing UI
│   │   │   └── repositories/                 # Location pricing data
│   │   ├── organization/
│   │   │   ├── bloc/                         # Organization BLoC
│   │   │   └── presentation/                 # Organization UI
│   │   │       ├── pages/
│   │   │       │   ├── organization_home_page.dart
│   │   │       │   └── organization_select_page.dart
│   │   │       └── widgets/
│   │   │           ├── add_organization_form.dart
│   │   │           ├── edit_organization_form.dart
│   │   │           ├── organization_card.dart
│   │   │           └── organization_settings_view.dart
│   │   ├── payment_accounts/
│   │   │   ├── bloc/                         # Payment account state
│   │   │   ├── models/                       # Payment account model
│   │   │   ├── presentation/                 # Payment account UI
│   │   │   └── repositories/                 # Payment account data
│   │   ├── product_prices/
│   │   │   ├── bloc/                         # Product price state
│   │   │   ├── models/                       # Product price model
│   │   │   ├── presentation/                 # Product price UI
│   │   │   └── repositories/                 # Product price data
│   │   ├── products/
│   │   │   ├── bloc/                         # Product state
│   │   │   ├── models/                       # Product model
│   │   │   ├── presentation/                 # Product UI
│   │   │   └── repositories/                 # Product data
│   │   ├── profile/
│   │   │   └── presentation/                 # Profile UI
│   │   ├── settings/
│   │   │   ├── bloc/                         # Settings BLoC
│   │   │   └── presentation/                 # Settings UI
│   │   ├── user/
│   │   │   └── presentation/                  # User management UI
│   │   │       ├── pages/
│   │   │       │   └── user_management_page.dart
│   │   │       └── widgets/
│   │   │           ├── add_user_form.dart
│   │   │           └── user_list.dart
│   │   └── vehicle/
│   │       ├── bloc/                         # Vehicle state
│   │       ├── models/                       # Vehicle model
│   │       ├── presentation/                 # Vehicle UI
│   │       └── repositories/                 # Vehicle data
│   ├── firebase_options.dart                 # Firebase configuration
│   └── main.dart                             # App entry point
├── web/
│   ├── index.html                            # Web entry point with CSP
│   ├── manifest.json                         # PWA manifest
│   ├── favicon.png                           # App icon
│   └── icons/                                # PWA icons
├── functions/
│   ├── index.js                              # Firebase Cloud Functions
│   ├── package.json                          # Node.js dependencies
│   └── README.md                             # Functions documentation
├── firebase.json                             # Firebase configuration
├── firestore.rules                           # Firestore security rules
├── firestore.indexes.json                    # Database indexes
├── storage.rules                             # Storage security rules
├── pubspec.yaml                              # Flutter dependencies
├── SUPERADMIN_SETUP_GUIDE.md                 # SuperAdmin setup guide
├── TESTING_GUIDE.md                          # Testing documentation
├── TESTING_CHECKLIST.md                       # Testing checklist
└── README.md                                  # This file
```

## ✨ Key Features

### 🔐 Authentication
- **Phone OTP Authentication**: Secure login with phone number verification
- **Super Admin Access**: Single authorized phone number with full system access
- **Session Management**: Automatic token refresh and session handling
- **Logout Functionality**: Secure session termination
- **Organization Selection**: Multi-organization support with role-based access

### 🏢 Organization Management
- **Create Organizations**: Add new organizations with comprehensive details
  - Organization name, email, GST number
  - Industry, location, subscription details
  - Logo upload and branding
- **Edit Organizations**: Update organization information and settings
- **Organization List**: View all organizations with search and filter capabilities
- **Organization Status**: Manage active, inactive, and suspended states
- **Organization Settings**: Configure organization-specific preferences
- **Logo Management**: Upload and update organization logos

### 👥 User Management
- **User Roles**: Comprehensive role system
  - Super Admin (0): Full system access
  - Admin (1): Organization management
  - Manager (2): Operational management
  - Driver (3): Field operations
- **Role-based Access Control**: Different permissions per role
- **User Profiles**: Complete user information management
- **Organization Assignment**: Users can belong to multiple organizations
- **User Status Management**: Active, inactive, invited, pending, suspended
- **Invitation System**: Invite users via phone and email

### 💳 Subscription Management
- **Subscription Tiers**: Basic, Premium, Enterprise
- **Billing Types**: Monthly and Yearly billing cycles
- **User Limits**: Configurable user limits per subscription tier
- **Expiration Tracking**: Monitor subscription end dates and renewals
- **Auto-renewal**: Automatic subscription renewal options
- **Revenue Tracking**: Track subscription revenue and payments

### 📦 Product Management
- **Product CRUD**: Create, read, update, delete products
- **Product Details**: Name, description, SKU, category
- **Product Images**: Upload and manage product images
- **Product Status**: Active/inactive product management
- **Product Categories**: Organize products by categories

### 💰 Product Pricing
- **Price Management**: Set and manage product prices
- **Organization-specific Pricing**: Different prices per organization
- **Bulk Price Updates**: Update multiple product prices at once
- **Price History**: Track price changes over time

### 📍 Location & Pricing
- **Location Management**: Manage delivery locations and zones
- **Location-based Pricing**: Configure prices for specific locations
- **Delivery Zones**: Define delivery areas and zones
- **Distance Calculation**: Calculate delivery distances and charges

### 🚗 Vehicle Management
- **Vehicle CRUD**: Manage vehicle fleet
- **Vehicle Details**: Registration, type, capacity, status
- **Driver Assignment**: Assign drivers to vehicles
- **Maintenance Tracking**: Track vehicle maintenance and service
- **Vehicle Status**: Active, maintenance, retired states

### 💳 Payment Accounts
- **Payment Method Management**: Add and manage payment methods
- **Account Details**: Bank accounts, UPI, wallets
- **Transaction History**: Track payments and transactions
- **Account Verification**: Verify and activate payment accounts

### 📮 Address Management
- **Address CRUD**: Create and manage delivery addresses
- **Address Validation**: Validate address data
- **Location Mapping**: Map addresses to geographic coordinates
- **Delivery Zones**: Associate addresses with delivery zones

### 📊 Analytics Dashboard
- **Real-time Metrics**: Live organization and user counts
- **Revenue Tracking**: Monthly and total revenue analytics
- **Subscription Analytics**: Tier distribution charts and graphs
- **Growth Metrics**: Month-over-month comparisons
- **Organization Statistics**: Per-organization analytics
- **Visual Dashboards**: Interactive charts using fl_chart

### ⚙️ System Configuration
- **App Preferences**: Theme, language, notifications
- **System Settings**: Default user limits, subscription tiers
- **Security Settings**: Authentication and access controls
- **Maintenance Mode**: System-wide maintenance toggle
- **SuperAdmin Config**: Configure SuperAdmin-specific settings

## 🔐 Authentication

### Super Admin Login Process

1. **Phone Number Input**
   - Enter: `9876543210` (10 digits)
   - Validation: Exactly 10 digits, Indian mobile format
   - Prefix: Automatically adds `+91`

2. **OTP Verification**
   - Test OTP: `123456` (development only)
   - Real OTP: Sent via SMS (production)
   - reCAPTCHA: Automatic verification for web

3. **Session Creation**
   - Firebase Auth token generation
   - Super Admin user document verification
   - Organization selection or dashboard access

### Authorization Logic
```dart
bool isAuthorizedPhoneNumber(String phoneNumber) {
  String cleanInput = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  String authorizedNumber = AppConstants.superAdminPhoneNumber
      .replaceAll(RegExp(r'[^\d]'), '');
  String authorizedMobileNumber = authorizedNumber
      .substring(authorizedNumber.length - 10);
  return cleanInput == authorizedMobileNumber;
}
```

### User Flow
1. Login with phone number
2. Verify OTP
3. Check user existence in Firestore
4. Select organization (if multiple)
5. Navigate to appropriate dashboard

## 🗄️ Database Schema

### Firestore Collections

#### ORGANIZATIONS
```javascript
{
  orgId: "auto-generated",
  orgName: "Organization Name",
  emailId: "contact@org.com",
  gstNo: "GST123456789",
  orgLogoUrl: "https://storage.../logo.jpg",
  status: "active|inactive|suspended",
  industry: "Technology",
  location: "Mumbai, Maharashtra",
  createdDate: Timestamp,
  updatedDate: Timestamp,
  subscription: {
    tier: "basic|premium|enterprise",
    subscriptionType: "monthly|yearly",
    startDate: Timestamp,
    endDate: Timestamp,
    userLimit: 10,
    amount: 999.00,
    currency: "INR",
    autoRenew: true
  },
  metadata: {
    totalUsers: 5,
    totalProducts: 50,
    totalVehicles: 3
  }
}
```

#### USERS
```javascript
{
  userId: "firebase-auth-uid",
  name: "User Name",
  phoneNo: "+919876543210",
  email: "user@example.com",
  profilePhotoUrl: "https://storage.../photo.jpg",
  status: "active|inactive|invited|pending|suspended",
  createdDate: Timestamp,
  updatedDate: Timestamp,
  lastLoginDate: Timestamp,
  metadata: {
    totalOrganizations: 1,
    primaryOrgId: "org-id",
    notificationPreferences: {}
  },
  organizations: [
    {
      orgId: "organization-id",
      role: 1,  // Admin role
      status: "active",
      joinedDate: Timestamp
    }
  ]
}
```

#### PRODUCTS
```javascript
{
  productId: "auto-generated",
  orgId: "organization-id",
  name: "Product Name",
  description: "Product description",
  sku: "SKU-12345",
  category: "Category Name",
  imageUrl: "https://storage.../image.jpg",
  status: "active|inactive",
  createdDate: Timestamp,
  updatedDate: Timestamp
}
```

#### LOCATION_PRICING
```javascript
{
  locationPricingId: "auto-generated",
  orgId: "organization-id",
  locationName: "Mumbai",
  state: "Maharashtra",
  pincode: "400001",
  pricingRules: {
    basePrice: 100.00,
    distanceMultiplier: 1.5,
    deliveryCharge: 50.00
  },
  createdDate: Timestamp,
  updatedDate: Timestamp
}
```

#### VEHICLES
```javascript
{
  vehicleId: "auto-generated",
  orgId: "organization-id",
  registrationNumber: "MH-01-AB-1234",
  vehicleType: "truck|van|car",
  capacity: "1000 kg",
  status: "active|maintenance|retired",
  driverId: "user-id",
  createdDate: Timestamp,
  updatedDate: Timestamp
}
```

#### PAYMENT_ACCOUNTS
```javascript
{
  paymentAccountId: "auto-generated",
  orgId: "organization-id",
  accountType: "bank|upi|wallet",
  accountDetails: {
    accountNumber: "1234567890",
    ifscCode: "BANK0001234",
    accountHolderName: "Account Name"
  },
  status: "active|inactive|verified",
  createdDate: Timestamp,
  updatedDate: Timestamp
}
```

#### SUPERADMIN_CONFIG
```javascript
{
  id: "settings",
  defaultUserLimit: 5,
  defaultSubscriptionTier: "basic",
  enableNewOrgRegistration: true,
  notificationSettings: {
    emailNotifications: true,
    smsNotifications: false
  },
  lastUpdated: Timestamp,
  updatedBy: "system"
}
```

#### DASHBOARD_METADATA/CLIENTS (Summary)
```javascript
{
  id: "CLIENTS",
  totalActiveClients: 120,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastEventAt: Timestamp
}
```

#### DASHBOARD_METADATA/CLIENTS/FINANCIAL_YEARS/{financialYearId}
```javascript
{
  financialYearId: "2024-2025",
  totalOnboarded: 52,
  totalActiveClientsSnapshot: 47,
  monthlyOnboarding: {
    "2024-04": 3,
    "2024-05": 6,
    // ...
    "2025-03": 4
  },
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastEventAt: Timestamp
}
```

### Storage Structure
```
organizations/
├── {orgId}/
│   ├── logos/
│   │   └── logo.jpg
│   ├── documents/
│   └── attachments/
users/
├── {userId}/
│   ├── profile_photos/
│   │   └── photo.jpg
│   ├── documents/
│   └── attachments/
products/
├── {orgId}/
│   └── {productId}/
│       └── images/
system/
├── templates/
└── assets/
```

## 🔧 Firebase Cloud Functions

### Available Functions

#### Dashboard Metadata Triggers
- `onClientCreated`: Update dashboard metadata when a client is created
- `onClientUpdated`: Track client status changes
- `onClientDeleted`: Keep active client counts accurate

#### Organization Functions
- `createOrganization`: Create new organization with admin
- `updateOrganization`: Update organization details
- `deleteOrganization`: Soft delete organization
- `onOrganizationCreated`: Trigger on org creation
- `onOrganizationUpdated`: Trigger on org update

#### User Functions
- `inviteUser`: Send user invitation
- `createUser`: Create user account
- `updateUser`: Update user details
- `onUserCreated`: Trigger on user creation
- `onUserUpdated`: Trigger on user update

#### Subscription Functions
- `updateSubscription`: Update subscription details
- `processSubscriptionRenewal`: Handle auto-renewal
- `onSubscriptionExpired`: Trigger on expiration

### Function Deployment
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### Function Logs
```bash
firebase functions:log
```

## 🚀 Deployment

### 1. Build Flutter Web App
```bash
# Production build
flutter build web --release

# Build with specific configuration
flutter build web --release --web-renderer html
```

### 2. Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

### 3. Deploy Firebase Functions
```bash
firebase deploy --only functions
```

### 4. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 5. Deploy Storage Rules
```bash
firebase deploy --only storage
```

### 6. Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```

### 7. Deploy All at Once
```bash
firebase deploy
```

### Production URLs
- **Web App**: `https://operanapp.web.app` or `https://operanapp.firebaseapp.com`
- **Firebase Console**: `https://console.firebase.google.com/project/operanapp`
- **Custom Domain**: Configure in Firebase Hosting settings

### Environment Configuration
For different environments (staging/production), use Firebase project aliases:
```bash
firebase use staging
firebase deploy --only hosting

firebase use production
firebase deploy --only hosting
```

## 🔧 Development Workflow

### 1. Local Development
```bash
# Start Flutter web development server
flutter run -d web-server --web-port 3000

# With hot reload
flutter run -d chrome --web-port 3000

# Start Firebase emulators (optional)
firebase emulators:start
```

### 2. Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Run linter
flutter pub run flutter_lints:lint
```

### 3. Testing
```bash
# Run Flutter tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage
```

See `TESTING_GUIDE.md` for comprehensive testing procedures.

### 4. Version Control
```bash
# Create feature branch
git checkout -b feature/new-feature

# Commit changes
git add .
git commit -m "feat: add new feature"

# Push to remote
git push origin feature/new-feature
```

### 5. Pre-deployment Checklist
- [ ] Run `flutter analyze`
- [ ] Run `flutter test`
- [ ] Update version in `pubspec.yaml`
- [ ] Update changelog
- [ ] Test locally with `flutter build web`
- [ ] Review Firebase rules and indexes
- [ ] Check Firebase Functions logs

## 🧪 Testing

### Test Scenarios
Refer to `TESTING_GUIDE.md` for detailed testing procedures:

1. **Authentication Testing**
   - Phone number validation
   - OTP verification
   - Session management
   - Organization selection

2. **Organization Management**
   - Create organization
   - Edit organization
   - Delete organization
   - Organization settings

3. **User Management**
   - Create user
   - Invite user
   - Update user
   - Role assignment

4. **Feature Testing**
   - Product management
   - Location pricing
   - Vehicle management
   - Payment accounts
   - Address management

### Test Data Setup
See `SUPERADMIN_SETUP_GUIDE.md` for test data initialization.

### Test Phone Numbers
- **SuperAdmin**: `+919876543210`
- **Test OTP**: `123456` (development only)

## 🔍 Troubleshooting

### Common Issues

#### 1. Phone Authentication Fails
**Problem**: "Unauthorized phone number" error

**Solution**: 
- Check `AppConstants.superAdminPhoneNumber` in `lib/core/constants/app_constants.dart`
- Verify phone number format in Firebase Console
- Ensure test phone number is configured in Firebase Authentication
- Check reCAPTCHA configuration

#### 2. reCAPTCHA Issues
**Problem**: reCAPTCHA verification fails

**Solution**:
- Check Content Security Policy in `web/index.html`
- Verify Firebase project configuration
- Test with different browsers
- Clear browser cache and cookies
- Check browser console for CSP violations

#### 3. Firestore Connection Errors
**Problem**: "Could not reach Cloud Firestore backend"

**Solution**:
- Check internet connection
- Verify Firestore rules are deployed
- Check Firebase project status
- Verify Firestore database is created
- Check Firestore indexes are deployed

#### 4. Build Errors
**Problem**: Flutter build fails

**Solution**:
```bash
# Clean build cache
flutter clean
flutter pub get
flutter pub upgrade
flutter build web --release
```

#### 5. CSP Violations
**Problem**: Content Security Policy errors

**Solution**:
- Update CSP in `web/index.html`
- Add required domains to `connect-src`
- Test with browser developer tools
- Check Firebase domains are whitelisted

#### 6. Firebase Functions Not Working
**Problem**: Functions not executing or errors

**Solution**:
- Verify functions are deployed: `firebase functions:list`
- Check function logs: `firebase functions:log`
- Verify billing is enabled (Blaze plan required)
- Check Node.js version compatibility
- Verify function permissions in Firebase Console

#### 7. Storage Upload Fails
**Problem**: File uploads fail

**Solution**:
- Check storage rules are deployed
- Verify authentication token is valid
- Check file size limits
- Verify file type is allowed
- Check storage bucket permissions

#### 8. Organization Not Loading
**Problem**: Organization list is empty or errors

**Solution**:
- Verify user has organization access in Firestore
- Check organization document structure
- Verify Firestore indexes are created
- Check BLoC state management
- Review browser console for errors

### Debug Mode
```bash
# Enable debug logging
flutter run -d web-server --web-port 3000 --debug

# Enable verbose logging
flutter run -d chrome --verbose
```

### Logs and Monitoring
- **Firebase Console**: Monitor usage and errors
  - Authentication logs
  - Firestore usage
  - Function executions
  - Storage usage
- **Chrome DevTools**: Debug frontend issues
  - Console logs
  - Network requests
  - Performance profiling
- **Firebase Analytics**: Track user behavior (if enabled)

### Getting Help
1. Check Firebase Console for error logs
2. Review browser console for client-side errors
3. Check `TESTING_GUIDE.md` for known issues
4. Review `SUPERADMIN_SETUP_GUIDE.md` for setup issues
5. Check GitHub issues (if applicable)

## 📝 Contributing

### Development Guidelines
1. **Code Style**: Follow Dart/Flutter conventions
2. **BLoC Pattern**: Use BLoC for state management
3. **Repository Pattern**: Use repositories for data access
4. **Error Handling**: Implement proper error handling with try-catch
5. **Testing**: Write unit and widget tests for new features
6. **Documentation**: Update README for new features
7. **Commit Messages**: Use conventional commits (feat:, fix:, docs:, etc.)

### Pull Request Process
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Make changes with tests
4. Ensure all tests pass
5. Update documentation
6. Submit pull request with description
7. Code review and merge

### Code Organization
- Follow feature-based architecture
- Keep BLoC files in `bloc/` directory
- Keep UI in `presentation/` directory
- Keep models in `models/` directory
- Keep repositories in `repositories/` directory

## 📞 Support

### Contact Information
- **Developer**: OPERON Development Team
- **Email**: [Your Email]
- **Project Repository**: [Repository URL]

### Documentation Links
- [Flutter Web Documentation](https://docs.flutter.dev/web)
- [Firebase Documentation](https://firebase.google.com/docs)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)

### Related Documentation
- `SUPERADMIN_SETUP_GUIDE.md` - SuperAdmin setup instructions
- `TESTING_GUIDE.md` - Comprehensive testing guide
- `TESTING_CHECKLIST.md` - Testing checklist
- `functions/README.md` - Cloud Functions documentation

---

## 📄 License

This project is proprietary software. All rights reserved.

## 🏷️ Version History

### v1.0.0 (Current)
- ✅ Super Admin authentication with phone OTP
- ✅ Organization management (CRUD operations)
- ✅ User management with role-based access
- ✅ Subscription tracking and management
- ✅ Analytics dashboard with charts
- ✅ System configuration
- ✅ Product management
- ✅ Location pricing management
- ✅ Vehicle management
- ✅ Payment account management
- ✅ Address management
- ✅ Organization selection and context
- ✅ Firebase Cloud Functions integration
- ✅ Comprehensive error handling
- ✅ Dark theme with Material Design 3

---

**Last Updated**: December 2024  
**Flutter Version**: 3.9.2+  
**Firebase SDK**: 10.x  
**Node.js**: 22.x (Functions)
