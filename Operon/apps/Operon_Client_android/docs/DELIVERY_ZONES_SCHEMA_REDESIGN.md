# Delivery Zones Database Schema Redesign

## Current Schema Analysis

### Current Structure
```
ORGANIZATIONS/{orgId}/
  ├── DELIVERY_CITIES/{cityId}
  │   └── { name: string, created_at: timestamp }
  │
  └── DELIVERY_ZONES/{zoneId}
      ├── { city: string, region: string, is_active: bool }
      └── PRICES/{productId}
          └── { product_id, product_name, unit_price, deliverable, updated_at }
```

### Current Issues

1. **Nested Subcollection for Prices**
   - Requires multiple queries to fetch zone + prices
   - Cannot query prices across zones efficiently
   - More complex batch operations

2. **City Reference by Name (String)**
   - Zones store city as a string name, not ID
   - Renaming a city requires batch update of all zones
   - Risk of data inconsistency if city name changes

3. **No Direct Price Queries**
   - Cannot easily query "all zones with price > X for product Y"
   - Cannot efficiently get "cheapest zone for product X"

4. **Organization Nesting**
   - All zones nested under organization
   - Similar to PENDING_ORDERS, could be standalone for better scalability

5. **Redundant Data**
   - `product_name` stored in every price document (denormalized)
   - `product_id` and `product_id` both exist (naming inconsistency)

---

## Proposed Schema Redesign

### Option 1: Flattened Prices (Recommended)

**Structure:**
```
ORGANIZATIONS/{orgId}/
  ├── DELIVERY_CITIES/{cityId}
  │   └── { name: string, created_at: timestamp, updated_at: timestamp }
  │
  └── DELIVERY_ZONES/{zoneId}
      └── {
            city_id: string,              // Reference to city ID
            city_name: string,             // Denormalized for queries
            region: string,
            is_active: bool,
            prices: {                     // Flattened map of prices
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

**Benefits:**
- ✅ Single query to get zone + all prices
- ✅ City reference by ID (normalized)
- ✅ City name denormalized for easy queries
- ✅ Nested collection (organized under organization)
- ✅ No price subcollections (simpler queries)
- ✅ Prices as map (easy to update individual products)

**Trade-offs:**
- ⚠️ Zone document size limit (1MB) - but prices map should be small
- ⚠️ Need to update city_name when city renamed (but only in zones, not prices)

---

### Option 2: Separate Prices Collection

**Structure:**
```
ORGANIZATIONS/{orgId}/
  └── DELIVERY_CITIES/{cityId}
      └── { name: string, created_at: timestamp, updated_at: timestamp }

DELIVERY_ZONES/{zoneId}  (Standalone collection)
  └── {
        organization_id: string,
        city_id: string,
        city_name: string,
        region: string,
        is_active: bool,
        created_at: timestamp,
        updated_at: timestamp
      }

ZONE_PRICES/{priceId}  (Standalone collection)
  └── {
        organization_id: string,
        zone_id: string,
        product_id: string,
        unit_price: number,
        deliverable: boolean,
        updated_at: timestamp
      }
```

**Benefits:**
- ✅ Can query prices across all zones efficiently
- ✅ No document size concerns
- ✅ Easy to add indexes on price queries
- ✅ Can query "all zones with price > X"

**Trade-offs:**
- ⚠️ Requires two queries (zone + prices)
- ⚠️ More complex batch operations
- ⚠️ Need composite indexes for queries

---

### Option 3: Hybrid (Zones with Embedded Prices + Separate Index)

**Structure:**
```
DELIVERY_ZONES/{zoneId}
  └── {
        organization_id: string,
        city_id: string,
        city_name: string,
        region: string,
        is_active: bool,
        prices: { [productId]: { unit_price, deliverable, updated_at } },
        created_at: timestamp,
        updated_at: timestamp
      }

ZONE_PRICE_INDEX/{indexId}  (Optional, for advanced queries)
  └── {
        organization_id: string,
        zone_id: string,
        product_id: string,
        unit_price: number,
        // Denormalized for querying
      }
