# Trip Wages Performance Testing Guide

## Overview
This guide helps you measure and verify the performance improvements from the batch fetching optimization.

---

## 📊 Test 1: Measure Page Load Time (Chrome DevTools)

### Setup
1. Open Trip Wages page in Chrome
2. Right-click → **Inspect** (or F12)
3. Go to **Network** tab
4. Check "Disable cache" checkbox

### Baseline (Before Optimization)
1. **Hard refresh**: Ctrl+Shift+R
2. **Start DevTools recorder**:
   - Click ⏸ (Record button) at bottom
3. **Action**: Select date with ~50 DMs
4. **Stop recording** after page fully loads

### Expected Results (Before)
- **DOMContentLoaded**: ~3-4 seconds
- **Load**: ~5-8 seconds
- **Number of requests**: 51+ (1 DM fetch + 50 wage queries)

### Measure Values
```
Before Optimization:
├─ Network Requests: 51
├─ Total Time: 5-8 seconds
├─ Largest Contentful Paint: ~4s
└─ Time to Interactive: ~5-6s
```

### Test After Optimization
1. **Deploy changes** to **staging** environment
2. **Hard refresh**: Ctrl+Shift+R
3. **Repeat recording** (same date with 50 DMs)

### Expected Results (After)
- **DOMContentLoaded**: <1 second
- **Load**: <2 seconds
- **Number of requests**: 6 (1 DM fetch + 5 batch queries)

### Measure Values
```
After Optimization:
├─ Network Requests: 6
├─ Total Time: 1.5-2 seconds
├─ Largest Contentful Paint: <1s
└─ Time to Interactive: <1.5s

✅ Success Criteria: 4x faster
```

---

## 📊 Test 2: Firestore Read Operations (Firebase Console)

### Location
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **operonappsuite** project
3. Navigate to **Firestore Database**
4. Click **Usage** tab

### Baseline Measurement
1. **Date range**: Set to 7 days ago → today
2. **Look for**: "Read Operations" graph
3. **Record**: Average daily reads

```
Before Optimization:
Date Range: [7 days]
Daily Reads Count: ████████████████████ ~50-100K reads/day
TRIP_WAGES Collection: ████ ~40-80K reads/day
```

### After Deployment
1. **Deploy changes** to production
2. **Wait 24 hours** for traffic stabilization
3. **Revisit Usage tab**
4. **Compare metrics**

```
After Optimization:
Date Range: [Next 7 days]
Daily Reads Count: ███ ~5-15K reads/day
TRIP_WAGES Collection: ███ ~3-10K reads/day

Expected Reduction: 85% ✅
```

### Expected Savings
```
Scenario: 100 users, 50 DMs per load, 10 loads/day each

Before: 100 users × 50 DMs × 51 reads × 10 loads = 2,550,000 reads/day
After:  100 users × 50 DMs × 6 reads × 10 loads = 300,000 reads/day

Daily Savings: 2,250,000 reads (88% reduction) 💰
Monthly Savings: ~67.5M reads (-$0.35/month per 100 users)
```

---

## 📊 Test 3: Network Waterfall Analysis

### Setup
1. **Network tab** → Sort by **Type**
2. **Filter**: Show only **XHR/Fetch** requests
3. **Select date** with 50+ DMs

### Before Optimization
```
Network Waterfall:

1. delivery-memos              200ms  ████
2. trip-wages?dmId=dm1         150ms  ███
3. trip-wages?dmId=dm2         150ms  ███
4. trip-wages?dmId=dm3         150ms  ███
5. trip-wages?dmId=dm4         150ms  ███
... (repeats 46 more times)
51. trip-wages?dmId=dm50        150ms  ███
                                      ───────────
                         Total: 7-9s   ████████████████

❌ Issue: Sequential queries = slow loading
```

### After Optimization
```
Network Waterfall:

1. delivery-memos              200ms  ████
2. trip-wages-batch-1-10       150ms  ███
3. trip-wages-batch-11-20      150ms  ███
4. trip-wages-batch-21-30      150ms  ███
5. trip-wages-batch-31-40      150ms  ███
6. trip-wages-batch-41-50      150ms  ███
                                      ───────────
                         Total: 1.5-2s ██

✅ Success: Parallel queries = fast loading
```

### Key Metrics to Compare
```
Before:          After:          Improvement:
───────────────────────────────────────────
51 requests  →   6 requests      -88% ✅
~7s total    →   ~1.5s total     -79% ✅
Sequential   →   Parallel        Better UX ✅
```

---

## 📊 Test 4: Memory Usage

### Chrome DevTools Memory Tab

#### Before Optimization
1. **Open Memory tab**
2. **Take heap snapshot** before loading DMs
3. **Record**: ~X MB baseline
4. **Action**: Load DMs
5. **Take heap snapshot** after loading
6. **Record**: ~2.5 MB for state objects

```
Before:
├─ Baseline: 50 MB
├─ After load: 52.5 MB
└─ State object size: ~2.5 MB ❌
```

#### After Optimization
1. **Same process**
2. **Record**: ~1.5 MB for state objects

```
After:
├─ Baseline: 50 MB
├─ After load: 51.5 MB
└─ State object size: ~1.5 MB ✅

Reduction: 40% less memory
```

---

## 📊 Test 5: CPU Performance

### Chrome DevTools Performance Tab

#### Setup
1. **Performance tab** → Click **Record**
2. **Hard refresh** page
3. **Load DMs** for 50 DMs
4. **Stop recording**

