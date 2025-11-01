import 'package:cloud_firestore/cloud_firestore.dart';

class ProductPrice {
  final String? id;
  final String productId;
  final String addressId;
  final double unitPrice;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  ProductPrice({
    this.id,
    required this.productId,
    required this.addressId,
    required this.unitPrice,
    this.effectiveFrom,
    this.effectiveTo,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create ProductPrice from Firestore document
  factory ProductPrice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ProductPrice(
      id: doc.id,
      productId: data['productId'] ?? '',
      addressId: data['addressId'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      effectiveFrom: (data['effectiveFrom'] as Timestamp?)?.toDate(),
      effectiveTo: (data['effectiveTo'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert ProductPrice to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'addressId': addressId,
      'unitPrice': unitPrice,
      if (effectiveFrom != null) 'effectiveFrom': Timestamp.fromDate(effectiveFrom!),
      if (effectiveTo != null) 'effectiveTo': Timestamp.fromDate(effectiveTo!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of ProductPrice with updated fields
  ProductPrice copyWith({
    String? productId,
    String? addressId,
    double? unitPrice,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ProductPrice(
      id: id,
      productId: productId ?? this.productId,
      addressId: addressId ?? this.addressId,
      unitPrice: unitPrice ?? this.unitPrice,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if price is currently effective
  bool get isCurrentlyEffective {
    final now = DateTime.now();
    final fromValid = effectiveFrom == null || now.isAfter(effectiveFrom!);
    final toValid = effectiveTo == null || now.isBefore(effectiveTo!);
    return fromValid && toValid;
  }

  @override
  String toString() {
    return 'ProductPrice(id: $id, productId: $productId, addressId: $addressId, unitPrice: $unitPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductPrice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Extended ProductPrice with joined data for display
class ProductPriceWithDetails {
  final ProductPrice price;
  final String productName;
  final String addressName;
  final String region;

  ProductPriceWithDetails({
    required this.price,
    required this.productName,
    required this.addressName,
    required this.region,
  });
}

