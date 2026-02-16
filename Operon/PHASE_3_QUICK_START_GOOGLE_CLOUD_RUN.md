# Phase 3: Quick Start - Deploy to Google Cloud Run in 20 Minutes

**Goal**: Get v1.0.1 with update checking live using Google Cloud Run  
**Estimated Time**: 20-25 minutes  
**Cost**: Free tier includes 2M requests/month + 360k GB-seconds  
**Advantage**: Fully managed, auto-scales, global CDN ready

---

## Step 1: Setup Google Cloud Project (3 min)

```bash
# Install Google Cloud CLI
brew install google-cloud-sdk

# Authenticate with Google account
gcloud auth login
# Opens browser → Sign in → Grant permissions

# Create new project
gcloud projects create operon-updates --name="Operon Updates Service"

# Set as current project
gcloud config set project operon-updates

# Enable required services
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

**Expected Output:**
```
Project [operon-updates] created successfully.
Enabling service run.googleapis.com on project operon-updates...
Enabling service artifactregistry.googleapis.com on project operon-updates...
Enabling service cloudbuild.googleapis.com on project operon-updates...
```

---

## Step 2: Create Dockerfile (2 min)

```bash
# Create Dockerfile in distribution-server directory
cat > /Users/vedantreddymuskawar/Operon/distribution-server/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Cloud Run automatically sets PORT environment variable (default 8080)
EXPOSE 8080

# Start the application
CMD ["node", "server.js"]
EOF

# Create .gcloudignore to exclude unnecessary files
cat > /Users/vedantreddymuskawar/Operon/distribution-server/.gcloudignore << 'EOF'
node_modules/
.git
.gitignore
npm-debug.log
*.log
test/
.env
.env.local
EOF
```

---

## Step 3: Deploy to Cloud Run (5 min)

```bash
# Navigate to distribution server
cd /Users/vedantreddymuskawar/Operon/distribution-server

# Deploy to Cloud Run (builds and deploys automatically)
gcloud run deploy operon-updates \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 256Mi \
  --cpu 1 \
  --timeout 600s \
  --set-env-vars NODE_ENV=production

# Wait for deployment to complete (2-3 minutes)
# You'll see output like:
# Service [operon-updates] revision [operon-updates-00001-abc] has been deployed
# Service URL: https://operon-updates-xxxxxx-uc.a.run.app
```

**Copy your service URL** (something like `https://operon-updates-xxxxxx-uc.a.run.app`)

---

## Step 4: Get Service URL (1 min)

```bash
# Get the service URL if you forgot it
gcloud run services describe operon-updates \
  --region us-central1 \
  --format='value(status.url)'

# Will output something like:
# https://operon-updates-xxxxxx-uc.a.run.app
```

Use this URL for your Flutter app configuration.

---

## Step 5: Upload v1.0.1 APK to Server (2 min)

```bash
# Verify APK exists
ls -lh apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk

# Copy to distribution server folder
cp apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
  distribution-server/apks/operon-client-v1.0.1-build2.apk

# Push changes to deploy with updated APK
cd /Users/vedantreddymuskawar/Operon/distribution-server
git add apks/
git commit -m "Add v1.0.1 APK"

# Redeploy to include APK
gcloud run deploy operon-updates \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

---

## Step 6: Test Server Connection (2 min)

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe operon-updates \
  --region us-central1 \
  --format='value(status.url)')

# Test version check endpoint
curl "${SERVICE_URL}/api/version/operon-client?currentBuild=1"

# Expected response:
# {
#   "version": "1.0.1",
#   "buildCode": 2,
#   "downloadUrl": "https://operon-updates-xxxxx.a.run.app/api/download/operon-client",
#   "releaseNotes": "Initial v1.0.1 release with update system",
#   "checksum": "...",
#   "mandatory": true,
#   "minSdkVersion": 21,
#   "size": 79453184
# }
```

✅ **If you see JSON response above, your server is working!**

---

## Step 7: Update Flutter App (2 min)

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Edit app.dart
open lib/presentation/app.dart
```

**Find line 189 and change**:
```dart
// FROM:
serverUrl: 'http://localhost:3000', // Change to production URL

// TO (use your actual Cloud Run URL):
serverUrl: 'https://operon-updates-xxxxxx-uc.a.run.app',
```

**Save the file**

---

## Step 8: Build Final APK (3 min)

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk (with Cloud Run URL)
```

---

## Step 9: Test on Device (Optional but Recommended)

### Option A: Via USB (Requires connected device)

```bash
# Install on connected Android device
adb install build/app/outputs/flutter-apk/app-release.apk

# Open app and wait 3-5 seconds
# You should see update checking in logs
adb logcat | grep -i "flutter\|update"
```

### Option B: Via Android Emulator

```bash
# Start emulator from Android Studio

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Open app and verify update checking works
adb logcat | grep -i "flutter"
```

---

## Step 10: Monitor Your Service (Ongoing)

