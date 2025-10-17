# OPERON - Organization Management System

A comprehensive Flutter web application for Super Admin organization management with Firebase backend integration.

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
- [Deployment](#deployment)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

OPERON is a modern web-based organization management system designed for Super Admins to:

- **Manage Organizations**: Create, edit, and monitor multiple organizations
- **User Management**: Handle user roles and permissions across organizations
- **Subscription Management**: Track and manage subscription tiers and billing
- **Analytics Dashboard**: View comprehensive metrics and reports
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

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.x (Web)
- **State Management**: BLoC Pattern
- **UI**: Material Design 3 with custom dark theme
- **Responsive**: Mobile-first responsive design
- **Animations**: Flutter animations and transitions

### Backend
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (Phone OTP)
- **Storage**: Firebase Storage
- **Functions**: Firebase Cloud Functions (Node.js)
- **Analytics**: Firebase Analytics

### Development Tools
- **IDE**: VS Code / Android Studio
- **Version Control**: Git
- **Package Manager**: Pub (Flutter)
- **Build Tool**: Flutter Web
- **Deployment**: Firebase Hosting

## 📋 Prerequisites

### Required Software
- **Flutter SDK**: 3.0+ (with web support)
- **Node.js**: 16.0+ (for Firebase Functions)
- **Firebase CLI**: Latest version
- **Git**: Latest version
- **Chrome/Edge**: For web development and testing

### Required Accounts
- **Firebase Account**: With billing enabled
- **Google Cloud Platform**: For Firebase services
- **GitHub/GitLab**: For version control (optional)

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

### 3. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 4. Login to Firebase
```bash
firebase login
```

### 5. Install Node.js Dependencies (for Functions)
```bash
cd functions
npm install
cd ..
```

### 6. Configure Firebase Project
```bash
firebase use <your-project-id>
```

## 🔥 Firebase Configuration

### 1. Firebase Project Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: `operanapp`
3. Enable Google Analytics (optional)

#### Enable Required Services
1. **Authentication** → Sign-in method → Phone
2. **Firestore Database** → Create database
3. **Storage** → Get started
4. **Functions** → Get started

### 2. Authentication Configuration

#### Phone Authentication
- **Test Phone Number**: `+919876543210`
- **Test OTP**: `123456`
- **reCAPTCHA**: Configured for web domain

#### Authorized Numbers
```dart
// lib/core/constants/app_constants.dart
static const String superAdminPhoneNumber = '+919876543210';
```

### 3. Firestore Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Super Admin can access all documents
    match /{document=**} {
      allow read, write: if request.auth != null 
        && request.auth.token.phone_number == '+919876543210';
    }
  }
}
```

### 4. Storage Security Rules
```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null 
        && request.auth.token.phone_number == '+919876543210';
    }
  }
}
```

### 5. Firestore Indexes
```json
// firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "ORGANIZATIONS",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdDate", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "USERS",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "createdDate", "order": "DESCENDING"}
      ]
    }
  ]
}
```

## 📁 Project Structure

```
OPERON/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart          # App-wide constants
│   │   ├── models/
│   │   │   ├── organization.dart           # Organization data model
│   │   │   ├── user.dart                   # User data model
│   │   │   ├── subscription.dart           # Subscription model
│   │   │   ├── organization_role.dart      # User role in org
│   │   │   ├── superadmin_config.dart      # Super Admin config
│   │   │   └── system_metadata.dart        # System metadata
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart        # Authentication logic
│   │   │   ├── organization_repository.dart # Organization CRUD
│   │   │   ├── user_repository.dart        # User management
│   │   │   └── config_repository.dart      # Configuration management
│   │   ├── theme/
│   │   │   └── app_theme.dart              # Dark theme configuration
│   │   ├── utils/
│   │   │   └── storage_utils.dart          # Firebase Storage utilities
│   │   └── widgets/
│   │       ├── loading_overlay.dart        # Loading states
│   │       ├── error_widget.dart           # Error handling
│   │       ├── custom_snackbar.dart        # Notifications
│   │       └── gradient_card.dart          # Custom card widgets
│   ├── features/
│   │   ├── auth/
│   │   │   ├── bloc/
│   │   │   │   ├── auth_bloc.dart          # Authentication BLoC
│   │   │   │   ├── auth_event.dart         # Auth events
│   │   │   │   └── auth_state.dart         # Auth states
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── login_page.dart     # Login UI
│   │   │   │   └── widgets/
│   │   │   │       ├── phone_input_field.dart # Phone input
│   │   │   │       └── otp_input_field.dart   # OTP input
│   │   │   └── repository/
│   │   │       └── auth_repository.dart    # Auth repository
│   │   ├── dashboard/
│   │   │   └── presentation/
│   │   │       ├── pages/
│   │   │       │   └── dashboard_page.dart # Main dashboard
│   │   │       └── widgets/
│   │   │           ├── dashboard_sidebar.dart # Navigation
│   │   │           ├── dashboard_header.dart  # Header
│   │   │           ├── metrics_cards.dart     # Statistics
│   │   │           ├── organizations_list.dart # Org list
│   │   │           └── subscription_analytics_chart.dart # Charts
│   │   ├── organization/
│   │   │   ├── bloc/
│   │   │   │   ├── organization_bloc.dart  # Organization BLoC
│   │   │   │   ├── organization_event.dart # Org events
│   │   │   │   └── organization_state.dart # Org states
│   │   │   └── presentation/
│   │   │       └── widgets/
│   │   │           ├── add_organization_form.dart # Add org form
│   │   │           └── edit_organization_form.dart # Edit org form
│   │   ├── profile/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── profile_page.dart   # Super Admin profile
│   │   └── settings/
│   │       ├── bloc/
│   │       │   ├── settings_bloc.dart      # Settings BLoC
│   │       │   ├── settings_event.dart     # Settings events
│   │       │   └── settings_state.dart     # Settings states
│   │       └── presentation/
│   │           ├── pages/
│   │           │   └── settings_page.dart  # Settings UI
│   │           └── widgets/
│   │               ├── setting_tile.dart   # Setting option
│   │               ├── app_preferences_section.dart # App settings
│   │               └── system_config_section.dart # System settings
│   ├── firebase_options.dart               # Firebase configuration
│   └── main.dart                           # App entry point
├── web/
│   ├── index.html                          # Web entry point with CSP
│   ├── manifest.json                       # PWA manifest
│   └── favicon.png                         # App icon
├── functions/
│   └── index.js                            # Firebase Cloud Functions
├── firebase.json                           # Firebase configuration
├── firestore.rules                         # Firestore security rules
├── firestore.indexes.json                  # Database indexes
├── storage.rules                           # Storage security rules
├── pubspec.yaml                            # Flutter dependencies
└── README.md                               # This file
```

## ✨ Key Features

### 🔐 Authentication
- **Phone OTP Authentication**: Secure login with phone number
- **Super Admin Access**: Single authorized phone number
- **Session Management**: Automatic token refresh
- **Logout Functionality**: Secure session termination

### 🏢 Organization Management
- **Create Organizations**: Add new organizations with details
- **Edit Organizations**: Update organization information
- **Organization List**: View all organizations with search/filter
- **Organization Status**: Active, inactive, suspended states
- **Logo Upload**: Organization branding support

### 👥 User Management
- **User Roles**: Super Admin (0), Admin (1), Manager (2), Driver (3)
- **Role-based Access**: Different permissions per role
- **User Profiles**: Complete user information management
- **Organization Assignment**: Users can belong to multiple organizations

### 💳 Subscription Management
- **Subscription Tiers**: Basic, Premium, Enterprise
- **Billing Types**: Monthly, Yearly
- **User Limits**: Configurable user limits per subscription
- **Expiration Tracking**: Monitor subscription end dates

### 📊 Analytics Dashboard
- **Real-time Metrics**: Live organization and user counts
- **Revenue Tracking**: Monthly and total revenue
- **Subscription Analytics**: Tier distribution charts
- **Growth Metrics**: Month-over-month comparisons

### ⚙️ System Configuration
- **App Preferences**: Theme, language, notifications
- **System Settings**: Default user limits, subscription tiers
- **Security Settings**: Authentication and access controls
- **Maintenance Mode**: System-wide maintenance toggle

## 🔐 Authentication

### Super Admin Login Process

1. **Phone Number Input**
   - Enter: `9876543210`
   - Validation: Exactly 10 digits, Indian mobile format
   - Prefix: Automatically adds `+91`

2. **OTP Verification**
   - Test OTP: `123456`
   - Real OTP: Sent via SMS (for production)
   - reCAPTCHA: Automatic verification

3. **Session Creation**
   - Firebase Auth token generation
   - Super Admin user document creation
   - Dashboard access granted

### Authorization Logic
```dart
bool isAuthorizedPhoneNumber(String phoneNumber) {
  String cleanInput = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  String authorizedNumber = AppConstants.superAdminPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  String authorizedMobileNumber = authorizedNumber.substring(authorizedNumber.length - 10);
  return cleanInput == authorizedMobileNumber;
}
```

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
  createdDate: Timestamp,
  updatedDate: Timestamp,
  subscription: {
    tier: "basic|premium|enterprise",
    subscriptionType: "monthly|yearly",
    startDate: Timestamp,
    endDate: Timestamp,
    userLimit: 10
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
      role: 1 // Admin role
    }
  ]
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

#### SYSTEM_METADATA
```javascript
{
  id: "counters",
  totalOrganizations: 25,
  totalUsers: 150,
  activeSubscriptions: 20,
  totalRevenue: 50000.0,
  lastUpdated: Timestamp
}
```

### Storage Structure
```
organizations/
├── {orgId}/
│   ├── logos/
│   ├── documents/
│   └── attachments/
users/
├── {userId}/
│   ├── profile_photos/
│   ├── documents/
│   └── attachments/
system/
├── templates/
└── assets/
```

## 🚀 Deployment

### 1. Build Flutter Web App
```bash
flutter build web --release
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

