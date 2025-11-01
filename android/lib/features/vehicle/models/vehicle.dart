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

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Debug: Print all available fields
    print('Vehicle document ${doc.id} fields: ${data.keys.toList()}');
    
    // Try different field name variations
    String getField(String primary, List<String> alternatives, String defaultValue) {
      if (data.containsKey(primary)) return data[primary]?.toString() ?? defaultValue;
      for (var alt in alternatives) {
        if (data.containsKey(alt)) return data[alt]?.toString() ?? defaultValue;
      }
      return defaultValue;
    }
    
    Map<String, int> weeklyCapacity = {};
    if (data['weeklyCapacity'] != null || data['weekly_capacity'] != null) {
      final capacity = (data['weeklyCapacity'] ?? data['weekly_capacity']) as Map<String, dynamic>?;
      if (capacity != null) {
        weeklyCapacity = capacity.map((key, value) => 
          MapEntry(key, (value as num?)?.toInt() ?? 0)
        );
      }
    }

    try {
      return Vehicle(
        id: doc.id,
        vehicleID: getField('vehicleID', ['vehicle_id', 'vehicleId'], ''),
        vehicleNo: getField('vehicleNo', ['vehicle_no', 'vehicleNumber', 'vehicle_number'], ''),
        type: getField('type', ['vehicleType', 'vehicle_type'], ''),
        meterType: getField('meterType', ['meter_type', 'meter'], ''),
        vehicleQuantity: (data['vehicleQuantity'] ?? data['vehicle_quantity'] ?? data['quantity'] ?? 0) as int,
        status: getField('status', [], 'Active'),
        weeklyCapacity: weeklyCapacity,
        createdAt: (data['createdAt'] ?? data['created_at'] ?? data['createdDate'] ?? data['created_date']) != null
            ? ((data['createdAt'] ?? data['created_at'] ?? data['createdDate'] ?? data['created_date']) as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: (data['updatedAt'] ?? data['updated_at'] ?? data['updatedDate'] ?? data['updated_date']) != null
            ? ((data['updatedAt'] ?? data['updated_at'] ?? data['updatedDate'] ?? data['updated_date']) as Timestamp).toDate()
            : DateTime.now(),
        createdBy: data['createdBy'] ?? data['created_by'] ?? data['createdBy'],
        updatedBy: data['updatedBy'] ?? data['updated_by'] ?? data['updatedBy'],
      );
    } catch (e, stackTrace) {
      print('Error creating Vehicle from document ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      print('Document data: $data');
      rethrow;
    }
  }

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

  bool get isActive => status == 'Active';

  int get totalWeeklyCapacity {
    return weeklyCapacity.values.fold(0, (sum, capacity) => sum + capacity);
  }
}

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

