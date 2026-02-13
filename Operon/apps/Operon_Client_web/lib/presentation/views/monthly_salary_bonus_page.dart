import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/attendance_repository_impl.dart';
import 'package:dash_web/data/datasources/bonus_settings_data_source.dart';
import 'package:dash_web/data/repositories/bonus_settings_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';
import 'package:dash_web/presentation/blocs/monthly_salary_bonus/monthly_salary_bonus_cubit.dart';
import 'package:dash_web/presentation/blocs/monthly_salary_bonus/monthly_salary_bonus_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class MonthlySalaryBonusPage extends StatefulWidget {
  const MonthlySalaryBonusPage({super.key});

  @override
  State<MonthlySalaryBonusPage> createState() => _MonthlySalaryBonusPageState();
}

class _MonthlySalaryBonusPageState extends State<MonthlySalaryBonusPage> {
  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected', style: TextStyle(color: AuthColors.textMain)),
              const SizedBox(height: 16),
              DashButton(label: 'Select Organization', onPressed: () => context.go('/org-selection')),
            ],
          ),
        ),
      );
    }

    final attendanceRepository = AttendanceRepositoryImpl(
      employeesRepository: context.read<EmployeesRepository>(),
      attendanceDataSource: EmployeeAttendanceDataSource(),
    );

    return BlocProvider(
      create: (context) => MonthlySalaryBonusCubit(
        organizationId: organization.id,
        employeesRepository: context.read<EmployeesRepository>(),
        jobRolesRepository: context.read<JobRolesRepository>(),
        bonusSettingsRepository: context.read<BonusSettingsRepository>(),
        employeeWagesRepository: context.read<EmployeeWagesRepository>(),
        attendanceRepository: attendanceRepository,
      )..setMonthAndLoad(
          _defaultYear(),
          _defaultMonth(),
        ),
      child: SectionWorkspaceLayout(
        panelTitle: 'Monthly Salary & Bonus',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _MonthlySalaryBonusContent(),
      ),
    );
  }

  int _defaultYear() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    return prev.year;
  }

  int _defaultMonth() {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    return prev.month;
  }
}

class _MonthlySalaryBonusContent extends StatefulWidget {
  const _MonthlySalaryBonusContent();

  @override
  State<_MonthlySalaryBonusContent> createState() => _MonthlySalaryBonusContentState();
}

