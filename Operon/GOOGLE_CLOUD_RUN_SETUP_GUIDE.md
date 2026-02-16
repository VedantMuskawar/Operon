# Google Cloud Run Setup - Step-by-Step Instructions

**Status**: Ready to Deploy | **Date**: February 14, 2025

## Important: Manual Authentication Required

Google Cloud authentication requires you to login with your browser. Follow these steps carefully.

---

## Step 1: Authenticate with Google Cloud (5 minutes)

### Option A: Using Your Terminal

```bash
# Open your terminal and run:
gcloud auth login

# This will:
# 1. Open your browser to Google login
# 2. Ask you to select/sign in with your Google account
# 3. Grant permissions to Google Cloud SDK
# 4. Return authorization code to terminal
```

**What to do:**
1. Run the command above
2. Your browser **will automatically open**
3. Sign in with your Google account (or create one if needed)
4. Click "Allow" to grant permissions
5. You'll see a code - just close the browser
6. Terminal will confirm authentication ✓

### Option B: If Browser Doesn't Open

```bash
# Run with explicit auth:
gcloud auth login --no-launch-browser

# This will give you a URL to visit manually:
# 1. Copy the URL
# 2. Open in your browser  
# 3. Sign in and grant permissions
# 4. Copy the authorization code
# 5. Paste it back in terminal
```

**Verify authentication:**
```bash
gcloud auth list --filter=status:ACTIVE --format="value(account)"
# Should show your email address
```

---

## Step 2: Run Automated Deployment Script (5 minutes)

Once authenticated, run the automated deployment script:

```bash
# From the Operon root directory
/Users/vedantreddymuskawar/Operon/deploy-google-cloud-run.sh
```

**What this script does:**
✓ Verifies you're authenticated  
✓ Creates Google Cloud project  
✓ Enables required APIs  
✓ Deploys distribution server  
✓ Returns your service URL  
✓ Tests the deployment  

**Expected output:**
```
✓ Authenticated as: your-email@gmail.com
✓ Project operon-updates already exists (or creates new one)
✓ All required APIs enabled
✓ Deployment completed
✓ Service URL: https://operon-updates-xxxxxx-uc.a.run.app
```

---

## Step 3: Update Flutter App with Service URL (2 minutes)

After deployment, you'll get a service URL like:
```
https://operon-updates-xxxxxx-uc.a.run.app
```

**Update your Flutter app:**

```bash
# Open the file
open /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android/lib/presentation/app.dart

# Find line 189 that says:
serverUrl: 'http://localhost:3000', // Change to production URL

# Change it to (use your actual URL):
serverUrl: 'https://operon-updates-xxxxxx-uc.a.run.app',
```

---

## Step 4: Build Final APK with Production URL (3 minutes)

```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_android

# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 5: Test the Deployment (1 minute)

```bash
# Test the version check endpoint
curl "https://operon-updates-xxxxxx-uc.a.run.app/api/version/operon-client?currentBuild=1"

# Should return JSON:
# {
#   "version": "1.0.1",
#   "buildCode": 2,
#   "downloadUrl": "https://operon-updates-xxxxxx-uc.a.run.app/api/download/operon-client",
#   "releaseNotes": "Initial v1.0.1 release...",
#   ...
# }
```

If you see JSON response: ✅ **Deployment successful!**

---

## Troubleshooting

### Issue: "gcloud command not found"

**Solution:**
```bash
# Verify gcloud is installed
which gcloud

# If not found, gcloud is installed at:
/opt/homebrew/bin/gcloud --version

# Add to your PATH:
export PATH="/opt/homebrew/bin:$PATH"

# Or use full path in scripts
```

### Issue: "You must be authenticated"

**Solution:**
```bash
gcloud auth login
# Follow browser login steps
```

### Issue: "Project not found"

**Solution:**
```bash
# List your projects
gcloud projects list

# Set the correct project
gcloud config set project operon-updates
```

### Issue: "Deployment fails with permission error"

**Solution:**
1. Make sure your Google account has billing enabled
2. Check your project has no quota restrictions
3. Run: `gcloud auth application-default login`

---

## Manual Deployment (If Script Fails)

If the automated script doesn't work, run these commands manually:

```bash
# 1. Authenticate
gcloud auth login

# 2. Create/set project
gcloud projects create operon-updates --name="Operon Updates Service" 2>/dev/null || true
gcloud config set project operon-updates

# 3. Enable APIs
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com  
gcloud services enable cloudbuild.googleapis.com

# 4. Deploy
cd /Users/vedantreddymuskawar/Operon/distribution-server
gcloud run deploy operon-updates \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 256Mi \
  --cpu 1 \
  --quiet

# 5. Get URL
gcloud run services describe operon-updates \
  --region us-central1 \
  --format='value(status.url)'
```

---

## Next Steps After Deployment

1. ✅ Service URL obtained
2. ✅ Flutter app updated with service URL  
3. ✅ Final APK built
4. ✅ Deployment tested

**Proceed to:**
- [PHASE_3_DEVICE_TESTING_GUIDE.md](PHASE_3_DEVICE_TESTING_GUIDE.md) - Test on device
- [PHASE_3_PRODUCTION_DEPLOYMENT.md](PHASE_3_PRODUCTION_DEPLOYMENT.md) - Continue with Wave 1 testing

---

## Useful Commands for Your Deployment

```bash
# View logs
gcloud run services logs read operon-updates --region us-central1 --limit 50

# Stream logs live
gcloud run services logs read operon-updates --region us-central1 --follow

# Redeploy after code changes
gcloud run deploy operon-updates --source . --platform managed --region us-central1 --allow-unauthenticated

# Set minimum instances (costs ~$10/month but eliminates cold starts)
gcloud run services update operon-updates --min-instances 1 --region us-central1

# Get service details
gcloud run services describe operon-updates --region us-central1

# Delete service (if needed)
gcloud run services delete operon-updates --region us-central1
```

---

## Estimated Timeline

| Step | Time | Status |
|------|------|--------|
| 1. Authenticate | 5 min | ⏳ Manual |
| 2. Run deployment script | 5 min | ⏳ Automated |
| 3. Update app code | 2 min | ⏳ Manual |
| 4. Build final APK | 3 min | ⏳ Automated |
| 5. Test deployment | 1 min | ⏳ Testing |
| **Total** | **16 minutes** | **Ready** |

---

## Need Help?

- **Deployment script**: See "Manual Deployment" section above
- **gcloud setup**: Check "Troubleshooting" section
- **Update system issues**: See FLUTTER_UPDATE_INTEGRATION_COMPLETE.md
- **Device testing**: See PHASE_3_DEVICE_TESTING_GUIDE.md

---

**Ready? Start with:**
```bash
gcloud auth login
```

Then run:
```bash
/Users/vedantreddymuskawar/Operon/deploy-google-cloud-run.sh
```

Good luck! 🚀
