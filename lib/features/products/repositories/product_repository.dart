import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductRepository {
  final FirebaseFirestore _firestore;

  ProductRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get products stream for a specific organization
  Stream<List<Product>> getProductsStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PRODUCTS')
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      // Sort products by productName for consistent ordering
      products.sort((a, b) => a.productName.compareTo(b.productName));
      return products;
    });
  }

  // Get products once (non-stream)
  Future<List<Product>> getProducts(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      // Sort products by productName for consistent ordering
      products.sort((a, b) => a.productName.compareTo(b.productName));
      return products;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  // Add a new product
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

  // Update an existing product
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

  // Delete a product
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

  // Search products by query
  Stream<List<Product>> searchProducts(
    String organizationId,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();

    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PRODUCTS')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .where((product) {
        return product.productId.toLowerCase().contains(lowerQuery) ||
            product.productName.toLowerCase().contains(lowerQuery) ||
            (product.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  // Get a single product by ID
  Future<Product?> getProductById(
    String organizationId,
    String productId,
  ) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .doc(productId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Product.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  // Check if product ID already exists for an organization
  Future<bool> productIdExists(String organizationId, String productId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check product ID: $e');
    }
  }

  // Get product by custom productId (not Firestore doc ID)
  Future<Product?> getProductByCustomId(
    String organizationId,
    String customProductId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCTS')
          .where('productId', isEqualTo: customProductId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Product.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Failed to fetch product by custom ID: $e');
    }
  }
}

