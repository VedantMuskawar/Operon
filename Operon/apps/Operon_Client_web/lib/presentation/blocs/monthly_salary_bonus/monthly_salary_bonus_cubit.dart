import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/datasources/bonus_settings_data_source.dart' show BonusSettings, RoleBonusSetting, BonusTier;
import 'package:dash_web/data/repositories/bonus_settings_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'monthly_salary_bonus_state.dart';

class MonthlySalaryBonusCubit extends Cubit<MonthlySalaryBonusState> {
  MonthlySalaryBonusCubit({
    required String organizationId,
    required EmployeesRepository employeesRepository,
    required JobRolesRepository jobRolesRepository,
    required BonusSettingsRepository bonusSettingsRepository,
    required EmployeeWagesRepository employeeWagesRepository,
    required AttendanceRepository attendanceRepository,
  })  : _organizationId = organizationId,
        _employeesRepository = employeesRepository,
        _jobRolesRepository = jobRolesRepository,
        _bonusSettingsRepository = bonusSettingsRepository,
        _employeeWagesRepository = employeeWagesRepository,
        _attendanceRepository = attendanceRepository,
        super(const MonthlySalaryBonusState());

  final String _organizationId;
  final EmployeesRepository _employeesRepository;
  final JobRolesRepository _jobRolesRepository;
  final BonusSettingsRepository _bonusSettingsRepository;
  final EmployeeWagesRepository _employeeWagesRepository;
  final AttendanceRepository _attendanceRepository;

