enum ProductStatus { active, paused, archived }

class OrganizationProduct {
  const OrganizationProduct({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.gstPercent,
    required this.status,
    this.stock = 0,
    this.fixedQuantityPerTripOptions,
  });

  final String id;
  final String name;
  final double unitPrice;
  final double? gstPercent; // Optional - null if no GST
  final ProductStatus status;
  final int stock;
  final List<int>? fixedQuantityPerTripOptions; // Product-specific fixed quantities per trip

  bool get hasGst => gstPercent != null && gstPercent! > 0;

  Map<String, dynamic> toJson() {
    return {
      'productId': id,
      'name': name,
      'unitPrice': unitPrice,
      if (gstPercent != null) 'gstPercent': gstPercent,
      'status': status.name,
      'stock': stock,
      if (fixedQuantityPerTripOptions != null && fixedQuantityPerTripOptions!.isNotEmpty)
        'fixedQuantityPerTripOptions': fixedQuantityPerTripOptions,
    };
  }

  factory OrganizationProduct.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    final fixedQuantityData = json['fixedQuantityPerTripOptions'] as List<dynamic>?;
    return OrganizationProduct(
      id: json['productId'] as String? ?? docId,
      name: json['name'] as String? ?? 'Unnamed Product',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      gstPercent: (json['gstPercent'] as num?)?.toDouble(),
      status: ProductStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ProductStatus.active,
      ),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      fixedQuantityPerTripOptions: fixedQuantityData?.map((e) => (e as num).toInt()).toList(),
    );
  }

  OrganizationProduct copyWith({
    String? id,
    String? name,
    double? unitPrice,
    double? gstPercent,
    ProductStatus? status,
    int? stock,
    List<int>? fixedQuantityPerTripOptions,
  }) {
    return OrganizationProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      gstPercent: gstPercent ?? this.gstPercent,
      status: status ?? this.status,
      stock: stock ?? this.stock,
      fixedQuantityPerTripOptions:
          fixedQuantityPerTripOptions ?? this.fixedQuantityPerTripOptions,
    );
  }
}

