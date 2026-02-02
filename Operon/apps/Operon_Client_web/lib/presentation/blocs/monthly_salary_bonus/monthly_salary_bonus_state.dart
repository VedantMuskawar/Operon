import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/datasources/bonus_settings_data_source.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';

/// One row in the monthly salary & bonus table.
class MonthlySalaryBonusRow {
  const MonthlySalaryBonusRow({
    required this.employeeId,
    required this.employeeName,
    required this.roleId,
    required this.roleTitle,
    required this.daysPresent,
    required this.salaryAmount,
    required this.bonusAmount,
    required this.salaryCredited,
    required this.bonusCredited,
    this.selected = false,
  });

  final String employeeId;
  final String employeeName;
  final String roleId;
  final String roleTitle;
  final int daysPresent;
  final double salaryAmount;
  final double bonusAmount;
  final bool salaryCredited;
  final bool bonusCredited;
  final bool selected;

  MonthlySalaryBonusRow copyWith({
    String? employeeId,
    String? employeeName,
    String? roleId,
    String? roleTitle,
    int? daysPresent,
    double? salaryAmount,
    double? bonusAmount,
    bool? salaryCredited,
    bool? bonusCredited,
    bool? selected,
  }) {
    return MonthlySalaryBonusRow(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      roleId: roleId ?? this.roleId,
      roleTitle: roleTitle ?? this.roleTitle,
      daysPresent: daysPresent ?? this.daysPresent,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      salaryCredited: salaryCredited ?? this.salaryCredited,
      bonusCredited: bonusCredited ?? this.bonusCredited,
      selected: selected ?? this.selected,
    );
  }
}

class MonthlySalaryBonusState extends BaseState {
  const MonthlySalaryBonusState({
    super.status,
    super.message,
    this.selectedYear,
    this.selectedMonth,
    this.bonusSettings,
    this.rows = const [],
    this.jobRoles = const [],
    this.isRecording = false,
    this.recordSuccessCount,
    this.recordFailureMessage,
  });

  final int? selectedYear;
  final int? selectedMonth;
  final BonusSettings? bonusSettings;
  final List<MonthlySalaryBonusRow> rows;
  final List<OrganizationJobRole> jobRoles;
  final bool isRecording;
  final int? recordSuccessCount;
  final String? recordFailureMessage;

  String? get yearMonth {
    if (selectedYear == null || selectedMonth == null) return null;
    return '$selectedYear-${selectedMonth!.toString().padLeft(2, '0')}';
  }

  MonthlySalaryBonusState copyWith({
    ViewStatus? status,
    String? message,
    int? selectedYear,
    int? selectedMonth,
    BonusSettings? bonusSettings,
    List<MonthlySalaryBonusRow>? rows,
    List<OrganizationJobRole>? jobRoles,
    bool? isRecording,
    int? recordSuccessCount,
    String? recordFailureMessage,
  }) {
    return MonthlySalaryBonusState(
      status: status ?? this.status,
      message: message ?? this.message,
      selectedYear: selectedYear ?? this.selectedYear,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      bonusSettings: bonusSettings ?? this.bonusSettings,
      rows: rows ?? this.rows,
      jobRoles: jobRoles ?? this.jobRoles,
      isRecording: isRecording ?? this.isRecording,
      recordSuccessCount: recordSuccessCount ?? this.recordSuccessCount,
      recordFailureMessage: recordFailureMessage ?? this.recordFailureMessage,
    );
  }
}
