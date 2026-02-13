# Trip Wages Page - Performance Optimization Guide

## Current Performance Bottlenecks

### 1. **N+1 Query Problem (CRITICAL) ⚠️**
**Location:** `TripWagesCubit.loadActiveDMsForDate()` (line 311)

**Problem:**
```dart
for (final memo in memos) {
  final dmId = memo['dmId'] as String?;
  if (dmId != null) {
    final existingWage = await _repository.fetchTripWageByDmId(dmId);  // ⚠️ ONE QUERY PER DM
    // ... process result
  }
}
```

**Impact:**
- With 50 DMs loaded: 1 initial DM fetch + 50 trip wage queries = **51 Firestore reads**
- Queries are **sequential**, not parallel → slow page load
- Firestore costs increase linearly with DM count

**Examples:**
- 50 DMs = ~51 reads = 51 billable operations
- 100 DMs = ~101 reads = 101 billable operations

---

### 2. **Missing Firestore Compound Index**
**Location:** `TripWagesDataSource.fetchTripWageByDmId()` (line 236)

**Problem:**
```dart
final snapshot = await _tripWagesRef
    .where('dmId', isEqualTo: dmId)
    .limit(1)
    .get();
```

This query filters on `dmId` but likely lacks a proper index for performance.

**Current Indexes in `firestore.indexes.json`:**
```json
// TRIP_WAGES Indexes (lines 1360-1407)
1. organizationId (ASC) + createdAt (DESC)
2. organizationId (ASC) + dmId (ASC)  ← This covers our query if it checks organizationId
3. organizationId (ASC) + status (ASC) + createdAt (DESC)
```

**Issue:** `fetchTripWageByDmId()` doesn't filter by `organizationId`, making the query inefficient.

---

### 3. **No Pagination for Delivery Memos**
**Location:** `TripWagesCubit.loadActiveDMsForDate()`

**Problem:**
- All DMs for a date are loaded into memory at once
- Single date with 100+ DMs = large payload
- No lazy loading or virtual scrolling

**Impact:**
- Memory bloat
- Slow initial page render
- Unnecessary bandwidth for off-screen items

---

### 4. **Sequential Leading in initState**
**Location:** `_TripWagesContentState.initState()` (line 93)

**Problem:**
```dart
cubit.loadActiveDMsForDate(_selectedDate);       // Wait 1s
cubit.loadEmployeesByRole('Loader');              // Wait 1s
cubit.loadWageSettings();                         // Wait 1s
// Total: ~3 seconds sequential
```

**Impact:**
- Three independent operations block each other
- Should load in **parallel** (~1 second total)

---

### 5. **Inefficient Data Structure & Over-Copying**
**Location:** `TripWagesCubit.loadActiveDMsForDate()` (line 330-350)

**Problem:**
```dart
final memoWithWageInfo = Map<String, dynamic>.from(memo);
memoWithWageInfo['tripWage'] = existingWage;  // Include full object
memoWithWageInfo['totalWages'] = existingWage.totalWages;
memoWithWageInfo['loadingWages'] = existingWage.loadingWages;
// ... 5+ more field copies
memoWithWageInfo['loadingEmployeeIds'] = existingWage.loadingEmployeeIds;
```

**Impact:**
- Duplicates nested data (memo already has basic DM info)
- Large state objects → slow state emission
- Difficult to maintain consistency

---

### 6. **Stream First Value Usage**
**Location:** `TripWagesCubit.loadActiveDMsForDate()` (line 318)

**Problem:**
```dart
final memos = await _deliveryMemoRepository
    .watchDeliveryMemos(...)
    .first;  // ⚠️ Takes first value, ignores real-time updates
```

**Impact:**
- Doesn't leverage real-time updates from Firestore
- Each date change requires full reload
- Material changes aren't reflected live

---

## Performance Test Baseline

| Scenario | Current | Target |
|----------|---------|--------|
| Load 50 DMs + trip wages | ~5-8s | <1.5s |
| Firestore read operations | 51 reads | 2 reads |
| Initial page render | ~3s (sequential loads) | <1s (parallel) |
| Memory usage (state) | High (duplicated data) | Low (lean data) |

---

## Optimization Solutions

### Solution 1: Batch Fetch Trip Wages (Highest Priority) 🚀
**Impact:** Reduce 50+ queries → 1-2 queries

