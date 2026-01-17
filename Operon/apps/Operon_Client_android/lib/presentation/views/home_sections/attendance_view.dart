import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/attendance/attendance_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Attendance view for Android - Read-only view grouped by role
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

class _AttendanceViewContent extends StatelessWidget {
  const _AttendanceViewContent();

  String _formatMonthYear(String? yearMonth) {
    if (yearMonth == null) return '';
    try {
      final parts = yearMonth.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
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
        if (month >= 1 && month <= 12) {
          return '${monthNames[month - 1]} $year';
        }
      }
    } catch (_) {}
    return yearMonth;
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
        final now = DateTime.now();
        final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final monthYear = _formatMonthYear(state.selectedYearMonth ?? currentMonth);

        // Calculate summary stats
        int totalPresent = 0;
        int totalEmployees = 0;
        for (final group in roleGroups.values) {
          totalPresent += group.totalPresent;
          totalEmployees += group.employees.length;
        }

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance - $monthYear',
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Summary cards
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.check_circle_outline,
                            label: 'Present Today',
                            value: totalPresent.toString(),
                            color: AuthColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.people_outline,
                            label: 'Employees',
                            value: totalEmployees.toString(),
                            color: AuthColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.calendar_today_outlined,
                            label: 'Rate',
                            value: totalEmployees > 0
                                ? '${((totalPresent / totalEmployees) * 100).toStringAsFixed(0)}%'
                                : '0%',
                            color: AuthColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Role groups
            if (roleGroups.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No attendance data available',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final group = roleGroups.values.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _RoleSection(group: group),
                    );
                  },
                  childCount: roleGroups.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
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
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSection extends StatefulWidget {
  const _RoleSection({required this.group});

  final RoleAttendanceGroup group;

  @override
  State<_RoleSection> createState() => _RoleSectionState();
}

class _RoleSectionState extends State<_RoleSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.roleTitle,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.group.employees.length} employees',
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
          // Employee list
          if (_isExpanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.group.employees.length,
              itemBuilder: (context, index) {
                return _EmployeeAttendanceTile(
                  employeeData: widget.group.employees[index],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmployeeAttendanceTile extends StatelessWidget {
  const _EmployeeAttendanceTile({required this.employeeData});

  final EmployeeAttendanceData employeeData;

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  Color _getEmployeeColor() {
    final hash = employeeData.employeeName.hashCode;
    final colors = [
      AuthColors.primary,
      AuthColors.success,
      AuthColors.secondary,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final employeeColor = _getEmployeeColor();
    final today = DateTime.now();
      final todayRecord = employeeData.dailyRecords.firstWhere(
      (record) {
        final recordDate = DateTime(
          record.date.year,
          record.date.month,
          record.date.day,
        );
        final todayDate = DateTime(today.year, today.month, today.day);
        return recordDate == todayDate;
      },
      orElse: () => DailyAttendanceRecord(
        date: DateTime.now(),
        isPresent: false,
        numberOfBatches: 0,
        batchIds: [],
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          DataListAvatar(
            initial: _getInitials(employeeData.employeeName),
            radius: 24,
            statusRingColor: employeeColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeData.employeeName,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employeeData.monthSummary,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Today's status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: todayRecord.isPresent
                  ? AuthColors.success.withOpacity(0.15)
                  : AuthColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  todayRecord.isPresent
                      ? Icons.check_circle
                      : Icons.cancel,
                  size: 14,
                  color: todayRecord.isPresent
                      ? AuthColors.success
                      : AuthColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  todayRecord.isPresent ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: todayRecord.isPresent
                        ? AuthColors.success
                        : AuthColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