### Production URLs
- **Web App**: `https://operanapp.web.app`
- **Firebase Console**: `https://console.firebase.google.com/project/operanapp`

## 🔧 Development Workflow

### 1. Local Development
```bash
# Start Flutter web development server
flutter run -d web-server --web-port 3000

# Start Firebase emulators (optional)
firebase emulators:start
```

### 2. Testing
```bash
# Run Flutter tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

### 3. Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .
```

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

## 🔍 Troubleshooting

### Common Issues

#### 1. Phone Authentication Fails
**Problem**: "Unauthorized phone number" error
**Solution**: 
- Check `AppConstants.superAdminPhoneNumber`
- Verify phone number format in Firebase Console
- Ensure test phone number is configured

#### 2. reCAPTCHA Issues
**Problem**: reCAPTCHA verification fails
**Solution**:
- Check Content Security Policy in `web/index.html`
- Verify Firebase project configuration
- Test with different browsers

#### 3. Firestore Connection Errors
**Problem**: "Could not reach Cloud Firestore backend"
**Solution**:
- Check internet connection
- Verify Firestore rules
- Check Firebase project status

#### 4. Build Errors
**Problem**: Flutter build fails
**Solution**:
```bash
# Clean build cache
flutter clean
flutter pub get
flutter build web --release
```

