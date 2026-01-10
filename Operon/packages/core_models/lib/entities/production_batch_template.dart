import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionBatchTemplate {
  const ProductionBatchTemplate({
    required this.batchId,
    required this.organizationId,
    required this.name,
    required this.employeeIds,
    required this.createdAt,
    required this.updatedAt,
    this.employeeNames,
  });

  final String batchId;
  final String organizationId;
  final String name;
  final List<String> employeeIds;
  final List<String>? employeeNames;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'organizationId': organizationId,
      'name': name,
      'employeeIds': employeeIds,
      if (employeeNames != null) 'employeeNames': employeeNames,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProductionBatchTemplate.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return ProductionBatchTemplate(
      batchId: json['batchId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      employeeIds: json['employeeIds'] != null
          ? List<String>.from(json['employeeIds'] as List)
          : [],
      employeeNames: json['employeeNames'] != null
          ? List<String>.from(json['employeeNames'] as List)
          : null,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  ProductionBatchTemplate copyWith({
    String? batchId,
    String? organizationId,
    String? name,
    List<String>? employeeIds,
    List<String>? employeeNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductionBatchTemplate(
      batchId: batchId ?? this.batchId,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      employeeIds: employeeIds ?? this.employeeIds,
      employeeNames: employeeNames ?? this.employeeNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

