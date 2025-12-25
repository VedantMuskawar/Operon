import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/organization_product.dart';

class ProductsDataSource {
  ProductsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _productsRef(String orgId) {
    return _firestore.collection('ORGANIZATIONS').doc(orgId).collection('PRODUCTS');
  }

  Future<List<OrganizationProduct>> fetchProducts(String orgId) async {
    final snapshot = await _productsRef(orgId).orderBy('name').get();
    return snapshot.docs
        .map((doc) => OrganizationProduct.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createProduct(String orgId, OrganizationProduct product) {
    return _productsRef(orgId).doc(product.id).set({
      ...product.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(String orgId, OrganizationProduct product) {
    return _productsRef(orgId).doc(product.id).update({
      ...product.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String orgId, String productId) {
    return _productsRef(orgId).doc(productId).delete();
  }
}
