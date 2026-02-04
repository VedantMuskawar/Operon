import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/data/repositories/attendance_repository_impl.dart';
import 'package:dash_mobile/presentation/blocs/attendance/attendance_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Attendance view for Android - Table-based view grouped by role
class AttendanceView extends StatelessWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Center(
        child: Text(
          'No organization selected',
          style: TextStyle(color: AuthColors.textMain),
        ),
      );
    }

    // Check if AttendanceCubit is already provided (e.g., in attendance_page.dart)
    try {
      context.read<AttendanceCubit>();
      // Provider exists, use it directly
      return const _AttendanceViewContent();
    } catch (_) {
      // Provider doesn't exist, create it (e.g., when used in home_page)
      return BlocProvider<AttendanceCubit>(
        create: (context) {
          final employeesDataSource = EmployeesDataSource();
          final attendanceDataSource = EmployeeAttendanceDataSource();
          final repository = AttendanceRepositoryImpl(
            employeesDataSource: employeesDataSource,
            attendanceDataSource: attendanceDataSource,
          );
          return AttendanceCubit(
            repository: repository,
            organizationId: organization.id,
          )..loadAttendanceForCurrentMonth();
        },
        child: const _AttendanceViewContent(),
      );
    }
  }
}

class _AttendanceViewContent extends StatelessWidget {
  const _AttendanceViewContent();

  /// Parse yearMonth string (YYYY-MM) to DateTime
  DateTime? _parseYearMonth(String? yearMonth) {
    if (yearMonth == null) return null;
    try {
      final parts = yearMonth.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return DateTime(year, month, 1);
      }
    } catch (_) {}
    return null;
  }

  /// Format month/year for display
  String _formatMonthYear(String? yearMonth) {
    if (yearMonth == null) return '';
    final date = _parseYearMonth(yearMonth);
    if (date == null) return yearMonth;
    
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.roleGroups == null) {
          return SizedBox.expand(
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
              ),
            ),
          );
        }

        if (state.status == ViewStatus.failure) {
          return SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AuthColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                  Text(
                    state.message ?? 'Failed to load attendance',
                    style: const TextStyle(color: AuthColors.textMain),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                  ElevatedButton(
                    onPressed: () => context.read<AttendanceCubit>().refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final roleGroups = state.roleGroups ?? {};
        final now = DateTime.now();
        final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final selectedYearMonth = state.selectedYearMonth ?? currentMonth;
        final monthDate = _parseYearMonth(selectedYearMonth) ?? DateTime.now();
        final monthYearDisplay = _formatMonthYear(selectedYearMonth);

        return SizedBox.expand(
          child: Column(
            children: [
              // Month Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingLG),
                child: _MonthPicker(
                  selectedYearMonth: selectedYearMonth,
                  onMonthSelected: (yearMonth) {
                    context.read<AttendanceCubit>().loadAttendanceForMonth(yearMonth);
                  },
                ),
              ),
              // Tables by Role
              if (roleGroups.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No attendance data available for $monthYearDisplay',
                      style: const TextStyle(color: AuthColors.textSub),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.paddingXXXL * 2.5),
                    itemCount: roleGroups.length,
                    itemBuilder: (context, index) {
                      final group = roleGroups.values.elementAt(index);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingSM),
                        child: _RoleAttendanceTable(
                          roleTitle: group.roleTitle,
                          employees: group.employees,
                          monthDate: monthDate,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Month picker widget
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.selectedYearMonth,
    required this.onMonthSelected,
  });

  final String selectedYearMonth;
  final Function(String yearMonth) onMonthSelected;

  String _formatMonthYear(String yearMonth) {
    try {
      final parts = yearMonth.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        if (month >= 1 && month <= 12) {
          return '${monthNames[month - 1]} $year';
        }
      }
    } catch (_) {}
    return yearMonth;
  }

  Future<void> _selectMonth(BuildContext context) async {
    final currentDate = DateTime.now();
    final selectedDate = DateTime(currentDate.year, currentDate.month, 1);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(currentDate.year + 1, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: Colors.white,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ), dialogTheme: DialogThemeData(backgroundColor: AuthColors.surface),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final yearMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      onMonthSelected(yearMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _selectMonth(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: AuthColors.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AuthColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.paddingMD),
                Text(
                  _formatMonthYear(selectedYearMonth),
                  style: AppTypography.withColor(
                    AppTypography.withWeight(AppTypography.h4, FontWeight.w600),
                    AuthColors.textMain,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AuthColors.textSub,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Table widget for employees grouped by role
class _RoleAttendanceTable extends StatelessWidget {
  const _RoleAttendanceTable({
    required this.roleTitle,
    required this.employees,
    required this.monthDate,
  });

  final String roleTitle;
  final List<EmployeeAttendanceData> employees;
  final DateTime monthDate;

  /// Get total days in a month
  int _getTotalDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  /// Get attendance ratio (X/Y)
  String _getAttendanceRatio(EmployeeAttendanceData employeeData) {
    final totalDays = _getTotalDaysInMonth(monthDate);
    return '${employeeData.daysPresent}/$totalDays';
  }

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: AuthColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Role Title Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  roleTitle,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.paddingSM),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM, vertical: AppSpacing.paddingXS),
                  decoration: BoxDecoration(
                    color: AuthColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  ),
                  child: Text(
                    '${employees.length}',
                    style: AppTypography.withColor(
                      AppTypography.withWeight(AppTypography.labelSmall, FontWeight.w600),
                      AuthColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              // Handle unbounded constraints by using a default width
              final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : 400.0; // Default width when constraints are unbounded
              
              final col1Width = (availableWidth * 0.6).clamp(150.0, 300.0);
              final col2Width = (availableWidth * 0.4).clamp(100.0, 200.0);
              final minTableWidth = col1Width + col2Width;
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth.isFinite && constraints.maxWidth > 0
                        ? constraints.maxWidth
                        : minTableWidth,
                  ),
                  child: Table(
                    border: TableBorder.all(
                      color: AuthColors.primary.withOpacity(0.3),
                      width: 1,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                    ),
                    columnWidths: {
                      0: FixedColumnWidth(col1Width),
                      1: FixedColumnWidth(col2Width),
                    },
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(
                          color: AuthColors.primary.withOpacity(0.1),
                        ),
                        children: [
                          _buildTableCell('Employee Name', isHeader: true),
                          _buildTableCell('Attendance', isHeader: true),
                        ],
                      ),
                      // Data Rows
                      ...employees.map((employee) {
                        return TableRow(
                          children: [
                            _buildTableCell(employee.employeeName, isHeader: false),
                            _buildTableCell(_getAttendanceRatio(employee), isHeader: false),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD, horizontal: AppSpacing.paddingLG),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isHeader ? AuthColors.primary : AuthColors.textMain,
          fontSize: isHeader ? 14 : 15,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
