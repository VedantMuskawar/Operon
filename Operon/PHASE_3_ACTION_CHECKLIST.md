# Operon v1.0.1 Deployment - Action Checklist

**Current Status**: ✅ All code complete, ✅ Distribution server running  
**Next Phase**: Choose deployment path and execute  
**Estimated Time to GA**: 3 weeks

---

## 🎯 Your Next Step (Choose One)

### 🚀 FASTEST TRACK: Deploy to Google Cloud Run in 20 Minutes (Recommended)

If you want auto-scaling, fully managed infrastructure:

1. **Setup Google Cloud** (3 min)
   ```bash
   brew install google-cloud-sdk
   gcloud auth login
   gcloud projects create operon-updates --name="Operon Updates Service"
   gcloud config set project operon-updates
   gcloud services enable run.googleapis.com artifactregistry.googleapis.com
   ```

2. **Create Dockerfile** (2 min)
   - File created automatically by guide

3. **Deploy to Cloud Run** (5 min)
   ```bash
   cd /Users/vedantreddymuskawar/Operon/functions/distribution-server
   gcloud run deploy operon-updates \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

4. **Get service URL** (1 min)
   ```bash
   gcloud run services describe operon-updates \
     --region us-central1 \
     --format='value(status.url)'
   ```

5. **Update app code** (2 min)
   - Edit line 189 in lib/presentation/app.dart with your Cloud Run URL

6. **Build final APK** (3 min)
   ```bash
   flutter clean && flutter pub get && flutter build apk --release
   ```

7. **Test** (1 min)
   ```bash
   curl "https://operon-updates-xxxxx.a.run.app/api/version/operon-client?currentBuild=1"
   ```

✅ **You're Done!** v1.0.1 is live with auto-scaling infrastructure

📖 **Full details**: [PHASE_3_QUICK_START_GOOGLE_CLOUD_RUN.md](PHASE_3_QUICK_START_GOOGLE_CLOUD_RUN.md)

---

### 🚀 FAST TRACK: Deploy to Heroku in 15 Minutes

If you want simplicity and don't need auto-scaling:

1. **Create Heroku app** (2 min)
   ```bash
   heroku login
   heroku create operon-updates-dev
   ```

2. **Deploy server** (3 min)
   ```bash
   cd /Users/vedantreddymuskawar/Operon/functions
   heroku git:remote -a operon-updates-dev
   echo "web: node distribution-server/lib/index.js" > Procfile
   git add Procfile && git commit -m "Add Procfile"
   git push heroku main
   ```

3. **Upload APK** (2 min)
   ```bash
   cp apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk \
      functions/distribution-server/apks/operon-client-v1.0.1-build2.apk
   cd functions
   git add distribution-server/apks/
   git commit -m "Add v1.0.1 APK"
   git push heroku main
   ```

4. **Update app code** (2 min)
   ```bash
   cd apps/Operon_Client_android
   # Edit line 189 in lib/presentation/app.dart:
   # Change: serverUrl: 'http://localhost:3000'
   # To: serverUrl: 'https://operon-updates-dev.herokuapp.com'
   ```

5. **Build final APK** (3 min)
   ```bash
   flutter clean && flutter pub get
   flutter build apk --release
   ```

6. **Test** (1 min)
   ```bash
   curl "https://operon-updates-dev.herokuapp.com/api/version/operon-client?currentBuild=1"
   # Should return JSON with v1.0.1 info
   ```

✅ **You're Done!** v1.0.1 is now live and ready for Wave 1 testing

📖 **Full details**: [PHASE_3_QUICK_START_HEROKU.md](PHASE_3_QUICK_START_HEROKU.md)

---

### 🧪 CAREFUL TRACK: Test Locally Before Deploying

If you want to understand and test everything locally first:

1. **Verify server running**
   ```bash
   lsof -i :3000
   # Should show "node" process on port 3000
   ```

2. **Test API endpoint**
   ```bash
   curl http://localhost:3000/api/version/operon-client?currentBuild=1
   # Should return JSON response
   ```

3. **Build APK** (already built, but rebuild to test)
   ```bash
   cd apps/Operon_Client_android
   flutter build apk --release
   ```

4. **Install to device/emulator**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

5. **Watch update system work**
   ```bash
   adb logcat | grep -i "flutter\|update"
   # You'll see:
   # "AppUpdateBloc: Checking for updates..."
   # "AppUpdateService: Update not available" (because v1.0.1 is latest)
   ```

6. **Read testing guide**
   📖 [PHASE_3_DEVICE_TESTING_GUIDE.md](PHASE_3_DEVICE_TESTING_GUIDE.md)

---

### 📚 COMPREHENSIVE TRACK: Understand Everything First

If you want complete knowledge before proceeding:

1. **Read the complete deployment guide**
   📖 [PHASE_3_PRODUCTION_DEPLOYMENT.md](PHASE_3_PRODUCTION_DEPLOYMENT.md) (30-40 min read)
   - All hosting options explained
   - Security considerations
   - Monitoring setup
   - Rollout strategy

2. **Understand update system**
   📖 [FLUTTER_UPDATE_INTEGRATION_COMPLETE.md](FLUTTER_UPDATE_INTEGRATION_COMPLETE.md) (15 min read)
   - What was built and why
   - How it works under the hood
   - Configuration and testing

3. **Plan your approach**
   - Choose hosting: Heroku / AWS / DigitalOcean / Custom
   - Set timeline: 1-2 weeks for Wave 1
   - Assign responsibilities

4. **Execute step by step**
   - Week 1: Setup + device testing
   - Week 2: Beta rollout
   - Week 3: General availability

---

## 📋 Current Status Summary

### ✅ What's Already Done

- **Code**: v1.0.1 update system fully integrated
- **APK**: Built (76 MB) and ready to ship
- **Server**: Running on localhost:3000, tested
- **Testing**: Passes flutter analyze with no new errors
- **Documentation**: Complete guides for all scenarios

### ⏳ What Needs Your Decision

- **Hosting Platform**: Heroku (easiest) vs AWS (more control) vs other
- **Timeline**: Immediate vs this week vs next week
- **Team**: Who does what (deployment, testing, monitoring)

### 🚫 What Will Block You

- Not choosing a deployment approach
- Not changing localhost:3000 to production URL
- Not testing on actual device before rolling out
- Not setting up monitoring/alerting

---

## 🔥 Blockers & How to Avoid Them

### Blocker 1: "Don't know where to deploy"
**Solution**: Use Heroku (easiest, free tier available)  
**Time to overcome**: 2 minutes (read [PHASE_3_QUICK_START_HEROKU.md](PHASE_3_QUICK_START_HEROKU.md) first 10 lines)

### Blocker 2: "Update dialog doesn't appear on device"
**Solution**: Likely server URL wrong or server not accessible  
**Check**:
1. Is server URL correct in app.dart line 189? (Must match actual server)
2. Does `curl` from your computer work to that URL?
3. Can device reach that URL? (Same WiFi? Public URL?)
4. Check `adb logcat | grep -i "update"` for error messages

### Blocker 3: "APK download fails"
**Solution**: APK file not found on server  
**Check**:
1. Is APK in `/functions/distribution-server/apks/`?
2. Does server respond with download URL?
3. Can you download it manually with `curl`?

### Blocker 4: "Device won't install APK"
**Solution**: Could be version conflict or device issue  
**Try**:
```bash
adb uninstall com.example.dash_mobile
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Blocker 5: "Don't know if it's working"
**Solution**: Check logs!  
**For device**:
```bash
adb logcat | grep -i "flutter"
```
**For server**:
```bash
heroku logs --tail
# or locally:
npm start (in distribution-server)
```

