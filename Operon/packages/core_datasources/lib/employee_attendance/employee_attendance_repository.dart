import 'package:core_models/core_models.dart';
import 'package:core_datasources/employee_attendance/employee_attendance_data_source.dart';

class EmployeeAttendanceRepository {
  EmployeeAttendanceRepository({
    required EmployeeAttendanceDataSource dataSource,
  }) : _dataSource = dataSource;

  final EmployeeAttendanceDataSource _dataSource;

  /// Record attendance for an employee when processing a production batch
  Future<void> recordAttendanceForBatch({
    required String organizationId,
    required String employeeId,
    required DateTime batchDate,
    required String batchId,
  }) {
    return _dataSource.recordAttendanceForBatch(
      organizationId: organizationId,
      employeeId: employeeId,
      batchDate: batchDate,
      batchId: batchId,
    );
  }

  /// Fetch attendance for a specific month
  Future<EmployeeAttendance?> fetchAttendanceForMonth({
    required String employeeId,
    required String financialYear,
    required String yearMonth, // "YYYY-MM" format
  }) {
    return _dataSource.fetchAttendanceForMonth(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
    );
  }

  /// Fetch attendance for a date range
  Future<List<EmployeeAttendance>> fetchAttendanceForDateRange({
    required String employeeId,
    required String financialYear,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _dataSource.fetchAttendanceForDateRange(
      employeeId: employeeId,
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Update an existing attendance record
  Future<void> updateAttendanceRecord({
    required String employeeId,
    required String financialYear,
    required String yearMonth,
    required EmployeeAttendance attendance,
  }) {
    return _dataSource.updateAttendanceRecord(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
      attendance: attendance,
    );
  }

  /// Revert attendance for a batch (remove batch from attendance records)
  Future<void> revertAttendanceForBatch({
    required String organizationId,
    required String employeeId,
    required DateTime batchDate,
    required String batchId,
  }) {
    return _dataSource.revertAttendanceForBatch(
      organizationId: organizationId,
      employeeId: employeeId,
      batchDate: batchDate,
      batchId: batchId,
    );
  }
}
