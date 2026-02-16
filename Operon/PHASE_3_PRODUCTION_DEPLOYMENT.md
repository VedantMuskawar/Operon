# Phase 3: Production Deployment Planning

**Status**: Ready to Plan & Execute  
**Version**: Operon Client Android v1.0.1  
**Update System**: BLoC-based update management with UpdateDialog  
**Current Server**: localhost:3000 (development only)

---

## 1. Pre-Production Checklist

### 1.1 Configuration Review
- [ ] **App Server URL**: Currently set to `http://localhost:3000`
  - Location: `lib/presentation/app.dart` line 189
  - Action: Will be updated to production domain with HTTPS
  - Example: `https://updates.operon.lakshmee.com`

- [ ] **Distribution Server Infrastructure**
  - Current: Node.js/Express on local machine
  - Needed: Production-grade hosting with HTTPS, backups, monitoring
  - Options:
    - Option A: Heroku (free tier + paid tiers, simple deployment)
    - Option B: AWS EC2 (full control, more configuration)
    - Option C: Google Cloud Run (serverless, auto-scaling)
    - Option D: DigitalOcean App Platform (simple, cost-effective)

- [ ] **SSL/TLS Certificate**
  - Required: For HTTPS connections (mandatory for modern Android)
  - Provider options: Let's Encrypt (free), AWS ACM, DigiCert (paid)
  - Duration: Plan 3-month initial cert, auto-renewal setup

- [ ] **Domain Name**
  - Current: None assigned
  - Recommendation: `updates.operon.lakshmee.com` or `api.operon.lakshmee.com`
  - DNS records: A record pointing to production server IP

### 1.2 Flutter App Testing (Before Deployment)
- [ ] **Device Installation Test**
  - Test device: Android device or emulator (API 21+)
  - Purpose: Verify APK installs and app launches without crashes
  - Command: `adb install build/app/outputs/flutter-apk/app-release.apk`
  - Verification: Check Settings → About → Version = 1.0.1

- [ ] **Update Dialog Test** (with localhost)
  - Method 1: Downgrade to v1.0.0, launch, verify dialog appears
  - Method 2: Use debug APK with modified version in pubspec.yaml
  - Expected: "Update Available" dialog → Click "Download & Install" → APK starts downloading
  - Note: Ensure localhost:3000 is accessible during test

- [ ] **Connectivity Test**
  - Network: Test both WiFi and mobile data
  - Firewall: Ensure no corporate firewall blocks port 3000
  - Error handling: Force network error, verify graceful error state

- [ ] **Error Scenarios**
  - Server offline: Dialog should show "Check again" or skip gracefully
  - Invalid checksum: Download should fail with helpful error
  - Mandatory update denied: App should prevent use (confirm behavior)
  - Large file: Test partial download resume capability

### 1.3 Distribution Server Validation
- [ ] **API Endpoints Working**
  ```bash
  # Health check
  curl http://localhost:3000/health
  
  # Version check
  curl "http://localhost:3000/api/version/operon-client?currentBuild=2"
  
  # Download
  curl "http://localhost:3000/api/download/operon-client"
  ```

- [ ] **Performance Testing**
  - Response time: < 1 second for version check
  - Download speed: Full 76 MB APK in reasonable time
  - Concurrent requests: Multiple devices querying simultaneously

- [ ] **Logging & Monitoring**
  - Server logs: Check that all requests are being logged
  - Error tracking: Implement Sentry or equivalent (optional but recommended)
  - Metrics: Response times, error rates, download success rates

- [ ] **Security Audit**
  - HTTPS requirement: Enforce in production URL
  - API rate limiting: Prevent abuse (e.g., 100 requests/hour per IP)
  - Checksum validation: APK corruption detection
  - CORS headers: Verify appropriate origins allowed

---

## 2. Step-by-Step Production Deployment (Phase 3A: Setup)

### 2.1 Configure Production Domain & Hosting

**Option A: Heroku (Recommended for Quick Start)**

1. **Create Heroku Account & App**
   ```bash
   # Install Heroku CLI
   brew install heroku/brew/heroku
   
   # Login to Heroku
   heroku login
   
   # Create new app
   heroku create operon-updates-prod
   ```

2. **Deploy Distribution Server**
   ```bash
   # From functions/ directory
   cd /Users/vedantreddymuskawar/Operon/functions
   
   # Convert distribution server to Heroku-compatible format
   # (Copy distribution server code to distribution-server/)
   
   # Deploy
   git push heroku main
   ```