class _MonthlySalaryBonusContentState extends State<_MonthlySalaryBonusContent> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<MonthlySalaryBonusCubit, MonthlySalaryBonusState>(
      listener: (context, state) {
        if (state.message != null && state.message!.isNotEmpty) {
          final isError = state.status == ViewStatus.failure ||
              (state.recordFailureMessage != null && state.recordFailureMessage!.isNotEmpty);
          DashSnackbar.show(context, message: state.message!, isError: isError);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildEmployeesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cubit = context.read<MonthlySalaryBonusCubit>();
    return BlocBuilder<MonthlySalaryBonusCubit, MonthlySalaryBonusState>(
      buildWhen: (a, b) => a.selectedYear != b.selectedYear || a.selectedMonth != b.selectedMonth,
      builder: (context, state) {
        final year = state.selectedYear ?? DateTime.now().year;
        final month = state.selectedMonth ?? DateTime.now().month;
        final monthLabel = _monthLabel(month, year);

        return Center(
          child: Material(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(year, month, 1),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null && context.mounted) {
                  cubit.setMonthAndLoad(picked.year, picked.month);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, color: AuthColors.textSub, size: 20),
                    const SizedBox(width: 10),
                    Text(monthLabel, style: const TextStyle(color: AuthColors.textMain, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AuthColors.textSub),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _monthLabel(int month, int year) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[month - 1]} $year';
  }

  void _showBonusSettingsModal(BuildContext context) {
    final cubit = context.read<MonthlySalaryBonusCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<MonthlySalaryBonusCubit, MonthlySalaryBonusState>(
          buildWhen: (a, b) => a.bonusSettings != b.bonusSettings || a.jobRoles != b.jobRoles,
          builder: (ctx, state) {
            final jobRoles = state.jobRoles;
            final settings = state.bonusSettings;
            if (jobRoles.isEmpty) {
              return AlertDialog(
                title: const Text('Bonus settings (by role)'),
                content: const Text('No job roles defined. Add roles first.'),
                actions: [
                  DashButton(
                    label: 'Close',
                    onPressed: () => Navigator.pop(dialogContext),
                    variant: DashButtonVariant.text,
                  ),
                ],
              );
            }
            return AlertDialog(
              title: const Text('Bonus settings (by role)'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add multiple tiers per role: e.g. 23 days → ₹3000, 25 days → ₹5000. Employee gets the highest tier they qualify for.',
                        style: TextStyle(color: AuthColors.textSub, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ...jobRoles.map((OrganizationJobRole role) {
                        final roleSetting = settings?.roleSettings[role.id];
                        final tiers = roleSetting?.tiers ?? [];
                        return Padding(
                          key: ValueKey(role.id),
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _BonusRoleSection(
                            roleId: role.id,
                            roleTitle: role.title,
                            tiers: tiers,
                            cubit: cubit,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                DashButton(
                  label: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  variant: DashButtonVariant.text,
                ),
                DashButton(
                  label: 'Save',
                  onPressed: () {
                    final s = state.bonusSettings;
                    if (s != null) {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      cubit.saveBonusSettings(s, updatedBy: uid);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmployeesSection(BuildContext context) {
    return BlocBuilder<MonthlySalaryBonusCubit, MonthlySalaryBonusState>(
      builder: (context, state) {
    final cubit = context.read<MonthlySalaryBonusCubit>();

    if (state.status == ViewStatus.loading && state.rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary)),
        ),
      );
    }

    if (state.status == ViewStatus.failure && state.rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(state.message ?? 'Failed to load', style: const TextStyle(color: AuthColors.textMain)),
            const SizedBox(height: 16),
            DashButton(label: 'Retry', onPressed: () => cubit.setMonthAndLoad(state.selectedYear!, state.selectedMonth!)),
          ],
        ),
      );
    }

    final rows = state.rows;
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: const Text(
          'No eligible employees (monthly salary) for this month.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }

    final selectedCount = rows.where((r) => r.selected).length;
    final canRecord = selectedCount > 0 && !state.isRecording;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Employees',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 24),
              DashButton(
                icon: Icons.settings_outlined,
                label: 'Bonus settings',
                onPressed: () => _showBonusSettingsModal(context),
                variant: DashButtonVariant.outlined,
              ),
              DashButton(
                label: 'Select all',
                onPressed: () => cubit.setAllSelected(true),
                variant: DashButtonVariant.text,
              ),
              DashButton(
                label: 'Deselect all',
                onPressed: () => cubit.setAllSelected(false),
                variant: DashButtonVariant.text,
              ),
              DashButton(
                icon: Icons.check_circle_outline,
                label: state.isRecording ? 'Recording...' : 'Record salary & bonus for selected',
                onPressed: canRecord
                    ? () {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) {
                          DashSnackbar.show(context, message: 'Not authenticated', isError: true);
                          return;
                        }
                        cubit.recordSelected(uid);
                      }
                    : null,
                isLoading: state.isRecording,
              ),
            ],
          ),
          const SizedBox(height: 20),
          custom_table.DataTable<MonthlySalaryBonusRow>(
            columns: [
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Select',
                width: 70,
                cellBuilder: (context, row, _) => Checkbox(
                  value: row.selected,
                  onChanged: row.salaryCredited
                      ? null
                      : (_) => cubit.toggleRowSelected(row.employeeId),
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Employee',
                flex: 2,
                cellBuilder: (context, row, _) => Text(
                  row.employeeName,
                  style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Role',
                flex: 1,
                cellBuilder: (context, row, _) => Text(
                  row.roleTitle,
                  style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Days present',
                width: 100,
                cellBuilder: (context, row, _) => Text(
                  '${row.daysPresent}',
                  style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Salary (₹)',
                width: 120,
                cellBuilder: (context, row, _) => _EditableAmount(
                  value: row.salaryAmount,
                  onChanged: (v) => cubit.updateRowSalary(row.employeeId, v),
                  enabled: !row.salaryCredited,
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Bonus (₹)',
                width: 120,
                cellBuilder: (context, row, _) => _EditableAmount(
                  value: row.bonusAmount,
                  onChanged: (v) => cubit.updateRowBonus(row.employeeId, v),
                  enabled: !row.bonusCredited,
                ),
              ),
              custom_table.DataTableColumn<MonthlySalaryBonusRow>(
                label: 'Status',
                width: 140,
                cellBuilder: (context, row, _) => Wrap(
                  spacing: 6,
                  children: [
                    if (row.salaryCredited)
                      const Chip(
                        label: Text('Salary ✓', style: TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (row.bonusCredited)
                      const Chip(
                        label: Text('Bonus ✓', style: TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (!row.salaryCredited && !row.bonusCredited)
                      const Text('—', style: TextStyle(color: AuthColors.textSub, fontSize: 13)),
                  ],
                ),
              ),
            ],
            rows: rows,
            rowKeyBuilder: (row, _) => ValueKey(row.employeeId),
            emptyStateMessage: 'No eligible employees (monthly salary) for this month.',
          ),
        ],
      ),
    );
      },
    );
  }
}

class _BonusRoleSection extends StatelessWidget {
  const _BonusRoleSection({
    required this.roleId,
    required this.roleTitle,
    required this.tiers,
    required this.cubit,
  });

  final String roleId;
  final String roleTitle;
  final List<BonusTier> tiers;
  final MonthlySalaryBonusCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roleTitle,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (tiers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'No tiers. Add one below.',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            )
          else
            ...tiers.asMap().entries.map((entry) {
              final index = entry.key;
              final tier = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BonusTierRow(
                  key: ValueKey('$roleId-$index'),
                  minDays: tier.minDays,
                  amount: tier.amount,
                  onChanged: (minDays, amount) => cubit.updateBonusTierAt(roleId, index, minDays, amount),
                  onRemove: () => cubit.removeBonusTier(roleId, index),
                ),
              );
            }),
          DashButton(
            icon: Icons.add,
            label: 'Add tier',
            onPressed: () => cubit.addBonusTier(roleId),
          ),
        ],
      ),
    );
  }
}

class _BonusTierRow extends StatefulWidget {
  const _BonusTierRow({
    super.key,
    required this.minDays,
    required this.amount,
    required this.onChanged,
    required this.onRemove,
  });

  final int minDays;
  final double amount;
  final void Function(int minDays, double amount) onChanged;
  final VoidCallback onRemove;

  @override
  State<_BonusTierRow> createState() => _BonusTierRowState();
}

class _BonusTierRowState extends State<_BonusTierRow> {
  late TextEditingController _daysController;
  late TextEditingController _amountController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController(text: widget.minDays.toString());
    _amountController = TextEditingController(text: widget.amount.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_BonusTierRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minDays != widget.minDays) _daysController.text = widget.minDays.toString();
    if (oldWidget.amount != widget.amount) _amountController.text = widget.amount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _daysController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _scheduleNotify() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final minDays = int.tryParse(_daysController.text) ?? 0;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      widget.onChanged(minDays, amount);
    });
  }

  void _flushNotify() {
    _debounce?.cancel();
    final minDays = int.tryParse(_daysController.text) ?? 0;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    widget.onChanged(minDays, amount);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Days',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _scheduleNotify(),
            onEditingComplete: _flushNotify,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _scheduleNotify(),
            onEditingComplete: _flushNotify,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: AuthColors.error),
          onPressed: widget.onRemove,
          tooltip: 'Remove tier',
        ),
      ],
    );
  }
}

class _EditableAmount extends StatefulWidget {
  const _EditableAmount({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  State<_EditableAmount> createState() => _EditableAmountState();
}

class _EditableAmountState extends State<_EditableAmount> {
  late TextEditingController _controller;
  bool _focused = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_EditableAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focused && oldWidget.value != widget.value) {
      _controller.text = widget.value.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleCommit(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final n = double.tryParse(value) ?? 0;
      widget.onChanged(n);
    });
  }

  void _flushCommit() {
    _debounce?.cancel();
    final n = double.tryParse(_controller.text) ?? 0;
    widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        onTap: () => setState(() => _focused = true),
        onTapOutside: (_) {
          setState(() => _focused = false);
          _flushCommit();
        },
        onEditingComplete: _flushCommit,
        onChanged: (v) {
          _scheduleCommit(v);
        },
      ),
    );
  }
}
