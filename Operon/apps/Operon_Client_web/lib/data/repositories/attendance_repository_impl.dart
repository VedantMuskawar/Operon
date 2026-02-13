import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required EmployeesRepository employeesRepository,
    required EmployeeAttendanceDataSource attendanceDataSource,
  })  : _employeesRepository = employeesRepository,
        _attendanceDataSource = attendanceDataSource;

  final EmployeesRepository _employeesRepository;
  final EmployeeAttendanceDataSource _attendanceDataSource;

  final Map<String, ({DateTime timestamp, Map<String, RoleAttendanceGroup> data})> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  /// Get year-month string in "YYYY-MM" format
  String _getYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Calculate financial year label from a date
  /// Financial year starts in April (month 4)
  /// Format: FY2425 (for April 2024 - March 2025)
  String _getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    if (month >= 4) {
      final startYear = year % 100;
      final endYear = (year + 1) % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    } else {
      final startYear = (year - 1) % 100;
      final endYear = year % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    }
  }

  /// Normalize date to start of day for comparison
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

    for (final record in dailyRecords) {
      final recordDate = _normalizeDate(record.date);
      if (recordDate.isAfter(monthEnd) || recordDate.isBefore(monthStart)) {
        continue;
      }

      if (record.isPresent) {
        presentDays.add(recordDate);
      }
    }

    return (presentDays.length, 0); // Only count present days for now
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
    final cacheKey = '${organizationId}_$yearMonth';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.data;
    }
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
    final employees = await _employeesRepository.fetchEmployees(organizationId);

    if (employees.isEmpty) {
      return {};
    }

    final financialYear = _getFinancialYear(monthStart);

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

      return EmployeeAttendanceData(
        employeeId: employee.id,
        employeeName: employee.name,
        roleTitle: employee.primaryJobRoleTitle.isEmpty
            ? 'No Role'
            : employee.primaryJobRoleTitle,
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

    _cache[cacheKey] = (timestamp: DateTime.now(), data: result);
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
    final employees = await _employeesRepository.fetchEmployees(organizationId);

    if (employees.isEmpty) {
      return {};
    }

    // Calculate financial year for date range (use start date)
    final financialYear = _getFinancialYear(startDate);

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

        return EmployeeAttendanceData(
          employeeId: employee.id,
          employeeName: employee.name,
          roleTitle:
              employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle,
          dailyRecords: allDailyRecords,
          daysPresent: daysPresent,
          daysAbsent: daysAbsent,
          monthSummary: monthSummary,
        );
      } catch (e) {
        // If attendance fetch fails, return empty data for this employee
        return EmployeeAttendanceData(
          employeeId: employee.id,
          employeeName: employee.name,
          roleTitle:
              employee.primaryJobRoleTitle.isEmpty ? 'No Role' : employee.primaryJobRoleTitle,
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
  }) async {
    // For Web app, we need to update the attendance record
    // Get or create the month document and update the daily record
    final financialYear = _getFinancialYear(date);
    final yearMonth = _getYearMonth(date);
    final normalizedDate = _normalizeDate(date);

    // Fetch existing attendance for the month
    EmployeeAttendance? existingAttendance =
        await _attendanceDataSource.fetchAttendanceForMonth(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
    );

    List<DailyAttendanceRecord> dailyRecords;
    if (existingAttendance != null) {
      dailyRecords = List<DailyAttendanceRecord>.from(existingAttendance.dailyRecords);

      // Find existing record for this date
      final dateIndex = dailyRecords.indexWhere((record) {
        return _normalizeDate(record.date) == normalizedDate;
      });

      if (dateIndex >= 0) {
        // Update existing record
        final existingRecord = dailyRecords[dateIndex];
        dailyRecords[dateIndex] = existingRecord.copyWith(
          isPresent: isPresent,
        );
      } else {
        // Create new record for this date
        dailyRecords.add(
          DailyAttendanceRecord(
            date: normalizedDate,
            isPresent: isPresent,
            numberOfBatches: 0,
            batchIds: [],
          ),
        );
      }
    } else {
      // Create new attendance document
      dailyRecords = [
        DailyAttendanceRecord(
          date: normalizedDate,
          isPresent: isPresent,
          numberOfBatches: 0,
          batchIds: [],
        ),
      ];
    }

    // Recalculate totals
    final totalDaysPresent =
        dailyRecords.where((record) => record.isPresent).length;
    final totalBatchesWorked =
        dailyRecords.fold<int>(0, (sum, record) => sum + record.numberOfBatches);

    // Get organization ID from existing attendance or fetch from employee
    String resolvedOrganizationId = organizationId?.trim() ?? '';
    if (resolvedOrganizationId.isEmpty) {
      resolvedOrganizationId = existingAttendance?.organizationId ?? '';
    }
    if (resolvedOrganizationId.isEmpty) {
      // Fetch employee to get organization ID for new attendance
      final employee = await _employeesRepository.fetchEmployee(employeeId);
      resolvedOrganizationId = employee?.organizationId ?? '';
    }

    // Create or update attendance document
    final updatedAttendance = EmployeeAttendance(
      yearMonth: yearMonth,
      employeeId: employeeId,
      organizationId: resolvedOrganizationId,
      financialYear: financialYear,
      dailyRecords: dailyRecords,
      totalDaysPresent: totalDaysPresent,
      totalBatchesWorked: totalBatchesWorked,
      createdAt: existingAttendance?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _attendanceDataSource.updateAttendanceRecord(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
      attendance: updatedAttendance,
    );

    if (resolvedOrganizationId.isNotEmpty) {
      _cache.remove('${resolvedOrganizationId}_$yearMonth');
    }
  }

  @override
  Future<void> markAttendance({
    required String organizationId,
    required DateTime date,
    required List<String> employeeIds,
    required bool isPresent,
  }) async {
    // Mark attendance for multiple employees in parallel
    final futures = employeeIds.map((employeeId) {
      return updateAttendance(
        employeeId: employeeId,
        date: date,
        isPresent: isPresent,
        organizationId: organizationId,
      );
    });

    await Future.wait(futures);
  }
}
