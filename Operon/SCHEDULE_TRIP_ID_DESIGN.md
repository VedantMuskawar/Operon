# Schedule Trip ID Design Discussion

## Requirements

1. **Generate unique scheduleTripID** with format: `ClientID-OrderID-Date-Vehicle-Slot`
2. **Constraints**:
   - ✅ Same client can have multiple orders
   - ✅ Same order can have multiple trips
   - ✅ Multiple trips can be scheduled on same vehicle and date
   - ❌ **Cannot have same vehicle + same slot + same date** (must be unique)

## Proposed Format

```
scheduleTripID = ClientID-OrderID-YYYYMMDD-VehicleNumber-Slot
```

**Example**: `CLIENT123-ORDER456-20240115-VEH001-1`

### Format Breakdown:
- **ClientID**: Full client document ID (e.g., `CLIENT123`)
- **OrderID**: Full order document ID (e.g., `ORDER456`)
- **Date**: `YYYYMMDD` format (e.g., `20240115` for Jan 15, 2024)
- **VehicleNumber**: Vehicle number/identifier (e.g., `VEH001` or `MH12AB1234`)
- **Slot**: Slot number (e.g., `1`, `2`, `3`)

## Key Considerations

### 1. **Uniqueness Constraint Enforcement**

The `scheduleTripID` format itself doesn't enforce the constraint that **Date+Vehicle+Slot** must be unique.

**Problem**: 
- Trip 1: `CLIENT-A-ORDER-1-20240115-VEH001-1`
- Trip 2: `CLIENT-B-ORDER-2-20240115-VEH001-1` 
- Both have different IDs but violate the constraint!

**Solution**: 
- Use `scheduleTripID` as a **human-readable reference ID**
- Keep Firestore document ID as primary key
- Add **validation query** before creating trip to check if `Date+Vehicle+Slot` already exists
- Store `scheduleTripID` in trip document for display/reference

### 2. **Validation Strategy**

**Option A: Frontend Validation (Current)**
- Check slot availability before showing modal
- But race condition possible if two users schedule simultaneously

**Option B: Backend Validation (Recommended)**
- Cloud Function validates before allowing trip creation
- Query: Check if any trip exists with same `scheduledDate + vehicleId + slot`
- Reject creation if conflict found

**Option C: Composite Index + Unique Constraint**
- Create Firestore composite index on `(scheduledDate, vehicleId, slot)`
- Use transaction to atomically check and create
- Still need application-level validation

### 3. **Date Format**

**Options**:
- `YYYYMMDD` (e.g., `20240115`) - ✅ Recommended: Sortable, no separators
- `YYYY-MM-DD` (e.g., `2024-01-15`) - ❌ Has separators, longer
- `DDMMYYYY` (e.g., `15012024`) - ❌ Not sortable

**Recommendation**: `YYYYMMDD` - Sortable, compact, no ambiguity

### 4. **Vehicle Identifier**

**Options**:
- `vehicleId` (Firestore document ID) - ✅ Recommended: Always unique, consistent
- `vehicleNumber` (Display number like `MH12AB1234`) - ⚠️ Could change, might have duplicates

**Recommendation**: Use `vehicleId` for uniqueness, but could also use `vehicleNumber` for readability

### 5. **Slot Format**

**Options**:
- Just number: `1`, `2`, `3` - ✅ Recommended: Simple
- Padded: `01`, `02`, `03` - ⚠️ Unnecessary if slots are single/double digits
- With prefix: `SLOT1`, `SLOT2` - ❌ Redundant

**Recommendation**: Just the number as-is

## Implementation Approach

### **Approach 1: scheduleTripID as Display ID (Recommended)**

1. **Generate scheduleTripID** when creating trip
2. **Store in trip document** as `scheduleTripId` field
3. **Keep Firestore document ID** as primary key
4. **Add validation** to check Date+Vehicle+Slot uniqueness before creation
5. **Update scheduleTripID** when rescheduling (new date/vehicle/slot)

**Pros**:
- Human-readable reference
- Can be updated on reschedule
- Doesn't break existing system
- Flexible for future changes

