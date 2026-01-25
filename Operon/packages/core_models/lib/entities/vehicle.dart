import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleDriverInfo {
  const VehicleDriverInfo({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String? id;
  final String? name;
  final String? phone;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    };
  }

  factory VehicleDriverInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VehicleDriverInfo(id: null, name: null, phone: null);
    return VehicleDriverInfo(
      id: json['id'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
    );
  }

  VehicleDriverInfo copyWith({
    String? id,
    String? name,
    String? phone,
  }) {
    return VehicleDriverInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }
}

class VehicleDocumentInfo {
  const VehicleDocumentInfo({
    this.documentNumber,
    this.expiryDate,
    this.attachmentUrl,
    this.provider,
  });

  final String? documentNumber;
  final DateTime? expiryDate;
  final String? attachmentUrl;
  final String? provider;

  Map<String, dynamic> toJson() {
    return {
      if (documentNumber != null) 'documentNumber': documentNumber,
      if (provider != null) 'provider': provider,
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate!),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    };
  }

  factory VehicleDocumentInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const VehicleDocumentInfo();
    }
    return VehicleDocumentInfo(
      documentNumber: json['documentNumber'] as String?,
      provider: json['provider'] as String?,
      expiryDate: (json['expiryDate'] as Timestamp?)?.toDate(),
      attachmentUrl: json['attachmentUrl'] as String?,
    );
  }

  VehicleDocumentInfo copyWith({
    String? documentNumber,
    DateTime? expiryDate,
    String? attachmentUrl,
    String? provider,
  }) {
    return VehicleDocumentInfo(
      documentNumber: documentNumber ?? this.documentNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      provider: provider ?? this.provider,
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.organizationId,
    required this.vehicleNumber,
    this.vehicleCapacity,
    this.weeklyCapacity,
    this.productCapacities,
    this.insurance,
    this.fitnessCertificate,
    this.puc,
    this.otherDocuments = const [],
    this.driver,
    this.isActive = true,
    this.notes,
    this.tag,
    this.meterType,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String vehicleNumber;
  final double? vehicleCapacity;
  final Map<String, double>? weeklyCapacity;
  final Map<String, double>? productCapacities;
  final VehicleDocumentInfo? insurance;
  final VehicleDocumentInfo? fitnessCertificate;
  final VehicleDocumentInfo? puc;
  final List<VehicleDocumentInfo> otherDocuments;
  final VehicleDriverInfo? driver;
  final bool isActive;
  final String? notes;
  final String? tag;
  final String? meterType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'vehicleNumber': vehicleNumber,
      'organizationId': organizationId,
      if (vehicleCapacity != null) 'vehicleCapacity': vehicleCapacity,
      if (weeklyCapacity != null)
        'weeklyCapacity': weeklyCapacity!.map((key, value) => MapEntry(key, value)),
      if (productCapacities != null && productCapacities!.isNotEmpty)
        'productCapacities': productCapacities!.map((key, value) => MapEntry(key, value)),
      if (insurance != null) 'insurance': insurance!.toJson(),
      if (fitnessCertificate != null) 'fitnessCertificate': fitnessCertificate!.toJson(),
      if (puc != null) 'puc': puc!.toJson(),
      if (otherDocuments.isNotEmpty)
        'otherDocuments': otherDocuments.map((doc) => doc.toJson()).toList(),
      if (driver != null) 'driver': driver!.toJson(),
      'isActive': isActive,
      if (notes != null) 'notes': notes,
      if (tag != null) 'tag': tag,
      if (meterType != null) 'meterType': meterType,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json, String id) {
    final weeklyCapacityData = json['weeklyCapacity'] as Map<String, dynamic>?;
    return Vehicle(
      id: id,
      organizationId: json['organizationId'] as String? ?? '',
      vehicleNumber: json['vehicleNumber'] as String? ?? '',
      vehicleCapacity: (json['vehicleCapacity'] as num?)?.toDouble(),
      weeklyCapacity: weeklyCapacityData?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      productCapacities: (json['productCapacities'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      insurance: VehicleDocumentInfo.fromJson(json['insurance'] as Map<String, dynamic>?),
      fitnessCertificate:
          VehicleDocumentInfo.fromJson(json['fitnessCertificate'] as Map<String, dynamic>?),
      puc: VehicleDocumentInfo.fromJson(json['puc'] as Map<String, dynamic>?),
      otherDocuments: (json['otherDocuments'] as List<dynamic>?)
              ?.map((doc) => VehicleDocumentInfo.fromJson(doc as Map<String, dynamic>?))
              .toList() ??
          const [],
      driver: VehicleDriverInfo.fromJson(json['driver'] as Map<String, dynamic>?),
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      tag: json['tag'] as String?,
      meterType: json['meterType'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Vehicle copyWith({
    String? id,
    String? organizationId,
    String? vehicleNumber,
    double? vehicleCapacity,
    Map<String, double>? weeklyCapacity,
    Map<String, double>? productCapacities,
    VehicleDocumentInfo? insurance,
    VehicleDocumentInfo? fitnessCertificate,
    VehicleDocumentInfo? puc,
    List<VehicleDocumentInfo>? otherDocuments,
    VehicleDriverInfo? driver,
    bool? isActive,
    String? notes,
    String? tag,
    String? meterType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleCapacity: vehicleCapacity ?? this.vehicleCapacity,
      weeklyCapacity: weeklyCapacity ?? this.weeklyCapacity,
      productCapacities: productCapacities ?? this.productCapacities,
      insurance: insurance ?? this.insurance,
      fitnessCertificate: fitnessCertificate ?? this.fitnessCertificate,
      puc: puc ?? this.puc,
      otherDocuments: otherDocuments ?? this.otherDocuments,
      driver: driver ?? this.driver,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      tag: tag ?? this.tag,
      meterType: meterType ?? this.meterType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

