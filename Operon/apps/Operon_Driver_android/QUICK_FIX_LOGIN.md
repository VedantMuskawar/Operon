# Quick Fix: Login Timeout Issue

## Problem
You're seeing this error:
```
TimeoutException after 0:01:00.000000: Phone verification request timed out
```

## Root Cause
Firebase Phone Authentication requires the **SHA-1 fingerprint** to be registered in Firebase Console. Without it, Firebase won't respond to authentication requests.

## Solution (5 minutes)

### Step 1: Get Your SHA-1 Fingerprint

Open Terminal and run:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

**Copy the SHA-1 value** (it looks like: `A1:B2:C3:D4:E5:F6:...`)

### Step 2: Add SHA-1 to Firebase Console

1. Go to: https://console.firebase.google.com/
2. Select project: **operonappsuite**
3. Click ⚙️ **Project settings**
4. Scroll to **Your apps** section
5. Find: **com.operondriverandroid.app** (Android app)
6. Click **"Add fingerprint"**
7. Paste your SHA-1 fingerprint
8. Click **Save**

### Step 3: Wait & Rebuild

1. **Wait 5-10 minutes** for Firebase to propagate changes
2. Rebuild the app:
   ```bash
   cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android
   flutter clean
   flutter pub get
   flutter run
   ```

## Alternative: Get SHA-1 Using Gradle

If keytool doesn't work:

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android/android
./gradlew signingReport
```

Look for:
```
Variant: debug
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

## Why This Happens

Firebase Phone Authentication uses **SafetyNet/Play Integrity** to verify your app. This requires:
- ✅ Package name registered in Firebase
- ✅ SHA-1 fingerprint registered in Firebase
- ✅ google-services.json properly configured

Without SHA-1, Firebase rejects the request silently, causing the timeout.

## Verification Checklist

After adding SHA-1, verify:
- [ ] SHA-1 added in Firebase Console
- [ ] Waited 5-10 minutes
- [ ] Ran `flutter clean`
- [ ] Rebuilt the app
- [ ] Phone authentication enabled in Firebase Console (Authentication → Sign-in method → Phone)

## Still Not Working?

1. **Double-check package name**: Must be exactly `com.operondriverandroid.app`
2. **Check Firebase Console**: Authentication → Sign-in method → Phone should be **Enabled**
3. **Verify google-services.json**: Should be at `android/app/google-services.json`
4. **Check network**: Ensure device has internet connection
5. **Try again**: Sometimes Firebase needs a few more minutes to propagate

## App Check Warning (Can Ignore)

The warning:
```
W/LocalRequestInterceptor: Error getting App Check token; using placeholder token instead
```

This is **not blocking** - Firebase will use a placeholder token. You can ignore this for now. If you want to fix it later, you can set up Firebase App Check, but it's not required for phone authentication to work.
