import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class ProductionBatchesDataSource {
  ProductionBatchesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'PRODUCTION_BATCHES';

  CollectionReference<Map<String, dynamic>> get _batchesRef =>
      _firestore.collection(_collection);

  Future<String> createProductionBatch(ProductionBatch batch) async {
    try {
      final batchJson = batch.toJson();
      batchJson['createdAt'] = FieldValue.serverTimestamp();
      batchJson['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = _batchesRef.doc();
      final batchId = docRef.id;
      
      if (batchId.isEmpty) {
        throw Exception('Generated batch ID is empty');
      }
      
      await docRef.set(batchJson);
      return batchId;
    } catch (e) {
      throw Exception('Failed to create production batch: $e');
    }
  }

  Future<List<ProductionBatch>> fetchProductionBatches(
    String organizationId, {
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _batchesRef
          .where('organizationId', isEqualTo: organizationId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (methodId != null) {
        query = query.where('methodId', isEqualTo: methodId);
      }

      if (startDate != null) {
        query = query.where('batchDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        final endTimestamp = Timestamp.fromDate(
            endDate.add(const Duration(days: 1)));
        query = query.where('batchDate', isLessThan: endTimestamp);
      }

      query = query.orderBy('batchDate', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ProductionBatch.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch production batches: $e');
    }
  }

  Stream<List<ProductionBatch>> watchProductionBatches(
    String organizationId, {
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _batchesRef
        .where('organizationId', isEqualTo: organizationId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (methodId != null) {
      query = query.where('methodId', isEqualTo: methodId);
    }

    if (startDate != null) {
      query = query.where('batchDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      final endTimestamp = Timestamp.fromDate(
          endDate.add(const Duration(days: 1)));
      query = query.where('batchDate', isLessThan: endTimestamp);
    }

    query = query.orderBy('batchDate', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductionBatch.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  Future<ProductionBatch?> getProductionBatch(String batchId) async {
    try {
      final doc = await _batchesRef.doc(batchId).get();
      if (!doc.exists) {
        return null;
      }
      return ProductionBatch.fromJson(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get production batch: $e');
    }
  }

  Future<void> updateProductionBatch(
    String batchId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _batchesRef.doc(batchId).update(updates);
    } catch (e) {
      throw Exception('Failed to update production batch: $e');
    }
  }

  Future<void> deleteProductionBatch(String batchId) async {
    try {
      await _batchesRef.doc(batchId).delete();
    } catch (e) {
      throw Exception('Failed to delete production batch: $e');
    }
  }
}

