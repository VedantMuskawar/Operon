import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AttendanceState extends BaseState {
  const AttendanceState({
    super.status = ViewStatus.initial,
    this.roleGroups,
    this.selectedYearMonth,
    this.selectedStartDate,
    this.selectedEndDate,
    this.isUpdating = false,
    this.message,
  }) : super(message: message);

  final Map<String, RoleAttendanceGroup>? roleGroups;
  final String? selectedYearMonth;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final bool isUpdating;
  @override
  final String? message;

  @override
  AttendanceState copyWith({
    ViewStatus? status,
    Map<String, RoleAttendanceGroup>? roleGroups,
    String? selectedYearMonth,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool? isUpdating,
    String? message,
    bool clearMessage = false,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      roleGroups: roleGroups ?? this.roleGroups,
      selectedYearMonth: selectedYearMonth ?? this.selectedYearMonth,
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
      isUpdating: isUpdating ?? this.isUpdating,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit({
    required AttendanceRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const AttendanceState());

  final AttendanceRepository _repository;
  final String _organizationId;

  // Cache key: '${organizationId}_$yearMonth' or '${organizationId}_${startDate}_${endDate}'
  final Map<String, ({DateTime timestamp, Map<String, RoleAttendanceGroup> data})> _cache = {};
  static const _cacheTTL = Duration(seconds: 30);

  String get organizationId => _organizationId;

  /// Get year-month string in "YYYY-MM" format
  String _getYearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Load attendance for current month
  Future<void> loadAttendanceForCurrentMonth() async {
    final now = DateTime.now();
    final yearMonth = _getYearMonth(now);
    await loadAttendanceForMonth(yearMonth);
  }

  /// Load attendance for a specific month
  Future<void> loadAttendanceForMonth(String yearMonth) async {
    final cacheKey = '${_organizationId}_$yearMonth';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTTL) {
      emit(state.copyWith(
        status: ViewStatus.success,
        roleGroups: cached.data,
        selectedYearMonth: yearMonth,
      ));
      return;
    }

    emit(state.copyWith(
      status: ViewStatus.loading,
      selectedYearMonth: yearMonth,
      message: null,
      clearMessage: true,
    ));

    try {
      final roleGroups = await _repository.getAttendanceByRole(
        organizationId: _organizationId,
        yearMonth: yearMonth,
      );

      _cache[cacheKey] = (timestamp: DateTime.now(), data: roleGroups);

      emit(state.copyWith(
        status: ViewStatus.success,
        roleGroups: roleGroups,
        selectedYearMonth: yearMonth,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load attendance. Please try again.',
      ));
    }
  }

  /// Load attendance for a date range
  Future<void> loadAttendanceForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cacheKey = '${_organizationId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTTL) {
      emit(state.copyWith(
        status: ViewStatus.success,
        roleGroups: cached.data,
        selectedStartDate: startDate,
        selectedEndDate: endDate,
      ));
      return;
    }

    emit(state.copyWith(
      status: ViewStatus.loading,
      selectedStartDate: startDate,
      selectedEndDate: endDate,
      message: null,
      clearMessage: true,
    ));

    try {
      final roleGroups = await _repository.getAttendanceByRoleForDateRange(
        organizationId: _organizationId,
        startDate: startDate,
        endDate: endDate,
      );

      _cache[cacheKey] = (timestamp: DateTime.now(), data: roleGroups);

      emit(state.copyWith(
        status: ViewStatus.success,
        roleGroups: roleGroups,
        selectedStartDate: startDate,
        selectedEndDate: endDate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load attendance. Please try again.',
      ));
    }
  }

  /// Update attendance for a specific employee and date
  Future<void> updateEmployeeAttendance({
    required String employeeId,
    required DateTime date,
    required bool isPresent,
  }) async {
    // Optimistic update
    final currentRoleGroups = Map<String, RoleAttendanceGroup>.from(
      state.roleGroups ?? {},
    );

    // Update the role groups optimistically
    for (final entry in currentRoleGroups.entries) {
      final roleGroup = entry.value;
      final updatedEmployees = roleGroup.employees.map((empData) {
        if (empData.employeeId == employeeId) {
          // Update the daily records
          final updatedRecords = List<DailyAttendanceRecord>.from(empData.dailyRecords);
          final normalizedDate = DateTime(date.year, date.month, date.day);

          // Find and update existing record or add new one
          final recordIndex = updatedRecords.indexWhere((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate == normalizedDate;
          });

          if (recordIndex >= 0) {
            // Update existing record
            updatedRecords[recordIndex] = updatedRecords[recordIndex].copyWith(
              isPresent: isPresent,
            );
          } else {
            // Add new record
            updatedRecords.add(
              DailyAttendanceRecord(
                date: normalizedDate,
                isPresent: isPresent,
                numberOfBatches: 0,
                batchIds: [],
              ),
            );
          }

          // Recalculate statistics
          final daysPresent = updatedRecords.where((r) => r.isPresent).length;
          final totalDaysInMonth = DateTime(date.year, date.month + 1, 0).day;
          final monthSummary = '$daysPresent/$totalDaysInMonth days';

          return empData.copyWith(
            dailyRecords: updatedRecords,
            daysPresent: daysPresent,
            monthSummary: monthSummary,
          );
        }
        return empData;
      }).toList();

      // Recalculate role group totals
      final totalPresent = updatedEmployees.fold<int>(0, (sum, e) => sum + e.daysPresent);
      final totalAbsent = updatedEmployees.fold<int>(0, (sum, e) => sum + e.daysAbsent);

      currentRoleGroups[entry.key] = roleGroup.copyWith(
        employees: updatedEmployees,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
      );
    }

    emit(state.copyWith(
      roleGroups: currentRoleGroups,
      isUpdating: true,
    ));

    try {
      await _repository.updateAttendance(
        employeeId: employeeId,
        date: date,
        isPresent: isPresent,
      );

      // Invalidate cache and refresh to get latest data
      _cache.clear();
      await refresh();

      emit(state.copyWith(isUpdating: false));
    } catch (e) {
      // Revert optimistic update on error
      await refresh();
      emit(state.copyWith(
        isUpdating: false,
        status: ViewStatus.failure,
        message: 'Unable to update attendance. Please try again.',
      ));
    }
  }

  /// Mark attendance for multiple employees on a specific date
  Future<void> bulkMarkAttendance({
    required DateTime date,
    required List<String> employeeIds,
    required bool isPresent,
  }) async {
    emit(state.copyWith(isUpdating: true));

    try {
      await _repository.markAttendance(
        organizationId: _organizationId,
        date: date,
        employeeIds: employeeIds,
        isPresent: isPresent,
      );

      // Invalidate cache and refresh to get latest data
      _cache.clear();
      await refresh();

      emit(state.copyWith(isUpdating: false));
    } catch (e) {
      emit(state.copyWith(
        isUpdating: false,
        status: ViewStatus.failure,
        message: 'Unable to mark attendance. Please try again.',
      ));
    }
  }

  /// Refresh current attendance data
  Future<void> refresh() async {
    if (state.selectedYearMonth != null) {
      await loadAttendanceForMonth(state.selectedYearMonth!);
    } else if (state.selectedStartDate != null && state.selectedEndDate != null) {
      await loadAttendanceForDateRange(
        startDate: state.selectedStartDate!,
        endDate: state.selectedEndDate!,
      );
    } else {
      await loadAttendanceForCurrentMonth();
    }
  }
}