**Step 1:** Add method to `TripWagesDataSource`
```dart
Future<Map<String, TripWage>> fetchTripWagesByDmIds(
  String organizationId,
  List<String> dmIds,
) async {
  if (dmIds.isEmpty) return {};
  
  try {
    // Batch queries into chunks (Firestore limit: 10 conditions per query)
    final chunks = <List<String>>[];
    for (int i = 0; i < dmIds.length; i += 10) {
      chunks.add(dmIds.sublist(i, min(i + 10, dmIds.length)));
    }
    
    final results = <String, TripWage>{};
    
    // Execute all chunk queries in parallel
    await Future.wait(chunks.map((chunk) async {
      final snapshot = await _tripWagesRef
          .where('organizationId', isEqualTo: organizationId)
          .where('dmId', whereIn: chunk)
          .get();
      
      for (final doc in snapshot.docs) {
        final tripWage = TripWage.fromJson(doc.data(), doc.id);
        results[tripWage.dmId] = tripWage;
      }
    }));
    
    return results;
  } catch (e) {
    throw Exception('Failed to fetch trip wages by DM IDs: $e');
  }
}
```

**Step 2:** Update `TripWagesCubit.loadActiveDMsForDate()`
```dart
Future<void> loadActiveDMsForDate(DateTime date) async {
  try {
    emit(state.copyWith(status: ViewStatus.loading));
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay;
    
    final memos = await _deliveryMemoRepository
        .watchDeliveryMemos(
          organizationId: _organizationId,
          startDate: startOfDay,
          endDate: endOfDay,
        )
        .first;

    // Extract all DM IDs
    final dmIds = memos
        .map((memo) => memo['dmId'] as String?)
        .whereType<String>()
        .toList();

    // BATCH FETCH instead of N+1 queries
    final tripWagesByDmId = dmIds.isNotEmpty
        ? await _repository.fetchTripWagesByDmIds(_organizationId, dmIds)
        : <String, TripWage>{};

    // Build active DMs with trip wage info
    final activeDMs = <Map<String, dynamic>>[];
    for (final memo in memos) {
      final dmId = memo['dmId'] as String?;
      if (dmId == null) continue;

      final tripWage = tripWagesByDmId[dmId];
      final memoData = {
        ...memo,
        'hasTripWage': tripWage != null,
        if (tripWage != null) ...{
          'tripWageId': tripWage.tripWageId,
          'tripWageStatus': tripWage.status.name,
          'tripWage': tripWage,
        },
      };
      activeDMs.add(memoData);
    }

    emit(state.copyWith(
      status: ViewStatus.success,
      activeDMs: activeDMs,
      selectedDate: date,
      message: null,
    ));
  } catch (e, stackTrace) {
    debugPrint('[TripWagesCubit] Error loading active DMs: $e');
    debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
    emit(state.copyWith(
      status: ViewStatus.failure,
      message: 'Failed to load active DMs: ${e.toString()}',
    ));
  }
}
```

**Expected Improvement:**
- 50 DMs: 51 reads → 6 reads (1 initial + 5 batches of 10)
- Time: ~5-8s → ~1.5-2s
- Cost reduction: ~90% fewer Firestore operations

---

### Solution 2: Ensure Optimal Firestore Index
**Location:** `firestore.indexes.json`

Verify the index for `fetchTripWageByDmId()`:
```json
{
  "collectionGroup": "TRIP_WAGES",
  "queryScope": "Collection",
  "fields": [
    {
      "fieldPath": "organizationId",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "dmId",
      "order": "ASCENDING"
    }
  ]
}
```

**To verify in Firebase Console:**
1. Go to Firestore Database → Indexes
2. Search for TRIP_WAGES collection
3. Confirm index exists for (organizationId, dmId)

---

### Solution 3: Parallelize Page Loading
**Location:** `_TripWagesContentState.initState()` (line 93)

**Before:**
```dart
cubit.loadActiveDMsForDate(_selectedDate);      // Sequential
cubit.loadEmployeesByRole('Loader');
cubit.loadWageSettings();
```

**After:**
```dart
await Future.wait([
  cubit.loadActiveDMsForDate(_selectedDate),
  cubit.loadEmployeesByRole('Loader'),
  cubit.loadWageSettings(),
]);
```

**Expected Improvement:**
- Time: ~3s → ~1s (3x faster)

---

### Solution 4: Implement Pagination for DMs
**Location:** `TripWagesCubit` and `delivery_memo_data_source.dart`

**Step 1:** Add pagination parameters to `loadActiveDMsForDate()`
```dart
Future<void> loadActiveDMsForDate(
  DateTime date, {
  int pageSize = 20,
  int pageNumber = 0,
}) async {
  // ... existing code ...
  
  // Use limit and offset
  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay;
  
  final memos = await _deliveryMemoRepository
      .watchDeliveryMemos(
        organizationId: _organizationId,
        startDate: startOfDay,
        endDate: endOfDay,
        limit: pageSize,
        // Add offset in next step (need to update data source)
      )
      .first;
  
  // ... rest of implementation ...
}
```

