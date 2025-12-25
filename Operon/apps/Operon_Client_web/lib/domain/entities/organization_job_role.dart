import 'package:dash_web/domain/entities/wage_type.dart';

/// Organization Job Role - Describes job positions/titles in the organization
/// 
/// This role represents the actual job/position an employee holds.
/// Separate from app access roles which control permissions.
/// Not all employees need app access, but all employees have job roles.
class OrganizationJobRole {
  const OrganizationJobRole({
    required this.id,
    required this.title,
    required this.colorHex,
    this.department,
    this.description,
    this.defaultWageType,
    this.sortOrder,
  });

  final String id;
  final String title;                   // e.g., "Delivery Driver", "Operations Manager", "Sales Executive"
  final String? department;             // Optional: "Logistics", "Sales", "HR", etc.
  final String? description;            // Job description
  final String colorHex;                // For UI display
  final WageType? defaultWageType;      // Suggested default wage type (employees can override)
  final int? sortOrder;                 // For display ordering

  Map<String, dynamic> toJson() {
    return {
      'jobRoleId': id,
      'title': title,
      if (department != null) 'department': department,
      if (description != null) 'description': description,
      'colorHex': colorHex,
      if (defaultWageType != null) 'defaultWageType': defaultWageType!.name,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }

  factory OrganizationJobRole.fromJson(Map<String, dynamic> json, String docId) {
    final wageTypeStr = json['defaultWageType'] as String?;
    WageType? defaultWageType;
    if (wageTypeStr != null) {
      try {
        defaultWageType = WageType.values.firstWhere(
          (type) => type.name == wageTypeStr,
        );
      } catch (_) {
        defaultWageType = null;
      }
    }

    return OrganizationJobRole(
      id: json['jobRoleId'] as String? ?? docId,
      title: json['title'] as String? ?? 'Untitled',
      department: json['department'] as String?,
      description: json['description'] as String?,
      colorHex: json['colorHex'] as String? ?? '#6F4BFF',
      defaultWageType: defaultWageType,
      sortOrder: json['sortOrder'] as int?,
    );
  }

  OrganizationJobRole copyWith({
    String? id,
    String? title,
    String? department,
    String? description,
    String? colorHex,
    WageType? defaultWageType,
    int? sortOrder,
  }) {
    return OrganizationJobRole(
      id: id ?? this.id,
      title: title ?? this.title,
      department: department ?? this.department,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      defaultWageType: defaultWageType ?? this.defaultWageType,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
