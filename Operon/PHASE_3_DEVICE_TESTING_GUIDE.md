# Phase 3: Device Testing Guide for Operon Client v1.0.1

**Purpose**: Validate update system and core functionality on real Android devices  
**Duration**: 30-45 minutes per device  
**Prerequisites**: Android device or emulator with API 21+, USB cable, Chrome/adb installed

---

## Pre-Testing Setup

### Install ADB (Android Debug Bridge)

**macOS**:
```bash
# Install via Homebrew
brew install android-platform-tools

# Verify installation
adb --version
```

**Windows**:
```powershell
choco install androidplatformtools
```

**Linux**:
```bash
sudo apt install android-tools-adb
```

### Enable Device Developer Mode

1. On Android device: **Settings → About Phone**
2. Tap "Build Number" **7 times** until it says "You are now a developer!"
3. Go back to **Settings → System → Developer Options** (or Developer Settings)
4. Enable: **USB Debugging**
5. Connect USB cable to computer
6. When prompted on device, tap **Allow** to trust the computer

**Verify connection**:
```bash
adb devices
# Should output:
# List of attached devices
# emulator-5554  device  (or your device's serial)
```

---

## Test Overview

| Scenario | Test Name | Duration | Purpose |
|----------|-----------|----------|---------|
| 1 | Fresh Install - No Update | 5 min | Verify v1.0.1 launches, no unwanted dialogs |
| 2 | Update Available - Download & Install | 10 min | Core update flow: dialog → download → install |
| 3 | Network Error Handling | 5 min | Graceful failure when server unavailable |
| 4 | Skip Optional Update (if implemented) | 5 min | Non-mandatory updates can be deferred |
| 5 | Force Mandatory Update | 5 min | Mandatory updates block use until installed |
| 6 | Core Feature Testing | 10 min | Confirm app works normally with v1.0.1 |

---

## Scenario 1: Fresh Install - No Update Available

**Setup**: Install latest v1.0.1 APK on clean device

**Steps**:

1. **Prepare APK**
   ```bash
   # Verify APK exists
   ls -lh apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Connect device via USB**
   ```bash
   # Verify connection
   adb devices
   
   # Clear app if previously installed
   adb uninstall com.example.dash_mobile || echo "Not installed"
   ```

3. **Install v1.0.1**
   ```bash
   adb install apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk
   
   # Wait for install to complete
   # Output: "Success"
   ```

4. **Launch app and inspect**
   ```bash
   # Open app
   adb shell am start -n com.example.dash_mobile/.MainActivity
   
   # Watch logs
   adb logcat | grep -i "flutter\|update\|version"
   ```

5. **Verify behavior on device**
   - [ ] App opens without crashes
   - [ ] No update dialog appears (since device has latest v1.0.1)
   - [ ] Main screen shows correctly (orders, inventory, etc.)
   - [ ] Settings → About → Version shows **1.0.1**

6. **Expected logs** (in terminal):
   ```
   I  flutter: AppUpdateBloc: Checking for updates...
   I  flutter: AppUpdateService: Current build: 2
   I  flutter: AppUpdateService: Update not available
   I  flutter: AppUpdateBloc: Update unavailable
   ```

**Record**:
- [ ] App version: ________________
- [ ] No update dialog: Yes / No
- [ ] App launches cleanly: Yes / No
- [ ] Crash logs: None / [describe]

**Go/No-Go**: ✅ If all checks pass, move to Scenario 2

---

## Scenario 2: Update Flow - v1.0.0 → v1.0.1

**Setup**: Need to build/prepare v1.0.0 APK for testing

### Part A: Build v1.0.0 APK for Testing

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Create a temporary backup of current pubspec.yaml
cp pubspec.yaml pubspec.yaml.prod_backup

# Edit pubspec.yaml to use old version temporarily
# Change: version: 1.0.1+2
# To:     version: 1.0.0+1

# Build v1.0.0 APK
flutter clean
flutter pub get
flutter build apk --release

# This creates: build/app/outputs/flutter-apk/app-release.apk (now v1.0.0)
# Save with different name for testing
cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/app-v1.0.0-release.apk

# Restore production version
cp pubspec.yaml.prod_backup pubspec.yaml

# Rebuild v1.0.1
flutter clean
flutter pub get
flutter build apk --release

# Now you have:
# - build/app/outputs/flutter-apk/app-v1.0.0-release.apk (for testing)
# - build/app/outputs/flutter-apk/app-release.apk (v1.0.1 production)
```

### Part B: Test Update Flow

**Steps**:

1. **Uninstall any previous version**
   ```bash
   adb uninstall com.example.dash_mobile
   ```

2. **Install v1.0.0 (the old version)**
   ```bash
   adb install apps/Operon_Client_android/build/app/outputs/flutter-apk/app-v1.0.0-release.apk
   ```