3. **Configure Environment Variables**
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set PORT=5000
   heroku logs --tail
   ```

4. **Get Production URL**
   - Your app will be at: `https://operon-updates-prod.herokuapp.com`
   - Update Flutter app with this URL

**Option B: AWS EC2 + Nginx**

1. **Launch EC2 Instance**
   - Image: Ubuntu 22.04 LTS
   - Instance type: t3.micro (free tier eligible)
   - Security groups: Allow 80 (HTTP), 443 (HTTPS), 22 (SSH)

2. **Install & Configure**
   ```bash
   # SSH into instance
   ssh -i key.pem ubuntu@your-instance-ip
   
   # Install Node.js
   curl https://deb.nodesource.com/setup_18.x | sudo bash
   sudo apt install nodejs
   
   # Install Nginx
   sudo apt install nginx
   
   # Install PM2 for process management
   sudo npm install -g pm2
   
   # Clone repository
   git clone your-repo /home/ubuntu/operon
   cd /home/ubuntu/operon/functions
   npm install
   
   # Start with PM2
   pm2 start server.js --name "operon-updates"
   pm2 startup
   pm2 save
   ```

3. **Configure Nginx as Reverse Proxy**
   ```nginx
   # /etc/nginx/sites-available/operon-updates
   server {
       listen 80;
       server_name updates.operon.lakshmee.com;
       
       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
       }
   }
   ```

