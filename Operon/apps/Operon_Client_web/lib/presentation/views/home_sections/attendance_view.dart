import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/attendance/attendance_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Attendance view for Web - Editable view grouped by role
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

    return const _AttendanceViewContent();
  }
}

class _AttendanceViewContent extends StatefulWidget {
  const _AttendanceViewContent();

  @override
  State<_AttendanceViewContent> createState() => _AttendanceViewContentState();
}

class _AttendanceViewContentState extends State<_AttendanceViewContent> {
  DateTime _selectedStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedEndDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  String _formatMonthYear(DateTime date) {
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

  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
      context.read<AttendanceCubit>().loadAttendanceForDateRange(
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceCubit, AttendanceState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.roleGroups == null) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
            ),
          );
        }

        if (state.status == ViewStatus.failure) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: AuthColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  state.message ?? 'Failed to load attendance',
                  style: const TextStyle(color: AuthColors.textMain),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
          );
        }

        final roleGroups = state.roleGroups ?? {};

        // Calculate summary stats
        int totalPresent = 0;
        int totalAbsent = 0;
        int totalEmployees = 0;
        for (final group in roleGroups.values) {
          totalPresent += group.totalPresent;
          totalAbsent += group.totalAbsent;
          totalEmployees += group.employees.length;
        }

        final attendanceRate = totalEmployees > 0
            ? ((totalPresent / (totalPresent + totalAbsent)) * 100)
            : 0.0;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date picker
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Text(
                      'Attendance Management',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _selectDateRange(context),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        '${_formatMonthYear(_selectedStartDate)} - ${_formatMonthYear(_selectedEndDate)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuthColors.textMain,
                        side: BorderSide(color: AuthColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              // Summary cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.check_circle_outline,
                        label: 'Total Present',
                        value: totalPresent.toString(),
                        color: AuthColors.success,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.cancel_outlined,
                        label: 'Total Absent',
                        value: totalAbsent.toString(),
                        color: AuthColors.error,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.trending_up,
                        label: 'Attendance Rate',
                        value: '${attendanceRate.toStringAsFixed(1)}%',
                        color: AuthColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.people_outline,
                        label: 'Employees',
                        value: totalEmployees.toString(),
                        color: AuthColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Role groups
              if (roleGroups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No attendance data available',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  ),
                )
              else
                ...roleGroups.values.map((group) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: _RoleGroup(
                      group: group,
                      startDate: _selectedStartDate,
                      endDate: _selectedEndDate,
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleGroup extends StatefulWidget {
  const _RoleGroup({
    required this.group,
    required this.startDate,
    required this.endDate,
  });

  final RoleAttendanceGroup group;
  final DateTime startDate;
  final DateTime endDate;

  @override
  State<_RoleGroup> createState() => _RoleGroupState();
}

class _RoleGroupState extends State<_RoleGroup> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Role header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.roleTitle,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.group.employees.length} employees • ${widget.group.totalPresent} present',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AuthColors.textSub,
                  ),
                ],
              ),
            ),
          ),
          // Attendance grid
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: _AttendanceGrid(
                employees: widget.group.employees,
                startDate: widget.startDate,
                endDate: widget.endDate,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceGrid extends StatelessWidget {
  const _AttendanceGrid({
    required this.employees,
    required this.startDate,
    required this.endDate,
  });

  final List<EmployeeAttendanceData> employees;
  final DateTime startDate;
  final DateTime endDate;

  String _getMonthAbbr(int month) {
    const monthAbbrs = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return monthAbbrs[month - 1];
  }

  List<DateTime> _getDateRange() {
    final dates = <DateTime>[];
    var current = startDate;
    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  bool _isPresentOnDate(EmployeeAttendanceData employee, DateTime date) {
    return employee.dailyRecords.any((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      final checkDate = DateTime(date.year, date.month, date.day);
      return recordDate == checkDate && record.isPresent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getDateRange();
    final cubit = context.read<AttendanceCubit>();
    
    // Calculate total table width
    final tableWidth = 150.0 + (dates.length * 60.0) + 100.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header row
          Container(
            color: AuthColors.background,
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Employee',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ...dates.map((date) {
                  return SizedBox(
                    width: 60,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${date.day} ${_getMonthAbbr(date.month)}',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
                SizedBox(
                  width: 100,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Summary',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows with ListView.builder for virtualization
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return Container(
                color: AuthColors.background,
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          employee.employeeName,
                          style: const TextStyle(color: AuthColors.textMain),
                        ),
                      ),
                    ),
                    ...dates.map((date) {
                      final isPresent = _isPresentOnDate(employee, date);
                      return SizedBox(
                        width: 60,
                        child: Center(
                          child: IconButton(
                            icon: Icon(
                              isPresent ? Icons.check_circle : Icons.cancel,
                              color: isPresent ? AuthColors.success : AuthColors.error,
                              size: 20,
                            ),
                            onPressed: () {
                              cubit.updateEmployeeAttendance(
                                employeeId: employee.employeeId,
                                date: date,
                                isPresent: !isPresent,
                              );
                            },
                          ),
                        ),
                      );
                    }),
                    SizedBox(
                      width: 100,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          employee.monthSummary,
                          style: const TextStyle(color: AuthColors.textSub),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}
