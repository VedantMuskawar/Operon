import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class RawMaterialsDataSource {
  RawMaterialsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _rawMaterialsRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('RAW_MATERIALS');
  }

  CollectionReference<Map<String, dynamic>> _stockHistoryRef(
    String orgId,
    String materialId,
  ) {
    return _rawMaterialsRef(orgId).doc(materialId).collection('STOCK_HISTORY');
  }

  Future<List<RawMaterial>> fetchRawMaterials(String orgId) async {
    final snapshot = await _rawMaterialsRef(orgId).orderBy('name').get();
    return snapshot.docs
        .map((doc) => RawMaterial.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createRawMaterial(String orgId, RawMaterial material) {
    return _rawMaterialsRef(orgId).doc(material.id).set({
      ...material.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRawMaterial(String orgId, RawMaterial material) {
    return _rawMaterialsRef(orgId).doc(material.id).update({
      ...material.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRawMaterial(String orgId, String materialId) {
    return _rawMaterialsRef(orgId).doc(materialId).delete();
  }

  Future<void> addStockHistoryEntry(
    String orgId,
    String materialId,
    StockHistoryEntry entry,
  ) {
    return _stockHistoryRef(orgId, materialId).doc(entry.id).set({
      ...entry.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<StockHistoryEntry>> fetchStockHistory(
    String orgId,
    String materialId, {
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _stockHistoryRef(orgId, materialId)
        .orderBy('createdAt', descending: true);
    
    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => StockHistoryEntry.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateMaterialStock(
    String orgId,
    String materialId,
    int newStock,
  ) {
    return _rawMaterialsRef(orgId).doc(materialId).update({
      'stock': newStock,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

