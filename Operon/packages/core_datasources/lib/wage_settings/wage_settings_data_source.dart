import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class WageSettingsDataSource {
  WageSettingsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _wageSettingsRef(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('WAGE_SETTINGS')
        .doc('settings');
  }

  Future<WageSettings?> fetchWageSettings(String organizationId) async {
    try {
      final doc = await _wageSettingsRef(organizationId).get();
      if (!doc.exists) {
        return null;
      }
      return WageSettings.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to fetch wage settings: $e');
    }
  }

  Future<void> updateWageSettings(String organizationId, WageSettings settings) async {
    try {
      final settingsJson = settings.toJson();
      settingsJson['updatedAt'] = FieldValue.serverTimestamp();
      await _wageSettingsRef(organizationId).set(settingsJson, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update wage settings: $e');
    }
  }

  Stream<WageSettings?> watchWageSettings(String organizationId) {
    return _wageSettingsRef(organizationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return WageSettings.fromJson(snapshot.data()!);
    });
  }
}

