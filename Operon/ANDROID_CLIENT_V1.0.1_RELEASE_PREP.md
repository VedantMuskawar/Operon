# Operon Client Android v1.0.1 Release Preparation

**Date Prepared:** February 14, 2026  
**Target Version:** 1.0.1 (Build Code: 2)  
**Previous Version:** 1.0.0 (Build Code: 1)

## ✅ Pre-Release Checklist

### 1. Version Update
- [x] Update `pubspec.yaml` version: `1.0.0+1` → `1.0.1+2`
  - Version name: `1.0.1`
  - Build code: `2`
  - Location: `/apps/Operon_Client_android/pubspec.yaml`

### 2. Code Quality & Testing
- [ ] Run unit tests: `flutter test`
- [ ] Run integration tests if available
- [ ] Check for any lint errors: `flutter analyze`
- [ ] Verify Firebase configuration is correct
- [ ] Test on physical Android device (API 26+)
- [ ] Test all critical features:
  - [ ] Login/Authentication
  - [ ] Order viewing and management
  - [ ] Delivery memo generation and printing
  - [ ] Navigation flows
  - [ ] Maps integration

### 3. Build Preparation
- [ ] Clean build artifacts: `flutter clean`
- [ ] Get dependencies: `flutter pub get`
- [ ] Verify `key.properties` exists for release signing
- [ ] Ensure Google Maps API key is configured

### 4. Build Release APK
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android
flutter clean
flutter pub get
flutter build apk --release
```

**Expected Output:** `build/app/outputs/apk/release/app-release.apk`

### 5. Build Release App Bundle (for Play Store)
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android
flutter build appbundle --release
```

**Expected Output:** `build/app/outputs/bundle/release/app-release.aab`

### 6. Verify Build Output
- [ ] Verify APK/AAB size is reasonable (~50-100 MB)
- [ ] Check version in build output matches v1.0.1+2
- [ ] Verify signing certificate is applied to release APK

### 7. Firebase & Backend Verification
- [ ] Verify Firestore indexes are deployed
- [ ] Confirm Cloud Functions are updated if needed
- [ ] Test Firebase Authentication flows
- [ ] Verify analytics setup
- [ ] Check Firebase Storage permissions

### 8. Internal App Distribution
- [ ] Upload APK to update server / Firebase App Distribution
- [ ] Update backend metadata with v1.0.1 info
- [ ] Configure version check endpoint
- [ ] Test update prompt on staging device
- [ ] Set update as available/mandatory if needed
- [ ] Prepare release notes for in-app display

### 9. Post-Release Monitoring
- [ ] Monitor app update logs for download/install stats
- [ ] Check Firebase Crashlytics for errors
- [ ] Monitor app usage patterns
- [ ] Review in-app telemetry for issues
- [ ] Be ready to disable update if critical issues found

## Important Notes

- **Release Signing:** Ensure `key.properties` contains correct keystore credentials
- **API Keys:** Google Maps API key must be set in build process
- **Firebase:** Service account credentials must be in creds folder
- **Build Warning:** PDF generation uses `dart:html` which is not compatible with WebAssembly builds, but this is not relevant for APK builds

## Version History
| Version | Build | Date       | Notes     |
|---------|-------|------------|-----------|
| 1.0.0   | 1     | Initial    | First release |
| 1.0.1   | 2     | 2026-02-14 | Bug fixes and improvements |

## Rollback Plan
If critical issues are discovered:
1. Disable v1.0.1 update from backend immediately
2. Keep v1.0.0 as available version
3. Document issue in GitHub
4. Fix and prepare v1.0.2
5. Re-test before next release deployment
