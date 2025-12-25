# Duplicate Phone Number Validation - Implementation

## Overview

Added comprehensive error handling to prevent duplicate phone numbers in the USERS Firestore collection. The system now validates phone number uniqueness when creating or updating users.

## Problem

Previously, the system could potentially create multiple user documents with the same phone number, leading to data integrity issues and confusion.

## Solution

### 1. Created Exception Class

**Files:**
- `apps/Operon_Client_web/lib/domain/exceptions/duplicate_phone_exception.dart`
- `apps/Operon_Client_android/lib/domain/exceptions/duplicate_phone_exception.dart`

```dart
class DuplicatePhoneNumberException implements Exception {
  const DuplicatePhoneNumberException(this.phoneNumber, [this.existingUserId]);
  // Provides user-friendly error messages
}
```

### 2. Enhanced User Creation Logic

**Files Modified:**
- `apps/Operon_Client_web/lib/data/datasources/users_data_source.dart`
- `apps/Operon_Client_android/lib/data/datasources/users_data_source.dart`

**Key Changes:**
- `_findOrCreateUserDoc()` now throws `DuplicatePhoneNumberException` when:
  - Creating a new user with a phone that already exists (when `allowUpdate: false`)
  - Providing a `preferredUserId` that conflicts with an existing user's phone
- Added double-check validation to prevent race conditions
- Added phone change validation when updating users

### 3. Updated Error Handling

**Files Modified:**
- `apps/Operon_Client_web/lib/presentation/blocs/users/users_cubit.dart`
- `apps/Operon_Client_android/lib/presentation/blocs/users/users_cubit.dart`

**Changes:**
- Added specific catch block for `DuplicatePhoneNumberException`
- Displays user-friendly error messages via `DashSnackbar`

### 4. SuperAdmin Protection

**File Modified:**
- `apps/Operon_SuperAdmin/lib/data/datasources/organization_remote_data_source.dart`

**Changes:**
- Added double-check validation in `createOrUpdateAdmin()` to prevent race conditions
- Handles existing users gracefully (updates instead of creating duplicate)

## Validation Rules

### When Creating a New User:
1. ✅ Check if phone number already exists
2. ✅ If exists → Throw `DuplicatePhoneNumberException`
3. ✅ If `preferredUserId` provided and conflicts → Throw error
4. ✅ Double-check before writing to prevent race conditions

### When Updating an Existing User:
1. ✅ Check if phone number is being changed
2. ✅ If changed, verify new phone doesn't already exist
3. ✅ If new phone exists for different user → Throw `DuplicatePhoneNumberException`
4. ✅ Allow updating same user's phone if it's the same number

## Error Messages

Users will see clear error messages:
- "Phone number {phone} is already registered to another user."
- "Phone number {phone} is already registered."

These are displayed via `DashSnackbar` in the UI.

## Database-Level Protection

### Recommended: Add Firestore Security Rule

For additional protection at the database level, consider adding this Firestore security rule:

```javascript
match /USERS/{userId} {
  // Allow read if authenticated
  allow read: if request.auth != null;
  
  // Allow create only if phone doesn't exist
  allow create: if request.auth != null 
    && !exists(/databases/$(database)/documents/USERS/$(request.resource.data.phone));
  
  // Allow update if phone doesn't change or new phone doesn't exist
  allow update: if request.auth != null
    && (request.resource.data.phone == resource.data.phone
        || !exists(/databases/$(database)/documents/USERS/$(request.resource.data.phone)));
  
  // Allow delete if authenticated
  allow delete: if request.auth != null;
}
```

**Note:** The above rule uses a simplified check. For production, you may need a Cloud Function to enforce uniqueness since Firestore security rules have limitations on querying other documents.

## Testing

### Test Cases:

1. **Create new user with unique phone** ✅
   - Should succeed

2. **Create new user with existing phone** ✅
   - Should throw `DuplicatePhoneNumberException`
   - Should show error message in UI

3. **Update user without changing phone** ✅
   - Should succeed

4. **Update user's phone to existing phone** ✅
   - Should throw `DuplicatePhoneNumberException`
   - Should show error message in UI

5. **Update user's phone to new unique phone** ✅
   - Should succeed

6. **Create user with preferredUserId that conflicts** ✅
   - Should throw `DuplicatePhoneNumberException`

## Files Changed

### Web App:
- `lib/domain/exceptions/duplicate_phone_exception.dart` (NEW)
- `lib/data/datasources/users_data_source.dart`
- `lib/presentation/blocs/users/users_cubit.dart`

### Android App:
- `lib/domain/exceptions/duplicate_phone_exception.dart` (NEW)
- `lib/data/datasources/users_data_source.dart`
- `lib/presentation/blocs/users/users_cubit.dart`

### SuperAdmin:
- `lib/data/datasources/organization_remote_data_source.dart`

## Status: ✅ COMPLETE

All validation logic is in place. The system now prevents duplicate phone numbers in the USERS collection with clear error messages displayed to users.