**Cons**:
- Not the primary key (Firestore ID still used)
- Need separate validation

### **Approach 2: scheduleTripID as Document ID**

1. **Generate scheduleTripID** as the Firestore document ID
2. **Use composite key** approach
3. **Validation built-in** (can't create duplicate document ID)

**Pros**:
- Built-in uniqueness
- No separate validation needed

**Cons**:
- ❌ **Problem**: If rescheduled, need to delete old and create new (loses history)
- ❌ **Problem**: Format might be too long for document ID
- ❌ **Problem**: Harder to query by other fields

**Recommendation**: ❌ Don't use as document ID

## Proposed Implementation

### **Step 1: Generate scheduleTripID**

```dart
String generateScheduleTripId({
  required String clientId,
  required String orderId,
  required DateTime scheduledDate,
  required String vehicleId, // or vehicleNumber
  required int slot,
}) {
  final dateStr = DateFormat('yyyyMMdd').format(scheduledDate);
  // Use last 8 chars of IDs for compactness, or full IDs
  final clientShort = clientId.length > 8 ? clientId.substring(clientId.length - 8) : clientId;
  final orderShort = orderId.length > 8 ? orderId.substring(orderId.length - 8) : orderId;
  final vehicleShort = vehicleId.length > 6 ? vehicleId.substring(vehicleId.length - 6) : vehicleId;
  
  return '$clientShort-$orderShort-$dateStr-$vehicleShort-$slot';
}
```

### **Step 2: Add Validation Before Creation**

```dart
Future<bool> isSlotAvailable({
  required String organizationId,
  required DateTime scheduledDate,
  required String vehicleId,
  required int slot,
}) async {
  final startOfDay = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  
  final existing = await _firestore
      .collection('SCHEDULE_TRIPS')
      .where('organizationId', isEqualTo: organizationId)
      .where('vehicleId', isEqualTo: vehicleId)
      .where('slot', isEqualTo: slot)
      .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
      .where('tripStatus', whereIn: ['scheduled', 'in_progress'])
      .limit(1)
      .get();
  
  return existing.docs.isEmpty;
}
```

### **Step 3: Store in Trip Document**

Add `scheduleTripId` field to trip document:
```dart
await docRef.set({
  'scheduleTripId': generatedId,
  // ... other fields
});
```

### **Step 4: Update on Reschedule**

When rescheduling, generate new `scheduleTripId` with new date/vehicle/slot.

## Questions to Clarify

1. **Use vehicleId or vehicleNumber?**
   - vehicleId: More reliable, always unique
   - vehicleNumber: More readable, but could change

2. **ID Length Concerns?**
   - Full IDs might be long (e.g., `abc123def456-xyz789uvw012-20240115-VEH001-1`)
   - Should we truncate to last N characters?

3. **Case Sensitivity?**
   - Should IDs be uppercase, lowercase, or mixed?
   - Recommendation: Uppercase for consistency

4. **Separator Character?**
   - Current: `-` (hyphen)
   - Alternatives: `_` (underscore), `.` (dot)
   - Recommendation: Keep `-` (hyphen) - readable

5. **Display vs Storage?**
   - Should we store full format or generate on-the-fly?
   - Recommendation: Store in document for consistency

## Recommended Format

```
scheduleTripId = CLIENT{last8}-ORDER{last8}-{YYYYMMDD}-{VEHICLE{last6}}-{SLOT}
```

**Example**: `CLIENT123-ORDER456-20240115-VEH001-1`

Or with full IDs:
```
scheduleTripId = {clientId}-{orderId}-{YYYYMMDD}-{vehicleId}-{slot}
```

**Example**: `abc123def456ghi-xyz789uvw012rst-20240115-veh001abc-1`

## Next Steps

1. **Decide on format** (full IDs vs truncated)
2. **Implement generation function**
3. **Add validation query**
4. **Update trip creation to include scheduleTripId**
5. **Update reschedule to regenerate ID**
6. **Add to Cloud Function trip entry**





