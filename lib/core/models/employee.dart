import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';

class Employee {
  final String id;
  final String organizationId;
  final String roleId;
  final String name;
  final String nameLowercase;
  final DateTime startDate;
  final double openingBalance;
  final String openingBalanceCurrency;
  final String status;
  final String? contactEmail;
  final String? contactPhone;
  final String? notes;
  final String? createdBy;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.organizationId,
    required this.roleId,
    required this.name,
    required this.nameLowercase,
    required this.startDate,
    required this.openingBalance,
    required this.openingBalanceCurrency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contactEmail,
    this.contactPhone,
    this.notes,
    this.createdBy,
    this.updatedBy,
  });

  factory Employee.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final name = (data['name'] as String? ?? '').trim();
    final nameLowercase =
        (data['nameLowercase'] as String? ?? name.toLowerCase()).trim();
    final startDate = _parseTimestamp(data['startDate']);
    final openingBalance = _readDouble(data['openingBalance']);
    final createdAt = _parseTimestamp(data['createdAt']);
    final updatedAt = _parseTimestamp(data['updatedAt']);

    return Employee(
      id: snapshot.id,
      organizationId: (data['organizationId'] as String? ?? '').trim(),
      roleId: (data['roleId'] as String? ?? '').trim(),
      name: name,
      nameLowercase: nameLowercase,
      startDate: startDate,
      openingBalance: openingBalance,
      openingBalanceCurrency:
          (data['openingBalanceCurrency'] as String? ?? AppConstants.defaultCurrency)
              .trim(),
      status: (data['status'] as String? ?? AppConstants.employeeStatusActive)
          .toLowerCase(),
      contactEmail: _readOptionalString(data['contactEmail']),
      contactPhone: _readOptionalString(data['contactPhone']),
      notes: _readOptionalString(data['notes']),
      createdBy: _readOptionalString(data['createdBy']),
      updatedBy: _readOptionalString(data['updatedBy']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'employeeId': id,
      'roleId': roleId,
      'name': name,
      'nameLowercase': nameLowercase,
      'startDate': Timestamp.fromDate(startDate),
      'openingBalance': openingBalance,
      'openingBalanceCurrency': openingBalanceCurrency,
      'status': status,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'createdBy': createdBy,
      if (updatedBy != null) 'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Employee copyWith({
    String? organizationId,
    String? roleId,
    String? name,
    DateTime? startDate,
    double? openingBalance,
    String? openingBalanceCurrency,
    String? status,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newName = name ?? this.name;
    return Employee(
      id: id,
      organizationId: organizationId ?? this.organizationId,
      roleId: roleId ?? this.roleId,
      name: newName,
      nameLowercase: newName.toLowerCase(),
      startDate: startDate ?? this.startDate,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceCurrency:
          openingBalanceCurrency ?? this.openingBalanceCurrency,
      status: status ?? this.status,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == AppConstants.employeeStatusActive;

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

  static double _readDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static String? _readOptionalString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    return null;
  }
}

class EmployeeStatus {
  static const String active = AppConstants.employeeStatusActive;
  static const String inactive = AppConstants.employeeStatusInactive;
  static const String invited = AppConstants.employeeStatusInvited;

  static const List<String> values = [active, inactive, invited];
}


