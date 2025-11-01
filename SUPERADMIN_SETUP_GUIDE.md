# SuperAdmin Setup Guide

## Overview
This guide will help you set up the SuperAdmin authentication system with proper Firebase schema and phone number-based user lookup.

## Problem Solved
The previous system had an issue where Firebase Auth generates random UIDs when users sign in with phone numbers, but user documents were created with custom IDs. This caused "user not found" errors even when users existed in the database.

## Solution Implemented
1. **Phone Number Lookup**: Added fallback mechanism to find users by phone number when UID lookup fails
2. **User Migration**: Automatically migrate user documents from old IDs to correct Firebase Auth UIDs
3. **SuperAdmin Organization**: Created dedicated SuperAdmin organization for data consistency
4. **Proper Schema**: Implemented comprehensive Firebase schema with all necessary collections

---

## Setup Instructions

### Option A: Using Initialization Script (Recommended)

#### Step 1: Clear Existing Data
1. Go to Firebase Console → Firestore Database
2. Delete all documents from `USERS` and `ORGANIZATIONS` collections
3. Keep the collections but remove all documents

#### Step 2: Create Firebase Auth User
1. Run your Flutter app
2. Login with SuperAdmin phone number: `+919876543210`
3. Use any 6-digit OTP (for development)
4. This will create a Firebase Auth user with a unique UID

#### Step 3: Get Firebase Auth UID
1. Go to Firebase Console → Authentication → Users
2. Find the user with phone number `+919876543210`
3. Copy the UID (it will look like: `kX9mP2nQ8rT7vB2cF5hJ8...`)

#### Step 4: Run Initialization Script
1. Open `lib/core/utils/init_superadmin.dart`
2. Update the example usage section with your actual UID:
   ```dart
   void main() async {
     const firebaseAuthUid = 'your-actual-firebase-auth-uid';
     await initializeSuperAdminData(firebaseAuthUid);
   }
   ```
3. Run the script: `dart lib/core/utils/init_superadmin.dart`

#### Step 5: Test Login
1. Logout from the app
2. Login again with phone number `+919876543210`
3. Should work perfectly and show organization selection

---

### Option B: Manual Setup in Firebase Console

#### Step 1: Clear Existing Data
1. Delete all documents from `USERS` and `ORGANIZATIONS` collections

#### Step 2: Create Firebase Auth User
1. Login once with SuperAdmin phone number to create Firebase Auth user
2. Get the Firebase Auth UID from Firebase Console

#### Step 3: Create Documents Manually
Use the templates in `firebase_init_data.json`:

1. **Create SuperAdmin Organization**:
   - Collection: `ORGANIZATIONS`
   - Document ID: `superadmin_org`
   - Data: Use template from `firebase_init_data.json`

2. **Create SuperAdmin User**:
   - Collection: `USERS`
   - Document ID: `{your-actual-firebase-auth-uid}`
   - Data: Use template, replace `{firebaseAuthUID}` with actual UID

3. **Create SuperAdmin Config**:
   - Collection: `SUPERADMIN_CONFIG`
   - Document ID: `settings`
   - Data: Use template from JSON file

4. **Create System Metadata**:
   - Collection: `SYSTEM_METADATA`
   - Document ID: `stats`
   - Data: Use template from JSON file

5. **Create Organization User Subcollection**:
   - Collection: `ORGANIZATIONS/superadmin_org/USERS`
   - Document ID: `{your-actual-firebase-auth-uid}`
   - Data: Use template from JSON file

---

## Adding Additional SuperAdmins

### Method 1: Through Firebase Console
1. Have the person login once with their phone number
2. Get their Firebase Auth UID from Firebase Console
3. Create a new document in `USERS` collection:
   - Document ID: `{their-firebase-auth-uid}`
   - Copy the SuperAdmin user template
   - Update phone number, email, and name
   - Keep the same organization structure
4. Add them to `ORGANIZATIONS/superadmin_org/USERS` subcollection

### Method 2: Through Code (Future Enhancement)
We can add a UI component for SuperAdmins to invite other SuperAdmins.

---

## Firebase Schema Overview

### Collections Created:

1. **USERS**: User documents with Firebase Auth UID as document ID
2. **ORGANIZATIONS**: Organization data including SuperAdmin org
3. **SUPERADMIN_CONFIG**: System configuration settings
4. **SYSTEM_METADATA**: System-wide statistics and metadata

### Key Features:

- **Phone Number Lookup**: Automatic fallback when UID lookup fails
- **User Migration**: Seamless migration from old document IDs to Firebase Auth UIDs
- **SuperAdmin Organization**: Dedicated org for all SuperAdmins
- **Security Rules**: Proper access control with SuperAdmin checks
- **Indexes**: Optimized queries for phone number lookups

---

## Troubleshooting

### Issue: "User not found" error
**Solution**: Make sure you've run the initialization script or manually created the user document with the correct Firebase Auth UID.

### Issue: Login works but no organization selection
**Solution**: Check that the user document has the `organizations` array with at least one active organization.

### Issue: Permission denied errors
**Solution**: Verify that Firestore rules are deployed and the user has the correct SuperAdmin role.

### Issue: Phone number lookup fails
**Solution**: Check that the phone number index is deployed in Firestore indexes.

---

## Files Modified/Created

### New Files:
- `lib/core/utils/init_superadmin.dart` - Initialization script
- `firebase_init_data.json` - JSON templates for manual setup
- `SUPERADMIN_SETUP_GUIDE.md` - This guide

### Modified Files:
- `lib/features/auth/repository/auth_repository.dart` - Added phone lookup and migration
- `lib/core/constants/app_constants.dart` - Added SuperAdmin constants
- `firestore.indexes.json` - Added phone number index
- `firestore.rules` - Updated security rules

### Deleted Files:
- `test_data_creator.dart` - No longer needed

---

## Testing Checklist

- [ ] Login with SuperAdmin phone number works
- [ ] Organization selection screen appears
- [ ] Dashboard loads correctly
- [ ] User document is created with correct Firebase Auth UID
- [ ] Phone number lookup fallback works for pre-created users
- [ ] User migration works when UID mismatch occurs
- [ ] Firestore security rules allow proper access
- [ ] All collections are created with correct data structure

---

## Next Steps

1. **Test the complete flow** with SuperAdmin login
2. **Add additional SuperAdmins** using the methods described above
3. **Create regular organizations** through the SuperAdmin interface
4. **Invite regular users** to organizations
5. **Monitor system performance** and adjust indexes if needed

The authentication system is now robust and will handle both new users and pre-created users seamlessly!
