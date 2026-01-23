# Troubleshooting: Phone Authentication Timeout

## ✅ Verified
- SHA-1 fingerprint is correctly added: `b2:78:d5:54:80:97:65:8e:72:73:70:b5:05:6b:8e:e1:15:94:2a:0f`
- Package name matches: `com.operondriverandroid.app`
- google-services.json is present

## 🔍 Step-by-Step Troubleshooting

### Step 1: Verify Phone Authentication is Enabled

1. Go to: https://console.firebase.google.com/project/operonappsuite/authentication/providers
2. Find **Phone** in the list
3. Click on it
4. Ensure it's **Enabled** (toggle should be ON)
5. Click **Save**

### Step 2: Full App Restart (Critical)

**DO NOT use hot restart** - you need a full rebuild:

```bash
# Stop the app completely first
# Then run:
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Driver_android
flutter clean
flutter pub get
flutter run
```

### Step 3: Wait for Firebase Propagation

After adding SHA-1, Firebase needs time to propagate:
- **Minimum**: 5 minutes
- **Recommended**: 10-15 minutes
- **Maximum**: Sometimes up to 30 minutes

If you just added SHA-1, wait 15 minutes and try again.

### Step 4: Test with Firebase Test Number

Try using a Firebase test number to isolate the issue:

**Test Phone Number**: `+16505553434`  
**OTP Code**: `123456`

If this works, the issue is with real phone numbers (likely propagation delay).

### Step 5: Check Network

1. Ensure device/emulator has internet
2. Try on a different network (WiFi vs Mobile data)
3. Check if other Firebase services work (Firestore, etc.)

### Step 6: Verify Firebase Project

1. Go to Firebase Console
2. Ensure you're in project: **operonappsuite**
3. Check that `com.operondriverandroid.app` is listed under Android apps
4. Verify SHA-1 is listed under that app

## Common Issues & Solutions

### Issue: Still timing out after 15 minutes

**Possible causes:**
1. Phone Authentication not enabled in Firebase Console
2. Wrong Firebase project selected
3. Network connectivity issues
4. Firebase quota exceeded (check Firebase Console → Usage)

**Solution:**
- Double-check Phone Authentication is enabled
- Try test number first
- Check Firebase Console for any quota/error messages

### Issue: Test number works but real number doesn't

**Cause**: SHA-1 propagation delay or real number restrictions

**Solution:**
- Wait another 10-15 minutes
- Check if your phone number format is correct (should include country code: +91...)
- Verify phone number isn't blocked in Firebase

### Issue: "App not authorized" error

**Cause**: SHA-1 mismatch or not propagated

**Solution:**
- Verify SHA-1 in Firebase Console matches: `b2:78:d5:54:80:97:65:8e:72:73:70:b5:05:6b:8e:e1:15:94:2a:0f`
- Wait for propagation
- Do full rebuild (`flutter clean` then `flutter run`)

## Quick Test Checklist

Run through this checklist:

- [ ] Phone Authentication enabled in Firebase Console
- [ ] SHA-1 added to `com.operondriverandroid.app` in Firebase Console
- [ ] Waited at least 10 minutes after adding SHA-1
- [ ] Did `flutter clean` and full rebuild (not hot restart)
- [ ] Tried test number: `+16505553434` with code `123456`
- [ ] Device has internet connection
- [ ] Using correct Firebase project: `operonappsuite`

## Still Not Working?

If all above steps are done and it's still timing out:

1. **Check Firebase Console Logs**: 
   - Go to Firebase Console → Authentication → Users
   - Check if there are any error messages

2. **Check Firebase Quota**:
   - Go to Firebase Console → Usage
   - Verify SMS quota isn't exceeded

3. **Try Different Phone Number**:
   - Test with a different phone number
   - Ensure format is correct: `+91XXXXXXXXXX` (with country code)

4. **Contact Firebase Support**:
   - If everything is configured correctly but still not working
   - Check Firebase status page for outages

## Expected Behavior After Fix

Once everything is working:
- OTP request should complete within 5-10 seconds
- You should receive verification code (or test code works)
- No timeout errors
- Login proceeds to OTP screen
