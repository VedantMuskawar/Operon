# RoundtripKM Field Implementation Proposal

## Overview
Add a `RoundtripKM` field to the DeliveryZone entity to store the round trip distance (in kilometers) that a vehicle must travel to deliver to a region and return. This field should only be collected when creating a new region.

---

## Current Schema Analysis

### DeliveryZone Model Structure
**Location:** `packages/core_models/lib/entities/delivery_zone.dart`

**Current Fields:**
```dart
class DeliveryZone {
  final String id;
  final String organizationId;
  final String cityId;
  final String cityName;
  final String region;
  final Map<String, DeliveryZonePrice> prices;  // Product prices
  final bool isActive;
}
```

**Current Database Schema:**
```
ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}
{
  organization_id: string,
  city_id: string,
  city_name: string,
  region: string,
  is_active: boolean,
  prices: {
    [productId]: {
      unit_price: number,
      deliverable: boolean,
      updated_at: timestamp
    }
  },
  created_at: timestamp,
  updated_at: timestamp
}
```

---

## Proposed Changes

### 1. Database Schema

**Updated Schema:**
```typescript
ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}
{
  organization_id: string,
  city_id: string,
  city_name: string,
  region: string,
  roundtrip_km: number | null,  // NEW FIELD (optional for backward compatibility)
  is_active: boolean,
  prices: {
    [productId]: {
      unit_price: number,
      deliverable: boolean,
      updated_at: timestamp
    }
  },
  created_at: timestamp,
  updated_at: timestamp
}
```

**Key Decisions:**
- ✅ Store at **zone level** (not product level) - Round trip distance is a property of the delivery location
- ✅ Make it **nullable** (`number | null`) for backward compatibility with existing zones
- ✅ Field name: `roundtrip_km` (snake_case for Firestore, camelCase in Dart)

---

### 2. Core Models Package

**File:** `packages/core_models/lib/entities/delivery_zone.dart`

**Changes:**
```dart
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.organizationId,
    required this.cityId,
    required this.cityName,
    required this.region,
    required this.prices,
    this.isActive = true,
    this.roundtripKm,  // NEW: Optional field
  });

  final String id;
  final String organizationId;
  final String cityId;
  final String cityName;
  final String region;
  final Map<String, DeliveryZonePrice> prices;
  final bool isActive;
  final double? roundtripKm;  // NEW: Round trip distance in kilometers

  factory DeliveryZone.fromMap(Map<String, dynamic> map, String id) {
    // ... existing code ...
    
    return DeliveryZone(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      cityId: map['city_id'] as String? ?? '',
      cityName: map['city_name'] as String? ?? '',
      region: map['region'] as String? ?? '',
      prices: prices,
      isActive: map['is_active'] as bool? ?? true,
      roundtripKm: (map['roundtrip_km'] as num?)?.toDouble(),  // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city_id': cityId,
      'city_name': cityName,
      'region': region,
      'is_active': isActive,
      if (roundtripKm != null) 'roundtrip_km': roundtripKm,  // NEW: Only include if not null
      'prices': prices.map(
        (key, value) => MapEntry(key, {
          'unit_price': value.unitPrice,
          'deliverable': value.deliverable,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      ),
    };
  }

  DeliveryZone copyWith({
    String? id,
    String? organizationId,
    String? cityId,
    String? cityName,
    String? region,
    Map<String, DeliveryZonePrice>? prices,
    bool? isActive,
    double? roundtripKm,  // NEW
  }) {
    return DeliveryZone(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      region: region ?? this.region,
      prices: prices ?? this.prices,
      isActive: isActive ?? this.isActive,
      roundtripKm: roundtripKm ?? this.roundtripKm,  // NEW
    );
  }
}
```

---

### 3. Android App Implementation

#### 3.1 Update CreateRegion Dialog
**File:** `apps/Operon_Client_android/lib/presentation/views/zones_page.dart`

