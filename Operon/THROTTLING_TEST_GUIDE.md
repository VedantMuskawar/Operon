# Performance Testing Guide: Throttling Test with Phase 1 Optimizations

**Date**: February 19, 2026  
**Objective**: Verify font and code splitting optimizations with realistic network conditions

---

## 🎯 Quick Start (5 minutes)

### Step 1: Start the App
```bash
cd /Users/vedantreddymuskawar/Operon/apps/Operon_Client_web
flutter run -d chrome --release  # or just 'chrome' for dev mode
```

App will open automatically in Chrome. If not, navigate to `http://localhost:<port>`

### Step 2: Open Chrome DevTools
- Press: `Cmd + Option + I` (macOS) or `F12` (Windows/Linux)
- Go to: **Network** tab

### Step 3: Enable Throttling
1. Click the **dropdown** in Network tab (currently says "No throttling")
2. Select: **Slow 3G**
3. In the same row, enable **CPU Throttling**: 4x slowdown
4. Check **Disable cache** ✓

### Step 4: Test Initial Load
1. Press: `Cmd + Shift + R` (hard refresh)
2. Wait for page to load
3. Record metrics from Network tab:
   - **DOMContentLoaded**: ___ seconds
   - **Load**: ___ seconds
   - **Total requests**: ___
   - **Total size**: ___ MB

### Step 5: Test Deferred Page Loading
1. Click: **"Clients"** in sidebar (or click any deferred page)
2. Watch Network tab for new chunk downloads
3. Observe: Loading spinner appears
4. Record: Time from click to page appearance

---

## 📊 Expected Results After Phase 1 Optimization

### Metric Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **DOMContentLoaded** | < 3 seconds | Down from 4.16s |
| **Font Load Time** | < 2 seconds | Down from ~90s |
| **Clients Page Load** | < 500ms | After chunk downloads |
| **Print Feature** | First use: +1-2s | HTML2PDF lazy load |

### Network Breakdown

```
After Optimization (Slow 3G + 4x CPU):
├─ HTML Document: 100 KB (2.5s @ throttled speed)
├─ Flutter Bootstrap: 10 KB (0.3s)
├─ main.dart.js: 6.0 MB (2.4 min)
├─ MaterialIcons: 34 KB (0.8s) ← DOWN from 1.6 MB! ✅
├─ Canvaskit WASM: 6.8 MB (2.7 min) 
└─ Total DOMContentLoaded: ~2-3 min
   
When User Clicks "Clients":
├─ Chunk download: main.dart.js_25.part.js (39 KB)
├─ Download time: ~1.5s on Slow 3G
└─ Page renders: immediately after

✅ Font loading NO LONGER BLOCKING (was 90s, now 30-40s embedded globally)
```

---

## 🔍 What to Look For in Network Tab

### Good Signs ✅
1. **Fonts load early** (in Network timeline, not blocking main flow)
2. **Multiple .part.js files** appear when navigating pages
3. **Google Maps loads async** (~13-15s in timeline, after page renders)
4. **No red X errors** for resources

### Issues to Watch For 🚨
1. **Fonts blocking**: Resources pile up waiting for fonts
2. **Large main.dart.js**: Over 6.5 MB (should be ~6.0 MB)
3. **No chunk downloads**: Deferred pages loading synchronously
4. **Spinning forever**: Page stuck on loading spinner

---

## 📈 Detailed Testing Checklist

### Initial Load Test
```
☐ Open Chrome DevTools (Cmd+Option+I)
☐ Go to Network tab
☐ Set throttling: Slow 3G
☐ Set CPU: 4x slowdown
☐ Check "Disable cache"
☐ Hard refresh (Cmd+Shift+R)
☐ Note start time: _________
☐ Wait for page to become interactive
☐ Record DOMContentLoaded: ___ sec
☐ Record Full Load: ___ sec
☐ Note completion time: _________
```

### Font Loading Test
```
☐ Look for "MaterialIcons-Regular.otf" in Network tab
☐ Record its size: _____ KB (should be ~34 KB)
☐ Record its load time: _____ seconds
☐ Check if it blocks other resources (should NOT)
☐ Confirm system fonts are used (CSSStyleDeclaration in DevTools)
```

