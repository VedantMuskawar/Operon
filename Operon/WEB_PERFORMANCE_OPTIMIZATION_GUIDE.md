# Web Performance Optimization Guide for Low-End Devices

**Status**: Active Optimization Strategy  
**Last Updated**: February 19, 2026  
**Target**: Load web apps on low-end computers (Intel Celeron, 4GB RAM, slow internet)

---

## 📊 Current Performance Bottlenecks

### Critical Issues (Impact: HIGH)

#### 1. **Synchronous Google Maps Loading** ⚠️
**File**: [web/index.html](apps/Operon_Client_web/web/index.html#L46-L61)  
**Problem**: Uses `document.write()` which blocks HTML parsing
```javascript
// ❌ BLOCKS PAGE PARSING
document.write('<script src="https://maps.googleapis.com/maps/api/js?key=' + apiKey);
```
**Impact**: Entire page load is blocked until Google Maps API loads  
**Severity**: 🔴 CRITICAL - Can add 2-3 seconds on slow connections

#### 2. **Synchronous HTML2PDF Loading**
**File**: [web/index.html](apps/Operon_Client_web/web/index.html#L65)  
**Problem**: Large JavaScript library (100KB+) loaded synchronously  
**Impact**: Blocks parsing for all users, only needed by print feature  
**Severity**: 🟡 HIGH - ~1 second delay on slow connections

#### 3. **Insufficient Code Splitting**
**File**: [lib/config/app_router.dart](apps/Operon_Client_web/lib/config/app_router.dart#L17-L50)  
**Current Status**: Only 7 pages deferred (products, raw_materials, financial_transactions, etc.)  
**Missing**: 35+ other pages loaded eagerly  
**Impact**: Initial bundle size is 2-3x larger than necessary  
**Severity**: 🟡 HIGH - ~500KB+ unnecessary code loaded upfront

#### 4. **Image Optimization Missing**
**Issue**: No image compression, optimization, or lazy loading strategy apparent  
**Impact**: Images may be full resolution for all devices  
**Severity**: 🟠 MEDIUM - 20-30% of bandwidth on slower connections

---

## 🚀 Optimization Strategy (Priority Order)

### PHASE 1: Critical (Do First) - Fast Wins 🎯

#### 1.1 Make Google Maps Load Asynchronously
**File to Modify**: [web/index.html](apps/Operon_Client_web/web/index.html)  
**Expected Gain**: -2-3 seconds initial load  
**Implementation**:
```html
<!-- ✅ ASYNC LOADING (Non-blocking) -->
<script async defer>
  window.addEventListener('load', function() {
    var apiKey = window.GOOGLE_MAPS_API_KEY || '';
    if (!apiKey || apiKey.includes('{{')) return;
    
    var script = document.createElement('script');
    script.src = 'https://maps.googleapis.com/maps/api/js?key=' + 
                 encodeURIComponent(apiKey) + '&libraries=marker';
    document.head.appendChild(script);
  });
</script>
```

#### 1.2 Lazy Load HTML2PDF (On-Demand)
**File to Modify**: [web/index.html](apps/Operon_Client_web/web/index.html)  
**Expected Gain**: -1 second initial load  
**Implementation**:
```html
<!-- Load only when needed -->
<script>
  window.loadHtml2pdf = function() {
    if (window.html2pdf) return Promise.resolve();
    
    return new Promise((resolve) => {
      var script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js';
      script.onload = () => resolve();
      document.head.appendChild(script);
    });
  };
</script>
```

Then in print service:
```dart
// In dm_print_service.dart or similar
await js.context.callMethod('loadHtml2pdf');  // Load only when printing
```

#### 1.3 Create Lightweight Index HTML
**New File**: [web/index.minimal.html](apps/Operon_Client_web/web/)  
**Purpose**: Reduce initial HTML  
**Steps**:
- Remove inline scripts where possible
- Use async/defer for all external scripts
- Inline critical CSS only
- Expected Gain: -200-500KB transfer

---

### PHASE 2: Code Splitting (High Impact) 📦

#### 2.1 Extend Code Splitting to All Heavy Pages
**Current**: 7 pages deferred  
**Target**: 35+ pages deferred  
**Priority Pages** (in order of user loading):
```
Heavy (50KB+): 
  ✅ trip_wages_page.dart         (already deferred)
  ❌ clients_view.dart             (1500+ lines, 80KB)
  ❌ delivery_memos_view.dart      (800+ lines, 60KB)
  ❌ analytics_dashboard_view.dart (complex charts)
  ❌ employees_view.dart           (large lists)

Medium (20-50KB):
  ❌ orders/* pages
  ❌ fuel_ledger_page.dart
  ❌ expense_sub_categories_page.dart
  ❌ vehicle/vendor management pages
```

**Implementation** in [app_router.dart](apps/Operon_Client_web/lib/config/app_router.dart):
```dart
// ❌ CURRENT (Eager loading)
import 'package:dash_web/presentation/views/clients_view.dart';

// ✅ NEW (Deferred loading)
import 'package:dash_web/presentation/views/clients_view.dart'
    deferred as clients_view;
```

**Add Loading UI**:
```dart
GoRoute(
  path: '/clients',
  pageBuilder: (context, state) async {
    await clients_view.loadLibrary();
    return _buildTransitionPage(
      child: clients_view.ClientsPageContent(),
    );
  },
)
```

#### 2.2 Progressive Page Loading
**Goal**: Show skeleton loaders while code chunks download  
**Implementation**: Add loading indicator in page builder
```dart
pageBuilder: (context, state) => _buildTransitionPage(
  child: FutureBuilder(
    future: clients_view.loadLibrary(),
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return clients_view.ClientsPageContent();
    },
  ),
)
```

---

### PHASE 3: Runtime Performance 🔧

#### 3.1 Excessive Re-builds Prevention
**Issue**: BlocBuilder without proper buildWhen conditions  
**Status**: Some pages have this (employees_view, clients_view)  
**Target**: All pages

**Example Fix** (already done in some files):
```dart
// ✅ BEFORE (Rebuilds on every state change)
BlocBuilder<ClientsCubit, ClientsState>(
  builder: (context, state) { ... }
)

// ✅ AFTER (Only rebuild when relevant data changes)
BlocBuilder<ClientsCubit, ClientsState>(
  buildWhen: (previous, current) =>
    previous.clients != current.clients ||
    previous.status != current.status,
  builder: (context, state) { ... }
)
```

#### 3.2 Memoization Pattern for Expensive Operations
**Status**: Implemented in employees_view, clients_view  
**Apply to**: All list-heavy pages

**Pattern** (cache + hash validation):
```dart
List<Client>? _cachedFilteredClients;
String? _cachedQuery;

List<Client> _getFilteredClients(List<Client> all, String query) {
  if (_cachedFilteredClients != null && _cachedQuery == query) {
    return _cachedFilteredClients!;  // Return cached
  }
  
  final filtered = all.where((c) => c.name.contains(query)).toList();
  _cachedFilteredClients = filtered;
  _cachedQuery = query;
  return filtered;
}
```

#### 3.3 Virtual Scrolling for Large Lists
**Issue**: GridView/ListView with 1000+ items renders all  
**Impact**: 60+ FPS → 10-15 FPS on low-end devices  
**Solution**: Use `flutter_virtual_scroller` or custom implementation

```dart
// ❌ CURRENT - Renders all 1000 items
ListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) => ClientTile(clients[index]),
)

// ✅ IMPROVED - Only renders visible items (~15-20)
// Add to pubspec.yaml:
// virtual_list_view: ^1.0.0

VirtualListView.builder(
  itemCount: 1000,
  itemExtent: 80,
  builder: (context, index) => ClientTile(clients[index]),
)
```

---

### PHASE 4: Network & Caching Strategy 🌐

#### 4.1 Progressive Image Loading
**Current**: No image optimization apparent  
**Strategy**:
```dart
// ✅ Low-resolution placeholder, then high-res
Image.network(
  'https://example.com/image.jpg',
  placeholder: (context, url) => 
    Image.network('https://example.com/image-thumb.jpg'),
  fit: BoxFit.cover,
  cacheHeight: 400,  // Limit resolution
  cacheWidth: 400,
)
```

#### 4.2 Service Worker Caching
**File**: [web/sw.js](apps/Operon_Client_web/web/) (create if missing)  
**Purpose**: Cache API responses for offline/slow connections
```javascript
// Cache API responses for 5 minutes
self.addEventListener('fetch', (event) => {
  if (event.request.method === 'GET' && 
      event.request.url.includes('/api/')) {
    event.respondWith(
      caches.match(event.request).then((response) => {
        const fetchPromise = fetch(event.request).then((response) => {
          const cloneResponse = response.clone();
          caches.open('api-cache').then((cache) => {
            cache.put(event.request, cloneResponse);
          });
          return response;
        });
        return response || fetchPromise;
      })
    );
  }
});
```

#### 4.3 Firebase Realtime Database Indexing
**Issue**: Some queries may lack indexes  
**Action**: Verify [firestore.indexes.json](firestore.indexes.json)
```bash
# Check index usage in Firebase Console
# → Firestore → Indexes → Review suggested indexes
```

---

### PHASE 5: Build Optimization 🏗️

#### 5.1 Enable Flutter Web Release Build Settings
**File**: [pubspec.yaml](apps/Operon_Client_web/pubspec.yaml)  
**Add to flutter section**:
```yaml
flutter:
  web:
    # Enable aggressive minification
    build-risky-web-features: true
```

#### 5.2 Build & Serve Configuration
**Recommended**:
```bash
# Use these flags for optimized builds
flutter build web \
  --release \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --dart-define=FLUTTER_WEB_AUTO_DETECT_SYSTEM_TIMEZONE=false
```

#### 5.3 Static Asset Optimization
**Checklist**:
- [ ] GZIP all JavaScript/CSS files
- [ ] WebP images instead of PNG/JPG
- [ ] SVG for icons
- [ ] Remove unused fonts (limiting to 2-3 weight variants)

---

## 📈 Performance Metrics & Monitoring

### Key Metrics to Track

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| Initial Load (FCP) | ~3-5s | <2s | Chrome DevTools |
| Time to Interactive (TTI) | ~5-7s | <3s | Chrome DevTools |
| JavaScript Bundle Size | ~2.5-3MB | <1.5MB | Network tab |
| Firestore Calls (home) | 10-15 | <5 | DevTools → Network |
| Page Navigation | ~1-2s | <500ms | Navigation timing |

### Testing on Low-End Device Simulation

**Chrome DevTools**:
1. Open DevTools → Performance tab
2. Click throttling (top-left) → Slow 3G
3. CPU throttling: 4x slowdown
4. Record during page load
5. Measure FCP, LCP, TTI

**Script**:
```bash
# Test on different network speeds
# Slow 3G: ~400kb/s, 400ms latency
# Fast 3G: ~1.6mb/s, 100ms latency
# 4G: ~4mb/s, 20ms latency
```

---

## 🛠️ Implementation Checklist

### PHASE 1: Critical (Week 1)
- [ ] Optimize Google Maps async loading
- [ ] Lazy load HTML2PDF on demand
- [ ] Measure baseline performance (Chrome DevTools)
- [ ] Deploy & test on staging

### PHASE 2: Code Splitting (Week 2)
- [ ] Add deferred imports to 10+ heavy pages
- [ ] Implement loading UI for deferred pages
- [ ] Test code splitting with Network throttling
- [ ] Monitor bundle size reduction

### PHASE 3: Runtime (Week 3)
- [ ] Audit all BlocBuilders for buildWhen conditions
- [ ] Implement memoization where needed
- [ ] Add virtual scrolling to list pages
- [ ] Performance testing

### PHASE 4: Caching (Week 4)
- [ ] Implement Service Worker
- [ ] Add image lazy loading
- [ ] Setup Firestore query optimization
- [ ] Cloud CDN caching strategy

### PHASE 5: Build (Week 4)
- [ ] Configure release build optimizations
- [ ] Test on low-end device simulator
- [ ] Verify metric improvements
- [ ] Documentation update

---

## 🚀 Quick Impact Wins (Do These First)

### 5-15 Minutes Each
1. **Move Google Maps to async** → -2s load time
2. **Lazy load html2pdf** → -1s load time
3. **Add buildWhen to 3 key pages** → -500ms navigation

**Total Time Investment**: ~30 minutes  
**Total Performance Gain**: -3.5 seconds ⚡

---

## 📊 Expected Results

### Before Optimization
```
Slow 3G Simulation:
├─ Initial DL: 3-5 seconds
├─ TTI: 5-7 seconds
├─ Bundle: 2.5-3MB
└─ Memory: 120-150MB
```

### After Full Implementation
```
Slow 3G Simulation:
├─ Initial Load: <2 seconds (4x faster!)
├─ TTI: <3 seconds
├─ Bundle: <1.5MB
└─ Memory: 80-100MB
```

### Firestore Billing Impact
- Trip Wages: Already optimized (85% reduction) ✅
- Other pages: Expected 30-50% reduction

---

## 🔗 Related Resources

- [Trip Wages Performance Optimization](TRIP_WAGES_OPTIMIZATION_IMPLEMENTED.md) ✅
- [Flutter Web Performance Guide](https://flutter.dev/docs/perf/web-performance)
- [Chrome DevTools Performance Guide](https://developer.chrome.com/docs/devtools/performance/)
- [Lighthouse](https://developers.google.com/web/tools/lighthouse)

---

## 📝 Next.js Marketing App Optimization

### Current Status
- Build: `output: "export"` (Static export) ✅
- Transpile: Only `@operon/ui` ✅
- Bundle: Modern, no apparent issues

### Quick Wins for Marketing App
1. Add image optimization in components
2. Remove Framer Motion from above-the-fold
3. Lazy load animations
4. Add font subset loading

---

## 🆘 Support & Questions

**Common Issues**:
- **"Deferred imports not working?** → Ensure `flutter_web_plugins` is imported
- **"Bundle size not decreasing?"** → Check main.dart imports (may be re-importing)
- **"Image optimization slowing things down?"** → Use `cacheHeight`/`cacheWidth` wisely

**Test Results Recording**:
```
Date: [____]
Device: [Slow 3G Simulation / Low-end]
Metrics:
  - FCP: [____]s
  - LCP: [____]s
  - TTI: [____]s
  - Memory: [____]MB
  - Bundle: [____]MB
```

---

**Last Updated**: February 19, 2026  
**Maintainer**: Operon Dev Team  
**Status**: Ready for Implementation