```bash
# View recent logs
gcloud run services logs read operon-updates \
  --region us-central1 \
  --limit 50

# Stream logs in real-time
gcloud run services logs read operon-updates \
  --region us-central1 \
  --limit 50 \
  --follow

# View metrics and monitoring
# Open: https://console.cloud.google.com/run/detail/us-central1/operon-updates
```

---

## (Optional) Step 11: Setup Custom Domain

If you have a domain like `updates.operon.lakshmee.com`:

```bash
# Map custom domain
gcloud run domain-mappings create \
  --service operon-updates \
  --domain updates.operon.lakshmee.com \
  --region us-central1

# In your domain registrar DNS settings:
# Create CNAME record:
# updates.operon.lakshmee.com → operon-updates-xxxxxx-uc.a.run.app

# Wait for DNS propagation (5-30 minutes)
# Then update app.dart to use custom domain:
serverUrl: 'https://updates.operon.lakshmee.com',
```

---

## Troubleshooting

### Issue: "gcloud command not found"

**Solution**:
```bash
brew install google-cloud-sdk
gcloud init
```

### Issue: Deployment fails with "Permission denied"

**Solution**:
```bash
# Ensure authenticated
gcloud auth login

# Set correct project
gcloud config set project operon-updates

# Try deployment again
```

### Issue: Server says "Connection refused"

**Solution**:
```bash
# Check service is running
gcloud run services list --region us-central1

# Check service status
gcloud run services describe operon-updates --region us-central1

# View error logs
gcloud run services logs read operon-updates --region us-central1 --limit 100
```

### Issue: APK not downloading from server

**Solutions**:
1. Verify APK is in `distribution-server/apks/`
2. Restart service: `gcloud run services update operon-updates --region us-central1`
3. Check logs for errors

### Issue: Slow cold starts (first request takes time)

**Solution** (optional):
```bash
# Set minimum instances to 1 (keeps service warm)
gcloud run services update operon-updates \
  --min-instances 1 \
  --region us-central1

# Note: This costs ~$10-15/month but eliminates cold start delays
```

---

## Success Indicators

✅ **Deployment is successful when:**

1. `gcloud run services describe operon-updates` shows status: "Ready"
2. `/api/version/operon-client` endpoint returns JSON response
3. Flutter app launches without crashes
4. App version shows 1.0.1 in Settings → About
5. (Optional) Device shows update checking logs in logcat

---

## Cost Comparison

| Metric | Cost |
|--------|------|
| Free tier requests | 2 million/month |
| Free tier compute | 360,000 GB-seconds/month |
| Per request (after free) | $0.00002 |
| Per GB-second (after free) | $0.000002778 |
| Typical monthly (low traffic) | $0-5 |
| Typical monthly (moderate traffic) | $5-15 |
| Typical monthly (high traffic) | $50+ |

**Free tier usually covers all testing and Wave 1 testing.**

---

## Google Cloud Run Commands Reference

```bash
# List all services
gcloud run services list --region us-central1

# View service details
gcloud run services describe operon-updates --region us-central1

# Redeploy (rebuild from source)
gcloud run deploy operon-updates --source .

# View logs
gcloud run services logs read operon-updates --region us-central1 --limit 50

# Stream logs live
gcloud run services logs read operon-updates --region us-central1 --follow

# Set environment variables
gcloud run services update operon-updates \
  --set-env-vars KEY=VALUE

# Set minimum instances (for warm starts)
gcloud run services update operon-updates --min-instances 1

# Delete service
gcloud run services delete operon-updates --region us-central1

# View project settings
gcloud config list
```

---

## Next Steps After Verification

Once you confirm v1.0.1 works on Cloud Run:

1. **Test update flow from v1.0.0 → v1.0.1**
   - Keep a backup of v1.0.0 APK
   - Install v1.0.0 first
   - Verify it shows update dialog pointing to v1.0.1
   - Test full download and install flow

2. **Invite team members to test**
   - Send them the Cloud Run URL
   - Ask them to test on their devices
   - Collect feedback

3. **Document results**
   - Create PHASE_3_TEST_RESULTS.md
   - Note any issues found
   - Plan fixes for v1.0.2 if needed

4. **Move to production domain**
   - Set up custom domain (Step 11 above)
   - Configure SSL certificate (automatic with custom domain)
   - Roll out to all users

---

## Why Choose Google Cloud Run?

✅ **Fully Managed** - No server maintenance needed  
✅ **Auto-Scaling** - Handles traffic spikes automatically  
✅ **Cost Effective** - Free tier + pay-per-use pricing  
✅ **Global by Default** - Multi-region capability  
✅ **Integrated Logging** - Built-in monitoring and alerts  
✅ **Easy Rollback** - Revisions tracked automatically  
✅ **Secure** - Free SSL/TLS certificate included  

---

## Questions?

- Cloud Run conceptual overview: https://cloud.google.com/run/docs
- Deployment docs: https://cloud.google.com/run/docs/deploying-source-code
- Pricing details: https://cloud.google.com/run/pricing

---

**Status**: ✅ Ready to deploy v1.0.1 to Google Cloud Run

