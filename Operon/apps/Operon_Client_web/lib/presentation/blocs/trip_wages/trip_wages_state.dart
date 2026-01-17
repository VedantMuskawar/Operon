import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';

class TripWagesState extends BaseState {
  const TripWagesState({
    super.status = ViewStatus.initial,
    this.tripWages = const [],
    this.returnedDMs = const [],
    this.selectedDate,
    this.activeDMs = const [],
    this.loadingEmployees = const [],
    this.wageSettings,
    super.message,
  });

  final List<TripWage> tripWages;
  final List<Map<String, dynamic>> returnedDMs;
  final DateTime? selectedDate;
  final List<Map<String, dynamic>> activeDMs;
  final List<OrganizationEmployee> loadingEmployees;
  final WageSettings? wageSettings;

  @override
  TripWagesState copyWith({
    ViewStatus? status,
    List<TripWage>? tripWages,
    List<Map<String, dynamic>>? returnedDMs,
    DateTime? selectedDate,
    List<Map<String, dynamic>>? activeDMs,
    List<OrganizationEmployee>? loadingEmployees,
    WageSettings? wageSettings,
    String? message,
  }) {
    return TripWagesState(
      status: status ?? this.status,
      tripWages: tripWages ?? this.tripWages,
      returnedDMs: returnedDMs ?? this.returnedDMs,
      selectedDate: selectedDate ?? this.selectedDate,
      activeDMs: activeDMs ?? this.activeDMs,
      loadingEmployees: loadingEmployees ?? this.loadingEmployees,
      wageSettings: wageSettings ?? this.wageSettings,
      message: message,
    );
  }
}

