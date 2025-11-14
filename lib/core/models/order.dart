import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double gstRate;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.gstRate = 0,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: (data['productId'] as String?) ?? '',
      productName: (data['productName'] as String?) ?? '',
      quantity: (data['quantity'] is num)
          ? (data['quantity'] as num).toInt()
          : int.tryParse('${data['quantity']}') ?? 0,
      unitPrice: (data['unitPrice'] is num)
          ? (data['unitPrice'] as num).toDouble()
          : double.tryParse('${data['unitPrice']}') ?? 0,
      totalPrice: (data['totalPrice'] is num)
          ? (data['totalPrice'] as num).toDouble()
          : double.tryParse('${data['totalPrice']}') ?? 0,
      gstRate: (data['gstRate'] is num)
          ? (data['gstRate'] as num).toDouble()
          : double.tryParse('${data['gstRate']}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'gstRate': gstRate,
    };
  }

  OrderItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    double? gstRate,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

class OrderDeliveryAddress {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  const OrderDeliveryAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  factory OrderDeliveryAddress.fromMap(Map<String, dynamic> data) {
    return OrderDeliveryAddress(
      street: (data['street'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      state: (data['state'] as String?) ?? '',
      zipCode: (data['zipCode'] as String?) ?? '',
      country: (data['country'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }
}

class Order {
  final String id;
  final String orderId;
  final String organizationId;
  final String clientId;
  final String? clientName;
  final String? clientPhone;
  final String status;
  final List<OrderItem> items;
  final OrderDeliveryAddress deliveryAddress;
  final String region;
  final String city;
  final String? locationId;
  final double subtotal;
  final double totalAmount;
  final bool gstApplicable;
  final double gstRate;
  final int trips;
  final String paymentType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? notes;
  final int remainingTrips;
  final DateTime? lastScheduledAt;
  final String? lastScheduledBy;
  final String? lastScheduledVehicleId;

  const Order({
    required this.id,
    required this.orderId,
    required this.organizationId,
    required this.clientId,
    this.clientName,
    this.clientPhone,
    required this.status,
    required this.items,
    required this.deliveryAddress,
    required this.region,
    required this.city,
    required this.subtotal,
    required this.totalAmount,
    this.gstApplicable = false,
    this.gstRate = 0,
    required this.trips,
    required this.paymentType,
    required this.createdAt,
    required this.updatedAt,
    this.locationId,
    this.createdBy,
    this.updatedBy,
    this.notes,
    required this.remainingTrips,
    this.lastScheduledAt,
    this.lastScheduledBy,
    this.lastScheduledVehicleId,
  });

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return Order(
      id: snapshot.id,
      orderId: (data['orderId'] as String?)?.trim().isNotEmpty == true
          ? data['orderId'] as String
          : snapshot.id,
      organizationId: (data['organizationId'] as String?) ?? '',
      clientId: (data['clientId'] as String?) ?? '',
      clientName: data['clientName'] as String?,
      clientPhone: data['clientPhone'] as String?,
      status: (data['status'] as String?) ?? OrderStatus.pending,
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromMap)
          .toList(growable: false),
      deliveryAddress: data['deliveryAddress'] is Map<String, dynamic>
          ? OrderDeliveryAddress.fromMap(
              data['deliveryAddress'] as Map<String, dynamic>,
            )
          : const OrderDeliveryAddress(
              street: '',
              city: '',
              state: '',
              zipCode: '',
              country: '',
            ),
      region: (data['region'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      locationId: data['locationId'] as String?,
      subtotal: _parseDouble(data['subtotal']),
      totalAmount: _parseDouble(data['totalAmount'] ?? data['total']),
      gstApplicable: (data['gstApplicable'] as bool?) ?? false,
      gstRate: _parseDouble(data['gstRate']),
      trips: _parseInt(data['trips'], fallback: 1),
      paymentType:
          (data['paymentType'] as String?) ?? PaymentType.payOnDelivery,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      notes: data['notes'] as String?,
      remainingTrips:
          _parseInt(data['remainingTrips'], fallback: _parseInt(data['trips'], fallback: 0)),
      lastScheduledAt: _parseNullableTimestamp(data['lastScheduledAt']),
      lastScheduledBy: data['lastScheduledBy'] as String?,
      lastScheduledVehicleId: data['lastScheduledVehicleId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'organizationId': organizationId,
      'clientId': clientId,
      if (clientName != null) 'clientName': clientName,
      if (clientPhone != null) 'clientPhone': clientPhone,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'deliveryAddress': deliveryAddress.toMap(),
      'region': region,
      'city': city,
      if (locationId != null) 'locationId': locationId,
      'subtotal': subtotal,
      'totalAmount': totalAmount,
      'gstApplicable': gstApplicable,
      'gstRate': gstRate,
      'trips': trips,
      'paymentType': paymentType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (notes != null) 'notes': notes,
      'remainingTrips': remainingTrips,
      if (lastScheduledAt != null)
        'lastScheduledAt': Timestamp.fromDate(lastScheduledAt!),
      if (lastScheduledBy != null) 'lastScheduledBy': lastScheduledBy,
      if (lastScheduledVehicleId != null)
        'lastScheduledVehicleId': lastScheduledVehicleId,
    };
  }

  Order copyWith({
    String? id,
    String? orderId,
    String? organizationId,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? status,
    List<OrderItem>? items,
    OrderDeliveryAddress? deliveryAddress,
    String? region,
    String? city,
    String? locationId,
    double? subtotal,
    double? totalAmount,
    bool? gstApplicable,
    double? gstRate,
    int? trips,
    String? paymentType,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
    int? remainingTrips,
    DateTime? lastScheduledAt,
    String? lastScheduledBy,
    String? lastScheduledVehicleId,
  }) {
    return Order(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      organizationId: organizationId ?? this.organizationId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      status: status ?? this.status,
      items: items ?? this.items,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      region: region ?? this.region,
      city: city ?? this.city,
      locationId: locationId ?? this.locationId,
      subtotal: subtotal ?? this.subtotal,
      totalAmount: totalAmount ?? this.totalAmount,
      gstApplicable: gstApplicable ?? this.gstApplicable,
      gstRate: gstRate ?? this.gstRate,
      trips: trips ?? this.trips,
      paymentType: paymentType ?? this.paymentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      notes: notes ?? this.notes,
      remainingTrips: remainingTrips ?? this.remainingTrips,
      lastScheduledAt: lastScheduledAt ?? this.lastScheduledAt,
      lastScheduledBy: lastScheduledBy ?? this.lastScheduledBy,
      lastScheduledVehicleId:
          lastScheduledVehicleId ?? this.lastScheduledVehicleId,
    );
  }

  bool get isPending => status == OrderStatus.pending;
  bool get isConfirmed => status == OrderStatus.confirmed;
  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static DateTime? _parseNullableTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class OrderStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> values = [
    pending,
    confirmed,
    completed,
    cancelled,
  ];
}

class PaymentType {
  static const String payOnDelivery = 'payOnDelivery';
  static const String payLater = 'payLater';
  static const String advance = 'advance';

  static const List<String> values = [
    payOnDelivery,
    payLater,
    advance,
  ];
}

