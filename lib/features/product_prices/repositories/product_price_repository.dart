import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_price.dart';

class ProductPriceRepository {
  final FirebaseFirestore _firestore;

  ProductPriceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ProductPrice>> getProductPricesStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PRODUCT_PRICES')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductPrice.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<ProductPrice>> getProductPrices(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .get();

      return snapshot.docs
          .map((doc) => ProductPrice.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch product prices: $e');
    }
  }

  Future<String> addProductPrice(
    String organizationId,
    ProductPrice price,
    String userId,
  ) async {
    try {
      final priceWithUser = ProductPrice(
        id: price.id,
        productId: price.productId,
        addressId: price.addressId,
        unitPrice: price.unitPrice,
        effectiveFrom: price.effectiveFrom,
        effectiveTo: price.effectiveTo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .add(priceWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add product price: $e');
    }
  }

  Future<void> updateProductPrice(
    String organizationId,
    String priceId,
    ProductPrice price,
    String userId,
  ) async {
    try {
      final priceWithUser = price.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .doc(priceId)
          .update(priceWithUser.toFirestore());
    } catch (e) {
      throw Exception('Failed to update product price: $e');
    }
  }

  Future<void> deleteProductPrice(String organizationId, String priceId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .doc(priceId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete product price: $e');
    }
  }

  Future<ProductPrice?> getProductPriceById(
    String organizationId,
    String priceId,
  ) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .doc(priceId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return ProductPrice.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch product price: $e');
    }
  }

  Future<bool> priceExistsForProductAndAddress(
    String organizationId,
    String productId,
    String addressId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PRODUCT_PRICES')
          .where('productId', isEqualTo: productId)
          .where('addressId', isEqualTo: addressId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check price existence: $e');
    }
  }
}

