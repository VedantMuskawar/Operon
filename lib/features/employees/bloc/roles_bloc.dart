import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/employee_role_definition.dart';
import '../../../core/repositories/employee_repository.dart';
import 'roles_event.dart';
import 'roles_state.dart';

class RolesBloc extends Bloc<RolesEvent, RolesState> {
  RolesBloc({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository,
        super(const RolesState()) {
    on<RolesRequested>(_onRolesRequested);
    on<RolesRefreshed>(_onRolesRefreshed);
    on<RolesSearchQueryChanged>(_onSearchChanged);
    on<RolesClearSearch>(_onSearchCleared);
    on<RoleCreateRequested>(_onRoleCreateRequested);
    on<RoleUpdateRequested>(_onRoleUpdateRequested);
    on<RoleDeleteRequested>(_onRoleDeleteRequested);
  }

  final EmployeeRepository _employeeRepository;

  final Map<String, EmployeeRoleDefinition> _roleCache = {};
  String? _organizationId;

  List<EmployeeRoleDefinition> get _allRoles {
    final list = _roleCache.values.toList(growable: false);
    list.sort((a, b) {
      final aPriority = a.priority ?? 9999;
      final bPriority = b.priority ?? 9999;
      final priorityCompare = aPriority.compareTo(bPriority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _onRolesRequested(
    RolesRequested event,
    Emitter<RolesState> emit,
  ) async {
    final shouldReload =
        _organizationId != event.organizationId || event.forceRefresh;

    if (!shouldReload &&
        state.status == RolesStatus.success &&
        _roleCache.isNotEmpty) {
      return;
    }

    _organizationId = event.organizationId;
    _roleCache.clear();

    emit(state.copyWith(
      status: RolesStatus.loading,
      roles: const [],
      visibleRoles: const [],
      searchQuery: '',
      errorMessage: null,
      clearError: true,
    ));

    try {
      final roles = await _employeeRepository.fetchRoleDefinitions(event.organizationId);
      _ingestRoles(roles);

      if (_roleCache.isEmpty) {
        emit(state.copyWith(
          status: RolesStatus.empty,
          roles: const [],
          visibleRoles: const [],
          searchQuery: '',
        ));
        return;
      }

      emit(_buildSuccessState());
    } catch (error) {
      emit(state.copyWith(
        status: RolesStatus.failure,
        errorMessage: 'Failed to load roles: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onRolesRefreshed(
    RolesRefreshed event,
    Emitter<RolesState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(isRefreshing: true, clearError: true));

    try {
      final roles = await _employeeRepository.fetchRoleDefinitions(organizationId);
      _roleCache.clear();
      _ingestRoles(roles);

      if (_roleCache.isEmpty) {
        emit(state.copyWith(
          status: RolesStatus.empty,
          roles: const [],
          visibleRoles: const [],
          searchQuery: state.searchQuery,
          isRefreshing: false,
        ));
        return;
      }

      emit(_buildSuccessState(isRefreshing: false));
    } catch (error) {
      emit(state.copyWith(
        status: RolesStatus.failure,
        isRefreshing: false,
        errorMessage: 'Failed to refresh roles: $error',
        clearError: false,
      ));
    }
  }

  void _onSearchChanged(
    RolesSearchQueryChanged event,
    Emitter<RolesState> emit,
  ) {
    final query = event.query.trim();
    emit(_buildSuccessState(searchQuery: query));
  }

  void _onSearchCleared(
    RolesClearSearch event,
    Emitter<RolesState> emit,
  ) {
    emit(_buildSuccessState(searchQuery: ''));
  }

  Future<void> _onRoleCreateRequested(
    RoleCreateRequested event,
    Emitter<RolesState> emit,
  ) async {
    emit(state.copyWith(isMutating: true, clearError: true));

    try {
      await _employeeRepository.createRoleDefinition(
        organizationId: event.organizationId,
        name: event.name,
        description: event.description,
        permissions: event.permissions,
        priority: event.priority,
        createdBy: event.createdBy,
        wageType: event.wageType,
        compensationFrequency: event.compensationFrequency,
        quantity: event.quantity,
        wagePerQuantity: event.wagePerQuantity,
        monthlySalary: event.monthlySalary,
        monthlyBonus: event.monthlyBonus,
      );

      add(RolesRequested(organizationId: event.organizationId, forceRefresh: true));
    } catch (error) {
      emit(state.copyWith(
        isMutating: false,
        status: RolesStatus.failure,
        errorMessage: 'Failed to create role: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onRoleUpdateRequested(
    RoleUpdateRequested event,
    Emitter<RolesState> emit,
  ) async {
    emit(state.copyWith(isMutating: true, clearError: true));

    try {
      await _employeeRepository.updateRoleDefinition(
        event.organizationId,
        event.roleId,
        name: event.name,
        description: event.description,
        permissions: event.permissions,
        priority: event.priority,
        updatedBy: event.updatedBy,
        wageType: event.wageType,
        compensationFrequency: event.compensationFrequency,
        quantity: event.quantity,
        clearQuantity: event.clearQuantity,
        wagePerQuantity: event.wagePerQuantity,
        clearWagePerQuantity: event.clearWagePerQuantity,
        monthlySalary: event.monthlySalary,
        clearMonthlySalary: event.clearMonthlySalary,
        monthlyBonus: event.monthlyBonus,
        clearMonthlyBonus: event.clearMonthlyBonus,
      );

      add(RolesRequested(organizationId: event.organizationId, forceRefresh: true));
    } catch (error) {
      emit(state.copyWith(
        isMutating: false,
        status: RolesStatus.failure,
        errorMessage: 'Failed to update role: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onRoleDeleteRequested(
    RoleDeleteRequested event,
    Emitter<RolesState> emit,
  ) async {
    emit(state.copyWith(isMutating: true, clearError: true));

    try {
      await _employeeRepository.deleteRoleDefinition(
        event.organizationId,
        event.roleId,
      );

      add(RolesRequested(organizationId: event.organizationId, forceRefresh: true));
    } catch (error) {
      emit(state.copyWith(
        isMutating: false,
        status: RolesStatus.failure,
        errorMessage: 'Failed to delete role: $error',
        clearError: false,
      ));
    }
  }

  void _ingestRoles(List<EmployeeRoleDefinition> roles) {
    for (final role in roles) {
      _roleCache[role.id] = role;
    }
  }

  RolesState _buildSuccessState({
    String? searchQuery,
    bool? isRefreshing,
    bool? isMutating,
  }) {
    final query = searchQuery ?? state.searchQuery;
    final filtered = _filterRoles(_allRoles, query);
    final status = filtered.isEmpty ? RolesStatus.empty : RolesStatus.success;

    return state.copyWith(
      status: status,
      roles: _allRoles,
      visibleRoles: filtered,
      searchQuery: query,
      isRefreshing: isRefreshing ?? false,
      isMutating: isMutating ?? false,
      errorMessage: state.clearError ? null : state.errorMessage,
      clearError: false,
    );
  }

  List<EmployeeRoleDefinition> _filterRoles(
    List<EmployeeRoleDefinition> roles,
    String query,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return roles;
    }

    return roles
        .where((role) {
          final matchesName = role.name.toLowerCase().contains(trimmed);
          final matchesDescription =
              (role.description ?? '').toLowerCase().contains(trimmed);
          final matchesWageType = role.wageType.toLowerCase().contains(trimmed);
          final matchesFrequency =
              role.compensationFrequency.toLowerCase().contains(trimmed);
          final matchesPermissions = role.permissions.any(
            (permission) => permission.toLowerCase().contains(trimmed),
          );
          return matchesName ||
              matchesDescription ||
              matchesWageType ||
              matchesFrequency ||
              matchesPermissions;
        })
        .toList(growable: false);
  }
}

