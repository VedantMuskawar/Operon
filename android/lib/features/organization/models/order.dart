 import 'package:cloud_firestore/cloud_firestore.dart';  

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double gstRate;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.gstRate = 0,
  });

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

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String,
      productName: data['productName'] as String,
      quantity: (data['quantity'] as num).toInt(),
      unitPrice: (data['unitPrice'] as num).toDouble(),
      totalPrice: (data['totalPrice'] as num).toDouble(),
      gstRate: (data['gstRate'] is num)
          ? (data['gstRate'] as num).toDouble()
          : double.tryParse('${data['gstRate']}') ?? 0,
    );
  }
}

class OrderDeliveryAddress {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  OrderDeliveryAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }

  factory OrderDeliveryAddress.fromMap(Map<String, dynamic> data) {
    return OrderDeliveryAddress(
      street: data['street'] as String,
      city: data['city'] as String,
      state: data['state'] as String,
      zipCode: data['zipCode'] as String,
      country: data['country'] as String,
    );
  }
}

class Order {
  final String? id;
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
  final double gstAmount;
  final bool gstApplicable;
  final double gstRate;
  final int trips; // Number of trips
  final String paymentType; // Payment type: payOnDelivery, payLater, advance
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? notes;
  final int remainingTrips;
  final DateTime? lastScheduledAt;
  final String? lastScheduledBy;
  final String? lastScheduledVehicleId;

  Order({
    this.id,
    required this.orderId,
    required this.organizationId,
    required this.clientId,
    this.clientName,
    this.clientPhone,
    this.status = OrderStatus.pending,
    required this.items,
    required this.deliveryAddress,
    required this.region,
    required this.city,
    this.locationId,
    required this.subtotal,
    required this.gstAmount,
    this.gstApplicable = false,
    this.gstRate = 0,
    this.trips = 1,
    this.paymentType = PaymentType.payOnDelivery,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.notes,
    required this.remainingTrips,
    this.lastScheduledAt,
    this.lastScheduledBy,
    this.lastScheduledVehicleId,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Order(
      id: doc.id,
      orderId: data['orderId'] as String? ?? doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String?,
      clientPhone: data['clientPhone'] as String?,
      status: data['status'] as String? ?? OrderStatus.pending,
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      deliveryAddress: data['deliveryAddress'] != null
          ? OrderDeliveryAddress.fromMap(
              data['deliveryAddress'] as Map<String, dynamic>)
          : OrderDeliveryAddress(
              street: '',
              city: '',
              state: '',
              zipCode: '',
              country: '',
            ),
      region: data['region'] as String? ?? '',
      city: data['city'] as String? ?? '',
      locationId: data['locationId'] as String?,
      subtotal: ((data['subtotal'] ?? 0) as num).toDouble(),
      gstAmount: ((data['gstAmount'] ?? 0) as num).toDouble(),
      gstApplicable: (data['gstApplicable'] as bool?) ?? false,
      gstRate: _parseDouble(data['gstRate']),
      trips: (data['trips'] ?? 1) as int? ?? 1,
      paymentType: data['paymentType'] as String? ?? PaymentType.payOnDelivery,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      notes: data['notes'] as String?,
      remainingTrips: _parseInt(
        data['remainingTrips'],
        fallback: _parseInt(data['trips'], fallback: 0),
      ),
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
      'gstAmount': gstAmount,
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
    String? orderId,
    String? status,
    List<OrderItem>? items,
    OrderDeliveryAddress? deliveryAddress,
    String? region,
    String? city,
    String? locationId,
    double? subtotal,
    double? gstAmount,
    bool? gstApplicable,
    double? gstRate,
    int? trips,
    String? paymentType,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
    int? remainingTrips,
    DateTime? lastScheduledAt,
    String? lastScheduledBy,
    String? lastScheduledVehicleId,
    String? clientName,
    String? clientPhone,
  }) {
    return Order(
      id: id,
      orderId: orderId ?? this.orderId,
      organizationId: organizationId,
      clientId: clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      status: status ?? this.status,
      items: items ?? this.items,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      region: region ?? this.region,
      city: city ?? this.city,
      locationId: locationId ?? this.locationId,
      subtotal: subtotal ?? this.subtotal,
      gstAmount: gstAmount ?? this.gstAmount,
      gstApplicable: gstApplicable ?? this.gstApplicable,
      gstRate: gstRate ?? this.gstRate,
      trips: trips ?? this.trips,
      paymentType: paymentType ?? this.paymentType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
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

  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => subtotal + gstAmount;

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static DateTime? _parseNullableTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class OrderStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const List<String> all = [
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

  static const List<String> all = [
    payOnDelivery,
    payLater,
    advance,
  ];

  static String getDisplayName(String paymentType) {
    switch (paymentType) {
      case payOnDelivery:
        return 'Pay on Delivery';
      case payLater:
        return 'Pay Later';
      case advance:
        return 'Advance';
      default:
        return paymentType;
    }
  }
}