#### Metrics to Track
```
Before Optimization:
├─ FCP (First Contentful Paint): ~3-4s
├─ LCP (Largest Contentful Paint): ~4-5s
├─ TTI (Time to Interactive): ~5-6s
└─ CLS (Cumulative Layout Shift): <0.1 ✅

After Optimization:
├─ FCP (First Contentful Paint): <0.8s ✅
├─ LCP (Largest Contentful Paint): <1.2s ✅
├─ TTI (Time to Interactive): <1.5s ✅
└─ CLS (Cumulative Layout Shift): <0.1 ✅
```

#### Success Criteria
- ✅ FCP < 1 second
- ✅ LCP < 2 seconds
- ✅ TTI < 2 seconds
- ✅ CLS < 0.1

---

## 📊 Test 6: Real-World User Testing

### 3G Network Simulation
1. **DevTools** → **Network tab**
2. **Throttling**: Select **Slow 3G**
3. **Reload page** with DM date
4. **Measure load time**

```
Slow 3G (Before): ~20s ❌
Slow 3G (After):  ~5s  ✅
Improvement:      4x faster
```

### 4G Network Simulation
1. **Throttling**: Select **Fast 3G**
2. **Reload page**
3. **Measure load time**

```
Fast 3G (Before): ~8s  ❌
Fast 3G (After):  ~2s  ✅
Improvement:      4x faster
```

---

## 📊 Test 7: Firestore Query Inspector

### Verify Batch Queries Work
1. **Firebase Console** → **Firestore**
2. **Go to**: Indexes tab
3. **Search for**: "trip-wages"
4. **Verify**: Index exists for (organizationId, dmId)

```
Required Index:
├─ Collection: TRIP_WAGES
├─ Field 1: organizationId (ASC)
├─ Field 2: dmId (ASC)
└─ Status: ✅ Enabled
```

### Check Batch Query Performance
1. **Firestore** → **Composite Indexes**
2. **Look for**: Index used by batch queries
3. **Status**: Should show "Enabled"

---

## 📋 Test Checklist

Create this checklist in Jira/GitHub:

```
Trip Wages Performance Verification

Environment: Staging
Date: [Today]

[ ] Page Load Baseline Recorded (Before)
    └─ Load Time: _____ seconds
    
[ ] Firestore Reads Baseline (Before)
    └─ Daily Reads: ______ K/day
    
[ ] Deploy Changes to Staging
    └─ Commit: ________________
    
[ ] Page Load Measured (After)
    └─ Load Time: _____ seconds
    └─ Target: <2 seconds? ✅/❌
    
[ ] Firestore Reads Measured (After)
    └─ Daily Reads: ______ K/day
    └─ Target: 85% reduction? ✅/❌
    
[ ] Network Waterfall Analyzed
    └─ Number of requests: _____
    └─ Target: <10 requests? ✅/❌
    
[ ] Memory Usage Tested
    └─ State Size: _____ MB
    └─ Target: <1.5 MB? ✅/❌
    
[ ] Chrome Core Web Vitals
    └─ FCP: _____ seconds (target <1s)
    └─ LCP: _____ seconds (target <2s)
    └─ TTI: _____ seconds (target <2s)
    
[ ] 3G Network Tested
    └─ Load Time: _____ seconds
    └─ Target: <5 seconds? ✅/❌
    
[ ] Approval from Product Team
    └─ Signed: _________________
    
[ ] Deploy to Production
    └─ Timestamp: ________________
    
[ ] Monitor 24 Hours
    └─ Confirm 85% read reduction? ✅/❌
```

---

## 🚀 Performance Regression Monitoring

After deployment, set up alerts:

### Firestore Read Operations
- **Alert If**: Daily reads increase >30% from baseline
- **Action**: Investigate + rollback if needed

### Page Load Time
- **Alert If**: Average load >3 seconds
- **Action**: Check for new issues

### CPU Usage
- **Alert If**: CPU spikes >80% sustained
- **Action**: Check for infinite loops

---

## 📝 Expected Test Results Summary

| Test | Before | After | Target | Status |
|------|--------|-------|--------|----------|
| Page Load Time | 5-8s | 1.5-2s | <2s | ✅ |
| Firestore Reads | 51 | 6 | <10 | ✅ |
| Network Requests | 51 | 6 | <10 | ✅ |
| Memory (State) | 2.5MB | 1.5MB | <1.5MB | ✅ |
| FCP | 3-4s | <0.8s | <1s | ✅ |
| LCP | 4-5s | <1.2s | <2s | ✅ |
| TTI | 5-6s | <1.5s | <2s | ✅ |
| 3G Load | ~20s | ~5s | <5s | ✅ |

---

## 🐛 Troubleshooting Test Issues

### Issue: Tests show no improvement
**Solution:**
1. Clear browser cache completely
2. Hard refresh (Ctrl+Shift+R)
3. Close all DevTools throttling
4. Test on private/incognito window
5. Verify code was actually deployed

### Issue: Firestore reads still high
**Solution:**
1. Check if users are still loading multiple dates
2. Monitor for 24+ hours (data takes time to aggregate)
3. Check if old clients are still running (they use old code)
4. Check Firestore index is properly deployed

### Issue: Page still seems slow
**Solution:**
1. Close other browser tabs
2. Disable extensions
3. Test on different device
4. Check network throttling is off
5. Monitor CPU usage separately

---

## 📞 Getting Help

If tests don't show expected results:
1. Check Firestore index is deployed
2. Verify code changes compiled correctly
3. Hard refresh browser cache
4. Wait 24 hours for metrics stabilization
5. Compare baseline from 7+ days ago vs today

---

**Document Created:** February 13, 2026
**Status:** Ready for Testing ✅

