import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class GeofenceDataSource {
  GeofenceDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _geofencesCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('GEOFENCES');
  }

  Future<List<Geofence>> fetchGeofences(String orgId) async {
    final snapshot = await _geofencesCollection(orgId)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Geofence.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<Geofence>> fetchActiveGeofences(String orgId) async {
    final snapshot = await _geofencesCollection(orgId)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Geofence.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<Geofence?> fetchGeofence({
    required String orgId,
    required String geofenceId,
  }) async {
    final doc = await _geofencesCollection(orgId).doc(geofenceId).get();
    if (!doc.exists) return null;
    return Geofence.fromMap(doc.data()!, doc.id);
  }

  Future<String> createGeofence({
    required String orgId,
    required Geofence geofence,
  }) async {
    final docRef = _geofencesCollection(orgId).doc();
    await docRef.set({
      ...geofence.toMap(),
      'organization_id': orgId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateGeofence({
    required String orgId,
    required Geofence geofence,
  }) async {
    await _geofencesCollection(orgId).doc(geofence.id).update({
      ...geofence.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGeofence({
    required String orgId,
    required String geofenceId,
  }) async {
    await _geofencesCollection(orgId).doc(geofenceId).delete();
  }

  Future<void> updateNotificationRecipients({
    required String orgId,
    required String geofenceId,
    required List<String> recipientIds,
  }) async {
    await _geofencesCollection(orgId).doc(geofenceId).update({
      'notification_recipient_ids': recipientIds,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleActive({
    required String orgId,
    required String geofenceId,
    required bool isActive,
  }) async {
    await _geofencesCollection(orgId).doc(geofenceId).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