**Changes to `_AddRegionDialog`:**
- Add `TextFormField` for RoundtripKM input
- Add validation (must be a positive number)
- Pass `roundtripKm` to `createRegion` method

```dart
class _AddRegionDialogState extends State<_AddRegionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedCity;
  final _regionController = TextEditingController();
  final _roundtripKmController = TextEditingController();  // NEW
  bool _submitting = false;

  @override
  void dispose() {
    _regionController.dispose();
    _roundtripKmController.dispose();  // NEW
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // ... existing code ...
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ... existing city dropdown ...
            
            TextFormField(
              controller: _regionController,
              // ... existing region field ...
            ),
            
            // NEW: RoundtripKM field
            const SizedBox(height: 12),
            TextFormField(
              controller: _roundtripKmController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Round Trip Distance (KM)',
                hintText: 'e.g., 25.5',
                prefixIcon: Icon(Icons.straighten, color: Colors.white54),
                filled: true,
                fillColor: Color(0xFF1B1B2C),
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter round trip distance';
                }
                final km = double.tryParse(value.trim());
                if (km == null || km <= 0) {
                  return 'Enter a valid positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        // ... existing cancel button ...
        TextButton(
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            if (_selectedCity == null) return;
            setState(() => _submitting = true);
            try {
              final roundtripKm = double.parse(_roundtripKmController.text.trim());  // NEW
              await context.read<DeliveryZonesCubit>().createRegion(
                    city: _selectedCity!,
                    region: _regionController.text.trim(),
                    roundtripKm: roundtripKm,  // NEW
                  );
              if (mounted) Navigator.of(context).pop();
            } catch (err) {
              // ... error handling ...
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

#### 3.2 Update CreateRegion in Order Flow
**File:** `apps/Operon_Client_android/lib/presentation/views/orders/sections/delivery_zone_selection_section.dart`

**Changes to `_AddRegionDialog` (in order creation flow):**
- Same changes as above to add RoundtripKM field

#### 3.3 Update DeliveryZonesCubit
**File:** `apps/Operon_Client_android/lib/presentation/blocs/delivery_zones/delivery_zones_cubit.dart`

**Changes to `createRegion` method:**
```dart
Future<void> createRegion({
  required String city,
  required String region,
  required double roundtripKm,  // NEW: Make required for new regions
}) async {
  final normalizedCity = city.trim();
  final normalizedRegion = region.trim();
  if (normalizedCity.isEmpty || normalizedRegion.isEmpty) {
    throw Exception('City and region are required');
  }
  
  // Find city by name
  final cityObj = _cities.firstWhere(
    (c) => c.name.toLowerCase() == normalizedCity.toLowerCase(),
    orElse: () => throw Exception('City not found'),
  );
  
  final duplicate = state.zones.any(
    (zone) =>
        zone.cityId == cityObj.id &&
        zone.region.toLowerCase() == normalizedRegion.toLowerCase(),
  );
  if (duplicate) {
    throw Exception('This address already exists.');
  }
  
  // ID will be auto-generated by Firestore
  final zone = DeliveryZone(
    id: '',
    organizationId: _orgId,
    cityId: cityObj.id,
    cityName: cityObj.name,
    region: normalizedRegion,
    prices: {},
    isActive: true,
    roundtripKm: roundtripKm,  // NEW
  );
  await createZone(zone);
}
```

#### 3.4 Update CreateOrderCubit (Pending Region)
**File:** `apps/Operon_Client_android/lib/presentation/blocs/create_order/create_order_cubit.dart`

**Changes to `addPendingRegion` method:**
```dart
void addPendingRegion({
  required String city,
  required String region,
  required double roundtripKm,  // NEW
}) {
  // Find city by name to get cityId
  final cityObj = state.cities.firstWhere(
    (c) => c.name == city,
    orElse: () => throw Exception('City not found'),
  );
  
  final newZone = DeliveryZone(
    id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
    organizationId: _organizationId,
    cityId: cityObj.id,
    cityName: cityObj.name,
    region: region,
    prices: {},
    isActive: true,
    roundtripKm: roundtripKm,  // NEW
  );
  
  emit(
    state.copyWith(
      pendingNewZone: newZone,
      selectedCity: city,
      selectedZoneId: newZone.id,
    ),
  );
}
```

---

### 4. Web App Implementation

#### 4.1 Update CreateRegion Dialog
**File:** `apps/Operon_Client_web/lib/presentation/views/zones_view.dart`

**Changes to `_AddRegionDialog`:**
- Similar changes as Android app
- Add RoundtripKM field with proper styling matching the web app design

```dart
class _AddRegionDialogState extends State<_AddRegionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _selectedCity;
  final _regionController = TextEditingController();
  final _roundtripKmController = TextEditingController();  // NEW
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // ... existing dialog structure ...
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // ... existing city dropdown ...
            
            TextFormField(
              controller: _regionController,
              // ... existing region field ...
            ),
            
            // NEW: RoundtripKM field
            const SizedBox(height: 16),
            TextFormField(
              controller: _roundtripKmController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Round Trip Distance (KM)',
                hintText: 'e.g., 25.5',
                prefixIcon: const Icon(Icons.straighten, color: Colors.white54, size: 20),
                filled: true,
                fillColor: const Color(0xFF1B1B2C),
                labelStyle: const TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF5AD8A4),
                    width: 2,
                  ),
                ),
                // ... error borders ...
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter round trip distance';
                }
                final km = double.tryParse(value.trim());
                if (km == null || km <= 0) {
                  return 'Enter a valid positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      // ... footer actions with updated onPressed ...
    );
  }
}
```

#### 4.2 Update DeliveryZonesCubit (Web)
**File:** `apps/Operon_Client_web/lib/presentation/blocs/delivery_zones/delivery_zones_cubit.dart`

**Changes:** Same as Android app's cubit changes

#### 4.3 Update Create Order Flow (Web)
**File:** `apps/Operon_Client_web/lib/presentation/views/orders/sections/delivery_zone_selection_section.dart`

**Changes:** Same as Android app's order flow changes

---

### 5. Core Datasources Package

**File:** `packages/core_datasources/lib/delivery_zones/delivery_zones_data_source.dart`

**Changes:** No changes needed - the data source uses `zone.toMap()` which will automatically include the new field.

However, we should verify that:
- `createZone` method properly handles the new field (it does, via `toMap()`)
- `updateZone` method properly handles the new field (it does, via `toMap()`)
- `fromMap` in DeliveryZone handles missing `roundtrip_km` gracefully (it does, as we make it nullable)

---

## Migration Strategy

### For Existing Zones
Since `roundtripKm` is nullable:
- ✅ **Existing zones** will have `roundtripKm: null`
- ✅ **No data migration needed** - backward compatible
- ✅ Existing zones can be updated later if needed (future enhancement)

### For New Zones
- ✅ **All new zones** must provide `roundtripKm` when created
- ✅ Validation ensures it's a positive number
- ✅ Field is stored in Firestore as `roundtrip_km`

---

## UI/UX Considerations

### Design Decisions
1. **Input Field Type:** `TextInputType.numberWithOptions(decimal: true)` to allow decimal values (e.g., 25.5 km)
2. **Validation:** 
   - Required field (cannot be empty)
   - Must be a positive number
   - Allows decimal values
3. **Placement:** Below the "Region / Address" field in the form
4. **Label:** "Round Trip Distance (KM)" with hint "e.g., 25.5"
5. **Icon:** `Icons.straighten` (measurement icon)

### User Flow
```
User clicks "Add Region"
  ↓
