import 'package:core_models/core_models.dart';

/// Repository interface for attendance management
abstract class AttendanceRepository {
  /// Fetch attendance for employees grouped by role for a specific month
  Future<Map<String, RoleAttendanceGroup>> getAttendanceByRole({
    required String organizationId,
    required String yearMonth, // "YYYY-MM"
  });

  /// Fetch attendance for employees grouped by role for a date range
  Future<Map<String, RoleAttendanceGroup>> getAttendanceByRoleForDateRange({
    required String organizationId,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Update attendance record for a specific employee and date (Web only)
  Future<void> updateAttendance({
    required String employeeId,
    required DateTime date,
    required bool isPresent,
    String? organizationId,
  });

  /// Mark attendance for multiple employees on a specific date (Web only)
  Future<void> markAttendance({
    required String organizationId,
    required DateTime date,
    required List<String> employeeIds,
    required bool isPresent,
  });
}