```

**Benefits:**
- ✅ Fast reads (prices in zone document)
- ✅ Can query prices separately if needed
- ✅ Best of both worlds

**Trade-offs:**
- ⚠️ Data duplication (prices in two places)
- ⚠️ Need to keep in sync
- ⚠️ More complex updates

---

## Recommended: Option 1 (Flattened Prices)

### Detailed Schema

#### Collection: `DELIVERY_CITIES`
**Location:** `ORGANIZATIONS/{orgId}/DELIVERY_CITIES/{cityId}`

**Document Structure:**
```typescript
{
  name: string;                    // City name (e.g., "Mumbai")
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**Indexes:**
- `name` (ascending)

---

#### Collection: `DELIVERY_ZONES`
**Location:** `ORGANIZATIONS/{orgId}/DELIVERY_ZONES/{zoneId}` (Nested collection)

**Document Structure:**
```typescript
{
  // Organization Reference
  organization_id: string;          // Reference to ORGANIZATIONS/{orgId}
  
  // Location
  city_id: string;                  // Reference to DELIVERY_CITIES/{cityId}
  city_name: string;                // Denormalized city name (for queries)
  region: string;                   // Region/Address (e.g., "Andheri East")
  
  // Status
  is_active: boolean;               // Default: true
  
  // Product Prices (Flattened Map)
  prices: {
    [productId: string]: {
      unit_price: number;           // Price per unit
      deliverable: boolean;         // Can deliver this product here
      updated_at: Timestamp;        // Last price update
    }
  };
  
  // Metadata
  created_at: Timestamp;
  updated_at: Timestamp;
}
```

**Example Document:**
```json
{
  "city_id": "city456",
  "city_name": "Mumbai",
  "region": "Andheri East",
  "is_active": true,
  "prices": {
    "prod789": {
      "unit_price": 5.2,
      "deliverable": true,
      "updated_at": "2024-11-30T10:25:13Z"
    },
    "prod790": {
      "unit_price": 6.5,
      "deliverable": true,
      "updated_at": "2024-11-30T10:25:13Z"
    }
  },
  "created_at": "2024-11-01T08:00:00Z",
  "updated_at": "2024-11-30T10:25:13Z"
}
```

**Indexes:**
- `city_name` (ascending) + `region` (ascending)
- `is_active` (ascending)
- `city_id` (ascending)

---

## Migration Strategy

### Step 1: Create New Schema
1. Create new `DELIVERY_ZONES` standalone collection
2. Keep old schema during migration period

### Step 2: Data Migration Script
```typescript
// Pseudo-code for migration
async function migrateDeliveryZones(orgId: string) {
  const oldZones = await firestore
    .collection('ORGANIZATIONS')
    .doc(orgId)
    .collection('DELIVERY_ZONES')
    .get();
  
  const batch = firestore.batch();
  
  for (const oldZone of oldZones.docs) {
    const zoneData = oldZone.data();
    
    // Fetch prices from subcollection
    const pricesSnapshot = await oldZone.ref
      .collection('PRICES')
      .get();
    
    // Build prices map
    const pricesMap: Record<string, any> = {};
    for (const priceDoc of pricesSnapshot.docs) {
      const priceData = priceDoc.data();
      pricesMap[priceData.product_id] = {
        unit_price: priceData.unit_price,
        deliverable: priceData.deliverable ?? true,
        updated_at: priceData.updated_at || FieldValue.serverTimestamp(),
      };
    }
    
    // Get city ID from city name
    const citySnapshot = await firestore
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('DELIVERY_CITIES')
      .where('name', '==', zoneData.city)
      .limit(1)
      .get();
    
    const cityId = citySnapshot.docs[0]?.id || '';
    const cityName = zoneData.city;
    
    // Create new zone document
    const newZoneRef = firestore
      .collection('ORGANIZATIONS')
      .doc(orgId)
      .collection('DELIVERY_ZONES')
      .doc();
    
    batch.set(newZoneRef, {
      city_id: cityId,
      city_name: cityName,
      region: zoneData.region,
      is_active: zoneData.is_active ?? true,
      prices: pricesMap,
      created_at: zoneData.created_at || FieldValue.serverTimestamp(),
      updated_at: zoneData.updated_at || FieldValue.serverTimestamp(),
    });
  }
  
  await batch.commit();
}
```

### Step 3: Update Application Code
1. Update `DeliveryZone` entity to include `cityId` and `prices` map
2. Update `DeliveryZonesDataSource` to use new schema
3. Update all queries and mutations

### Step 4: Verify & Cleanup
1. Verify all zones migrated correctly
2. Test order creation with new schema
3. Delete old schema after verification period

---

## Code Changes Required

### 1. Update `DeliveryZone` Entity

```dart
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.organizationId,
    required this.cityId,
    required this.cityName,
    required this.region,
    required this.prices,  // Map<String, DeliveryZonePrice>
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String cityId;
  final String cityName;
  final String region;
  final Map<String, DeliveryZonePrice> prices;  // Changed from subcollection
  final bool isActive;

  factory DeliveryZone.fromMap(Map<String, dynamic> map, String id) {
    final pricesMap = map['prices'] as Map<String, dynamic>? ?? {};
    final prices = pricesMap.map(
      (key, value) => MapEntry(
        key,
        DeliveryZonePrice.fromMap({
          ...value as Map<String, dynamic>,
          'product_id': key,
        }),
      ),
    );

    return DeliveryZone(
      id: id,
      organizationId: map['organization_id'] as String? ?? '',
      cityId: map['city_id'] as String? ?? '',
      cityName: map['city_name'] as String? ?? '',
      region: map['region'] as String? ?? '',
      prices: prices,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organization_id': organizationId,
      'city_id': cityId,
      'city_name': cityName,
      'region': region,
      'is_active': isActive,
      'prices': prices.map(
        (key, value) => MapEntry(key, {
          'unit_price': value.unitPrice,
          'deliverable': value.deliverable,
          'updated_at': FieldValue.serverTimestamp(),
        }),
      ),
    };
  }
}
```

### 2. Update `DeliveryZonesDataSource`

```dart
class DeliveryZonesDataSource {
  // ... existing code ...

  CollectionReference<Map<String, dynamic>> _zonesCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('DELIVERY_ZONES');
  }

  Future<List<DeliveryZone>> fetchZones(String orgId) async {
    final snapshot = await _zonesCollection(orgId)
        .orderBy('city_name')
        .orderBy('region')
        .get();
    
    return snapshot.docs
        .map((doc) => DeliveryZone.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<DeliveryZonePrice>> fetchZonePrices(
    String orgId,
    String zoneId,
  ) async {
    final zoneDoc = await _zonesCollection(orgId).doc(zoneId).get();
    if (!zoneDoc.exists) return [];
    
    final zoneData = zoneDoc.data()!;
    final pricesMap = zoneData['prices'] as Map<String, dynamic>? ?? {};
    
    return pricesMap.entries.map((entry) {
      return DeliveryZonePrice.fromMap({
        ...entry.value as Map<String, dynamic>,
        'product_id': entry.key,
      });
    }).toList();
  }

  Future<void> createZone(String orgId, DeliveryZone zone) {
    final doc = _zonesCollection(orgId).doc(zone.id);
    return doc.set({
      ...zone.toMap(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> upsertPrice({
    required String orgId,
    required String zoneId,
    required DeliveryZonePrice price,
  }) {
    final zoneRef = _zonesCollection(orgId).doc(zoneId);
    return zoneRef.update({
      'prices.${price.productId}': {
        'unit_price': price.unitPrice,
        'deliverable': price.deliverable,
        'updated_at': FieldValue.serverTimestamp(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePrice({
    required String orgId,
    required String zoneId,
    required String productId,
  }) {
    final zoneRef = _zonesCollection().doc(zoneId);
    return zoneRef.update({
      'prices.$productId': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameCity({
    required String orgId,
    required String cityId,
    required String oldName,
    required String newName,
  }) async {
    final batch = _firestore.batch();
    
    // Update city document
    final cityDoc = _citiesCollection(orgId).doc(cityId);
    batch.update(cityDoc, {
      'name': newName,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update all zones with this city
    final zonesSnapshot = await _zonesCollection(orgId)
        .where('city_id', isEqualTo: cityId)
        .get();
    
    for (final doc in zonesSnapshot.docs) {
      batch.update(doc.reference, {
        'city_name': newName,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }
}
```

---

## Benefits of New Schema

1. **Single Query Performance**
   - Fetch zone + all prices in one query
   - No subcollection queries needed

2. **Better Data Integrity**
   - City referenced by ID (normalized)
   - City name denormalized for queries only

3. **Simpler Updates**
   - Update single price: `prices.{productId}.unit_price`
   - No subcollection management

4. **Scalability**
   - Standalone collection (like PENDING_ORDERS)
   - Better for cross-organization analytics

5. **Consistent Naming**
   - All fields use snake_case
   - No duplicate fields (productId vs product_id)

6. **Atomic Operations**
   - Easier batch writes
   - Update zone + prices atomically

---

## Considerations

### Document Size Limits
- Firestore document limit: 1MB
- For 100 products with prices: ~10-15KB per zone
- Well within limits ✅

### Query Performance
- Indexes on `organization_id`, `city_name`, `region`
- Single query for zone + prices
- Faster than current subcollection approach ✅

### Migration Complexity
- Need migration script
- Dual-write period (old + new schema)
- Verification before cleanup

---

## Next Steps

1. **Review & Approve** this schema design
2. **Create Migration Script** for existing data
3. **Update Entity Models** (DeliveryZone, DeliveryZonePrice)
4. **Update Data Source** (DeliveryZonesDataSource)
5. **Update Repository & Cubit** (if needed)
6. **Test Migration** on staging
7. **Deploy & Migrate** production data
8. **Update Documentation** (FIREBASE_SCHEMA_AND_FUNCTIONS.md)

