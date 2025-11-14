import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String productId;
  final String productName;
  final String? description;
  final double unitPrice;
  final double gstRate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Product({
    this.id,
    required this.productId,
    required this.productName,
    this.description,
    required this.unitPrice,
    this.gstRate = 0,
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create Product from Firestore document
  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Product(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      description: data['description'],
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      gstRate: (data['gstRate'] ?? 0).toDouble(),
      status: data['status'] ?? 'Active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert Product to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      if (description != null) 'description': description,
      'unitPrice': unitPrice,
      'gstRate': gstRate,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of Product with updated fields
  Product copyWith({
    String? productId,
    String? productName,
    String? description,
    double? unitPrice,
    double? gstRate,
    String? status,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return Product(
      id: id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      gstRate: gstRate ?? this.gstRate,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if product is active
  bool get isActive => status == 'Active';

  @override
  String toString() {
    return 'Product(id: $id, productId: $productId, productName: $productName, unitPrice: $unitPrice, gstRate: $gstRate, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Product status
class ProductStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

