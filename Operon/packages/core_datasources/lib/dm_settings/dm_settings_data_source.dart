import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class DmSettingsDataSource {
  DmSettingsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _dmSettingsRef(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('DM_SETTINGS')
        .doc('settings');
  }

  Future<DmSettings?> fetchDmSettings(String organizationId) async {
    try {
      final doc = await _dmSettingsRef(organizationId).get();
      if (!doc.exists) {
        return null;
      }
      final data = doc.data()!;
      return DmSettings.fromJson({
        ...data,
        'organizationId': organizationId,
      });
    } catch (e) {
      throw Exception('Failed to fetch DM settings: $e');
    }
  }

  Future<void> updateDmSettings(String organizationId, DmSettings settings) async {
    try {
      final settingsJson = settings.toJson();
      settingsJson['updatedAt'] = FieldValue.serverTimestamp();
      await _dmSettingsRef(organizationId).set(settingsJson, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update DM settings: $e');
    }
  }

  Stream<DmSettings?> watchDmSettings(String organizationId) {
    return _dmSettingsRef(organizationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data()!;
      return DmSettings.fromJson({
        ...data,
        'organizationId': organizationId,
      });
    });
  }
}
