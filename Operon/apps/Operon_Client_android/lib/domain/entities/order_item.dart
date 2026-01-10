class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.estimatedTrips,
    required this.fixedQuantityPerTrip,
    required this.unitPrice,
    this.gstPercent,
  });

  final String productId;
  final String productName;
  final int estimatedTrips; // Estimated trips (for quantity calculation only)
  final int fixedQuantityPerTrip; // Fixed quantity per trip
  final double unitPrice;
  final double? gstPercent; // Optional GST percentage

  // Calculated properties
  int get totalQuantity => estimatedTrips * fixedQuantityPerTrip;
  double get subtotal => totalQuantity * unitPrice;
  double get gstAmount => gstPercent != null
      ? subtotal * (gstPercent! / 100)
      : 0.0;
  double get total => subtotal + gstAmount;

  // Display helpers
  String get displayText =>
      '$estimatedTrips Trip${estimatedTrips > 1 ? 's' : ''} × $fixedQuantityPerTrip = $totalQuantity units';

  bool get hasGst => gstPercent != null && gstPercent! > 0;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'estimatedTrips': estimatedTrips,
      'fixedQuantityPerTrip': fixedQuantityPerTrip,
      // ❌ REMOVED: totalQuantity (calculate on-the-fly)
      'scheduledTrips': 0, // ✅ Initialize scheduledTrips counter
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'total': total,
    };
    
    // ✅ Only include GST fields if GST applies
    if (gstPercent != null && gstPercent! > 0) {
      json['gstPercent'] = gstPercent!;
      json['gstAmount'] = gstAmount;
    }
    
    return json;
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      estimatedTrips: json['estimatedTrips'] as int? ?? json['trips'] as int, // Backward compatibility
      fixedQuantityPerTrip: json['fixedQuantityPerTrip'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      gstPercent: (json['gstPercent'] as num?)?.toDouble(),
    );
  }

  OrderItem copyWith({
    String? productId,
    String? productName,
    int? estimatedTrips,
    int? fixedQuantityPerTrip,
    double? unitPrice,
    double? gstPercent,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      estimatedTrips: estimatedTrips ?? this.estimatedTrips,
      fixedQuantityPerTrip: fixedQuantityPerTrip ?? this.fixedQuantityPerTrip,
      unitPrice: unitPrice ?? this.unitPrice,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}

