import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class AndroidProductRepository {
  final FirebaseFirestore _firestore;

  AndroidProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Product>> getProductsStream(String organizationId) {
    print('Getting products stream for orgId: $organizationId');
    try {
      return _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .snapshots()
          .map((snapshot) {
        print('Products snapshot received: ${snapshot.docs.length} documents');
        try {
          final products = <Product>[];
          for (var doc in snapshot.docs) {
            try {
              final product = Product.fromFirestore(doc);
              products.add(product);
              print('Parsed product: ${product.productName}');
            } catch (e) {
              print('Error parsing product document ${doc.id}: $e');
              print('Document data: ${doc.data()}');
            }
          }
          products.sort((a, b) => a.productName.compareTo(b.productName));
          print('Returning ${products.length} products');
          return products;
        } catch (e) {
          print('Error processing products stream: $e');
          return <Product>[];
        }
      }).handleError((error) {
        print('Error in products stream: $error');
        return <Product>[];
      });
    } catch (e) {
      print('Error creating products stream: $e');
      return Stream.value(<Product>[]);
    }
  }

  Future<String> addProduct(
    String organizationId,
    Product product,
    String userId,
  ) async {
    try {
      final productWithUser = Product(
        id: product.id,
        productId: product.productId,
        productName: product.productName,
        description: product.description,
        unitPrice: product.unitPrice,
        status: product.status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .add(productWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  Future<void> updateProduct(
    String organizationId,
    String productId,
    Product product,
    String userId,
  ) async {
    try {
      final productWithUser = product.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .doc(productId)
          .update(productWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String organizationId, String productId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .doc(productId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  /// Get all products for an organization
  Future<List<Product>> getProducts(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .where('status', isEqualTo: 'Active')
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      products.sort((a, b) => a.productName.compareTo(b.productName));
      return products;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }
}

