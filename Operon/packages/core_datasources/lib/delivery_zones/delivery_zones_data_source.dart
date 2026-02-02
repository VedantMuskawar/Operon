import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class DeliveryZonesDataSource {
  DeliveryZonesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _zonesCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('DELIVERY_ZONES');
  }

  CollectionReference<Map<String, dynamic>> _citiesCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('DELIVERY_CITIES');
  }

  Future<List<DeliveryZone>> fetchZones(String orgId) async {
    try {
      final snapshot = await _zonesCollection(orgId)
          .orderBy('city_name')
          .orderBy('region')
          .limit(500)
          .get();
      return snapshot.docs
          .map((doc) {
            final zone = DeliveryZone.fromMap(doc.data(), doc.id);
            return zone.copyWith(organizationId: orgId);
          })
          .toList();
    } catch (e) {
      // If index error, try without orderBy
      if (e.toString().contains('index')) {
        final snapshot = await _zonesCollection(orgId).limit(500).get();
        final zones = snapshot.docs
            .map((doc) {
              final zone = DeliveryZone.fromMap(doc.data(), doc.id);
              return zone.copyWith(organizationId: orgId);
            })
            .toList();
        // Sort manually
        zones.sort((a, b) {
          final cityCompare = a.cityName.compareTo(b.cityName);
          if (cityCompare != 0) return cityCompare;
          return a.region.compareTo(b.region);
        });
        return zones;
      }
      rethrow;
    }
  }

  Future<List<DeliveryCity>> fetchCities(String orgId) async {
    final snapshot = await _citiesCollection(orgId).orderBy('name').limit(500).get();
    return snapshot.docs
        .map((doc) => DeliveryCity.fromMap(doc.data(), doc.id))
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

  Future<String> createZone(String orgId, DeliveryZone zone) async {
    final doc = _zonesCollection(orgId).doc();
    await doc.set({
      ...zone.toMap(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateZone(String orgId, DeliveryZone zone) {
    return _zonesCollection(orgId).doc(zone.id).update({
      ...zone.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteZone(String orgId, String zoneId) async {
    await _zonesCollection(orgId).doc(zoneId).delete();
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
    final zoneRef = _zonesCollection(orgId).doc(zoneId);
    return zoneRef.update({
      'prices.$productId': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createCity({
    required String orgId,
    required String cityName,
  }) {
    final doc = _citiesCollection(orgId).doc();
    return doc.set({
      'name': cityName,
      'created_at': FieldValue.serverTimestamp(),
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

  Future<void> deleteCity({
    required String orgId,
    required String cityId,
    required String cityName,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_citiesCollection(orgId).doc(cityId));

    final zonesSnapshot = await _zonesCollection(orgId)
        .where('city_id', isEqualTo: cityId)
        .get();
    
    for (final doc in zonesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }
}

