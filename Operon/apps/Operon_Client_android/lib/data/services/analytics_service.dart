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

  /// Fetch multiple analytics documents by their IDs
  Future<List<Map<String, dynamic>>> fetchAnalyticsDocuments(List<String> documentIds) async {
    try {
      final futures = documentIds.map((docId) => fetchAnalyticsDocument(docId));
      final results = await Future.wait(futures);
      return results.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      throw Exception('Failed to fetch analytics documents: $e');
    }
  }
}