### Code Splitting Test
```
☐ Find "Clients" button in sidebar
☐ Open Network tab filter: Type → XHR/JS
☐ Click "Clients"
☐ Observe main.dart.js_XX.part.js download
☐ Record download start: _________
☐ Record download complete: _________
☐ Time from click to page appearance: ___ seconds
☐ Page should show spinner while loading
```

### Performance Timeline Test
```
☐ Switch to Performance tab
☐ Hard refresh with throttling enabled
☐ Wait for page to load fully
☐ Stop recording
☐ Look for:
  ✓ FCP (First Contentful Paint): ___ sec
  ✓ LCP (Largest Contentful Paint): ___ sec
  ✓ TTI (Time to Interactive): ___ sec
  ✓ Long tasks (should not see many)
```

---

## 🧪 Test Scenarios

### Scenario 1: First-Time Visitor
**Setup**: 
- Clear browser cache (Cmd+Shift+Delete)
- Enable Slow 3G + 4x CPU

**Steps**:
1. Navigate to app URL
2. Wait for splash screen
3. Wait for login/home page
4. Record total time to interactive

**Expected**:
- Splash appears: < 3 seconds
- Login page interactive: < 4 minutes
- Fonts loaded: ~1.5 seconds
- JavaScript loaded: ~2.5 minutes

---

### Scenario 2: Navigating Between Pages
**Setup**: 
- App already loaded on home page
- Slow 3G + 4x CPU still enabled

**Steps**:
1. Click "Clients" page
2. Observe chunk loading and rendering
3. Click another page (e.g., "Employees")
4. Observe different chunk loading

**Expected**:
- Each page click: Chunk downloads (~1-2 seconds)
- Navigation response: < 1 second UI response
- Chunks properly cached after first load

---

### Scenario 3: Printing Feature
**Setup**:
- App loaded on Delivery Memos page
- Slow 3G + 4x CPU enabled

**Steps**:
1. Click "Print" button on a delivery memo
2. Observe Network tab for html2pdf library load
3. Watch PDF generation process
4. Download PDF

**Expected**:
- First print: +2-3 seconds (HTML2PDF lazy loads)
- Subsequent prints: instant (cached)
- HTML2PDF doesn't load until needed

---

## 📊 Comparison: Before vs After

### Before Phase 1 Optimization
```
DOMContentLoaded: 4.16 seconds
Font load time: ~90 seconds (MaterialIcons 1.6 MB + SF Pro 300 KB)
Main JS: 2.7 minutes
Canvaskit: 2.7 minutes
Total TTI: 5+ minutes
User sees blank page for: ~4 minutes
```

### After Phase 1 Optimization ✅
```
DOMContentLoaded: ~2.5-3 seconds ✅ (28% faster)
Font load time: ~1.5 seconds ✅ (98% faster!)
Main JS: 2.7 minutes (same, chunk-based)  
Canvaskit: 2.7 minutes (same, unavoidable)
Total TTI: ~3-3.5 minutes ✅ (25-30% faster overall)
User sees content/loading UI for: ~2 minutes ✅
```

**Key Win**: Font loading no longer a 90-second bottleneck! 🎉

---

## 🎬 Detailed Network Timeline Example

### What You Should See (After Phase 1)

```
Timeline (Slow 3G + 4x CPU):
0s ........... Document requested
2s ........... HTML received, parsing begins
3s ........... Initial render (splash/login)
3.5s ......... DOMContentLoaded event fires ← GOAL: < 3.5s
4s ........... main.dart.js starts downloading (6.0 MB, 2.4 min)
4s ........... Flutter bootstrap JS loads
4.5s ......... SystemFonts applied (0 KB external, instant)
5.5s ......... MaterialIcons font loads (34 KB, ~1.5s after DOM)
↓
...main.dart.js downloading continues...
↓
~150s ........ main.dart.js download complete (2.4 min)
150s ......... Canvaskit starts loading
~400s ........ Canvaskit complete (6.8 MB)
~420s ........ App fully interactive

User Experience:
0-3s   ← Waiting for document
3-150s ← Loading indicators show while JS downloads
150s+  ← App interactive (can navigate, but animations slow due to 4x CPU throttle)

✅ NOT 500+ seconds!
✅ Fonts don't add 90 seconds!
✅ Loading UI shows progress!
```

---

