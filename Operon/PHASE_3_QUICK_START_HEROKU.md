# Phase 3: Quick Start - Deploy to Heroku in 10 Minutes

**Goal**: Get v1.0.1 with update checking live for internal testing  
**Estimated Time**: 10-15 minutes  
**Risk Level**: Low (Heroku staging)

---

## Step 1: Create Heroku App (2 min)

```bash
# Install Heroku CLI (if not installed)
brew install heroku/brew/heroku

# Login to Heroku
heroku login
# Opens browser → Sign in with your Heroku account

# Create app
heroku create operon-updates-dev

# You'll see output like:
# Creating ⬢ operon-updates-dev... done
# https://operon-updates-dev.herokuapp.com/ | https://git.heroku.com/operon-updates-dev.git
```

**Copy your production URL**: `https://operon-updates-dev.herokuapp.com`

---

## Step 2: Deploy Distribution Server (3 min)

```bash
# Go to functions directory where distribution server exists
cd /Users/vedantreddymuskawar/Operon/functions

# Add Heroku remote
heroku git:remote -a operon-updates-dev

# Create Procfile for Heroku (if not exists)
cat > Procfile << 'EOF'
web: node distribution-server/lib/index.js
EOF

# Add to git
git add Procfile
git commit -m "Add Procfile for Heroku deployment"

# Deploy
git push heroku main

# Check logs
heroku logs --tail
```

**Expected Output**:
```
Distribution server running on port 5000
```

---

## Step 3: Upload v1.0.1 APK to Server (2 min)

```bash
# Verify APK exists
ls -lh apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk

# Copy to distribution server folder
cp apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
   functions/distribution-server/apks/operon-client-v1.0.1-build2.apk

# Verify it's there
ls -lh functions/distribution-server/apks/

# Push to Heroku
cd /Users/vedantreddymuskawar/Operon/functions
git add distribution-server/apks/
git commit -m "Add v1.0.1 APK to distribution server"
git push heroku main
```

---

## Step 4: Test Server Connection (2 min)

```bash
# Get your app URL (from Step 1)
# Example: https://operon-updates-dev.herokuapp.com

# Test version check
curl "https://operon-updates-dev.herokuapp.com/api/version/operon-client?currentBuild=1"

# Expected response:
# {
#   "version": "1.0.1",
#   "buildCode": 2,
#   "downloadUrl": "https://operon-updates-dev.herokuapp.com/api/download/operon-client",
#   "releaseNotes": "Initial v1.0.1 release with update system",
#   "checksum": "...",
#   "mandatory": true,
#   "minSdkVersion": 21,
#   "size": 79453184
# }
```

✅ **If you see the JSON response above, your server is working!**

---

## Step 5: Update Flutter App (2 min)

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Edit app.dart
open lib/presentation/app.dart
```

**Find line 189 and change**:
```dart
// FROM:
serverUrl: 'http://localhost:3000', // Change to production URL

// TO:
serverUrl: 'https://operon-updates-dev.herokuapp.com',
```

**Save the file**

---

## Step 6: Build New APK with Production URL (2 min)

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk (with production URL)
```

---

## Step 7: Test on Device (Optional but Recommended)

### Option A: Via USB (Requires connected device)

```bash
# Install on connected Android device
adb install build/app/outputs/flutter-apk/app-release.apk

# Open app and wait 3-5 seconds
# You should see "Update Available" dialog (since this is v1.0.1 with update checking already in place)
# The dialog will check your production server URL
```

### Option B: Via Android Emulator

```bash
# Open Android Studio → AVD Manager → Start an emulator

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Open app
adb shell am start -n com.example.dash_mobile/.MainActivity

# Wait for update check to complete
```

---

## Step 8: Verify Update Checking Works

**On the installed app:**

1. Open Settings → About
2. Verify version shows **1.0.1**
3. Close app completely
4. Reopen app
5. Wait 3-5 seconds
6. You should see update checking logs if you open adb logcat:
   ```bash
   adb logcat | grep -i "update"
   ```

