import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/domain/entities/organization_job_role.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  EmployeesCubit({
    required EmployeesRepository repository,
    required JobRolesRepository jobRolesRepository,
    required String orgId,
  })  : _repository = repository,
        _jobRolesRepository = jobRolesRepository,
        _orgId = orgId,
        super(const EmployeesState());

  final EmployeesRepository _repository;
  final JobRolesRepository _jobRolesRepository;
  final String _orgId;

  Future<void> loadEmployees({bool refreshJobRoles = false}) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      debugPrint('[EmployeesCubit] Loading employees for orgId: $_orgId');

      final employeesFuture = _repository.fetchEmployees(_orgId);
      final shouldFetchJobRoles = refreshJobRoles || state.jobRoles.isEmpty;

      if (shouldFetchJobRoles) {
        // Load both employees and job roles in parallel
        final jobRolesFuture = _jobRolesRepository.fetchJobRoles(_orgId);
        final results = await Future.wait([employeesFuture, jobRolesFuture]);
        final employees = results[0] as List<OrganizationEmployee>;
        final jobRoles = results[1] as List<OrganizationJobRole>;

        debugPrint('[EmployeesCubit] Fetched ${employees.length} employees and ${jobRoles.length} job roles');
        emit(state.copyWith(
          status: ViewStatus.success,
          employees: employees,
          jobRoles: jobRoles,
          message: null,
        ));
      } else {
        final employees = await employeesFuture;
        debugPrint('[EmployeesCubit] Fetched ${employees.length} employees');
        emit(state.copyWith(
          status: ViewStatus.success,
          employees: employees,
          message: null,
        ));
      }
    } catch (e, stackTrace) {
      debugPrint('[EmployeesCubit] Error loading employees: $e');
      debugPrint('[EmployeesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load employees: ${e.toString()}',
      ));
    }
  }
  
  Future<void> loadJobRoles() async {
    try {
      final jobRoles = await _jobRolesRepository.fetchJobRoles(_orgId);
      emit(state.copyWith(jobRoles: jobRoles));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load job roles: ${e.toString()}',
      ));
    }
  }

  Future<void> createEmployee(OrganizationEmployee employee) async {
    try {
      await _repository.createEmployee(employee);
      _upsertEmployeeInState(employee);
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create employee: ${e.toString()}',
      ));
    }
  }

  Future<void> updateEmployee(OrganizationEmployee employee) async {
    try {
      await _repository.updateEmployee(employee);
      _upsertEmployeeInState(employee);
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update employee: ${e.toString()}',
      ));
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    try {
      await _repository.deleteEmployee(employeeId);
      _removeEmployeeFromState(employeeId);
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete employee: ${e.toString()}',
      ));
    }
  }

  void applyEmployeeUpdate(OrganizationEmployee employee) {
    _upsertEmployeeInState(employee);
  }

  void _upsertEmployeeInState(OrganizationEmployee employee) {
    final employees = List<OrganizationEmployee>.from(state.employees);
    final index = employees.indexWhere((e) => e.id == employee.id);
    if (index >= 0) {
      employees[index] = employee;
    } else {
      employees.add(employee);
    }
    emit(state.copyWith(status: ViewStatus.success, employees: employees, message: null));
  }

  void _removeEmployeeFromState(String employeeId) {
    final employees = state.employees.where((e) => e.id != employeeId).toList();
    emit(state.copyWith(status: ViewStatus.success, employees: employees, message: null));
  }
}
