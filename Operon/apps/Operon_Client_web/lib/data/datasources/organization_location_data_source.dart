import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class OrganizationLocationDataSource {
  OrganizationLocationDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _locationsCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('LOCATIONS');
  }

  Future<List<OrganizationLocation>> fetchLocations(String orgId) async {
    final snapshot = await _locationsCollection(orgId)
        .orderBy('is_primary', descending: true)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => OrganizationLocation.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> createLocation({
    required String orgId,
    required OrganizationLocation location,
  }) async {
    final docRef = _locationsCollection(orgId).doc();
    await docRef.set({
      ...location.toMap(),
      'organization_id': orgId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateLocation({
    required String orgId,
    required OrganizationLocation location,
  }) async {
    await _locationsCollection(orgId).doc(location.id).update({
      ...location.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLocation({
    required String orgId,
    required String locationId,
  }) async {
    await _locationsCollection(orgId).doc(locationId).delete();
  }

  Future<void> setPrimaryLocation({
    required String orgId,
    required String locationId,
  }) async {
    // First, unset all other primary locations
    final allLocations = await _locationsCollection(orgId).get();
    final batch = _firestore.batch();
    
    for (final doc in allLocations.docs) {
      if (doc.id != locationId) {
        batch.update(doc.reference, {
          'is_primary': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }
    
    // Set the selected location as primary
    batch.update(_locationsCollection(orgId).doc(locationId), {
      'is_primary': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
}