3. **Open app and observe**
   ```bash
   # Launch app
   adb shell am start -n com.example.dash_mobile/.MainActivity
   
   # Watch logs (in new terminal)
   adb logcat | grep -i "flutter\|update\|version"
   
   # Keep device screen on and watch for dialog
   ```

4. **On device screen, you should see**:
   - App loads
   - 2-5 second wait
   - **"Update Available" dialog appears**
   - Title: "Update Available"
   - Subtitle: "New version: 1.0.1"
   - Release notes visible
   - "Download & Install" button (and optionally "Later" button)

5. **Verify dialog details**
   - [ ] Version shown: 1.0.1
   - [ ] Release notes visible and readable
   - [ ] If mandatory: No "Later" button; dialog cannot be dismissed
   - [ ] If optional: Both "Later" and "Download" buttons visible

6. **Test Download**
   - Tap **"Download & Install"** button
   - Device might show system download notification
   - Wait for APK to download (should be 76 MB, may take 30-60 seconds on WiFi)
   - After download: System should prompt to install
   - Tap **"Install"** on system dialog
   - App should close and reinstall
   - After installation: App reopens showing v1.0.1

7. **Verify Update Success**
   ```bash
   # Check version
   adb shell dumpsys package com.example.dash_mobile | grep versionName
   # Should show: versionName=1.0.1
   
   # Or in-app: Settings → About → Version should show 1.0.1
   ```

8. **Relaunch and verify no update prompts**
   ```bash
   # Kill app
   adb shell am force-stop com.example.dash_mobile
   
   # Relaunch
   adb shell am start -n com.example.dash_mobile/.MainActivity
   
   # Wait 5 seconds - should NOT show update dialog
   # Device already has latest v1.0.1
   ```

**Record**:
- [ ] v1.0.0 installed: Yes / No
- [ ] Update dialog appeared: Yes / No / [timing]
- [ ] Dialog content correct: Yes / No / [issues]
- [ ] Download started: Yes / No
- [ ] Download completed: Yes / No / [time taken]
- [ ] Installation succeeded: Yes / No
- [ ] Post-update version: 1.0.1 / [other]
- [ ] No re-prompt on relaunch: Yes / No

**Go/No-Go**: ✅ If all checks pass, move to Scenario 3

---

## Scenario 3: Network Error Handling

**Purpose**: Ensure app doesn't crash when update server is unavailable

**Steps**:

1. **Install v1.0.0 again**
   ```bash
   adb install apps/Operon_Client_android/build/app/outputs/flutter-apk/app-v1.0.0-release.apk
   ```

2. **Disable network**
   ```bash
   # Option A: Enable Airplane Mode
   adb shell settings put global airplane_mode_on 1
   adb shell am broadcast -a android.intent.action.AIRPLANE_MODE
   
   # Option B: At device: Settings → Airplane Mode → On
   ```

3. **Open app**
   ```bash
   adb shell am start -n com.example.dash_mobile/.MainActivity
   
   # Watch logs
   adb logcat | grep -i "flutter\|update\|error"
   ```

