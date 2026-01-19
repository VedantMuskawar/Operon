import 'package:core_models/entities/employee_job_role.dart';
import 'package:core_models/entities/employee_wage.dart';

/// Organization Employee - Represents an employee in an organization
class OrganizationEmployee {
  const OrganizationEmployee({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.jobRoleIds,
    required this.jobRoles,
    required this.wage,
    required this.openingBalance,
    required this.currentBalance,
  });

  final String id;
  final String organizationId;
  final String name;
  
  // Multiple Job Roles Support
  final List<String> jobRoleIds;                        // Array of job role IDs
  final Map<String, EmployeeJobRole> jobRoles;          // Denormalized job role details
  
  // Wage Structure (per-employee, not per-role)
  final EmployeeWage wage;
  
  // Financial
  final double openingBalance;
  final double currentBalance;

  /// Get primary job role ID
  String get primaryJobRoleId {
    final primary = jobRoles.values.where((r) => r.isPrimary).firstOrNull;
    return primary?.jobRoleId ?? (jobRoleIds.isNotEmpty ? jobRoleIds.first : '');
  }

  /// Get primary job role title
  String get primaryJobRoleTitle {
    final primary = jobRoles.values.where((r) => r.isPrimary).firstOrNull;
    return primary?.jobRoleTitle ?? '';
  }

  /// Get all job role titles as comma-separated string
  String get jobRoleTitles {
    return jobRoles.values.map((r) => r.jobRoleTitle).join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': id,
      'organizationId': organizationId,
      'employeeName': name,
      'jobRoleIds': jobRoleIds,
      'jobRoles': jobRoles.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'wage': wage.toJson(),
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
    };
  }

  factory OrganizationEmployee.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    // Parse job role IDs
    final jobRoleIdsList = json['jobRoleIds'] as List<dynamic>?;
    final jobRoleIds = jobRoleIdsList?.map((e) => e as String).toList() ?? [];

    // Parse job roles map
    final jobRolesMap = json['jobRoles'] as Map<String, dynamic>? ?? {};
    final jobRoles = jobRolesMap.map(
      (key, value) => MapEntry(
        key,
        EmployeeJobRole.fromJson(value as Map<String, dynamic>),
      ),
    );

    // Backward compatibility: If jobRoles is empty but jobRoleTitle exists, create a jobRole entry
    if (jobRoles.isEmpty) {
      final jobRoleTitle = json['jobRoleTitle'] as String?;
      final roleTitle = json['roleTitle'] as String?;
      final effectiveJobRoleTitle = jobRoleTitle ?? roleTitle;
      
      if (effectiveJobRoleTitle != null && effectiveJobRoleTitle.isNotEmpty) {
        // Try to use roleId if available, otherwise generate a temporary ID
        final roleId = json['roleId'] as String? ?? 'legacy_role';
        
        // Create a single job role entry from legacy fields
        final legacyJobRole = EmployeeJobRole(
          jobRoleId: roleId,
          jobRoleTitle: effectiveJobRoleTitle,
          assignedAt: DateTime.now(),
          isPrimary: true,
        );
        
        jobRoles[roleId] = legacyJobRole;
        if (jobRoleIds.isEmpty) {
          jobRoleIds.add(roleId);
        }
      }
    }

    // Parse wage
    final wageJson = json['wage'] as Map<String, dynamic>?;
    EmployeeWage wage;
    if (wageJson != null) {
      wage = EmployeeWage.fromJson(wageJson);
    } else {
      // Backward compatibility: Convert old salaryType/salaryAmount to wage
      final salaryTypeStr = json['salaryType'] as String?;
      final salaryAmount = (json['salaryAmount'] as num?)?.toDouble();
      
      WageType wageType = WageType.perMonth;
      if (salaryTypeStr != null) {
        // Map old SalaryType to WageType
        switch (salaryTypeStr.toLowerCase()) {
          case 'salarymonthly':
          case 'fixed':
            wageType = WageType.perMonth;
            break;
          case 'commission':
            wageType = WageType.commission;
            break;
          case 'hybrid':
            wageType = WageType.hybrid;
            break;
        }
      }
      
      wage = EmployeeWage(
        type: wageType,
        baseAmount: salaryAmount,
      );
    }

    return OrganizationEmployee(
      id: json['employeeId'] as String? ?? docId,
      organizationId: json['organizationId'] as String? ?? '',
      name: json['employeeName'] as String? ?? '',
      jobRoleIds: jobRoleIds,
      jobRoles: jobRoles,
      wage: wage,
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
    );
  }

  OrganizationEmployee copyWith({
    String? id,
    String? organizationId,
    String? name,
    List<String>? jobRoleIds,
    Map<String, EmployeeJobRole>? jobRoles,
    EmployeeWage? wage,
    double? openingBalance,
    double? currentBalance,
  }) {
    return OrganizationEmployee(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      jobRoleIds: jobRoleIds ?? this.jobRoleIds,
      jobRoles: jobRoles ?? this.jobRoles,
      wage: wage ?? this.wage,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}