Dialog opens with:
  - City dropdown
  - Region/Address text field
  - Round Trip Distance (KM) text field  ← NEW
  ↓
User fills all fields
  ↓
Clicks "Save"
  ↓
Validation checks:
  - City selected ✓
  - Region not empty ✓
  - RoundtripKM is valid positive number ✓
  ↓
Zone created with roundtripKm field
```

---

## Implementation Checklist

### Phase 1: Core Models
- [ ] Update `DeliveryZone` class in `packages/core_models/lib/entities/delivery_zone.dart`
  - [ ] Add `roundtripKm` field (nullable double)
  - [ ] Update `fromMap` to handle `roundtrip_km`
  - [ ] Update `toMap` to include `roundtrip_km` (conditional)
  - [ ] Update `copyWith` to include `roundtripKm`
  - [ ] Run tests (if any)

### Phase 2: Android App
- [ ] Update `_AddRegionDialog` in `zones_page.dart`
  - [ ] Add `_roundtripKmController`
  - [ ] Add RoundtripKM TextFormField
  - [ ] Add validation
  - [ ] Update `createRegion` call
- [ ] Update `_AddRegionDialog` in `delivery_zone_selection_section.dart` (order flow)
  - [ ] Same changes as above
- [ ] Update `DeliveryZonesCubit.createRegion`
  - [ ] Add `roundtripKm` parameter
  - [ ] Pass to `DeliveryZone` constructor
- [ ] Update `CreateOrderCubit.addPendingRegion`
  - [ ] Add `roundtripKm` parameter
  - [ ] Pass to `DeliveryZone` constructor

### Phase 3: Web App
- [ ] Update `_AddRegionDialog` in `zones_view.dart`
  - [ ] Add `_roundtripKmController`
  - [ ] Add RoundtripKM TextFormField with web styling
  - [ ] Add validation
  - [ ] Update `createRegion` call
- [ ] Update `_AddRegionDialog` in `delivery_zone_selection_section.dart` (order flow)
  - [ ] Same changes as above
- [ ] Update `DeliveryZonesCubit.createRegion` (web)
  - [ ] Add `roundtripKm` parameter
  - [ ] Pass to `DeliveryZone` constructor

### Phase 4: Testing & Verification
- [ ] Test creating new region in Android app
- [ ] Test creating new region in Web app
- [ ] Test creating pending region in order flow (Android)
- [ ] Test creating pending region in order flow (Web)
- [ ] Verify existing zones still load correctly (null roundtripKm)
- [ ] Verify Firestore documents have correct `roundtrip_km` field

---

## Questions for Discussion

1. **Field Name:** Should we use `roundtripKm` (camelCase) in Dart and `roundtrip_km` (snake_case) in Firestore? ✅ **YES** (follows existing conventions)

2. **Required vs Optional:** Should `roundtripKm` be required for new regions? ✅ **YES** (user requirement: "Only Ask when new region created")

3. **Data Type:** Should we use `double` or `int`? ✅ **double** (allows decimal values like 25.5 km)

4. **Display:** Should we show `roundtripKm` in the zones list or detail view? ⚠️ **NOT IN SCOPE** (only collection required, display can be added later)

5. **Editing:** Should users be able to edit `roundtripKm` for existing zones? ⚠️ **NOT IN SCOPE** (can be added later as enhancement)

6. **Unit:** Should we hardcode "KM" or make it configurable? ✅ **Hardcode KM** (standard unit in India)

---

## Future Enhancements (Out of Scope)

- Display `roundtripKm` in zones list/detail views
- Edit `roundtripKm` for existing zones
- Use `roundtripKm` in trip cost calculations
- Use `roundtripKm` in route optimization
- Validation rules (e.g., max distance)

---

## Summary

This proposal adds a `RoundtripKM` field to the DeliveryZone entity:
- ✅ **Database:** New nullable field `roundtrip_km` in Firestore
- ✅ **Models:** Updated `DeliveryZone` class in `core_models`
- ✅ **Android:** Updated create region dialogs and cubits
- ✅ **Web:** Updated create region dialogs and cubits
- ✅ **Backward Compatible:** Existing zones have `null` roundtripKm
- ✅ **Validation:** Required positive number for new regions

The implementation is straightforward and follows existing patterns in the codebase.