**Step 2:** Update UI to show "Load More" button
```dart
ElevatedButton(
  onPressed: () {
    cubit.loadActiveDMsForDate(
      _selectedDate,
      pageNumber: currentPage + 1,
    );
  },
  child: const Text('Load More DMs'),
)
```

**Expected Improvement:**
- Initial load: 100 DMs → 20 DMs
- Memory: 60% reduction
- Page load time: ~1.5s faster

---

### Solution 5: Lean Data Structure
**Location:** `TripWagesCubit.loadActiveDMsForDate()` (line 330)

**Before:**
```dart
final memoWithWageInfo = Map<String, dynamic>.from(memo);
memoWithWageInfo['tripWage'] = existingWage;  // Full object
memoWithWageInfo['totalWages'] = existingWage.totalWages;
memoWithWageInfo['loadingWages'] = existingWage.loadingWages;
// ... 5+ duplicate fields
```

**After:**
```dart
final memoData = {
  ...memo,  // Keep original DM data
  'hasTripWage': tripWage != null,
  if (tripWage != null) ...{
    'tripWageId': tripWage.tripWageId,
    'tripWageStatus': tripWage.status.name,
    // Only include essential fields, not the full object
  },
};
```

**Expected Improvement:**
- State size: ~40% reduction
- Emission speed: 2x faster
- Easier to debug/maintain

---

### Solution 6: Use Real-time Updates
**Current:**
```dart
final memos = await _deliveryMemoRepository
    .watchDeliveryMemos(...)
    .first;  // One-time fetch
```

**Improved:**
```dart
void watchActiveDMsForDate(DateTime date) {
  _dmsSubscription?.cancel();
  _dmsSubscription = _deliveryMemoRepository
      .watchDeliveryMemos(...)
      .listen((memos) {
    // Rebuild on each update
    _processAndEmitDMs(memos);
  });
}

@override
Future<void> close() {
  _dmsSubscription?.cancel();
  return super.close();
}
```

**Expected Improvement:**
- Real-time updates: DMs/wages update automatically
- No need for manual refresh
- Better UX

---

## Implementation Priority

| Priority | Solution | Effort | Impact | Time Saved |
|----------|----------|--------|--------|-----------|
| 🔴 P1 | Batch fetch trip wages | 2 hours | 90% read reduction | 5-6s |
| 🟡 P2 | Parallelize loading | 30 min | 3x faster init | 2s |
| 🟡 P2 | Lean data structure | 1 hour | 40% state reduction | 1s |
| 🟢 P3 | Implement pagination | 3 hours | Scalability | Variable |
| 🟢 P3 | Real-time updates | 2 hours | Better UX | User perceived |
| 🟢 P3 | Verify Firestore index | 30 min | Baseline perf | 500ms |

---

## Implementation Checklist

- [ ] **Phase 1 - Critical Fixes**
  - [ ] Add `fetchTripWagesByDmIds()` to `TripWagesDataSource`
  - [ ] Update `loadActiveDMsForDate()` to use batch fetching
  - [ ] Parallelize initState loading with `Future.wait`
  - [ ] Test with 50+ DMs, verify page load < 2s

- [ ] **Phase 2 - Optimizations**
  - [ ] Simplify DM data structure (remove duplicate fields)
  - [ ] Verify Firestore index exists for (organizationId, dmId)
  - [ ] Add pagination support to `loadActiveDMsForDate()`
  - [ ] Test memory usage, verify < previous levels

- [ ] **Phase 3 - Real-time UX**
  - [ ] Implement `watchActiveDMsForDate()` for live updates
  - [ ] Add subscription lifecycle management
  - [ ] Test that changes reflect without reload

---

## Performance Monitoring

After implementation, measure:

```dart
// Add timing logs
final stopwatch = Stopwatch()..start();
await cubit.loadActiveDMsForDate(_selectedDate);
debugPrint('Time to load: ${stopwatch.elapsedMilliseconds}ms');
```

**Target Metrics:**
- ✅ Page load: < 1.5 seconds
- ✅ Firestore reads: < 10 per date change
- ✅ Memory (state): < 2MB
- ✅ Real-time updates: Observable within 1s

---

## Additional Notes

1. **Firestore Billing Impact:**
   - Current (50 DMs): ~51 reads per page load
   - Optimized: ~6 reads per page load
   - **Savings: ~85% reduction in read operations**

2. **Database Indexing:**
   - Ensure compound index on (organizationId, dmId) exists
   - Add index for (organizationId, dmId, createdAt) if filtering by date

3. **Future Enhancements:**
   - Implement client-side caching using local Firestore
   - Add offset-based pagination to`watchDeliveryMemos()`
   - Consider denormalizing trip wage summary in DELIVERY_MEMOS

