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

  factory LocationPricing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Debug: Print all available fields
    print('LocationPricing document ${doc.id} fields: ${data.keys.toList()}');

    try {
      return LocationPricing(
        id: doc.id,
        locationId: data['locationId'] ?? data['location_id'] ?? '',
        locationName: data['locationName'] ?? data['location_name'] ?? data['name'] ?? '',
        city: data['city'] ?? '',
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
      print('Error creating LocationPricing from document ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      print('Document data: $data');
      rethrow;
    }
  }

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

  bool get isActive => status == 'Active';
}

class LocationStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';

  static const List<String> all = [
    active,
    inactive,
  ];
}