  /// Set selected month and load page data (employees, attendance, bonus settings, credited flags).
  Future<void> setMonthAndLoad(int year, int month) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      selectedYear: year,
      selectedMonth: month,
      message: null,
      recordSuccessCount: null,
      recordFailureMessage: null,
    ));

    try {
      final yearMonth = '$year-${month.toString().padLeft(2, '0')}';

      final employeesFuture = _employeesRepository.fetchEmployees(_organizationId);
      final jobRolesFuture = _jobRolesRepository.fetchJobRoles(_organizationId);
      final bonusSettingsFuture = _bonusSettingsRepository.fetch(_organizationId);
      final attendanceFuture = _attendanceRepository.getAttendanceByRole(
        organizationId: _organizationId,
        yearMonth: yearMonth,
      );

      final employees = await employeesFuture;
      final jobRoles = await jobRolesFuture;
      final bonusSettings = await bonusSettingsFuture;
      final attendanceByRole = await attendanceFuture;

      // Build employeeId -> (daysPresent, roleTitle) from attendance
      final employeeAttendanceMap = <String, ({int daysPresent, String roleTitle})>{};
      for (final group in attendanceByRole.values) {
        for (final emp in group.employees) {
          employeeAttendanceMap[emp.employeeId] = (
            daysPresent: emp.daysPresent,
            roleTitle: emp.roleTitle,
          );
        }
      }

      // Eligible: perMonth or hybrid with base
      final eligible = employees.where((e) {
        final t = e.wage.type;
        if (t == WageType.perMonth) return true;
        if (t == WageType.hybrid && e.wage.hybridStructure != null) return true;
        return false;
      }).toList();

      final defaultSalary = (OrganizationEmployee e) {
        if (e.wage.type == WageType.perMonth) return e.wage.baseAmount ?? 0.0;
        if (e.wage.hybridStructure != null) return e.wage.hybridStructure!.baseAmount;
        return 0.0;
      };

      final roleIdByTitle = <String, String>{};
      for (final r in jobRoles) {
        roleIdByTitle[r.title] = r.id;
      }

      final rows = <MonthlySalaryBonusRow>[];
      for (final emp in eligible) {
        final att = employeeAttendanceMap[emp.id];
        final daysPresent = att?.daysPresent ?? 0;
        final roleTitle = att?.roleTitle ?? emp.primaryJobRoleTitle;
        final roleId = emp.primaryJobRoleId;
        final salaryAmount = defaultSalary(emp);

        final roleSetting = bonusSettings?.roleSettings[roleId];
        final bonusAmount = roleSetting?.resolveAmount(daysPresent) ?? 0.0;

        final salaryCredited = await _employeeWagesRepository.isSalaryCreditedForMonth(
          organizationId: _organizationId,
          employeeId: emp.id,
          year: year,
          month: month,
        );
        final bonusCredited = await _employeeWagesRepository.isBonusCreditedForMonth(
          organizationId: _organizationId,
          employeeId: emp.id,
          year: year,
          month: month,
        );

        rows.add(MonthlySalaryBonusRow(
          employeeId: emp.id,
          employeeName: emp.name,
          roleId: roleId,
          roleTitle: roleTitle,
          daysPresent: daysPresent,
          salaryAmount: salaryAmount,
          bonusAmount: bonusAmount,
          salaryCredited: salaryCredited,
          bonusCredited: bonusCredited,
          selected: false,
        ));
      }

      emit(state.copyWith(
        status: ViewStatus.success,
        bonusSettings: bonusSettings ?? BonusSettings(roleSettings: {}),
        rows: rows,
        jobRoles: jobRoles,
        message: null,
      ));
    } catch (e, st) {
      debugPrint('[MonthlySalaryBonusCubit] loadPage error: $e\n$st');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load: ${e.toString()}',
      ));
    }
  }

  /// Load bonus settings only (e.g. after save).
  Future<void> loadBonusSettings() async {
    try {
      final settings = await _bonusSettingsRepository.fetch(_organizationId);
      emit(state.copyWith(bonusSettings: settings ?? BonusSettings(roleSettings: {})));
    } catch (e) {
      debugPrint('[MonthlySalaryBonusCubit] loadBonusSettings error: $e');
    }
  }

  /// Set a role's bonus tiers (draft in state). Call saveBonusSettings to persist.
  void updateBonusRoleTiers(String roleId, List<BonusTier> tiers) {
    final current = state.bonusSettings ?? BonusSettings(roleSettings: {});
    final newMap = Map<String, RoleBonusSetting>.from(current.roleSettings);
    newMap[roleId] = RoleBonusSetting(tiers: tiers);
    emit(state.copyWith(bonusSettings: BonusSettings(roleSettings: newMap)));
  }

  /// Add a tier to a role (minDays: 0, amount: 0).
  void addBonusTier(String roleId) {
    final current = state.bonusSettings ?? BonusSettings(roleSettings: {});
    final existing = current.roleSettings[roleId]?.tiers ?? [];
    final updated = List<BonusTier>.from(existing)..add(const BonusTier(minDays: 0, amount: 0));
    updateBonusRoleTiers(roleId, updated);
  }

  /// Remove a tier at index.
  void removeBonusTier(String roleId, int index) {
    final current = state.bonusSettings ?? BonusSettings(roleSettings: {});
    final existing = current.roleSettings[roleId]?.tiers ?? [];
    if (index < 0 || index >= existing.length) return;
    final updated = List<BonusTier>.from(existing)..removeAt(index);
    updateBonusRoleTiers(roleId, updated);
  }

  /// Update a tier at index.
  void updateBonusTierAt(String roleId, int index, int minDays, double amount) {
    final current = state.bonusSettings ?? BonusSettings(roleSettings: {});
    final existing = current.roleSettings[roleId]?.tiers ?? [];
    if (index < 0 || index >= existing.length) return;
    final updated = List<BonusTier>.from(existing);
    updated[index] = BonusTier(minDays: minDays, amount: amount);
    updateBonusRoleTiers(roleId, updated);
  }

  /// Save bonus settings (roleSettings map).
  Future<void> saveBonusSettings(BonusSettings settings, {String? updatedBy}) async {
    try {
      await _bonusSettingsRepository.save(
        organizationId: _organizationId,
        settings: settings,
        updatedBy: updatedBy,
      );
      await loadBonusSettings();
    } catch (e) {
      debugPrint('[MonthlySalaryBonusCubit] saveBonusSettings error: $e');
      emit(state.copyWith(message: 'Failed to save bonus settings: $e'));
    }
  }

  /// Update salary amount for a row by employeeId.
  void updateRowSalary(String employeeId, double value) {
    final rows = state.rows.map((r) {
      if (r.employeeId == employeeId) return r.copyWith(salaryAmount: value);
      return r;
    }).toList();
    emit(state.copyWith(rows: rows));
  }

  /// Update bonus amount for a row by employeeId.
  void updateRowBonus(String employeeId, double value) {
    final rows = state.rows.map((r) {
      if (r.employeeId == employeeId) return r.copyWith(bonusAmount: value);
      return r;
    }).toList();
    emit(state.copyWith(rows: rows));
  }

  /// Toggle selected for a row.
  void toggleRowSelected(String employeeId) {
    final rows = state.rows.map((r) {
      if (r.employeeId == employeeId) return r.copyWith(selected: !r.selected);
      return r;
    }).toList();
    emit(state.copyWith(rows: rows));
  }

  /// Select all / deselect all.
  void setAllSelected(bool selected) {
    final rows = state.rows.map((r) => r.copyWith(selected: selected)).toList();
    emit(state.copyWith(rows: rows));
  }

  /// Record salary and bonus transactions for all selected rows.
  /// createdBy: current user uid.
  Future<void> recordSelected(String createdBy) async {
    final selectedRows = state.rows.where((r) => r.selected).toList();
    if (selectedRows.isEmpty) {
      emit(state.copyWith(message: 'No employees selected'));
      return;
    }

    final year = state.selectedYear;
    final month = state.selectedMonth;
    if (year == null || month == null) {
      emit(state.copyWith(message: 'Please select a month'));
      return;
    }

    final invalid = selectedRows.where((r) => r.salaryAmount <= 0).toList();
    if (invalid.isNotEmpty) {
      emit(state.copyWith(message: 'Salary must be > 0 for all selected employees'));
      return;
    }

    emit(state.copyWith(isRecording: true, message: null, recordSuccessCount: null, recordFailureMessage: null));

    var successCount = 0;
    final errors = <String>[];

    final paymentDate = DateTime(year, month, DateTime(year, month + 1, 0).day);
    final yearMonth = '$year-${month.toString().padLeft(2, '0')}';

    for (final row in selectedRows) {
      try {
        await _employeeWagesRepository.createSalaryTransaction(
          organizationId: _organizationId,
          employeeId: row.employeeId,
          amount: row.salaryAmount,
          paymentDate: paymentDate,
          createdBy: createdBy,
          description: 'Salary for $yearMonth',
          metadata: {'salaryMonth': yearMonth},
        );
        if (row.bonusAmount > 0) {
          await _employeeWagesRepository.createBonusTransaction(
            organizationId: _organizationId,
            employeeId: row.employeeId,
            amount: row.bonusAmount,
            paymentDate: paymentDate,
            createdBy: createdBy,
            bonusType: 'attendance',
            description: 'Bonus for $yearMonth',
            metadata: {'bonusMonth': yearMonth, 'bonusType': 'attendance'},
          );
        }
        successCount++;
      } catch (e) {
        errors.add('${row.employeeName}: ${e.toString()}');
      }
    }

    final failureMessage = errors.isEmpty ? null : errors.join('; ');
    emit(state.copyWith(
      isRecording: false,
      recordSuccessCount: successCount,
      recordFailureMessage: failureMessage,
      message: failureMessage == null
          ? 'Recorded for $successCount employee(s)'
          : 'Recorded for $successCount; ${errors.length} failed.',
    ));

    if (successCount > 0) {
      await setMonthAndLoad(year, month);
    }
  }
}
