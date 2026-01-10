import 'package:cloud_firestore/cloud_firestore.dart';

enum TripWageStatus {
  recorded,
  calculated,
  processed,
}

class TripWage {
  const TripWage({
    required this.tripWageId,
    required this.organizationId,
    required this.dmId,
    required this.tripId,
    required this.quantityDelivered,
    required this.methodId,
    required this.loadingEmployeeIds,
    required this.unloadingEmployeeIds,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.productId,
    this.productName,
    this.totalWages,
    this.loadingWages,
    this.unloadingWages,
    this.loadingWagePerEmployee,
    this.unloadingWagePerEmployee,
    this.wageTransactionIds,
  });

  final String tripWageId;
  final String organizationId;
  final String dmId; // Reference to DELIVERY_MEMOS
  final String tripId; // Reference to SCHEDULE_TRIPS
  final String? orderId;
  final String? productId;
  final String? productName;
  final int quantityDelivered;
  final String methodId;
  final List<String> loadingEmployeeIds;
  final List<String> unloadingEmployeeIds;
  final double? totalWages;
  final double? loadingWages;
  final double? unloadingWages;
  final double? loadingWagePerEmployee;
  final double? unloadingWagePerEmployee;
  final TripWageStatus status;
  final List<String>? wageTransactionIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'tripWageId': tripWageId,
      'organizationId': organizationId,
      'dmId': dmId,
      'tripId': tripId,
      if (orderId != null) 'orderId': orderId,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      'quantityDelivered': quantityDelivered,
      'methodId': methodId,
      'loadingEmployeeIds': loadingEmployeeIds,
      'unloadingEmployeeIds': unloadingEmployeeIds,
      if (totalWages != null) 'totalWages': totalWages,
      if (loadingWages != null) 'loadingWages': loadingWages,
      if (unloadingWages != null) 'unloadingWages': unloadingWages,
      if (loadingWagePerEmployee != null)
        'loadingWagePerEmployee': loadingWagePerEmployee,
      if (unloadingWagePerEmployee != null)
        'unloadingWagePerEmployee': unloadingWagePerEmployee,
      'status': status.name,
      if (wageTransactionIds != null) 'wageTransactionIds': wageTransactionIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TripWage.fromJson(Map<String, dynamic> json, String docId) {
    final statusStr = json['status'] as String? ?? 'recorded';
    final status = TripWageStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => TripWageStatus.recorded,
    );

    return TripWage(
      tripWageId: json['tripWageId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      dmId: json['dmId'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      orderId: json['orderId'] as String?,
      productId: json['productId'] as String?,
      productName: json['productName'] as String?,
      quantityDelivered: (json['quantityDelivered'] as num?)?.toInt() ?? 0,
      methodId: json['methodId'] as String? ?? '',
      loadingEmployeeIds: json['loadingEmployeeIds'] != null
          ? List<String>.from(json['loadingEmployeeIds'] as List)
          : [],
      unloadingEmployeeIds: json['unloadingEmployeeIds'] != null
          ? List<String>.from(json['unloadingEmployeeIds'] as List)
          : [],
      totalWages: (json['totalWages'] as num?)?.toDouble(),
      loadingWages: (json['loadingWages'] as num?)?.toDouble(),
      unloadingWages: (json['unloadingWages'] as num?)?.toDouble(),
      loadingWagePerEmployee:
          (json['loadingWagePerEmployee'] as num?)?.toDouble(),
      unloadingWagePerEmployee:
          (json['unloadingWagePerEmployee'] as num?)?.toDouble(),
      status: status,
      wageTransactionIds: json['wageTransactionIds'] != null
          ? List<String>.from(json['wageTransactionIds'] as List)
          : null,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  TripWage copyWith({
    String? tripWageId,
    String? organizationId,
    String? dmId,
    String? tripId,
    String? orderId,
    String? productId,
    String? productName,
    int? quantityDelivered,
    String? methodId,
    List<String>? loadingEmployeeIds,
    List<String>? unloadingEmployeeIds,
    double? totalWages,
    double? loadingWages,
    double? unloadingWages,
    double? loadingWagePerEmployee,
    double? unloadingWagePerEmployee,
    TripWageStatus? status,
    List<String>? wageTransactionIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripWage(
      tripWageId: tripWageId ?? this.tripWageId,
      organizationId: organizationId ?? this.organizationId,
      dmId: dmId ?? this.dmId,
      tripId: tripId ?? this.tripId,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityDelivered: quantityDelivered ?? this.quantityDelivered,
      methodId: methodId ?? this.methodId,
      loadingEmployeeIds: loadingEmployeeIds ?? this.loadingEmployeeIds,
      unloadingEmployeeIds: unloadingEmployeeIds ?? this.unloadingEmployeeIds,
      totalWages: totalWages ?? this.totalWages,
      loadingWages: loadingWages ?? this.loadingWages,
      unloadingWages: unloadingWages ?? this.unloadingWages,
      loadingWagePerEmployee:
          loadingWagePerEmployee ?? this.loadingWagePerEmployee,
      unloadingWagePerEmployee:
          unloadingWagePerEmployee ?? this.unloadingWagePerEmployee,
      status: status ?? this.status,
      wageTransactionIds: wageTransactionIds ?? this.wageTransactionIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

