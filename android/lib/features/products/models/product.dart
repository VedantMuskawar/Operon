import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String? id;
  final String productId;
  final String productName;
  final String? description;
  final double unitPrice;
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
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Debug: Print all available fields
    print('Product document ${doc.id} fields: ${data.keys.toList()}');

    try {
      return Product(
        id: doc.id,
        productId: data['productId'] ?? data['product_id'] ?? '',
        productName: data['productName'] ?? data['product_name'] ?? data['name'] ?? '',
        description: data['description'],
        unitPrice: ((data['unitPrice'] ?? data['unit_price'] ?? data['price'] ?? 0) as num).toDouble(),
        status: data['status'] ?? 'Active',
        createdAt: (data['createdAt'] ?? data['created_at']) != null
            ? ((data['createdAt'] ?? data['created_at']) as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: (data['updatedAt'] ?? data['updated_at']) != null
            ? ((data['updatedAt'] ?? data['updated_at']) as Timestamp).toDate()
            : DateTime.now(),
        createdBy: data['createdBy'] ?? data['created_by'],
        updatedBy: data['updatedBy'] ?? data['updated_by'],
      );
    } catch (e, stackTrace) {
      print('Error creating Product from document ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      print('Document data: $data');
      rethrow;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'productName': productName,
      if (description != null) 'description': description,
      'unitPrice': unitPrice,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  Product copyWith({
    String? productId,
    String? productName,
    String? description,
    double? unitPrice,
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
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  bool get isActive => status == 'Active';
}

class ProductStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

