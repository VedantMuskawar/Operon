import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String? id;
  final String vehicleID;
  final String vehicleNo;
  final String type;
  final String meterType;
  final int vehicleQuantity;
  final String status;
  final Map<String, int> weeklyCapacity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;

  Vehicle({
    this.id,
    required this.vehicleID,
    required this.vehicleNo,
    required this.type,
    required this.meterType,
    required this.vehicleQuantity,
    required this.status,
    required this.weeklyCapacity,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // Create Vehicle from Firestore document
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse weekly capacity map
    Map<String, int> weeklyCapacity = {};
    if (data['weeklyCapacity'] != null) {
      final capacity = data['weeklyCapacity'] as Map<String, dynamic>?;
      if (capacity != null) {
        weeklyCapacity = capacity.map((key, value) => 
          MapEntry(key, (value as num).toInt())
        );
      }
    }

    return Vehicle(
      id: doc.id,
      vehicleID: data['vehicleID'] ?? '',
      vehicleNo: data['vehicleNo'] ?? '',
      type: data['type'] ?? '',
      meterType: data['meterType'] ?? '',
      vehicleQuantity: data['vehicleQuantity'] ?? 0,
      status: data['status'] ?? 'Active',
      weeklyCapacity: weeklyCapacity,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }

  // Convert Vehicle to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'vehicleID': vehicleID,
      'vehicleNo': vehicleNo,
      'type': type,
      'meterType': meterType,
      'vehicleQuantity': vehicleQuantity,
      'status': status,
      'weeklyCapacity': weeklyCapacity,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  // Create copy of Vehicle with updated fields
  Vehicle copyWith({
    String? vehicleID,
    String? vehicleNo,
    String? type,
    String? meterType,
    int? vehicleQuantity,
    String? status,
    Map<String, int>? weeklyCapacity,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return Vehicle(
      id: id,
      vehicleID: vehicleID ?? this.vehicleID,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      type: type ?? this.type,
      meterType: meterType ?? this.meterType,
      vehicleQuantity: vehicleQuantity ?? this.vehicleQuantity,
      status: status ?? this.status,
      weeklyCapacity: weeklyCapacity ?? this.weeklyCapacity,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  // Check if vehicle is active
  bool get isActive => status == 'Active';

  // Get total weekly capacity
  int get totalWeeklyCapacity {
    return weeklyCapacity.values.fold(0, (sum, capacity) => sum + capacity);
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, vehicleID: $vehicleID, vehicleNo: $vehicleNo, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Vehicle types enum
class VehicleType {
  static const String tractor = 'Tractor';
  static const String truck = 'Truck';
  static const String trailer = 'Trailer';
  static const String loader = 'Loader';
  static const String excavator = 'Excavator';
  static const String other = 'Other';

  static const List<String> all = [
    tractor,
    truck,
    trailer,
    loader,
    excavator,
    other,
  ];
}

// Meter types enum
class MeterType {
  static const String hours = 'Hours';
  static const String kilometers = 'Kilometers';
  static const String miles = 'Miles';
  static const String units = 'Units';

  static const List<String> all = [
    hours,
    kilometers,
    miles,
    units,
  ];
}

// Vehicle status enum
class VehicleStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String maintenance = 'Maintenance';

  static const List<String> all = [
    active,
    inactive,
    maintenance,
  ];
}

