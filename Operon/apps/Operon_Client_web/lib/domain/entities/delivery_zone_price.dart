class DeliveryZonePrice {
  const DeliveryZonePrice({
    required this.productId,
    required this.productName,
    required this.deliverable,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final bool deliverable;
  final double unitPrice;

  factory DeliveryZonePrice.fromMap(Map<String, dynamic> map) {
    return DeliveryZonePrice(
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      deliverable: map['deliverable'] as bool? ?? false,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'deliverable': deliverable,
      'unit_price': unitPrice,
      'updated_at': DateTime.now(),
    };
  }

  DeliveryZonePrice copyWith({
    String? productId,
    String? productName,
    bool? deliverable,
    double? unitPrice,
  }) {
    return DeliveryZonePrice(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      deliverable: deliverable ?? this.deliverable,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

