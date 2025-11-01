import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String? id;
  final String addressId;
  final String addressName;
  final String address;
  final String region;
  final String? city;
  final String? state;
  final String? pincode;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Address({
    this.id,
    required this.addressId,
    required this.addressName,
    required this.address,
    required this.region,
    this.city,
    this.state,
    this.pincode,
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create Address from Firestore document
  factory Address.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Address(
      id: doc.id,
      addressId: data['addressId'] ?? '',
      addressName: data['addressName'] ?? '',
      address: data['address'] ?? '',
      region: data['region'] ?? '',
      city: data['city'],
      state: data['state'],
      pincode: data['pincode'],
      status: data['status'] ?? 'Active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert Address to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'addressId': addressId,
      'addressName': addressName,
      'address': address,
      'region': region,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (pincode != null) 'pincode': pincode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of Address with updated fields
  Address copyWith({
    String? addressId,
    String? addressName,
    String? address,
    String? region,
    String? city,
    String? state,
    String? pincode,
    String? status,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return Address(
      id: id,
      addressId: addressId ?? this.addressId,
      addressName: addressName ?? this.addressName,
      address: address ?? this.address,
      region: region ?? this.region,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if address is active
  bool get isActive => status == 'Active';

  @override
  String toString() {
    return 'Address(id: $id, addressId: $addressId, addressName: $addressName, region: $region, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Address region
class AddressRegion {
  static const String north = 'North';
  static const String south = 'South';
  static const String east = 'East';
  static const String west = 'West';
  static const String central = 'Central';

  static const List<String> all = [
    north,
    south,
    east,
    west,
    central,
  ];
}

// Address status
class AddressStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