---

## ⚡ Quick Reference Commands

### Check Current Status
```bash
# Is server running?
lsof -i :3000

# Is APK built?
ls -lh apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk

# Is device connected?
adb devices

# What's the app version?
adb shell dumpsys package com.example.dash_mobile | grep versionName
```

### Build & Deploy Commands
```bash
# Build APK
cd apps/Operon_Client_android && flutter build apk --release

# Install to device
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs from device
adb logcat | grep -i flutter

# Deploy to Heroku
cd functions && git push heroku main
```

### Test Endpoints
```bash
# Health check
curl http://localhost:3000/health

# Version check
curl "http://localhost:3000/api/version/operon-client?currentBuild=1"

# Download (gives you URL)
curl http://localhost:3000/api/download/operon-client
```

---

## 📅 Recommended Timeline

### Week 1: Setup & Initial Testing
- **Day 1-2**: Choose hosting, set up account
- **Day 2-3**: Deploy distribution server to cloud
- **Day 3-4**: Update app code with production URL, build APK
- **Day 4-5**: Device testing (Scenarios 1-2 from testing guide)
- **Day 5-7**: Fix any issues, Wave 1 internal testing with team

### Week 2: Beta Testing
- **Days 1-3**: Roll out to 10-15 beta users
- **Days 3-5**: Collect feedback, monitor for issues
- **Days 5-7**: Fix minor issues, prepare GA rollout

