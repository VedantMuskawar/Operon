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
    super.message,
  });

  final Map<String, RoleAttendanceGroup>? roleGroups;
  final String? selectedYearMonth;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  @override
  AttendanceState copyWith({
    ViewStatus? status,
    Map<String, RoleAttendanceGroup>? roleGroups,
    String? selectedYearMonth,
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    String? message,
    bool clearMessage = false,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      roleGroups: roleGroups ?? this.roleGroups,
      selectedYearMonth: selectedYearMonth ?? this.selectedYearMonth,
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate: selectedEndDate ?? this.selectedEndDate,
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
  final Map<String,
          ({DateTime timestamp, Map<String, RoleAttendanceGroup> data})>
      _cache = {};
  static const _cacheTTL = Duration(minutes: 2);

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
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheTTL) {
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
      print('❌ Error loading attendance for $yearMonth: $e');
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
    final cacheKey =
        '${_organizationId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheTTL) {
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
      print('❌ Error loading attendance for date range: $e');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load attendance. Please try again.',
      ));
    }
  }

  /// Refresh current attendance data
  Future<void> refresh() async {
    if (state.selectedYearMonth != null) {
      await loadAttendanceForMonth(state.selectedYearMonth!);
    } else if (state.selectedStartDate != null &&
        state.selectedEndDate != null) {
      await loadAttendanceForDateRange(
        startDate: state.selectedStartDate!,
        endDate: state.selectedEndDate!,
      );
    } else {
      await loadAttendanceForCurrentMonth();
    }
  }
}
