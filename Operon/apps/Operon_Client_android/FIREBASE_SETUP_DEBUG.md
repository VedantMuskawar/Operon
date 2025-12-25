# Firebase Phone Auth Debugging Guide

## Current Issue
Firebase Auth's `verifyPhoneNumber` is being called but **no callbacks are firing**. This indicates the native Android plugin isn't responding, which is almost always a Firebase configuration issue.

## Step-by-Step Fix

### 1. Verify Package Name in Firebase Console
- Go to [Firebase Console](https://console.firebase.google.com/)
- Select your project: `dash-6866c`
- Go to **Project Settings** (gear icon) → **Your apps**
- Find the Android app with package name: **`com.operon.app`**
- If it doesn't exist, you need to add it
- If it exists but package name is different, that's the problem

### 2. Add SHA Certificate Fingerprints
In Firebase Console → Your apps → Android app (`com.operon.app`):

**Under "SHA certificate fingerprints", add BOTH:**

**SHA-1:**
```
b2:78:d5:54:80:97:65:8e:72:73:70:b5:05:6b:8e:e1:15:94:2a:0f
```

**SHA-256:**
```
d8:f3:93:25:e4:b3:1f:78:76:3f:1e:bf:d0:13:eb:f3:f7:47:bb:20:52:0c:59:f7:72:9b:3c:3b:84:c0:a2:db
```

**Important:** 
- Make sure there are NO spaces
- Make sure you're adding to the correct app (`com.operon.app`)
- After adding, you MUST download the new `google-services.json`

### 3. Download and Replace google-services.json
- After adding SHA keys, click **"Download google-services.json"** in Firebase Console
- Replace the file at: `apps/dash_mobile/android/app/google-services.json`
- Verify the file contains:
  ```json
  "package_name": "com.operon.app"
  ```

### 4. Verify Phone Authentication is Enabled
- Firebase Console → **Authentication** → **Sign-in method**
- Find **Phone** in the list
- Click it and ensure it's **Enabled**
- Save if you made changes

### 5. Get Your Actual SHA Fingerprints (Verification)
Run this command to verify your app's actual SHA fingerprints:

```bash
cd apps/dash_mobile/android
./gradlew signingReport
```

Look for the output under `Variant: debug` and compare with what you added in Firebase Console.

### 6. Check Android Logcat for Firebase Errors
Run this command while testing the OTP flow:

```bash
adb logcat | grep -i "firebase\|auth\|ERROR"
```

Look for errors like:
- `ERROR_APP_NOT_AUTHORIZED`
- `ERROR_INVALID_APP_CREDENTIAL`
- `ERROR_MISSING_INSTANCEID_SERVICE`
- Any other Firebase-related errors

### 7. Clean Rebuild
After making changes:

```bash
cd apps/dash_mobile
flutter clean
flutter pub get
flutter run
```

## Common Issues

### Issue: "No callbacks firing"
**Cause:** SHA keys not added or wrong package name
**Fix:** Follow steps 1-3 above

### Issue: "App not authorized"
**Cause:** SHA keys don't match the app's actual signature
**Fix:** Run `./gradlew signingReport` and add the EXACT SHA keys shown

### Issue: "Invalid app credential"
**Cause:** `google-services.json` is outdated or wrong
**Fix:** Download fresh `google-services.json` after adding SHA keys

## Testing
After completing all steps:
1. Rebuild the app completely
2. Try sending OTP
3. Check logs for `[AuthRepository] codeSent` or `[AuthRepository] verificationFailed`
4. If still timing out, check Android logcat for Firebase errors


