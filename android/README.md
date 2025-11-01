# OPERON Android App

A comprehensive Flutter Android application for OPERON Organization Management System with phone number OTP authentication, organization management, and field operations support.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
- [Firebase Configuration](#firebase-configuration)
- [Project Structure](#project-structure)
- [Authentication Flow](#authentication-flow)
- [Key Features](#key-features)
- [Usage Guide](#usage-guide)
- [Development](#development)
- [Build Configuration](#build-configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Android-Specific Considerations](#android-specific-considerations)

## 🎯 Overview

OPERON Android App is a mobile application designed for field operations and on-the-go organization management. It provides:

- **Phone-based Authentication**: Secure login using phone number OTP
- **Multi-Organization Support**: Switch between organizations seamlessly
- **Organization Management**: View and configure organization settings
- **Product Management**: Manage products on mobile devices
- **Location Pricing**: Configure and view location-based pricing
- **Vehicle Management**: Track and manage vehicle fleet
- **Payment Accounts**: Manage payment methods and accounts
- **Material Design 3**: Modern, mobile-optimized UI with dark theme
- **Offline Capability**: Local caching for offline access (future enhancement)

## ✨ Features

### 🔐 Authentication & Organization
- **Phone Number Authentication**: OTP-based login using Firebase Authentication
- **Organization Selection**: Switch between multiple organizations
- **Organization Settings**: Configure organization preferences
- **User Profile Management**: View and manage user information

### 📦 Product Management
- **Product CRUD**: Create, read, update, delete products
- **Product List View**: Browse products with search and filter
- **Product Details**: View comprehensive product information
- **Image Upload**: Upload product images from device camera or gallery

### 💰 Location Pricing
- **Location Management**: Add and manage delivery locations
- **Pricing Configuration**: Set location-based pricing rules
- **Zone Management**: Define delivery zones and areas
- **Bulk Updates**: Update multiple location prices

### 🚗 Vehicle Management
- **Vehicle CRUD**: Manage vehicle fleet
- **Vehicle Tracking**: Track vehicle status and location
- **Driver Assignment**: Assign drivers to vehicles
- **Maintenance Records**: Track vehicle maintenance

### 💳 Payment Accounts
- **Account Management**: Add and manage payment accounts
- **Multiple Payment Methods**: Support for bank accounts, UPI, wallets
- **Account Verification**: Verify payment account details
- **Transaction History**: View payment transactions

### 🎨 User Interface
- **Material Design 3**: Modern, clean interface
- **Dark Theme**: Consistent dark theme across app
- **Responsive Design**: Optimized for various screen sizes
- **Smooth Animations**: Fluid transitions and animations
- **Intuitive Navigation**: Easy-to-use navigation patterns

## 🏗️ Architecture

### Architecture Pattern
- **BLoC Pattern**: State management using flutter_bloc
- **Repository Pattern**: Data access layer abstraction
- **Provider**: Dependency injection
- **Firebase Integration**: Backend services

### Data Flow
```
UI Layer (Widgets)
    ↓
BLoC (State Management)
    ↓
Repository (Data Access)
    ↓
Firebase Services (Auth, Firestore, Storage)
```

## 🛠️ Tech Stack

### Core Framework
- **Flutter**: 3.9.2+
- **Dart**: 3.9.2+
- **Android**: API Level 21+ (Android 5.0+)

### State Management
- **flutter_bloc**: ^8.1.6 - BLoC pattern implementation
- **equatable**: ^2.0.7 - Value equality

### Firebase Services
- **firebase_core**: ^3.15.2 - Firebase initialization
- **firebase_auth**: ^5.3.1 - Phone OTP authentication
- **cloud_firestore**: ^5.4.4 - NoSQL database
- **firebase_storage**: ^12.4.10 - File storage

### Utilities
- **intl**: ^0.19.0 - Internationalization
- **uuid**: ^4.5.1 - UUID generation
- **file_picker**: ^10.3.3 - File and image selection

## 📋 Prerequisites

### Required Software
- **Flutter SDK**: 3.9.2 or higher
  ```bash
  flutter --version  # Verify version
  flutter doctor     # Check installation
  ```
- **Android Studio**: Latest version with Flutter plugin
- **Android SDK**: API Level 21+ (Android 5.0 Lollipop)
- **Java Development Kit (JDK)**: 11 or higher
- **Gradle**: Included with Android Studio

### Required Accounts
- **Firebase Account**: With billing enabled (if using Cloud Functions)
- **Google Play Console**: For app publishing (optional)

### System Requirements
- **OS**: Windows 10+, macOS 10.14+, or Linux
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 10GB free space
- **Internet**: Stable connection for Firebase services

### Android Device Requirements
- **Android Version**: 5.0 (API 21) or higher
- **RAM**: 2GB minimum
- **Storage**: 100MB free space
- **Network**: Internet connection for authentication and data sync

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd OPERON/android
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Install Android Dependencies
The Android project uses Gradle, which will automatically download dependencies when building.

### 4. Verify Flutter Setup
```bash
flutter doctor
flutter doctor --android-licenses  # Accept Android licenses
```

### 5. Connect Android Device or Start Emulator

**Physical Device:**
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect device via USB
4. Verify device is detected: `flutter devices`

**Emulator:**
1. Open Android Studio
2. Go to Tools → Device Manager
3. Create new virtual device or start existing one
4. Verify emulator is running: `flutter devices`

### 6. Run the App
```bash
flutter run
```

Or specify device:
```bash
flutter run -d <device-id>
```

## 🔥 Firebase Configuration

### 1. Get google-services.json

**Step-by-Step Instructions:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`operanapp` or your project name)
3. Go to **Project Settings** (gear icon) → **General**
4. Scroll to **Your apps** section
5. Click **Add app** → Select **Android** icon
6. Enter Android package name: `com.example.operon`
   - This must match the `applicationId` in `android/app/build.gradle.kts`
7. Enter app nickname (optional): `OPERON Android`
8. Click **Register app**
9. Download `google-services.json` file
10. Place the file in: `android/android/app/google-services.json`
    - **Important**: The path is `android/android/app/` (double android folder)

### 2. Verify Package Name

Check that the package name in `google-services.json` matches your app's package name:

```kotlin
// android/android/app/build.gradle.kts
applicationId = "com.example.operon"
```

### 3. Enable Firebase Services

**Authentication:**
1. Go to Firebase Console → **Authentication** → **Sign-in method**
2. Enable **Phone** authentication
3. Configure reCAPTCHA settings
4. Add test phone numbers for development

**Firestore:**
1. Go to Firebase Console → **Firestore Database**
2. Create database if not exists
3. Start in **production mode** (rules deployed separately)
4. Choose location close to your users

**Storage:**
1. Go to Firebase Console → **Storage**
2. Get started if not initialized
3. Configure storage rules

### 4. Configure Android App

Verify `build.gradle.kts` includes Google Services plugin:

```kotlin
// android/android/app/build.gradle.kts
plugins {
    id("com.google.gms.google-services")
}
```

The plugin is already included in the project configuration.

### 5. Initialize Firebase in App

Firebase is automatically initialized in `lib/main.dart`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 6. Test Firebase Connection

Run the app and verify:
- App launches without Firebase errors
- Authentication screen appears
- No connection errors in logs

## 📁 Project Structure

```
android/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts           # App build configuration
│   │   ├── google-services.json        # Firebase config (you provide)
│   │   └── src/
│   │       └── main/
│   │           ├── AndroidManifest.xml # App manifest
│   │           └── kotlin/             # Kotlin source (if any)
│   ├── build.gradle.kts                # Project build configuration
│   ├── gradle/                         # Gradle wrapper
│   └── settings.gradle.kts             # Gradle settings
├── lib/
│   ├── core/
│   │   ├── app_constants.dart          # App-wide constants
│   │   ├── app_theme.dart              # Theme configuration
│   │   ├── config/
│   │   │   └── android_config.dart     # Android-specific config
│   │   ├── services/
│   │   │   └── android_auth_repository.dart  # Auth service
│   │   ├── organization_role.dart     # Organization role model
│   │   ├── phone_input_field.dart      # Phone input widget
│   │   ├── otp_input_field.dart        # OTP input widget
│   │   └── user.dart                   # User model
│   ├── features/
│   │   ├── auth/
│   │   │   ├── android_auth_bloc.dart  # Authentication BLoC
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── android_login_page.dart
│   │   ├── home/
│   │   │   └── presentation/
│   │   │       └── pages/
│   │   │           └── android_home_page.dart
│   │   ├── organization/
│   │   │   ├── bloc/
│   │   │   │   └── android_organization_settings_bloc.dart
│   │   │   ├── presentation/
│   │   │   │   ├── bloc/
│   │   │   │   │   └── android_organization_bloc.dart
│   │   │   │   ├── pages/
│   │   │   │   │   ├── android_organization_home_page.dart
│   │   │   │   │   ├── android_organization_select_page.dart
│   │   │   │   │   └── android_organization_settings_page.dart
│   │   │   │   └── widgets/
│   │   │   └── repositories/
│   │   │       └── android_organization_repository.dart
│   │   ├── location_pricing/
│   │   │   ├── bloc/
│   │   │   │   └── android_location_pricing_bloc.dart
│   │   │   ├── models/
│   │   │   │   └── location_pricing.dart
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── android_location_pricing_management_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── android_location_pricing_form_dialog.dart
│   │   │   └── repositories/
│   │   │       └── android_location_pricing_repository.dart
│   │   ├── payment_accounts/
│   │   │   ├── bloc/
│   │   │   │   └── android_payment_account_bloc.dart
│   │   │   ├── models/
│   │   │   │   └── payment_account.dart
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── android_payment_account_management_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── android_payment_account_form_dialog.dart
│   │   │   └── repositories/
│   │   │       └── android_payment_account_repository.dart
│   │   ├── products/
│   │   │   ├── bloc/
│   │   │   │   └── android_product_bloc.dart
│   │   │   ├── models/
│   │   │   │   └── product.dart
│   │   │   ├── presentation/
│   │   │   │   ├── pages/
│   │   │   │   │   └── android_product_management_page.dart
│   │   │   │   └── widgets/
│   │   │   │       └── android_product_form_dialog.dart
│   │   │   └── repositories/
│   │   │       └── android_product_repository.dart
│   │   └── vehicle/
│   │       ├── bloc/
│   │       │   └── android_vehicle_bloc.dart
│   │       ├── models/
│   │       │   └── vehicle.dart
│   │       ├── presentation/
│   │       │   ├── pages/
│   │       │   │   └── android_vehicle_management_page.dart
│   │       │   └── widgets/
│   │       │       └── android_vehicle_form_dialog.dart
│   │       └── repositories/
│   │           └── android_vehicle_repository.dart
│   ├── firebase_options.dart            # Firebase configuration
│   └── main.dart                        # App entry point
├── pubspec.yaml                         # Flutter dependencies
└── README.md                            # This file
```

## 🔐 Authentication Flow

### 1. Phone Number Input
- User enters 10-digit Indian mobile number
- Format: `9876543210`
- Auto-validation and formatting

### 2. OTP Verification
- OTP sent via SMS through Firebase
- User enters 6-digit OTP
- Verification code validated with Firebase Auth

### 3. User Validation
- App checks if user exists in Firestore `USERS` collection
- Verifies user document with Firebase Auth UID
- Falls back to phone number lookup if UID mismatch

### 4. Organization Check
- Verifies user has active organization access
- Checks organization status and permissions
- Loads user's organizations list

### 5. Organization Selection
- If multiple organizations: show selection screen
- If single organization: auto-select
- If no organizations: show error message

### 6. Home Screen
- Navigate to organization home page
- Display user information
- Show organization details
- Provide access to features

### Authentication States
```dart
// Auth States
- AndroidAuthInitial          // Initial state
- AndroidAuthAuthenticating   // OTP verification in progress
- AndroidAuthAuthenticated    // Successfully authenticated
- AndroidAuthUnauthenticated // Not authenticated
- AndroidAuthError           // Authentication error
```

## 💡 Key Features

### Organization Management
- **Organization Selection**: Switch between multiple organizations
- **Organization Home**: View organization overview and statistics
- **Organization Settings**: Configure organization preferences
- **Organization Details**: View organization information

### Product Management
- **Product List**: Browse all products in organization
- **Add Product**: Create new products with details
- **Edit Product**: Update existing product information
- **Delete Product**: Remove products from organization
- **Product Search**: Search products by name or SKU
- **Image Upload**: Add product images from device

### Location Pricing
- **Location List**: View all delivery locations
- **Add Location**: Create new delivery locations
- **Edit Location**: Update location details and pricing
- **Delete Location**: Remove delivery locations
- **Pricing Rules**: Configure location-based pricing rules

### Vehicle Management
- **Vehicle List**: View all vehicles in organization
- **Add Vehicle**: Register new vehicles
- **Edit Vehicle**: Update vehicle information
- **Delete Vehicle**: Remove vehicles from fleet
- **Driver Assignment**: Assign drivers to vehicles
- **Status Tracking**: Track vehicle status (active, maintenance, retired)

### Payment Accounts
- **Account List**: View all payment accounts
- **Add Account**: Register new payment accounts
- **Edit Account**: Update account details
- **Delete Account**: Remove payment accounts
- **Account Verification**: Verify payment account details

## 📱 Usage Guide

### First-Time Setup

1. **Install App**: Install APK or download from Play Store
2. **Launch App**: Open OPERON Android app
3. **Login**: Enter phone number and verify OTP
4. **Select Organization**: Choose your organization
5. **Navigate**: Use bottom navigation or menu to access features

### Daily Usage

**Login:**
1. Open app
2. Enter phone number
3. Enter OTP received via SMS
4. Select organization (if multiple)

**Navigate Features:**
- Use bottom navigation bar
- Access menu from app bar
- Use swipe gestures where available

**Manage Products:**
1. Navigate to Products
2. Tap + to add new product
3. Fill product details
4. Upload image (optional)
5. Save product

**Manage Vehicles:**
1. Navigate to Vehicles
2. View vehicle list
3. Tap vehicle to view details
4. Edit or delete as needed

## 🔧 Development

### Running in Debug Mode
```bash
flutter run
```

### Running in Release Mode
```bash
flutter run --release
```

### Hot Reload and Hot Restart
- **Hot Reload**: Press `r` in terminal (preserves state)
- **Hot Restart**: Press `R` in terminal (resets state)
- **Full Restart**: Press `q` to quit and restart

### Debug Logging
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  debugPrint('Debug message');
}
```

### Code Style
Follow Flutter/Dart conventions:
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused
- Use BLoC pattern for state management
- Implement proper error handling

## 🏗️ Build Configuration

### App Configuration

**Package Name:**
```kotlin
// android/android/app/build.gradle.kts
applicationId = "com.example.operon"
```

**Version Information:**
```yaml
# pubspec.yaml
version: 1.0.0+1
```
- Version name: `1.0.0`
- Version code: `1`

**Minimum SDK:**
```kotlin
minSdk = flutter.minSdkVersion  // Typically 21
```

**Target SDK:**
```kotlin
targetSdk = 36
```

**Compile SDK:**
```kotlin
compileSdk = 36
```

### Signing Configuration

For release builds, configure signing:

1. **Generate Keystore:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create key.properties:**
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

3. **Update build.gradle.kts:**
```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

## 🚀 Deployment

### 1. Build APK (Debug)
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### 2. Build APK (Release)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### 3. Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### 4. Build Split APKs (by ABI)
```bash
flutter build apk --split-per-abi --release
```
Creates separate APKs for:
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

### 5. Verify Build
```bash
# Check APK size
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 6. Google Play Store Deployment

1. **Create App in Play Console**
   - Go to Google Play Console
   - Create new app
   - Fill app details

2. **Upload App Bundle**
   - Go to Production → Create new release
   - Upload `app-release.aab`
   - Add release notes
   - Review and roll out

3. **Complete Store Listing**
   - Add app description
   - Upload screenshots
   - Set content rating
   - Complete privacy policy

## 🧪 Testing

### Test Phone Numbers

The app requires users to exist in Firestore `USERS` collection. For testing:

**Setup Test User in Firestore:**
```json
// Collection: USERS
// Document ID: [Firebase Auth UID]
{
  "userId": "[Firebase Auth UID]",
  "name": "Test User",
  "phoneNo": "+919876543210",
  "email": "test@example.com",
  "status": "active",
  "createdDate": "2024-01-01T00:00:00Z",
  "updatedDate": "2024-01-01T00:00:00Z",
  "organizations": [
    {
      "orgId": "test-org-1",
      "role": 1,
      "status": "active",
      "joinedDate": "2024-01-01T00:00:00Z"
    }
  ],
  "metadata": {
    "totalOrganizations": 1,
    "primaryOrgId": "test-org-1",
    "notificationPreferences": {}
  }
}
```

**Test with Real Phone Number:**
1. Use a real phone number for OTP testing
2. Ensure the phone number has corresponding user data in Firestore
3. Verify organization access is configured

### Unit Testing
```bash
flutter test
```

### Widget Testing
```bash
flutter test test/widget_test.dart
```

### Integration Testing
```bash
flutter drive --target=test_driver/app.dart
```

### Manual Testing Checklist
- [ ] Phone number input validation
- [ ] OTP verification flow
- [ ] User authentication
- [ ] Organization selection
- [ ] Product CRUD operations
- [ ] Location pricing management
- [ ] Vehicle management
- [ ] Payment account management
- [ ] Navigation between screens
- [ ] Error handling and error messages
- [ ] Image upload functionality
- [ ] Offline behavior (if implemented)

## 🔍 Troubleshooting

### Common Issues

#### 1. Firebase not initialized
**Problem**: App crashes or shows Firebase initialization errors

**Solution**:
- Ensure `google-services.json` is in `android/android/app/`
- Verify package name matches in `google-services.json` and `build.gradle.kts`
- Check Firebase project configuration
- Verify Firebase services are enabled in Firebase Console

#### 2. OTP not received
**Problem**: SMS with OTP code not received

**Solution**:
- Verify phone number format: `+91XXXXXXXXXX` (with country code)
- Check Firebase Authentication quota (free tier limits)
- Ensure reCAPTCHA is configured properly
- Test with Firebase test phone numbers
- Check device has active SIM and network connection
- Verify Firebase project has billing enabled (if required)

#### 3. User not found error
**Problem**: "User not found" after successful OTP verification

**Solution**:
- Verify user exists in Firestore `USERS` collection
- Check user has organization access in `organizations` array
- Ensure organization status is "active"
- Verify Firebase Auth UID matches Firestore document ID
- Check user document structure matches expected schema
- Review authentication repository phone lookup logic

#### 4. Build errors
**Problem**: Gradle build fails

**Solution**:
```bash
# Clean build
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

**Common Build Issues**:
- **Gradle version mismatch**: Update Gradle wrapper
- **Missing dependencies**: Run `flutter pub get`
- **SDK version**: Check Android SDK is installed
- **Java version**: Verify JDK 11+ is installed

#### 5. App crashes on launch
**Problem**: App immediately crashes after opening

**Solution**:
- Check logcat for error messages: `adb logcat`
- Verify Firebase initialization in `main.dart`
- Check all required permissions in `AndroidManifest.xml`
- Ensure all dependencies are properly installed
- Review Firebase configuration

#### 6. Organization selection not working
**Problem**: Can't select or switch organizations

**Solution**:
- Verify user has multiple organizations in Firestore
- Check organization documents are properly structured
- Ensure organization status is "active"
- Review organization BLoC state management
- Check network connectivity

#### 7. Image upload fails
**Problem**: Cannot upload images from device

**Solution**:
- Check storage permissions in `AndroidManifest.xml`
- Verify Firebase Storage rules allow uploads
- Check file size limits
- Ensure image format is supported (JPG, PNG)
- Verify network connection
- Check Firebase Storage quota

#### 8. Performance issues
**Problem**: App is slow or unresponsive

**Solution**:
- Enable Flutter performance overlay: `flutter run --profile`
- Check for memory leaks
- Optimize image loading and caching
- Review BLoC state management efficiency
- Consider implementing pagination for large lists
- Use Flutter DevTools for profiling

### Debug Mode
```dart
// Enable debug logging in main.dart
import 'package:flutter/foundation.dart';

void main() async {
  if (kDebugMode) {
    debugPrint('Debug mode enabled');
  }
  // ... rest of main function
}
```

### Viewing Logs
```bash
# View Flutter logs
flutter logs

# View Android logcat
adb logcat

# Filter logs
adb logcat | grep -i "flutter\|operon"
```

### Firebase Console Debugging
- **Authentication Logs**: Firebase Console → Authentication → Users
- **Firestore Data**: Firebase Console → Firestore Database
- **Storage Files**: Firebase Console → Storage
- **Function Logs**: Firebase Console → Functions → Logs

## ⚡ Performance Optimization

### Image Optimization
- Use cached network images
- Compress images before upload
- Lazy load images in lists
- Use appropriate image formats

### State Management
- Avoid unnecessary rebuilds
- Use `const` constructors where possible
- Implement proper BLoC state management
- Cache data locally when appropriate

### Network Optimization
- Implement request batching
- Use pagination for large lists
- Cache frequently accessed data
- Minimize Firestore reads

### Build Optimization
- Use release builds for production
- Enable code obfuscation for release
- Remove debug code in release builds
- Optimize app size with split APKs

## 📱 Android-Specific Considerations

### Permissions

Required permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

Optional permissions (for features):
```xml
<!-- Camera access for image capture -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>

<!-- Storage access for file picking -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### App Icon

Update app icon:
1. Generate icons using [Flutter Launcher Icons](https://pub.dev/packages/flutter_launcher_icons)
2. Place icons in `android/app/src/main/res/mipmap-*` folders
3. Update `AndroidManifest.xml` with icon reference

### App Name

Update app name in `AndroidManifest.xml`:
```xml
<application
    android:label="OPERON"
    ...>
```

### ProGuard/R8 Rules

For release builds with code obfuscation, add rules to `android/app/proguard-rules.pro`:
```
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
```

### Background Services (Future)
- Implement background sync
- Handle push notifications
- Sync data when app is backgrounded

### Deep Linking (Future)
- Implement deep links for organization invitations
- Handle app links from SMS/email

## 📚 Additional Resources

### Documentation
- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Android Documentation](https://firebase.google.com/docs/android/setup)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)
- [Material Design 3](https://m3.material.io/)

### Related Files
- Main app README: `../README.md`
- SuperAdmin Setup: `../SUPERADMIN_SETUP_GUIDE.md`
- Testing Guide: `../TESTING_GUIDE.md`

### Support
- **Flutter Issues**: Check Flutter GitHub issues
- **Firebase Support**: Firebase Console support
- **Development Team**: Contact OPERON development team

---

## 📄 License

This project is part of the OPERON Organization Management System. All rights reserved.

## 🏷️ Version

**Current Version**: 1.0.0+1  
**Flutter Version**: 3.9.2+  
**Android SDK**: 21+ (Android 5.0+)  
**Target SDK**: 36

**Last Updated**: December 2024
