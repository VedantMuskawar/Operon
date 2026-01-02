import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseSubCategory {
  const ExpenseSubCategory({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.colorHex,
    required this.isActive,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.icon,
    this.createdBy,
    this.transactionCount = 0,
    this.totalAmount = 0.0,
    this.lastUsedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? icon; // Optional icon identifier (e.g., "home", "wifi", "car")
  final String colorHex; // Color code (e.g., "#6F4BFF")
  final bool isActive;
  final int order; // For sorting/ordering
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Analytics fields (updated by Cloud Functions)
  final int transactionCount; // Number of expenses using this sub-category
  final double totalAmount; // Total amount of expenses in this sub-category
  final DateTime? lastUsedAt; // Last time this sub-category was used

  Map<String, dynamic> toJson() {
    return {
      'subCategoryId': id,
      'organizationId': organizationId,
      'name': name,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      'colorHex': colorHex,
      'isActive': isActive,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (createdBy != null) 'createdBy': createdBy,
      'transactionCount': transactionCount,
      'totalAmount': totalAmount,
      if (lastUsedAt != null) 'lastUsedAt': Timestamp.fromDate(lastUsedAt!),
    };
  }

  factory ExpenseSubCategory.fromJson(Map<String, dynamic> json, String docId) {
    return ExpenseSubCategory(
      id: json['subCategoryId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      colorHex: json['colorHex'] as String? ?? '#6F4BFF',
      isActive: json['isActive'] as bool? ?? true,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] as String?,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      lastUsedAt: (json['lastUsedAt'] as Timestamp?)?.toDate(),
    );
  }

  ExpenseSubCategory copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    String? icon,
    String? colorHex,
    bool? isActive,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? transactionCount,
    double? totalAmount,
    DateTime? lastUsedAt,
  }) {
    return ExpenseSubCategory(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      transactionCount: transactionCount ?? this.transactionCount,
      totalAmount: totalAmount ?? this.totalAmount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}