7. Since this IS v1.0.1, the server will respond with:
   - "No update available" (because currentBuild=2 is already latest)
   - **OR** show an update anyway (if we manually set a higher version on server for testing)

---

## Troubleshooting

### Issue: Deployment fails with "Permission denied"

**Solution**:
```bash
# Ensure you're in functions directory
cd /Users/vedantreddymuskawar/Operon/functions

# Check Heroku remote
git remote -v | grep heroku

# Try again
git push heroku main
```

### Issue: App crashes when checking for update

**Check logs**:
```bash
adb logcat | grep -i "flutter\|error\|exception"
```

**Common causes**:
- [ ] Wrong server URL in app.dart (should be `https://operon-updates-dev.herokuapp.com`)
- [ ] Server not running (`heroku logs --tail` to check)
- [ ] APK not uploaded to server

### Issue: Server says "503 Service Unavailable"

**Solution**:
```bash
# Check Heroku logs
heroku logs --tail

# Restart app
heroku dyno:restart web

# Check if APK file exists
curl https://operon-updates-dev.herokuapp.com/api/download/operon-client
```

### Issue: Network timeout from device

**Solutions**:
1. Device must have internet access (WiFi or mobile data)
2. Check device can reach public URLs:
   ```bash
   adb shell curl https://www.google.com
   ```
3. Heroku might be sleeping (free tier) - visit URL in browser to wake it up

---

## Success Indicators

✅ **Deployment is successful when:**

1. `https://operon-updates-dev.herokuapp.com/api/version/operon-client` returns JSON
2. Flutter app launches without crashes
3. App version shows 1.0.1 in Settings → About
4. (Optional) Device shows update dialog or checking logs in logcat

---

## Next Steps After Verification

Once you confirm v1.0.1 works on Heroku:

1. **Test update flow from v1.0.0 → v1.0.1**
   - Keep a backup of v1.0.0 APK
   - Install v1.0.0 first
   - Verify it shows update dialog pointing to v1.0.1
   - Test full download and install flow

2. **Invite team members to test**
   - Send them installation URL: `https://operon-updates-dev.herokuapp.com/api/download/operon-client`
   - Ask them to test on their devices
   - Collect feedback

3. **Document results**
   - Create PHASE_3_TEST_RESULTS.md
   - Note any issues found
   - Plan fixes for v1.0.2 if needed

4. **Move to production**
   - Once Wave 1 testing complete, update production domain
   - Switch to `https://operon-updates.lakshmee.com` (or your domain)
   - Roll out to all users

---

## Heroku Commands Reference

```bash
# View logs
heroku logs --tail

# Restart app
heroku dyno:restart

# View environment variables
heroku config

# Set environment variable
heroku config:set VARIABLE=VALUE

# Open app URL in browser
heroku open

# View all apps
heroku apps

# Delete app (careful!)
heroku apps:destroy --app operon-updates-dev

# SSH into app (for debugging)
heroku ps:exec
```

---

## Estimated Cost

**Heroku Pricing (as of 2024)**:
- Free tier: Up to 5 apps (limited resources, sleeps after 30 min inactivity)
- Hobby: $7/month per dyno (always on, good for testing)
- Standard: $25-$50/month per dyno (production-grade)

**Recommendation**: Start with free tier for testing, upgrade to Hobby for Wave 1 (internal testing), then Standard for GA.

---

## Questions?

If anything fails:
1. Check the full [PHASE_3_PRODUCTION_DEPLOYMENT.md](PHASE_3_PRODUCTION_DEPLOYMENT.md) guide
2. Review [FLUTTER_UPDATE_INTEGRATION_COMPLETE.md](FLUTTER_UPDATE_INTEGRATION_COMPLETE.md) for update system details
3. Check Heroku logs: `heroku logs --tail`
4. Check device logs: `adb logcat | grep -i flutter`

