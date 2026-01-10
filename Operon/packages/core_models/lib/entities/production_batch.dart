import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductionBatchStatus {
  recorded,
  calculated,
  approved,
  processed,
}

class ProductionBatch {
  const ProductionBatch({
    required this.batchId,
    required this.organizationId,
    required this.batchDate,
    required this.methodId,
    required this.totalBricksProduced,
    required this.totalBricksStacked,
    required this.employeeIds,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.productId,
    this.productName,
    this.employeeNames,
    this.totalWages,
    this.wagePerEmployee,
    this.wageTransactionIds,
    this.notes,
    this.metadata,
  });

  final String batchId;
  final String organizationId;
  final DateTime batchDate;
  final String methodId;
  final String? productId;
  final String? productName;
  final int totalBricksProduced;
  final int totalBricksStacked;
  final List<String> employeeIds;
  final List<String>? employeeNames;
  final double? totalWages;
  final double? wagePerEmployee;
  final ProductionBatchStatus status;
  final List<String>? wageTransactionIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'organizationId': organizationId,
      'batchDate': Timestamp.fromDate(batchDate),
      'methodId': methodId,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      'totalBricksProduced': totalBricksProduced,
      'totalBricksStacked': totalBricksStacked,
      'employeeIds': employeeIds,
      if (employeeNames != null) 'employeeNames': employeeNames,
      if (totalWages != null) 'totalWages': totalWages,
      if (wagePerEmployee != null) 'wagePerEmployee': wagePerEmployee,
      'status': status.name,
      if (wageTransactionIds != null) 'wageTransactionIds': wageTransactionIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (notes != null) 'notes': notes,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory ProductionBatch.fromJson(Map<String, dynamic> json, String docId) {
    final statusStr = json['status'] as String? ?? 'recorded';
    final status = ProductionBatchStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ProductionBatchStatus.recorded,
    );

    return ProductionBatch(
      batchId: json['batchId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      batchDate: (json['batchDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      methodId: json['methodId'] as String? ?? '',
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      totalBricksProduced: (json['totalBricksProduced'] as num?)?.toInt() ?? 0,
      totalBricksStacked: (json['totalBricksStacked'] as num?)?.toInt() ?? 0,
      employeeIds: json['employeeIds'] != null
          ? List<String>.from(json['employeeIds'] as List)
          : [],
      employeeNames: json['employeeNames'] != null
          ? List<String>.from(json['employeeNames'] as List)
          : null,
      totalWages: (json['totalWages'] as num?)?.toDouble(),
      wagePerEmployee: (json['wagePerEmployee'] as num?)?.toDouble(),
      status: status,
      wageTransactionIds: json['wageTransactionIds'] != null
          ? List<String>.from(json['wageTransactionIds'] as List)
          : null,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  ProductionBatch copyWith({
    String? batchId,
    String? organizationId,
    DateTime? batchDate,
    String? methodId,
    String? productId,
    String? productName,
    int? totalBricksProduced,
    int? totalBricksStacked,
    List<String>? employeeIds,
    List<String>? employeeNames,
    double? totalWages,
    double? wagePerEmployee,
    ProductionBatchStatus? status,
    List<String>? wageTransactionIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return ProductionBatch(
      batchId: batchId ?? this.batchId,
      organizationId: organizationId ?? this.organizationId,
      batchDate: batchDate ?? this.batchDate,
      methodId: methodId ?? this.methodId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      totalBricksProduced: totalBricksProduced ?? this.totalBricksProduced,
      totalBricksStacked: totalBricksStacked ?? this.totalBricksStacked,
      employeeIds: employeeIds ?? this.employeeIds,
      employeeNames: employeeNames ?? this.employeeNames,
      totalWages: totalWages ?? this.totalWages,
      wagePerEmployee: wagePerEmployee ?? this.wagePerEmployee,
      status: status ?? this.status,
      wageTransactionIds: wageTransactionIds ?? this.wageTransactionIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }
}

