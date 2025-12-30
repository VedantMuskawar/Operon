import 'package:cloud_firestore/cloud_firestore.dart';

enum RawMaterialStatus { active, paused, archived }

class RawMaterial {
  const RawMaterial({
    required this.id,
    required this.name,
    required this.purchasePrice,
    this.gstPercent,
    required this.unitOfMeasurement,
    required this.stock,
    required this.minimumStockLevel,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double purchasePrice;
  final double? gstPercent; // Optional - null if no GST
  final String unitOfMeasurement; // e.g., "kg", "liters", "pieces", "bags"
  final int stock; // Current stock quantity
  final int minimumStockLevel; // Alert threshold for low stock
  final RawMaterialStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasGst => gstPercent != null && gstPercent! > 0;
  bool get isLowStock => stock < minimumStockLevel;

  Map<String, dynamic> toJson() {
    return {
      'materialId': id,
      'name': name,
      'purchasePrice': purchasePrice,
      if (gstPercent != null) 'gstPercent': gstPercent,
      'unitOfMeasurement': unitOfMeasurement,
      'stock': stock,
      'minimumStockLevel': minimumStockLevel,
      'status': status.name,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory RawMaterial.fromJson(Map<String, dynamic> json, String docId) {
    return RawMaterial(
      id: json['materialId'] as String? ?? docId,
      name: json['name'] as String? ?? 'Unnamed Material',
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
      gstPercent: (json['gstPercent'] as num?)?.toDouble(),
      unitOfMeasurement: json['unitOfMeasurement'] as String? ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minimumStockLevel: (json['minimumStockLevel'] as num?)?.toInt() ?? 0,
      status: RawMaterialStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RawMaterialStatus.active,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  RawMaterial copyWith({
    String? id,
    String? name,
    double? purchasePrice,
    double? gstPercent,
    String? unitOfMeasurement,
    int? stock,
    int? minimumStockLevel,
    RawMaterialStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      gstPercent: gstPercent ?? this.gstPercent,
      unitOfMeasurement: unitOfMeasurement ?? this.unitOfMeasurement,
      stock: stock ?? this.stock,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

