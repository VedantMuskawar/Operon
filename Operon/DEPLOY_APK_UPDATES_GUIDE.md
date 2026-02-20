# Operon Client Android – APK Update Deployment Guide (GCS + Cloud Run)

This guide documents the exact steps used in this repo to publish a new APK update for the Operon Client Android app using:
- **Google Cloud Storage (GCS)** for APK hosting
- **Cloud Run** distribution server for update metadata and download redirects

---

## 0) Prerequisites

- Flutter SDK installed and working
- Google Cloud CLI authenticated (`gcloud auth login`)
- Access to Cloud Run service: **operon-updates**
- GCS bucket: **operon-updates**
- Android signing configured at: `apps/Operon_Client_android/android/key.properties`

---

## 1) Update the app version

Update the version in:
- `apps/Operon_Client_android/pubspec.yaml`

Example:
```
version: 1.2.1+5
```

> **Version format:** `X.Y.Z+BUILD`
> - `X.Y.Z` = semantic version
> - `BUILD` = incrementing build code

---

## 2) Build the release APK

From repo root:

```
cd apps/Operon_Client_android
flutter clean
flutter pub get
flutter build apk --release --no-shrink
```

APK output:
```
apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk
```

---

## 3) Upload the APK to GCS

The Cloud Run server is configured with:
```
APK_BASE_URL = https://storage.googleapis.com/operon-updates/operon-client
```

So the APK **must** be uploaded to:
```
gs://operon-updates/operon-client/operon-client-vX.Y.Z.apk
```

Example:
```
gcloud storage cp \
  apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
  gs://operon-updates/operon-client/operon-client-v1.2.1.apk
```

---

## 4) Update the distribution server metadata

Edit:
- `distribution-server/server.js`

Update the `versionRegistry` for **operon-client**:
- `currentVersion`
- `currentBuildCode`
- `releaseUrl`
- `releaseNotes`
- `checksum` (MD5)
- `size` (bytes)
- Add new changelog entry

### Get checksum + size

```
APK=apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk
stat -f%z "$APK"   # size
md5 -q "$APK"      # checksum
```

---

## 5) Redeploy Cloud Run (to apply server.js changes)

From repo root:

```
cd distribution-server
gcloud run deploy operon-updates \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --quiet
```

---

## 6) Verify live endpoints

### Check version endpoint

```
curl -s "https://operon-updates-nlwuwnlpia-uc.a.run.app/api/version/operon-client?currentBuild=4"
```

Expected response should include:
- `version: X.Y.Z`
- `buildCode: <new build>`
- `updateAvailable: true` (for older builds)

### Check APK exists in GCS

```
curl -I "https://storage.googleapis.com/operon-updates/operon-client/operon-client-v1.2.1.apk"
```

Expect `HTTP 200`.

---

## 7) Install + confirm

- Install the APK on a test device
- In **Settings → About**, confirm version/build
- Tap **Check for Updates**:
  - On the latest build, it should say **up to date**

---

## Common Errors & Fixes

### ❌ “No such object” / key not found
**Cause:** APK uploaded to wrong GCS path

**Fix:** Upload to:
```
operon-updates/operon-client/operon-client-vX.Y.Z.apk
```

### ❌ “Not latest version” even after update
**Cause:** App build code < server build code

**Fix:** Install the latest APK (build code must match)

### ❌ Version endpoint still shows old version
**Cause:** Cloud Run not redeployed after `server.js` update

**Fix:** Redeploy Cloud Run

---

## Reference: Current Cloud Run URL

```
https://operon-updates-nlwuwnlpia-uc.a.run.app
```

---

If you want this to be automated (scripted release flow), we can add a single `deploy_apk_update.sh` to run everything in order.