4. **Observe behavior**
   - [ ] App launches (doesn't hang)
   - [ ] No crash or ANR (App Not Responding)
   - [ ] Update dialog doesn't appear (no network)
   - [ ] After 5 seconds, app becomes fully usable
   - [ ] No error messages or red screens
   - [ ] User can navigate app normally

5. **Re-enable network**
   ```bash
   # Option A:
   adb shell settings put global airplane_mode_on 0
   adb shell am broadcast -a android.intent.action.AIRPLANE_MODE
   
   # Option B: At device: Settings → Airplane Mode → Off
   ```

6. **Force update check**
   ```bash
   # Kill and reopen app
   adb shell am force-stop com.example.dash_mobile
   adb shell am start -n com.example.dash_mobile/.MainActivity
   
   # Should now see update dialog (network restored)
   ```

**Record**:
- [ ] App didn't crash: Yes / No
- [ ] No hanging/freezing: Yes / No
- [ ] Dialog didn't appear (network down): Yes / No
- [ ] App usable after timeout: Yes / No
- [ ] Update dialog appeared (network restored): Yes / No

**Go/No-Go**: ✅ If all checks pass, move to Scenario 4

---

## Scenario 4: Skip Optional Update (if configured)

**Setup**: Update system is currently mandatory-only

**Current Behavior**: All updates are `mandatory: true`

**To Test If You Make Updates Optional**:

1. Modify server response (temporary):
   ```bash
   # In distribution-server/lib/index.js, add:
   "mandatory": false  # Instead of true
   ```

2. Install v1.0.0
   ```bash
   adb install apps/Operon_Client_android/build/app/outputs/flutter-apk/app-v1.0.0-release.apk
   ```

3. Open app
   - Dialog should appear with **"Later"** button visible

4. Tap **"Later"**
   - Dialog dismisses
   - App becomes usable

5. Close and reopen app
   - Dialog should appear again (skip is not persistent)
   - This is expected behavior for optional updates

**Note**: Current implementation treats all updates as mandatory (no "Later" button)

**Record**:
- [ ] Non-mandatory update skippable: (N/A - currently all mandatory)

---

## Scenario 5: Core Feature Testing v1.0.1

**Purpose**: Ensure new v1.0.1 doesn't break existing functionality

**On device running v1.0.1, test**:

### Navigation
- [ ] All menu items present
- [ ] Navigation between screens works
- [ ] Back button behaves correctly
- [ ] App bar displays properly

### Orders (if accessible)
- [ ] Order list loads
- [ ] Can view order details
- [ ] Order status displays correctly
- [ ] Pagination works (if applicable)

### Inventory (if accessible)
- [ ] Inventory counts display
- [ ] Material names readable
- [ ] Brick pallet tracking works
- [ ] Search/filter works

### Driver App Features (if applicable)
- [ ] Map displays location
- [ ] Trip list loads
- [ ] Can accept/complete trips
- [ ] Navigation/directions work

### Notifications (if implemented)
- [ ] Notification permissions granted
- [ ] Can receive notifications
- [ ] Tap notification opens correct screen

### Settings
- [ ] Settings page loads
- [ ] Version shows 1.0.1
- [ ] Can modify settings
- [ ] Settings persist on relaunch

**Record** (✅ pass / ❌ fail / ⚠️ needs fix):
- Navigation: ___
- Orders: ___
- Inventory: ___
- Notifications: ___
- Settings: ___
- Overall App Stability: ___

**Go/No-Go**: ✅ If all critical features work

---

## Scenario 6: Performance & Stability

**Purpose**: Ensure update system doesn't degrade app performance

**Tests**:

### Startup Performance
```bash
# Measure app startup time
time adb shell am start -W com.example.dash_mobile/.MainActivity

# Expected: < 5 seconds on mid-range device
# Record: _________ seconds
```

### Memory Usage
```bash
# Check memory while app is running
adb shell dumpsys meminfo com.example.dash_mobile | grep TOTAL

# Expected: < 200 MB on mid-range device
# Record: _________ MB
```

### Battery Usage (Qualitative)
- [ ] App doesn't drain battery rapidly
- [ ] App doesn't create excessive background work
- [ ] Device battery level stable over 5-min test

### Crash Testing
1. Open app
2. Rapid tap all buttons/navigate all screens for 1 minute
3. [ ] App doesn't crash
4. [ ] No ANR (App Not Responding) dialogs
5. [ ] Responsive to touches

**Record**:
- Startup time: _________ sec
- Memory usage: _________ MB
- Battery drain: Normal / Excessive
- Stability: Stable / Crashes observed

**Go/No-Go**: ✅ If performance acceptable

---

## Post-Testing Summary

### Issues Found

| Issue | Severity | Steps to Reproduce | Impact |
|-------|----------|-------------------|--------|
| | Critical / High / Medium / Low | | |
| | | | |

### Recommendations

- [ ] Ready for Wave 1 (internal testing)
- [ ] Ready for Wave 2 (beta testing)
- [ ] Ready for Wave 3 (general availability)
- [ ] Needs fixes before proceeding

### Tester Information

**Device Details**:
- Device Model: _______________
- Android Version: _______________
- RAM: _______________
- Storage: _______________

**Tester**: _______________ Date: _______________

**Signature**: _______________

---

## Failure Troubleshooting

### Issue: "cmd: Can't find service: package"

**Solution**:
```bash
adb kill-server
adb start-server
adb devices
```

### Issue: App crashes on start

**Check logs**:
```bash
adb logcat | grep -A5 "FATAL\|Exception\|ERROR"
```

**Common causes**:
- Wrong server URL in code
- Missing permissions (check AndroidManifest.xml)
- Invalid JSON response from server

### Issue: Update dialog doesn't appear

**Check**:
1. Device version 1.0.0, server has 1.0.1 available
2. Device has internet access
3. Check logcat: `adb logcat | grep -i "update\|api\|flutter"`
4. Ensure server URL is correct in code

### Issue: Download freezes

**Causes**:
1. Network connection dropped
2. Server not responding (check `heroku logs --tail`)
3. Large file (76 MB) - may take several minutes

**Solution**: Restart wifi, check server, be patient

---

## Next Steps After Testing Complete

1. **Document all findings** in testing summary above
2. **Create PHASE_3_TEST_RESULTS.md** with findings
3. **Fix any critical issues** in v1.0.2
4. **Invite beta testers** for Wave 2
5. **Plan GA rollout** after successful Wave 2

