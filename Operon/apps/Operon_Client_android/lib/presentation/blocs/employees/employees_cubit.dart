import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmployeesState extends BaseState {
  const EmployeesState({
    super.status = ViewStatus.initial,
    this.employees = const [],
    this.roles = const [],
    super.message,
  });

  final List<OrganizationEmployee> employees;
  final List<OrganizationRole> roles;
  @override
  EmployeesState copyWith({
    ViewStatus? status,
    List<OrganizationEmployee>? employees,
    List<OrganizationRole>? roles,
    String? message,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      roles: roles ?? this.roles,
      message: message ?? this.message,
    );
  }
}

class EmployeesCubit extends Cubit<EmployeesState> {
  EmployeesCubit({
    required EmployeesRepository repository,
    required RolesRepository rolesRepository,
    required String organizationId,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  })  : _repository = repository,
        _rolesRepository = rolesRepository,
        _organizationId = organizationId,
        _canCreate = canCreate,
        _canEdit = canEdit,
        _canDelete = canDelete,
        super(const EmployeesState());

  final EmployeesRepository _repository;
  final RolesRepository _rolesRepository;
  final String _organizationId;
  final bool _canCreate;
  final bool _canEdit;
  final bool _canDelete;

  bool get canCreate => _canCreate;
  bool get canEdit => _canEdit;
  bool get canDelete => _canDelete;
  String get organizationId => _organizationId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final employees = await _repository.fetchEmployees(_organizationId);
      final roles = await _rolesRepository.fetchRoles(_organizationId);
      emit(
        state.copyWith(
          status: ViewStatus.success,
          employees: employees,
          roles: roles,
        ),
      );
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load employees.',
      ));
    }
  }

  Future<void> createEmployee(OrganizationEmployee employee) async {
    if (!_canCreate) return;
    try {
      await _repository.createEmployee(employee);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create employee.',
      ));
    }
  }

  Future<void> updateEmployee(OrganizationEmployee employee) async {
    if (!_canEdit) return;
    try {
      await _repository.updateEmployee(employee);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update employee.',
      ));
    }
  }

  Future<void> deleteEmployee(String employeeId) async {
    if (!_canDelete) return;
    try {
      await _repository.deleteEmployee(employeeId);
      await load();
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete employee.',
      ));
    }
  }
}
