
/// Employee Job Role Assignment
/// 
/// Represents an employee's assignment to a job role,
/// including metadata about when and which is primary.
class EmployeeJobRole {
  const EmployeeJobRole({
    required this.jobRoleId,
    required this.jobRoleTitle,
    required this.assignedAt,
    this.isPrimary = false,
  });

  final String jobRoleId;
  final String jobRoleTitle;      // Denormalized for quick access
  final DateTime assignedAt;
  final bool isPrimary;           // Primary role for display purposes

  Map<String, dynamic> toJson() {
    return {
      'jobRoleId': jobRoleId,
      'jobRoleTitle': jobRoleTitle,
      'assignedAt': assignedAt.toIso8601String(),
      'isPrimary': isPrimary,
    };
  }

  factory EmployeeJobRole.fromJson(Map<String, dynamic> json) {
    DateTime assignedAt;
    try {
      assignedAt = DateTime.parse(json['assignedAt'] as String);
    } catch (_) {
      assignedAt = DateTime.now();
    }

    return EmployeeJobRole(
      jobRoleId: json['jobRoleId'] as String? ?? '',
      jobRoleTitle: json['jobRoleTitle'] as String? ?? '',
      assignedAt: assignedAt,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  EmployeeJobRole copyWith({
    String? jobRoleId,
    String? jobRoleTitle,
    DateTime? assignedAt,
    bool? isPrimary,
  }) {
    return EmployeeJobRole(
      jobRoleId: jobRoleId ?? this.jobRoleId,
      jobRoleTitle: jobRoleTitle ?? this.jobRoleTitle,
      assignedAt: assignedAt ?? this.assignedAt,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
