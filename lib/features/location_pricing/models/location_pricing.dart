import 'package:cloud_firestore/cloud_firestore.dart';

class LocationPricing {
  final String? id;
  final String locationId;
  final String locationName;
  final String city;
  final double unitPrice;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  LocationPricing({
    this.id,
    required this.locationId,
    required this.locationName,
    required this.city,
    required this.unitPrice,
    this.status = 'Active',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create LocationPricing from Firestore document
  factory LocationPricing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LocationPricing(
      id: doc.id,
      locationId: data['locationId'] ?? '',
      locationName: data['locationName'] ?? '',
      city: data['city'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      status: data['status'] ?? 'Active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert LocationPricing to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'locationId': locationId,
      'locationName': locationName,
      'city': city,
      'unitPrice': unitPrice,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of LocationPricing with updated fields
  LocationPricing copyWith({
    String? locationId,
    String? locationName,
    String? city,
    double? unitPrice,
    String? status,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return LocationPricing(
      id: id,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      city: city ?? this.city,
      unitPrice: unitPrice ?? this.unitPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if location is active
  bool get isActive => status == 'Active';

  @override
  String toString() {
    return 'LocationPricing(id: $id, locationId: $locationId, locationName: $locationName, city: $city, unitPrice: $unitPrice, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPricing && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Location status
class LocationStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

