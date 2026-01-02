import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class ExpenseSubCategoriesDataSource {
  ExpenseSubCategoriesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _subCategoriesRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('EXPENSE_SUB_CATEGORIES');
  }

  /// Fetch all sub-categories for an organization
  Future<List<ExpenseSubCategory>> fetchSubCategories(String organizationId) async {
    try {
      final snapshot = await _subCategoriesRef(organizationId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) => ExpenseSubCategory.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // If index is not ready, fetch without orderBy and sort in memory
      final snapshot = await _subCategoriesRef(organizationId)
          .where('isActive', isEqualTo: true)
          .get();
      final categories = snapshot.docs
          .map((doc) => ExpenseSubCategory.fromJson(doc.data(), doc.id))
          .toList();
      categories.sort((a, b) {
        final orderCompare = a.order.compareTo(b.order);
        if (orderCompare != 0) return orderCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return categories;
    }
  }

  /// Stream of sub-categories for real-time updates
  Stream<List<ExpenseSubCategory>> watchSubCategories(String organizationId) {
    return _subCategoriesRef(organizationId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => ExpenseSubCategory.fromJson(doc.data(), doc.id))
              .toList();
          categories.sort((a, b) {
            final orderCompare = a.order.compareTo(b.order);
            if (orderCompare != 0) return orderCompare;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          return categories;
        });
  }

  /// Get a single sub-category by ID
  Future<ExpenseSubCategory?> getSubCategory(
    String organizationId,
    String subCategoryId,
  ) async {
    final doc = await _subCategoriesRef(organizationId).doc(subCategoryId).get();
    if (!doc.exists) return null;
    return ExpenseSubCategory.fromJson(doc.data()!, doc.id);
  }

  /// Create a new sub-category
  Future<String> createSubCategory(
    String organizationId,
    ExpenseSubCategory category,
  ) async {
    final docRef = _subCategoriesRef(organizationId).doc();
    final categoryData = category.copyWith(id: docRef.id).toJson();
    categoryData['subCategoryId'] = docRef.id;
    await docRef.set(categoryData);
    return docRef.id;
  }

  /// Update an existing sub-category
  Future<void> updateSubCategory(
    String organizationId,
    ExpenseSubCategory category,
  ) async {
    final categoryData = category.toJson();
    categoryData['updatedAt'] = FieldValue.serverTimestamp();
    await _subCategoriesRef(organizationId)
        .doc(category.id)
        .update(categoryData);
  }

  /// Delete a sub-category (soft delete by setting isActive=false)
  Future<void> deleteSubCategory(
    String organizationId,
    String subCategoryId,
  ) async {
    await _subCategoriesRef(organizationId).doc(subCategoryId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reorder sub-categories (update order field)
  Future<void> reorderSubCategories(
    String organizationId,
    Map<String, int> orderMap, // Map of subCategoryId -> new order
  ) async {
    final batch = _firestore.batch();
    for (final entry in orderMap.entries) {
      final ref = _subCategoriesRef(organizationId).doc(entry.key);
      batch.update(ref, {
        'order': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

