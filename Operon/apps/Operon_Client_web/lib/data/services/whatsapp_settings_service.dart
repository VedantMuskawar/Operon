import 'package:cloud_firestore/cloud_firestore.dart';

class WhatsappSettingsService {
  WhatsappSettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'WHATSAPP_SETTINGS';

  Future<bool> fetchEnabled(String orgId) async {
    if (orgId.isEmpty) return false;
    try {
      final doc = await _firestore.collection(_collection).doc(orgId).get();
      final data = doc.data();
      return (data?['enabled'] as bool?) ?? false;
    } catch (_) {
      throw Exception('Unable to load WhatsApp settings.');
    }
  }

  Future<void> setEnabled(String orgId, bool enabled) async {
    if (orgId.isEmpty) return;
    try {
      await _firestore
          .collection(_collection)
          .doc(orgId)
          .set({'enabled': enabled}, SetOptions(merge: true));
    } catch (_) {
      throw Exception('Unable to update WhatsApp settings.');
    }
  }
}
