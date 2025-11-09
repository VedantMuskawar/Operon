import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../../lib/core/constants/app_constants.dart' as shared;

class AndroidRoleDefinition extends Equatable {
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
  final DateTime createdAt;
  final DateTime updatedAt;

  const AndroidRoleDefinition({
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
  });

  factory AndroidRoleDefinition.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String organizationId,
  }) {
    final data = snapshot.data() ?? <String, dynamic>{};

    DateTime _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double? _parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return null;
    }

    final rawPermissions = data['permissions'];
    final permissions = rawPermissions is List
        ? rawPermissions.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList()
        : const <String>[];

    final wageType = (data['wageType'] as String?)?.toLowerCase();

    final normalizedWageType = () {
      const allowed = {
        shared.AppConstants.employeeWageTypeHourly,
        shared.AppConstants.employeeWageTypeQuantity,
        shared.AppConstants.employeeWageTypeMonthly,
      };
      if (wageType != null && allowed.contains(wageType)) {
        return wageType;
      }
      return shared.AppConstants.employeeWageTypeMonthly;
    }();

    final rawFrequency = (data['compensationFrequency'] as String?)?.toLowerCase();
    final normalizedFrequency = () {
      const allowed = {
        shared.AppConstants.employeeCompFrequencyMonthly,
        shared.AppConstants.employeeCompFrequencyBiweekly,
        shared.AppConstants.employeeCompFrequencyWeekly,
        shared.AppConstants.employeeCompFrequencyPerShift,
      };
      if (rawFrequency != null && allowed.contains(rawFrequency)) {
        return rawFrequency;
      }
      return shared.AppConstants.employeeCompFrequencyMonthly;
    }();

    return AndroidRoleDefinition(
      id: snapshot.id,
      organizationId: organizationId,
      name: (data['name'] as String? ?? '').trim(),
      description: (data['description'] as String?)?.trim().isNotEmpty == true
          ? (data['description'] as String).trim()
          : null,
      permissions: permissions,
      isSystem: data['isSystem'] as bool? ?? false,
      priority: (data['priority'] as num?)?.toInt(),
      wageType: normalizedWageType,
      compensationFrequency: normalizedFrequency,
      quantity: _parseDouble(data['quantity']),
      wagePerQuantity: _parseDouble(data['wagePerQuantity']),
      monthlySalary: _parseDouble(data['monthlySalary']),
      monthlyBonus: _parseDouble(data['monthlyBonus']),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        name,
        description,
        permissions,
        isSystem,
        priority,
        wageType,
        compensationFrequency,
        quantity,
        wagePerQuantity,
        monthlySalary,
        monthlyBonus,
        createdAt,
        updatedAt,
      ];
}

