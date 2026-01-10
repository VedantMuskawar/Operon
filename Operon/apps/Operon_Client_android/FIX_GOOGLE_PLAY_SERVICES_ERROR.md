# Fix Google Play Services SecurityException Error

## Error
```
E/GoogleApiManager: Failed to get service from broker.
E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
W/GoogleApiManager: Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR, resolution=null, message=null, clientMethodKey=null}
```

## Root Cause
This error occurs when your app's SHA certificate fingerprints are not registered in Firebase Console. Google Play Services requires these fingerprints to verify your app's identity.

## Solution

### Step 1: Get Your Debug SHA Fingerprints

Run this command in your terminal:

```bash
cd apps/Operon_Client_android/android
./gradlew signingReport
```

Look for output like this:
```
Variant: debug
Config: debug
Store: ~/.android/debug.keystore
Alias: AndroidDebugKey
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

**Alternative method (if gradlew doesn't work):**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Step 2: Add SHA Fingerprints to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **`operonappsuite`**
3. Click the gear icon ⚙️ → **Project Settings**
4. Scroll down to **Your apps** section
5. Find the Android app with package name: **`com.operonclientandroid.app`**
   - If it doesn't exist, click **"Add app"** → **Android** and register it
6. Under **SHA certificate fingerprints**, click **"Add fingerprint"**
7. Add BOTH:
   - **SHA-1** (from Step 1)
   - **SHA-256** (from Step 1)
8. Click **Save**

### Step 3: Download Updated google-services.json

1. After adding SHA fingerprints, click **"Download google-services.json"** in Firebase Console
2. Replace the file at: `apps/Operon_Client_android/android/app/google-services.json`
3. Verify the file contains your package name: `"package_name": "com.operonclientandroid.app"`

### Step 4: Clean and Rebuild

```bash
cd apps/Operon_Client_android
flutter clean
flutter pub get
flutter run
```

## Verification

After completing these steps, the error should disappear. You can verify by:

1. Running the app again
2. Checking logcat - the `DEVELOPER_ERROR` should be gone
3. Firebase services (Auth, Firestore, etc.) should work properly

## Important Notes

- **Debug vs Release**: You need to add SHA fingerprints for BOTH debug and release keystores
- **Team Development**: Each developer's debug keystore has different fingerprints - add all of them
- **CI/CD**: If using CI/CD, add the release keystore's SHA fingerprints
- **Wait Time**: Sometimes it takes a few minutes for Firebase to recognize new fingerprints

## Current Configuration

- **Package Name**: `com.operonclientandroid.app` ✅ (matches google-services.json)
- **Firebase Project**: `operonappsuite`
- **google-services.json**: Already present at `android/app/google-services.json`

The only missing piece is the SHA fingerprints in Firebase Console.

