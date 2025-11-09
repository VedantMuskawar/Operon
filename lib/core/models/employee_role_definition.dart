import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

class EmployeeRoleDefinition {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final List<String> permissions;
  final bool isSystem;
  final int? priority;
  final String wageType;
  final String compensationFrequency;
  final double? quantity;
  final double? wagePerQuantity;
  final double? monthlySalary;
  final double? monthlyBonus;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeRoleDefinition({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.permissions,
    required this.isSystem,
    required this.wageType,
    required this.compensationFrequency,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.priority,
    this.quantity,
    this.wagePerQuantity,
    this.monthlySalary,
    this.monthlyBonus,
    this.createdBy,
    this.updatedBy,
  });

  factory EmployeeRoleDefinition.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String organizationId,
  }) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return EmployeeRoleDefinition(
      id: snapshot.id,
      organizationId: organizationId,
      name: (data['name'] as String? ?? '').trim(),
      description: _readOptionalString(data['description']),
      permissions: _readStringList(data['permissions']),
      isSystem: data['isSystem'] as bool? ?? false,
      priority: (data['priority'] as num?)?.toInt(),
      wageType: _readOptionalString(data['wageType']) ??
          AppConstants.employeeWageTypeMonthly,
      compensationFrequency:
          _readOptionalString(data['compensationFrequency']) ??
              AppConstants.employeeCompFrequencyMonthly,
      quantity: _readDouble(data['quantity']),
      wagePerQuantity: _readDouble(data['wagePerQuantity']),
      monthlySalary: _readDouble(data['monthlySalary']),
      monthlyBonus: _readDouble(data['monthlyBonus']),
      createdBy: _readOptionalString(data['createdBy']),
      updatedBy: _readOptionalString(data['updatedBy']),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (permissions.isNotEmpty) 'permissions': permissions,
      'isSystem': isSystem,
      if (priority != null) 'priority': priority,
      'wageType': wageType,
      'compensationFrequency': compensationFrequency,
      if (quantity != null) 'quantity': quantity,
      if (wagePerQuantity != null) 'wagePerQuantity': wagePerQuantity,
      if (monthlySalary != null) 'monthlySalary': monthlySalary,
      if (monthlyBonus != null) 'monthlyBonus': monthlyBonus,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EmployeeRoleDefinition copyWith({
    String? name,
    String? description,
    List<String>? permissions,
    bool? isSystem,
    int? priority,
    String? wageType,
    String? compensationFrequency,
    double? quantity,
    double? wagePerQuantity,
    double? monthlySalary,
    double? monthlyBonus,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeRoleDefinition(
      id: id,
      organizationId: organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isSystem: isSystem ?? this.isSystem,
      priority: priority ?? this.priority,
      wageType: wageType ?? this.wageType,
      compensationFrequency:
          compensationFrequency ?? this.compensationFrequency,
      quantity: quantity ?? this.quantity,
      wagePerQuantity: wagePerQuantity ?? this.wagePerQuantity,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      monthlyBonus: monthlyBonus ?? this.monthlyBonus,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isEditable => !isSystem;

  static List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString())
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static String? _readOptionalString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

