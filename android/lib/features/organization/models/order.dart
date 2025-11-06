import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String,
      productName: data['productName'] as String,
      quantity: (data['quantity'] as num).toInt(),
      unitPrice: (data['unitPrice'] as num).toDouble(),
      totalPrice: (data['totalPrice'] as num).toDouble(),
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
  final String status;
  final List<OrderItem> items;
  final OrderDeliveryAddress deliveryAddress;
  final String region;
  final String city;
  final String? locationId;
  final double subtotal;
  final double totalAmount;
  final int trips; // Number of trips
  final String paymentType; // Payment type: payOnDelivery, payLater, advance
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? notes;

  Order({
    this.id,
    required this.orderId,
    required this.organizationId,
    required this.clientId,
    this.status = OrderStatus.pending,
    required this.items,
    required this.deliveryAddress,
    required this.region,
    required this.city,
    this.locationId,
    required this.subtotal,
    required this.totalAmount,
    this.trips = 1,
    this.paymentType = PaymentType.payOnDelivery,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.notes,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Order(
      id: doc.id,
      orderId: data['orderId'] as String? ?? doc.id,
      organizationId: data['organizationId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
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
      totalAmount: ((data['totalAmount'] ?? data['total'] ?? 0) as num)
          .toDouble(),
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
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'organizationId': organizationId,
      'clientId': clientId,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'deliveryAddress': deliveryAddress.toMap(),
      'region': region,
      'city': city,
      if (locationId != null) 'locationId': locationId,
      'subtotal': subtotal,
      'totalAmount': totalAmount,
      'trips': trips,
      'paymentType': paymentType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (notes != null) 'notes': notes,
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
    double? totalAmount,
    int? trips,
    String? paymentType,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
  }) {
    return Order(
      id: id,
      orderId: orderId ?? this.orderId,
      organizationId: organizationId,
      clientId: clientId,
      status: status ?? this.status,
      items: items ?? this.items,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      region: region ?? this.region,
      city: city ?? this.city,
      locationId: locationId ?? this.locationId,
      subtotal: subtotal ?? this.subtotal,
      totalAmount: totalAmount ?? this.totalAmount,
      trips: trips ?? this.trips,
      paymentType: paymentType ?? this.paymentType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      notes: notes ?? this.notes,
    );
  }

  bool get isPending => status == OrderStatus.pending;
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