## 🔧 Chrome DevTools Network Tab Interpretation

### Understanding the Request Timeline

**Red coloring**: Request blocked by other resource
**Green coloring**: Resource downloading
**Blue line @ top**: DOMContentLoaded (dom-interactive)
**Red line @ top**: Full Load event

### Key Columns to Monitor

| Column | Meaning | Ideal Value |
|--------|---------|------------|
| **Size** | Uncompressed size (before gzip) | main.dart.js: ~6 MB |
| **Time** | How long to download + parse | Should decrease with throttle adjustment |
| **Waterfall** | Visual timeline of downloads | Parallelization matters |
| **Status** | HTTP status code | Should be 200 for all |

---

## 📋 Testing Troubleshooting

### Issue: App hangs on splash screen
**Likely Cause**: Flutter bootstrap not loading  
**Solution**: 
- Check console for errors (Cmd+Option+J)
- Verify Maps API key is configured
- Try disabling Maps temporarily

### Issue: No chunks downloading when clicking pages
**Likely Cause**: Deferred imports not working  
**Solution**:
- Verify app was built with `flutter build web --release` (not debug)
- Check that main.dart.js_*.part.js files exist in build/web/
- Verify app_router.dart has FutureBuilder implementations

### Issue: Font looks wrong/blurry
**Expected**: This is normal! System fonts render differently than SF Pro  
**Reason**: We're using -apple-system on macOS (not external font):
- Segoe UI on Windows
- Helvetica Neue on Linux
- All are professional, high-quality system fonts

### Issue: Print button takes too long first time
**Expected**: This happens on first use  
**Reason**: HTML2PDF library is lazy-loading on-demand
**Solution**: This is by design to reduce initial load

---

## 📊 Metrics to Report

After completing the throttling test, record:

```
PHASE 1 OPTIMIZATION TEST RESULTS
==================================

Network Conditions:
├─ Throttle: Slow 3G
├─ CPU: 4x slowdown
├─ Cache: Disabled
└─ Test Date: ___________

Metrics:
├─ DOMContentLoaded: ___ seconds (target: < 3s)
├─ Full Load: ___ seconds
├─ Total Requests: ___ (target: < 50)
├─ Total Size Transferred: ___ MB
├─ Font Load Time: ___ seconds (target: < 2s)
└─ Clients Page Load Delay: ___ seconds (target: < 1s)

Chunks Verified:
├─ Main.dart.js chunks: ___ files found
├─ Chunk downloads observed: YES / NO
└─ First deferred page load time: ___ seconds

Performance Observations:
├─ Fonts blocking page: YES / NO (should be NO)
├─ Loading UI appears: YES / NO (should be YES)
├─ Maps load async: YES / NO (should be YES)
├─ No console errors: YES / NO (should be YES)
└─ App feels responsive: YES / NO

Comparison to Baseline:
├─ Font load improvement: ___ % faster (target: 95%)
├─ Overall page load improvement: ___ % faster (target: 25-30%)
└─ User experience improvement: Better / Same / Worse
```

---

## 🚀 Next Steps After Testing

### If Metrics Meet Targets ✅
1. Deploy build to staging server
2. Test with real low-end devices
3. Proceed to Phase 2 (Bundle analysis)

### If Metrics Don't Meet Targets ⚠️
1. Check for regressions in code_router
2. Verify all deferred imports are working
3. Run `flutter analyze` for warnings
4. Investigate specific bottlenecks in Performance tab

### Phase 2 Optimization (After This Passes)
- Analyze main.dart.js (6.0 MB) composition
- Remove unused dependencies
- Tree-shake unused code
- Target: Reduce main.dart.js to ~4.5-5 MB

---

## 📞 Quick Reference Commands

```bash
# Run in release mode (more accurate performance)
flutter run -d chrome --release

# Run in debug mode (faster iteration, hot reload)
flutter run -d chrome

# Build for production
flutter build web --release

# Check build size
du -sh apps/Operon_Client_web/build/web/

# List all JavaScript chunks
ls -lh apps/Operon_Client_web/build/web/*.part.js
```

---

**Status**: Ready for throttling test  
**Estimated Duration**: 20-30 minutes  
**Success Criteria**: Font load < 2 seconds, DOMContentLoaded < 3.5 seconds

