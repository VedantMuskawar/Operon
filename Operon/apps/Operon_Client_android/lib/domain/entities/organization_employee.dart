import 'package:core_models/core_models.dart';

class OrganizationEmployee {
  const OrganizationEmployee({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.roleId,
    required this.roleTitle,
    required this.openingBalance,
    required this.currentBalance,
    required this.salaryType,
    this.salaryAmount,
  });

  final String id;
  final String organizationId;
  final String name;
  final String roleId;
  final String roleTitle;
  final double openingBalance;
  final double currentBalance;
  final SalaryType salaryType;
  final double? salaryAmount;

  Map<String, dynamic> toJson() {
    return {
      'employeeId': id,
      'organizationId': organizationId,
      'employeeName': name,
      'roleId': roleId,
      'roleTitle': roleTitle,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'salaryType': salaryType.name,
      'salaryAmount': salaryAmount,
    };
  }

  factory OrganizationEmployee.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    return OrganizationEmployee(
      id: json['employeeId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['employeeName'] as String? ?? '',
      roleId: json['roleId'] as String? ?? '',
      roleTitle: json['roleTitle'] as String? ?? '',
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      salaryType: SalaryType.values.firstWhere(
        (type) => type.name == json['salaryType'],
        orElse: () => SalaryType.salaryMonthly,
      ),
      salaryAmount: (json['salaryAmount'] as num?)?.toDouble(),
    );
  }
}