### Week 3+: General Availability
- **Day 1+**: Automatic rollout to all users
- **Ongoing**: Monitor metrics, respond to user issues

---

## 💰 Estimated Costs

### Hosting Options

| Platform | Initial | Monthly | Best For |
|----------|---------|---------|----------|
| Heroku Free | $0 | $0 | Testing only (sleeps) |
| Heroku Hobby | $0 | $7 | Wave 1 (always on) |
| AWS EC2 t3.micro | $0 | ~$5-10 | Production |
| DigitalOcean | $0 | $5-10 | Simple production |
| Own Server | Varies | Varies | Maximum control |

**Recommendation**: Start with Heroku Hobby ($7/month) for Wave 1 & 2, upgrade to Standard ($25+/month) for Wave 3 GA if needed.

---

## ✨ Success Criteria

You'll know Phase 3 is successful when:

- ✅ v1.0.1 APK accessible from production domain
- ✅ At least 5 team members can install v1.0.1
- ✅ Update dialog appears correctly on v1.0.0 → v1.0.1
- ✅ Users can download and install update successfully
- ✅ No critical crashes reported
- ✅ Update system monitoring working
- ✅ Rollout plan documented and tested
- ✅ Team trained and confident

---

## 📞 Need Help?

### Quick Issues
- Update system not working: [FLUTTER_UPDATE_INTEGRATION_COMPLETE.md](FLUTTER_UPDATE_INTEGRATION_COMPLETE.md) → Troubleshooting
- Deployment issues: [PHASE_3_QUICK_START_HEROKU.md](PHASE_3_QUICK_START_HEROKU.md) → Troubleshooting
- Device testing issues: [PHASE_3_DEVICE_TESTING_GUIDE.md](PHASE_3_DEVICE_TESTING_GUIDE.md) → Failure Troubleshooting

### Comprehensive Help
- Complete reference: [PHASE_3_PRODUCTION_DEPLOYMENT.md](PHASE_3_PRODUCTION_DEPLOYMENT.md)
- Everything in one place: [OPERON_V1_0_1_COMPLETE_DEPLOYMENT_PACKAGE.md](OPERON_V1_0_1_COMPLETE_DEPLOYMENT_PACKAGE.md)

---

## 🎬 Action Items (Pick One to Start)

### ✋ Option 1: Start Now (15 min)
- [ ] Follow [PHASE_3_QUICK_START_HEROKU.md](PHASE_3_QUICK_START_HEROKU.md)
- [ ] Get v1.0.1 live on Heroku staging
- [ ] Test with device

### ✋ Option 2: Understand First (1 hour)
- [ ] Read [PHASE_3_PRODUCTION_DEPLOYMENT.md](PHASE_3_PRODUCTION_DEPLOYMENT.md)
- [ ] Decide on hosting and timeline
- [ ] Plan team responsibilities

### ✋ Option 3: Test Locally (30 min)
- [ ] Verify localhost server running
- [ ] Build APK and install to device
- [ ] Walk through Scenario 1 from testing guide
- [ ] Then decide on deployment approach

---

## 📌 Pinned Information

**v1.0.1 Release Details:**
- Version Code: 1.0.1
- Build: 2
- APK Size: 76 MB
- Release Date: Feb 14, 2025
- Status: Ready for production

**Current Server:**
- Address: http://localhost:3000 (dev)
- Will be: https://your-domain.com (production)
- Type: Node.js/Express
- API: Version check, download, changelog endpoints

**Update System:**
- Type: In-app BLoC-based state management
- UI: Material Design dialog
- Features: Auto-check, progress tracking, error handling
- Support: Mandatory and optional updates

---

**Next Step**: Choose an option above and proceed!

**Start with**: [PHASE_3_QUICK_START_HEROKU.md](PHASE_3_QUICK_START_HEROKU.md) if unsure 👈

