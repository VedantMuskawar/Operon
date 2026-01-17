import 'package:core_models/core_models.dart';

/// Represents a group of employees with their attendance data, grouped by role
class RoleAttendanceGroup {
  const RoleAttendanceGroup({
    required this.roleTitle,
    required this.employees,
    this.totalPresent = 0,
    this.totalAbsent = 0,
  });

  final String roleTitle;
  final List<EmployeeAttendanceData> employees;
  final int totalPresent;
  final int totalAbsent;

  RoleAttendanceGroup copyWith({
    String? roleTitle,
    List<EmployeeAttendanceData>? employees,
    int? totalPresent,
    int? totalAbsent,
  }) {
    return RoleAttendanceGroup(
      roleTitle: roleTitle ?? this.roleTitle,
      employees: employees ?? this.employees,
      totalPresent: totalPresent ?? this.totalPresent,
      totalAbsent: totalAbsent ?? this.totalAbsent,
    );
  }
}

/// Represents attendance data for a single employee
class EmployeeAttendanceData {
  const EmployeeAttendanceData({
    required this.employeeId,
    required this.employeeName,
    required this.roleTitle,
    required this.dailyRecords,
    required this.daysPresent,
    required this.daysAbsent,
    required this.monthSummary,
  });

  final String employeeId;
  final String employeeName;
  final String roleTitle;
  final List<DailyAttendanceRecord> dailyRecords;
  final int daysPresent;
  final int daysAbsent;
  final String monthSummary; // e.g., "15/30 days"

  EmployeeAttendanceData copyWith({
    String? employeeId,
    String? employeeName,
    String? roleTitle,
    List<DailyAttendanceRecord>? dailyRecords,
    int? daysPresent,
    int? daysAbsent,
    String? monthSummary,
  }) {
    return EmployeeAttendanceData(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      roleTitle: roleTitle ?? this.roleTitle,
      dailyRecords: dailyRecords ?? this.dailyRecords,
      daysPresent: daysPresent ?? this.daysPresent,
      daysAbsent: daysAbsent ?? this.daysAbsent,
      monthSummary: monthSummary ?? this.monthSummary,
    );
  }
}
