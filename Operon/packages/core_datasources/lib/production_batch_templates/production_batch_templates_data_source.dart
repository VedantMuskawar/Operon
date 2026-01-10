import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class ProductionBatchTemplatesDataSource {
  ProductionBatchTemplatesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _getBatchesRef(String organizationId) =>
      _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTION_BATCHES');

  Future<String> createBatchTemplate(ProductionBatchTemplate template) async {
    try {
      final templateJson = template.toJson();
      templateJson['createdAt'] = FieldValue.serverTimestamp();
      templateJson['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = _getBatchesRef(template.organizationId).doc();
      final batchId = docRef.id;
      templateJson['batchId'] = batchId;

      await docRef.set(templateJson);
      return batchId;
    } catch (e) {
      throw Exception('Failed to create production batch template: $e');
    }
  }

  Future<List<ProductionBatchTemplate>> fetchBatchTemplates(
    String organizationId,
  ) async {
    try {
      final snapshot = await _getBatchesRef(organizationId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProductionBatchTemplate.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch production batch templates: $e');
    }
  }

  Stream<List<ProductionBatchTemplate>> watchBatchTemplates(
    String organizationId,
  ) {
    return _getBatchesRef(organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductionBatchTemplate.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  Future<ProductionBatchTemplate?> getBatchTemplate(
    String organizationId,
    String batchId,
  ) async {
    try {
      final doc = await _getBatchesRef(organizationId).doc(batchId).get();
      if (!doc.exists) {
        return null;
      }
      return ProductionBatchTemplate.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get production batch template: $e');
    }
  }

  Future<void> updateBatchTemplate(
    String organizationId,
    String batchId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _getBatchesRef(organizationId).doc(batchId).update(updates);
    } catch (e) {
      throw Exception('Failed to update production batch template: $e');
    }
  }

  Future<void> deleteBatchTemplate(
    String organizationId,
    String batchId,
  ) async {
    try {
      await _getBatchesRef(organizationId).doc(batchId).delete();
    } catch (e) {
      throw Exception('Failed to delete production batch template: $e');
    }
  }
}