#### 5. CSP Violations
**Problem**: Content Security Policy errors
**Solution**:
- Update CSP in `web/index.html`
- Add required domains to `connect-src`
- Test with browser developer tools

### Debug Mode
```bash
# Enable debug logging
flutter run -d web-server --web-port 3000 --debug
```

### Logs and Monitoring
- **Firebase Console**: Monitor usage and errors
- **Chrome DevTools**: Debug frontend issues
- **Firebase Analytics**: Track user behavior

## 📝 Contributing

### Development Guidelines
1. **Code Style**: Follow Dart/Flutter conventions
2. **BLoC Pattern**: Use BLoC for state management
3. **Error Handling**: Implement proper error handling
4. **Testing**: Write unit and widget tests
5. **Documentation**: Update README for new features

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request
5. Code review and merge

## 📞 Support

### Contact Information
- **Developer**: [Your Name]
- **Email**: [Your Email]
- **Project Repository**: [Repository URL]

### Documentation Links
- [Flutter Web Documentation](https://docs.flutter.dev/web)
- [Firebase Documentation](https://firebase.google.com/docs)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)

---

## 📄 License

This project is proprietary software. All rights reserved.

## 🏷️ Version History

- **v1.0.0** - Initial release with core functionality
  - Super Admin authentication
  - Organization management
  - User management
  - Subscription tracking
  - Analytics dashboard
  - System configuration

---

**Last Updated**: October 2024
**Flutter Version**: 3.x
**Firebase SDK**: 10.x