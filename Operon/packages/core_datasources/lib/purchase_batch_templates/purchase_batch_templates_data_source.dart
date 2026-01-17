import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class PurchaseBatchTemplatesDataSource {
  PurchaseBatchTemplatesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _getTemplatesRef(String organizationId) =>
      _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PURCHASE_BATCH_TEMPLATES');

  Future<String> createTemplate(PurchaseBatchTemplate template) async {
    try {
      final templateJson = template.toJson();
      templateJson['createdAt'] = FieldValue.serverTimestamp();
      templateJson['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = _getTemplatesRef(template.organizationId).doc();
      final templateId = docRef.id;
      templateJson['templateId'] = templateId;

      await docRef.set(templateJson);
      return templateId;
    } catch (e) {
      throw Exception('Failed to create purchase batch template: $e');
    }
  }

  Future<List<PurchaseBatchTemplate>> fetchTemplates(
    String organizationId,
  ) async {
    try {
      final snapshot = await _getTemplatesRef(organizationId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PurchaseBatchTemplate.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch purchase batch templates: $e');
    }
  }

  Stream<List<PurchaseBatchTemplate>> watchTemplates(
    String organizationId,
  ) {
    return _getTemplatesRef(organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PurchaseBatchTemplate.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  Future<PurchaseBatchTemplate?> getTemplate(
    String organizationId,
    String templateId,
  ) async {
    try {
      final doc = await _getTemplatesRef(organizationId).doc(templateId).get();
      if (!doc.exists) {
        return null;
      }
      return PurchaseBatchTemplate.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get purchase batch template: $e');
    }
  }

  Future<void> updateTemplate(
    String organizationId,
    String templateId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _getTemplatesRef(organizationId).doc(templateId).update(updates);
    } catch (e) {
      throw Exception('Failed to update purchase batch template: $e');
    }
  }

  Future<void> deleteTemplate(
    String organizationId,
    String templateId,
  ) async {
    try {
      await _getTemplatesRef(organizationId).doc(templateId).delete();
    } catch (e) {
      throw Exception('Failed to delete purchase batch template: $e');
    }
  }
}
