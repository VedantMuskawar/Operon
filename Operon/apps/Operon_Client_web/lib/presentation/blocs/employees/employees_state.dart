part of 'employees_cubit.dart';

class EmployeesState extends BaseState {
  const EmployeesState({
    super.status = ViewStatus.initial,
    this.employees = const [],
    this.jobRoles = const [], // ✅ NEW: Available job roles for selection
    this.message,
  }) : super(message: message);

  final List<OrganizationEmployee> employees;
  final List<OrganizationJobRole> jobRoles; // ✅ NEW: For dropdowns/selection
  @override
  final String? message;

  @override
  EmployeesState copyWith({
    ViewStatus? status,
    List<OrganizationEmployee>? employees,
    List<OrganizationJobRole>? jobRoles,
    String? message,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      jobRoles: jobRoles ?? this.jobRoles,
      message: message ?? this.message,
    );
  }
}