4. **Install SSL Certificate (Let's Encrypt)**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d updates.operon.lakshmee.com
   ```

**Option C: Google Cloud Run (Serverless - Recommended for Scalability)**

1. **Setup Google Cloud Project**
   ```bash
   # Install Google Cloud CLI
   brew install google-cloud-sdk
   
   # Authenticate
   gcloud auth login
   
   # Create or select project
   gcloud projects create operon-updates --name="Operon Updates Service"
   gcloud config set project operon-updates
   
   # Enable required APIs
   gcloud services enable run.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   ```

2. **Create Dockerfile for Cloud Run**
   ```dockerfile
   # distribution-server/Dockerfile
   FROM node:18-alpine
   
   WORKDIR /app
   
   # Copy package files
   COPY package*.json ./
   
   # Install dependencies
   RUN npm ci --only=production
   
   # Copy app code
   COPY . .
   
   # Expose port (Cloud Run uses PORT env variable)
   EXPOSE 8080
   
   # Start app
   CMD ["node", "server.js"]
   ```

3. **Update Environment for Cloud Run**
   - Cloud Run automatically sets PORT environment variable (default 8080)
   - Create `.gcloudignore` to exclude unnecessary files:
   ```
   # .gcloudignore
   node_modules/
   .git
   .gitignore
   *.log
   test/
   .env
   ```

4. **Deploy to Cloud Run**
   ```bash
   cd /Users/vedantreddymuskawar/Operon/distribution-server
   
   # Build and deploy in one command
   gcloud run deploy operon-updates \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --memory 256Mi \
     --cpu 1 \
     --timeout 600s \
     --set-env-vars NODE_ENV=production
   
   # Get the service URL (output will show something like:
   # Service [operon-updates] revision [operon-updates-00001-abc] has been deployed
   # Service URL: https://operon-updates-xxxxxx-uc.a.run.app
   ```

5. **Configure Custom Domain (Optional but Recommended)**
   ```bash
   # Map custom domain to Cloud Run service
   gcloud run services update-traffic operon-updates --to-revisions LATEST=100
   
   # Get the service URL and set up DNS
   gcloud run services describe operon-updates --format='value(status.url)'
   
   # In your domain registrar, create CNAME record:
   # updates.operon.lakshmee.com → operon-updates-xxxxxx-uc.a.run.app
   
   # Verify custom domain mapping
   gcloud run domain-mappings create \
     --service operon-updates \
     --domain updates.operon.lakshmee.com \
     --region us-central1
   ```

6. **Monitor & View Logs**
   ```bash
   # View recent logs
   gcloud run services describe operon-updates --region us-central1
   
   # Stream logs in real-time
   gcloud run services logs read operon-updates --region us-central1 --limit 50 --follow
   
   # View metrics in Cloud Console
   # https://console.cloud.google.com/run/detail/us-central1/operon-updates
   ```

7. **Configure Autoscaling (Already Enabled)**
   - Cloud Run auto-scales based on traffic
   - Default: 0 minimum instances (cheaper, cold starts ~1-2 sec)
   - To improve performance, set minimum instances:
   ```bash
   gcloud run services update operon-updates \
     --min-instances 1 \
     --region us-central1
   ```

**Cost Estimate** (Google Cloud Run):
- Free tier: 2 million requests/month, 360k GB-seconds compute
- After free tier: ~$0.00002 per request, $0.000002778 per GB-second
- Typical monthly cost: $5-15 for moderate traffic, scaling to $50+ for high traffic

**Advantages of Cloud Run:**
- ✅ Fully managed (no server maintenance)
- ✅ Auto-scales to zero when idle
- ✅ Built-in monitoring and logging
- ✅ Global CDN integration available
- ✅ Easy rollback to previous versions
- ✅ Free SSL/TLS certificate included
- ✅ Pay-per-request pricing

**Option D: DigitalOcean App Platform (Alternative Simple Option)**

1. **Create App on DigitalOcean**
   - Connect GitHub repository
   - Select distribution server code
   - Set environment: Node.js

2. **Configure Buildpack & Runtime**
   - Node.js version: 18 or higher
   - Start command: `node server.js`

3. **Deploy**
   - DigitalOcean handles SSL automatically
   - Gets auto-generated domain or use custom domain
   - Monitor via DigitalOcean dashboard

---

## 3. Update Flutter App for Production (Phase 3B: Code Change)

### 3.1 Update Server URL in app.dart

**File**: `lib/presentation/app.dart` (line 189)

**Change From**:
```dart
serverUrl: 'http://localhost:3000', // Change to production URL
```

**Change To** (example with Heroku):
```dart
serverUrl: 'https://operon-updates-prod.herokuapp.com',
```

**Build Command**:
```bash
cd apps/Operon_Client_android
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (v1.0.1 with production URL)
```

### 3.2 Upload New APK to Distribution Server

```bash
# Copy new APK to distribution server location
cp apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
   distribution-server/apks/operon-client-v1.0.1-build2.apk

# Verify on production server
curl "https://your-production-url/api/version/operon-client?currentBuild=1"
# Should return v1.0.1 as available update
```

---

## 4. Device Testing (Phase 3C: Validation)

### 4.1 Setup Test Environment

**Test Device**: Android device with API 21+ or emulator

**Current Version**: Build APK with old version for testing:
```bash
# Temporarily change pubspec.yaml
# version: 1.0.0+1

# Build APK
flutter build apk --release
# Save as: app-v1.0.0-release.apk
```

### 4.2 Test Scenario 1: Fresh Install of v1.0.1

1. Install v1.0.1 APK on test device
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. Open app → Verify no update dialog appears (device has latest)

3. Go to Settings → About → Confirm version = 1.0.1

4. Test all core features work (orders, inventory, etc.)

### 4.3 Test Scenario 2: Update Flow from v1.0.0 → v1.0.1

1. Build and install v1.0.0 APK (prepare test APK as shown above)
   ```bash
   adb install app-v1.0.0-release.apk
   ```

2. Open app → Wait 3-5 seconds → Update dialog should appear

3. Verify dialog shows:
   - "Update Available"
   - "New version: 1.0.1"
   - Release notes visible
   - "Download & Install" button

4. Click "Download & Install" → APK should start downloading

5. Wait for download to complete → Installation should begin

6. After app restarts → Should show version 1.0.1

7. Open app again → No update dialog (already latest)

### 4.4 Test Scenario 3: Network Error Handling

1. Enable Airplane Mode on device

2. Downgrade to v1.0.0 and reopen app

3. Verify app doesn't crash, error state handled gracefully

4. Disable Airplane Mode, wait for retry

5. Update dialog should appear once network restored

### 4.5 Test Scenario 4: Skip Update (Optional Updates Only)

**Current Implementation**: All updates are mandatory by default

To test skip functionality:
1. Change `mandatory: false` in server response (temporary)
2. Install v1.0.0
3. Open app → Dialog appears with "Later" button
4. Click "Later" → Dialog should dismiss
5. Reopen app → Dialog appears again (no persistent skip)

---

## 5. Rollout Plan (Phase 3D: User Deployment)

### 5.1 Staged Rollout Strategy

**Wave 1: Internal Testing (Week 1)**
- Users: Dev team (2-3 people)
- Duration: 3-5 days
- Success criteria: No crashes, update installs cleanly
- Monitoring: Daily check-ins, log review

**Wave 2: Beta Testing (Week 2)**
- Users: Sales + Operations team (10-15 people)
- Duration: 5-7 days
- Success criteria: <1% error rate, positive feedback
- Monitoring: Daily metrics review, user feedback survey

**Wave 3: General Availability (Week 3)**
- Users: All active users
- Rollout method: Automatic via update check
- Success criteria: >80% adoption within 2 weeks
- Monitoring: 24/7 log monitoring, daily metrics dashboard

### 5.2 Communication Plan

**For Wave 1 (Internal)**
```
Subject: Update Available - v1.0.1 (Testing)
Body:
- New update check system implemented
- Should auto-prompt when you open app
- Please test and report any issues
- Contact: [Your Slack Channel]
```

**For Wave 2 (Beta)**
```
Subject: Operon Client v1.0.1 Available
Body:
- Bug fixes and improvements
- Auto-update will prompt you (example)
- Takes 2-3 minutes to download and install
- Your data is safe - nothing lost
- Questions? Contact: [Support Channel]
```

**For Wave 3 (GA)**
```
Subject: Keep Your Operon Updated
Body:
- New version available with important updates
- App will prompt you to update
- Updates help keep your business running smoothly
- No action needed from you
```

### 5.3 Rollback Plan

If critical issues occur:

1. **Pause Distribution**
   ```bash
   # Temporarily disable update by returning error
   # In distribution-server/server.js, modify /api/version endpoint
   # to return 503 Service Unavailable
   ```

2. **Notify Users**
   - Send WhatsApp message to all affected groups
   - Update status page
   - Prepare rollback communication

3. **Recover**
   - Fix issue in v1.0.2
   - Build new APK
   - Re-enable distribution server
   - Announce fix to users

---

## 6. Post-Deployment Monitoring (Phase 3E: Ongoing)

### 6.1 Key Metrics to Track

1. **Adoption Rate**
   - % of active users on v1.0.1
   - Target: >80% within 2 weeks

2. **Update Success Rate**
   - % of users who successfully downloaded & installed APK
   - Target: >95%

3. **Error Rate**
   - % of users encountering errors during update
   - Target: <1%

4. **Download Performance**
   - Average download time for 76 MB APK
   - Target: <5 minutes on typical network

5. **User Feedback**
   - Any reported issues with v1.0.1
   - Feature requests
   - Performance complaints

### 6.2 Logging Setup

Add Firebase Analytics or Crashlytics:

```dart
// In any BLoC state handler
FirebaseAnalytics.instance.logEvent(
  name: 'update_check',
  parameters: {
    'from_version': currentVersion,
    'available_version': availableVersion ?? 'none',
    'update_available': updateAvailable,
  },
);
```

### 6.3 Dashboard Creation

Create a simple Firestore collection to track:
- update_checks (count, averages)
- update_downloads (success, failure, delays)
- update_installations (success, duration)

Query with:
```bash
# View update checks in last 24 hours
firebase functions:log --limit 500
```

---

## 7. Timeline & Responsibilities

```
Week 1 (Setup):
  Days 1-2: Configure hosting (Heroku/AWS/DigitalOcean)
  Days 2-3: Update app code with production URL
  Days 3-4: Build production APK
  Days 4-5: Upload to distribution server, verify connectivity
  Days 5-7: Internal testing, bug fixes

Week 2 (Beta):
  Days 1-3: Deploy to beta users
  Days 3-5: Monitor, collect feedback
  Days 5-7: Make improvements, plan GA release

Week 3+ (GA):
  Days 1+: Rollout to all users
  Ongoing: Monitor metrics, respond to issues
```

---

## 8. Checklist for Go/No-Go Decision

Before deploying to production, verify:

- [ ] Production hosting account created and configured
- [ ] SSL certificate installed and HTTPS working
- [ ] Domain name pointing to production server
- [ ] Flutter app code updated with production URL
- [ ] Production APK built and tested locally
- [ ] APK uploaded to distribution server
- [ ] API endpoints responding correctly from production URL
- [ ] Device testing completed (4 scenarios passed)
- [ ] Error handling tested (network offline, server down, etc.)
- [ ] Rollback plan documented and tested
- [ ] Team trained on deployment procedure
- [ ] Monitoring/logging configured
- [ ] Communication templates prepared
- [ ] Success metrics defined

**Overall Status**: ⏳ **Awaiting User Decision** on hosting platform and timeline

---

## Contact & Support

For questions or issues during deployment:
- **Update System Issues**: Check [FLUTTER_UPDATE_INTEGRATION_COMPLETE.md](FLUTTER_UPDATE_INTEGRATION_COMPLETE.md)
- **Distribution Server Issues**: Check distribution-server logs
- **Firebase Issues**: Check Firebase console for function errors
- **Device Issues**: Check adb logcat for app crashes

---

**Next Action**: After reviewing this plan, please confirm:
1. Preferred hosting platform (Heroku/AWS/DigitalOcean)
2. Production domain name
3. When you'd like to start Wave 1 testing

