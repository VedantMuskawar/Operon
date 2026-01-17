import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseBatchTemplate {
  const PurchaseBatchTemplate({
    required this.templateId,
    required this.organizationId,
    required this.name,
    required this.vendorId,
    this.vendorType,
    this.description,
    this.materialEntries,
    this.unloadingCharges,
    this.unloadingGstPercent,
    this.unloadingHasGst,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  final String templateId;
  final String organizationId;
  final String name;
  final String vendorId;
  final String? vendorType;
  final String? description;
  final List<MaterialTemplateEntry>? materialEntries;
  final double? unloadingCharges;
  final double? unloadingGstPercent;
  final bool? unloadingHasGst;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'organizationId': organizationId,
      'name': name,
      'vendorId': vendorId,
      if (vendorType != null) 'vendorType': vendorType,
      if (description != null) 'description': description,
      if (materialEntries != null)
        'materialEntries': materialEntries!.map((e) => e.toJson()).toList(),
      if (unloadingCharges != null) 'unloadingCharges': unloadingCharges,
      if (unloadingGstPercent != null) 'unloadingGstPercent': unloadingGstPercent,
      if (unloadingHasGst != null) 'unloadingHasGst': unloadingHasGst,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  factory PurchaseBatchTemplate.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return PurchaseBatchTemplate(
      templateId: json['templateId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      vendorId: json['vendorId'] as String? ?? '',
      vendorType: json['vendorType'] as String?,
      description: json['description'] as String?,
      materialEntries: json['materialEntries'] != null
          ? (json['materialEntries'] as List)
              .map((e) => MaterialTemplateEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      unloadingCharges: (json['unloadingCharges'] as num?)?.toDouble(),
      unloadingGstPercent: (json['unloadingGstPercent'] as num?)?.toDouble(),
      unloadingHasGst: json['unloadingHasGst'] as bool?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] as String?,
    );
  }

  PurchaseBatchTemplate copyWith({
    String? templateId,
    String? organizationId,
    String? name,
    String? vendorId,
    String? vendorType,
    String? description,
    List<MaterialTemplateEntry>? materialEntries,
    double? unloadingCharges,
    double? unloadingGstPercent,
    bool? unloadingHasGst,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return PurchaseBatchTemplate(
      templateId: templateId ?? this.templateId,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      vendorId: vendorId ?? this.vendorId,
      vendorType: vendorType ?? this.vendorType,
      description: description ?? this.description,
      materialEntries: materialEntries ?? this.materialEntries,
      unloadingCharges: unloadingCharges ?? this.unloadingCharges,
      unloadingGstPercent: unloadingGstPercent ?? this.unloadingGstPercent,
      unloadingHasGst: unloadingHasGst ?? this.unloadingHasGst,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class MaterialTemplateEntry {
  const MaterialTemplateEntry({
    required this.materialId,
    required this.materialName,
    required this.unitPrice,
    this.unitOfMeasurement,
  });

  final String materialId;
  final String materialName;
  final double unitPrice;
  final String? unitOfMeasurement;

  Map<String, dynamic> toJson() {
    return {
      'materialId': materialId,
      'materialName': materialName,
      'unitPrice': unitPrice,
      if (unitOfMeasurement != null) 'unitOfMeasurement': unitOfMeasurement,
    };
  }

  factory MaterialTemplateEntry.fromJson(Map<String, dynamic> json) {
    return MaterialTemplateEntry(
      materialId: json['materialId'] as String? ?? '',
      materialName: json['materialName'] as String? ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unitOfMeasurement: json['unitOfMeasurement'] as String?,
    );
  }

  MaterialTemplateEntry copyWith({
    String? materialId,
    String? materialName,
    double? unitPrice,
    String? unitOfMeasurement,
  }) {
    return MaterialTemplateEntry(
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      unitPrice: unitPrice ?? this.unitPrice,
      unitOfMeasurement: unitOfMeasurement ?? this.unitOfMeasurement,
    );
  }
}
