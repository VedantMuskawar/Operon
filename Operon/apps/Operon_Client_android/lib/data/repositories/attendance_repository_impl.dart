import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required EmployeesDataSource employeesDataSource,
    required EmployeeAttendanceDataSource attendanceDataSource,
  })  : _employeesDataSource = employeesDataSource,
        _attendanceDataSource = attendanceDataSource;

  final EmployeesDataSource _employeesDataSource;
  final EmployeeAttendanceDataSource _attendanceDataSource;

  /// Normalize date to start of day for comparison
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get year-month string in "YYYY-MM" format
  String _getYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  bool _isFullMonthRange(DateTime startDate, DateTime endDate) {
    if (startDate.year != endDate.year || startDate.month != endDate.month) {
      return false;
    }
    final lastDay = _getTotalDaysInMonth(startDate);
    return startDate.day == 1 && endDate.day == lastDay;
  }

  /// Calculate days present/absent from daily records for a given month
  (int present, int absent) _calculateDaysForMonth(
    List<DailyAttendanceRecord> dailyRecords,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final presentDays = <DateTime>{};
    final absentDays = <DateTime>{};

    for (final record in dailyRecords) {
      final recordDate = _normalizeDate(record.date);
      if (recordDate.isAfter(monthEnd) || recordDate.isBefore(monthStart)) {
        continue;
      }

      if (record.isPresent) {
        presentDays.add(recordDate);
      } else {
        absentDays.add(recordDate);
      }
    }

    // Generate all days in month and mark missing as absent
    var currentDate = monthStart;
    while (!currentDate.isAfter(monthEnd)) {
      final normalized = _normalizeDate(currentDate);
      if (!presentDays.contains(normalized) && !absentDays.contains(normalized)) {
        // Only mark as absent if we have records but this date is missing
        // For now, we only count days with records
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return (presentDays.length, absentDays.length);
  }

  /// Get month summary string (e.g., "15/30 days")
  String _getMonthSummary(
    int daysPresent,
    int totalDaysInMonth,
  ) {
    return '$daysPresent/$totalDaysInMonth days';
  }

  /// Get total days in a month
  int _getTotalDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  @override
  Future<Map<String, RoleAttendanceGroup>> getAttendanceByRole({
    required String organizationId,
    required String yearMonth, // "YYYY-MM"
  }) async {
    // Parse yearMonth to get start/end of month
    final parts = yearMonth.split('-');
    if (parts.length != 2) {
      throw ArgumentError('yearMonth must be in format YYYY-MM');
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month, _getTotalDaysInMonth(monthStart));

    // Fetch all employees for the organization
    final employees = await _employeesDataSource.fetchEmployees(organizationId);

    if (employees.isEmpty) {
      return {};
    }

    final financialYear = FinancialYearUtils.getFinancialYear(monthStart);

    final attendanceDocs = await _attendanceDataSource
        .fetchAttendanceForMonthForOrganization(
      organizationId: organizationId,
      financialYear: financialYear,
      yearMonth: yearMonth,
    );

    final attendanceByEmployeeId = <String, EmployeeAttendance>{
      for (final attendance in attendanceDocs) attendance.employeeId: attendance,
    };

    final attendanceDataList = employees.map((employee) {
      final attendance = attendanceByEmployeeId[employee.id];
      final dailyRecords = attendance?.dailyRecords ?? <DailyAttendanceRecord>[];

      final (daysPresent, daysAbsent) =
          _calculateDaysForMonth(dailyRecords, monthStart, monthEnd);

      final totalDaysInMonth = _getTotalDaysInMonth(monthStart);
      final monthSummary = _getMonthSummary(daysPresent, totalDaysInMonth);

      final effectiveRoleTitle =
          employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle;

      return EmployeeAttendanceData(
        employeeId: employee.id,
        employeeName: employee.name,
        roleTitle: effectiveRoleTitle,
        dailyRecords: dailyRecords,
        daysPresent: daysPresent,
        daysAbsent: daysAbsent,
        monthSummary: monthSummary,
      );
    }).toList();

    // Group by role
    final roleGroups = <String, List<EmployeeAttendanceData>>{};
    for (final attendanceData in attendanceDataList) {
      final roleKey = attendanceData.roleTitle;
      roleGroups.putIfAbsent(roleKey, () => []).add(attendanceData);
    }

    // Convert to RoleAttendanceGroup map
    final result = <String, RoleAttendanceGroup>{};
    for (final entry in roleGroups.entries) {
      final employees = entry.value;
      final totalPresent = employees.fold<int>(0, (sum, e) => sum + e.daysPresent);
      final totalAbsent = employees.fold<int>(0, (sum, e) => sum + e.daysAbsent);

      result[entry.key] = RoleAttendanceGroup(
        roleTitle: entry.key,
        employees: employees,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
      );
    }

    return result;
  }

  @override
  Future<Map<String, RoleAttendanceGroup>> getAttendanceByRoleForDateRange({
    required String organizationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_isFullMonthRange(startDate, endDate)) {
      return getAttendanceByRole(
        organizationId: organizationId,
        yearMonth: _getYearMonth(startDate),
      );
    }
    // Fetch all employees for the organization
    final employees = await _employeesDataSource.fetchEmployees(organizationId);

    if (employees.isEmpty) {
      return {};
    }

    // Calculate financial year for date range (use start date)
    final financialYear = FinancialYearUtils.getFinancialYear(startDate);

    // Fetch attendance for all employees in parallel
    final attendanceFutures = employees.map((employee) async {
      try {
        final attendanceList = await _attendanceDataSource
            .fetchAttendanceForDateRange(
          employeeId: employee.id,
          financialYear: financialYear,
          startDate: startDate,
          endDate: endDate,
        );

        // Combine all daily records from all month documents
        final allDailyRecords = <DailyAttendanceRecord>[];
        for (final attendance in attendanceList) {
          // Filter records to be within the date range during iteration
          final filteredRecords = attendance.dailyRecords.where((record) {
            final recordDate = _normalizeDate(record.date);
            return !recordDate.isBefore(_normalizeDate(startDate)) &&
                !recordDate.isAfter(_normalizeDate(endDate));
          }).toList();
          // Only add if has records in range
          if (filteredRecords.isNotEmpty) {
            allDailyRecords.addAll(filteredRecords);
          }
        }

        // Calculate statistics
        final monthStart = DateTime(startDate.year, startDate.month, 1);
        final monthEnd = DateTime(endDate.year, endDate.month,
            _getTotalDaysInMonth(DateTime(endDate.year, endDate.month, 1)));
        final (daysPresent, daysAbsent) =
            _calculateDaysForMonth(allDailyRecords, monthStart, monthEnd);

        final totalDaysInMonth = _getTotalDaysInMonth(monthStart);
        final monthSummary = _getMonthSummary(daysPresent, totalDaysInMonth);

        // Use primaryJobRoleTitle from shared OrganizationEmployee entity
        final effectiveRoleTitle = employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle;
        
        return EmployeeAttendanceData(
          employeeId: employee.id,
          employeeName: employee.name,
          roleTitle: effectiveRoleTitle,
          dailyRecords: allDailyRecords,
          daysPresent: daysPresent,
          daysAbsent: daysAbsent,
          monthSummary: monthSummary,
        );
      } catch (e) {
        // If attendance fetch fails, return empty data for this employee
        final effectiveRoleTitle = employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle;
        
        return EmployeeAttendanceData(
          employeeId: employee.id,
          employeeName: employee.name,
          roleTitle: effectiveRoleTitle,
          dailyRecords: [],
          daysPresent: 0,
          daysAbsent: 0,
          monthSummary: '0/0 days',
        );
      }
    });

    final attendanceDataList = await Future.wait(attendanceFutures);

    // Group by role
    final roleGroups = <String, List<EmployeeAttendanceData>>{};
    for (final attendanceData in attendanceDataList) {
      final roleKey = attendanceData.roleTitle;
      roleGroups.putIfAbsent(roleKey, () => []).add(attendanceData);
    }

    // Convert to RoleAttendanceGroup map
    final result = <String, RoleAttendanceGroup>{};
    for (final entry in roleGroups.entries) {
      final employees = entry.value;
      final totalPresent = employees.fold<int>(0, (sum, e) => sum + e.daysPresent);
      final totalAbsent = employees.fold<int>(0, (sum, e) => sum + e.daysAbsent);

      result[entry.key] = RoleAttendanceGroup(
        roleTitle: entry.key,
        employees: employees,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
      );
    }

    return result;
  }

  @override
  Future<void> updateAttendance({
    required String employeeId,
    required DateTime date,
    required bool isPresent,
    String? organizationId,
  }) {
    // Android app is read-only, so this method should not be called
    throw UnimplementedError(
      'updateAttendance is not supported in Android app. Use Web app for editing attendance.',
    );
  }

  @override
  Future<void> markAttendance({
    required String organizationId,
    required DateTime date,
    required List<String> employeeIds,
    required bool isPresent,
  }) {
    // Android app is read-only, so this method should not be called
    throw UnimplementedError(
      'markAttendance is not supported in Android app. Use Web app for editing attendance.',
    );
  }
}
