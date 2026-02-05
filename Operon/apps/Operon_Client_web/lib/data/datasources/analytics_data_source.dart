import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsDataSource {
  AnalyticsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'ANALYTICS';

  Future<Map<String, dynamic>?> fetchAnalyticsDocument(String documentId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(documentId).get();
      if (!doc.exists) {
        return null;
      }
      return doc.data();
    } catch (e) {
      throw Exception('Failed to fetch analytics document: $e');
    }
  }

  Stream<Map<String, dynamic>?> watchAnalyticsDocument(String documentId) {
    return _firestore
        .collection(_collection)
        .doc(documentId)
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
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





