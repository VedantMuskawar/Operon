import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  AnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'ANALYTICS';

  Future<Map<String, dynamic>?> fetchAnalyticsDocument(String documentId) async {
    final snapshot =
        await _firestore.collection(_collection).doc(documentId).get();
    if (!snapshot.exists) return null;
    return snapshot.data();
  }
}

