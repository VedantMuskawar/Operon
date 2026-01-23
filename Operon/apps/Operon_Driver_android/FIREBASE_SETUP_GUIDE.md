# Firebase Configuration Guide for Operon Driver Android

## Current Configuration Status

✅ **Package Name**: `com.operondriverandroid.app` (verified in google-services.json)
✅ **google-services.json**: Present at `android/app/google-services.json`
✅ **Firebase Project**: `operonappsuite`

## Step 1: Get SHA-1 Fingerprint

You need to get the SHA-1 fingerprint of your app's signing key. There are two scenarios:

### Option A: Debug Build (Development)

For development builds, use the debug keystore:

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android/android

# Get SHA-1 from debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Or use Gradle command:**
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android/android
./gradlew signingReport
```

Look for the line that says:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

### Option B: Release Build (Production)

If you have a release keystore, use:

```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-key-alias
```

**Note**: You'll need both **debug** and **release** SHA-1 fingerprints if you want to test with debug builds and deploy release builds.

## Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **operonappsuite**
3. Click the gear icon ⚙️ next to "Project Overview" → **Project settings**
4. Scroll down to **Your apps** section
5. Find the Android app with package name: **com.operondriverandroid.app**
6. Click on the app to expand it
7. Click **"Add fingerprint"** button
8. Paste your SHA-1 fingerprint (the one you got from Step 1)
9. Click **Save**

## Step 3: Download Updated google-services.json (if needed)

After adding SHA-1:
1. In Firebase Console, click **"Download google-services.json"**
2. Replace the existing file at:
   ```
   apps/Operon_Driver_android/android/app/google-services.json
   ```

## Step 4: Verify Configuration

### Check Package Name Matches

The package name in your `build.gradle.kts` should match:
- Firebase Console: `com.operondriverandroid.app`
- google-services.json: `com.operondriverandroid.app`

### Verify google-services.json Location

Make sure `google-services.json` is in:
```
apps/Operon_Driver_android/android/app/google-services.json
```

### Check build.gradle.kts

Ensure your `android/app/build.gradle.kts` includes:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // This line is required
}
```

And at the bottom of the file:
```kotlin
apply plugin: 'com.google.gms.google-services'
```

## Step 5: Rebuild the App

After adding SHA-1 fingerprint:

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android
flutter clean
flutter pub get
flutter run
```

## Troubleshooting

### Issue: "App not authorized" error

**Solution**: 
- Make sure you added the SHA-1 fingerprint correctly
- Wait 5-10 minutes after adding SHA-1 for Firebase to propagate changes
- Rebuild the app completely (`flutter clean` then `flutter run`)

### Issue: Phone authentication not working

**Check**:
1. SHA-1 fingerprint is added in Firebase Console
2. Package name matches exactly: `com.operondriverandroid.app`
3. google-services.json is in the correct location
4. Firebase Authentication → Sign-in method → Phone is enabled

### Issue: Can't find SHA-1

**Alternative method using Gradle**:
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android/android
./gradlew signingReport
```

Look for output like:
```
Variant: debug
Config: debug
Store: ~/.android/debug.keystore
Alias: AndroidDebugKey
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

## Quick Command Reference

```bash
# Get SHA-1 (Debug)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1

# Get SHA-1 (Using Gradle)
cd apps/Operon_Driver_android/android && ./gradlew signingReport

# Clean and rebuild
cd apps/Operon_Driver_android && flutter clean && flutter pub get && flutter run
```

## Important Notes

1. **Debug vs Release**: You need separate SHA-1 fingerprints for debug and release builds
2. **Wait Time**: After adding SHA-1, wait 5-10 minutes before testing
3. **Case Sensitive**: Package names are case-sensitive, ensure exact match
4. **Multiple SHA-1s**: You can add multiple SHA-1 fingerprints for the same app
