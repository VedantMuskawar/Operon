import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/employee.dart';
import '../../../core/repositories/employee_repository.dart';
import 'employees_event.dart';
import 'employees_state.dart';

class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  EmployeesBloc({required EmployeeRepository employeeRepository})
      : _employeeRepository = employeeRepository,
        super(const EmployeesState()) {
    on<EmployeesRequested>(_onEmployeesRequested);
    on<EmployeesRefreshed>(_onEmployeesRefreshed);
    on<EmployeesLoadMore>(_onEmployeesLoadMore);
    on<EmployeesSearchQueryChanged>(_onSearchChanged);
    on<EmployeesClearSearch>(_onSearchCleared);
    on<EmployeesStatusFilterChanged>(_onStatusFilterChanged);
    on<EmployeesRoleFilterChanged>(_onRoleFilterChanged);
    on<EmployeesRolesRequested>(_onRolesRequested);
    on<EmployeeCreateRequested>(_onEmployeeCreateRequested);
  }

  final EmployeeRepository _employeeRepository;

  final Map<String, Employee> _employeeCache = {};
  String? _organizationId;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMore = false;
  bool _isFetchingMore = false;
  bool _hasLoadedAllForSearch = false;

  List<Employee> get _allEmployees {
    final list = _employeeCache.values.toList(growable: false);
    list.sort((a, b) => a.nameLowercase.compareTo(b.nameLowercase));
    return list;
  }

  Future<void> _onEmployeesRequested(
    EmployeesRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    final shouldReload =
        _organizationId != event.organizationId || event.forceRefresh;

    if (!shouldReload &&
        state.status == EmployeesStatus.success &&
        _employeeCache.isNotEmpty) {
      return;
    }

    _organizationId = event.organizationId;
    _employeeCache.clear();
    _lastDocument = null;
    _hasMore = false;
    _hasLoadedAllForSearch = false;

    emit(state.copyWith(
      status: EmployeesStatus.loading,
      employees: const [],
      visibleEmployees: const [],
      metrics: EmployeesMetrics.empty,
      searchQuery: '',
      hasMore: false,
      isRefreshing: false,
      isFetchingMore: false,
      errorMessage: null,
      clearError: true,
    ));

    try {
      await _loadRolesForOrganization(event.organizationId, emit);
      await _loadInitialEmployees(event.organizationId, emit);
    } catch (error) {
      emit(state.copyWith(
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to load employees: $error',
        isRefreshing: false,
        isFetchingMore: false,
        clearError: false,
      ));
    }
  }

  Future<void> _loadInitialEmployees(
    String organizationId,
    Emitter<EmployeesState> emit,
  ) async {
    final result = await _employeeRepository.fetchEmployeesPage(
      organizationId: organizationId,
      limit: AppConstants.defaultPageSize,
    );

    _ingestEmployees(result.employees);
    _lastDocument = result.lastDocument;
    _hasMore = result.hasMore;

    if (_employeeCache.isEmpty) {
      emit(state.copyWith(
        status: EmployeesStatus.empty,
        employees: const [],
        visibleEmployees: const [],
        metrics: EmployeesMetrics.empty,
        hasMore: false,
      ));
      return;
    }

    emit(_buildSuccessState(hasMore: _hasMore));
  }

  Future<void> _onEmployeesRefreshed(
    EmployeesRefreshed event,
    Emitter<EmployeesState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(isRefreshing: true, clearError: true));

    try {
      await _loadRolesForOrganization(organizationId, emit);
      final result = await _employeeRepository.fetchEmployeesPage(
        organizationId: organizationId,
        limit: AppConstants.defaultPageSize,
      );

      _employeeCache.clear();
      _ingestEmployees(result.employees);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
      _hasLoadedAllForSearch = false;

      if (_employeeCache.isEmpty) {
        emit(state.copyWith(
          status: EmployeesStatus.empty,
          employees: const [],
          visibleEmployees: const [],
          metrics: EmployeesMetrics.empty,
          hasMore: false,
          isRefreshing: false,
        ));
        return;
      }

      emit(_buildSuccessState(hasMore: _hasMore, isRefreshing: false));
    } catch (error) {
      emit(state.copyWith(
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to refresh employees: $error',
        isRefreshing: false,
        clearError: false,
      ));
    }
  }

  Future<void> _onEmployeesLoadMore(
    EmployeesLoadMore event,
    Emitter<EmployeesState> emit,
  ) async {
    if (!_hasMore || _isFetchingMore) {
      return;
    }

    final organizationId = _organizationId;
    final lastDocument = _lastDocument;
    if (organizationId == null || lastDocument == null) {
      return;
    }

    _isFetchingMore = true;
    emit(state.copyWith(isFetchingMore: true, clearError: true));

    try {
      final result = await _employeeRepository.fetchEmployeesPage(
        organizationId: organizationId,
        limit: AppConstants.defaultPageSize,
        startAfter: lastDocument,
        status: state.statusFilter,
        roleId: state.roleFilter,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      _ingestEmployees(result.employees);
      _lastDocument = result.lastDocument ?? _lastDocument;
      _hasMore = result.hasMore;

      emit(_buildSuccessState(hasMore: _hasMore, isFetchingMore: false));
    } catch (error) {
      emit(state.copyWith(
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to load more employees: $error',
        isFetchingMore: false,
        clearError: false,
      ));
    } finally {
      _isFetchingMore = false;
    }
  }

  Future<void> _onSearchChanged(
    EmployeesSearchQueryChanged event,
    Emitter<EmployeesState> emit,
  ) async {
    final trimmed = event.query.trim();

    if (trimmed.isEmpty) {
      emit(_buildSuccessState(
        searchQuery: '',
        hasMore: _hasMore,
        isFetchingMore: false,
      ));
      return;
    }

    if (!_hasLoadedAllForSearch && _hasMore) {
      await _loadRemainingEmployees();
    }

    emit(_buildSuccessState(
      searchQuery: trimmed,
      hasMore: _hasMore,
      isFetchingMore: false,
    ));
  }

  void _onSearchCleared(
    EmployeesClearSearch event,
    Emitter<EmployeesState> emit,
  ) {
    emit(_buildSuccessState(
      searchQuery: '',
      hasMore: _hasMore,
      isFetchingMore: false,
    ));
  }

  Future<void> _onStatusFilterChanged(
    EmployeesStatusFilterChanged event,
    Emitter<EmployeesState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(statusFilter: event.status, clearError: true));

    try {
      final result = await _employeeRepository.fetchEmployeesPage(
        organizationId: organizationId,
        limit: AppConstants.defaultPageSize,
        status: event.status,
        roleId: state.roleFilter,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      _employeeCache.clear();
      _ingestEmployees(result.employees);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;

      emit(_buildSuccessState(hasMore: _hasMore));
    } catch (error) {
      emit(state.copyWith(
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to apply status filter: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onRoleFilterChanged(
    EmployeesRoleFilterChanged event,
    Emitter<EmployeesState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    emit(state.copyWith(roleFilter: event.roleId, clearError: true));

    try {
      final result = await _employeeRepository.fetchEmployeesPage(
        organizationId: organizationId,
        limit: AppConstants.defaultPageSize,
        status: state.statusFilter,
        roleId: event.roleId,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      _employeeCache.clear();
      _ingestEmployees(result.employees);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;

      emit(_buildSuccessState(hasMore: _hasMore));
    } catch (error) {
      emit(state.copyWith(
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to apply role filter: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onRolesRequested(
    EmployeesRolesRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    try {
      await _loadRolesForOrganization(organizationId, emit);
    } catch (error) {
      emit(state.copyWith(
        errorMessage: 'Failed to load roles: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _onEmployeeCreateRequested(
    EmployeeCreateRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    emit(state.copyWith(isCreateInProgress: true, clearError: true));

    try {
      await _employeeRepository.createEmployee(
        organizationId: event.organizationId,
        name: event.name,
        roleId: event.roleId,
        startDate: event.startDate,
        openingBalance: event.openingBalance,
        openingBalanceCurrency: event.currency,
        status: event.status ?? AppConstants.employeeStatusActive,
        contactEmail: event.contactEmail,
        contactPhone: event.contactPhone,
        notes: event.notes,
        createdBy: event.requestedBy,
      );

      add(EmployeesRequested(organizationId: event.organizationId, forceRefresh: true));
    } catch (error) {
      emit(state.copyWith(
        isCreateInProgress: false,
        status: EmployeesStatus.failure,
        errorMessage: 'Failed to add employee: $error',
        clearError: false,
      ));
    }
  }

  Future<void> _loadRolesForOrganization(
    String organizationId,
    Emitter<EmployeesState> emit,
  ) async {
    final roles = await _employeeRepository.fetchRoleDefinitions(organizationId);
    emit(state.copyWith(roles: roles));
  }

  Future<void> _loadRemainingEmployees() async {
    final organizationId = _organizationId;
    if (organizationId == null) return;

    try {
      final allEmployees = await _employeeRepository.fetchAllEmployees(
        organizationId: organizationId,
      );
      _employeeCache.clear();
      _ingestEmployees(allEmployees);
      _hasMore = false;
      _hasLoadedAllForSearch = true;
    } catch (_) {
      // ignore errors to keep existing cache
    }
  }

  void _ingestEmployees(List<Employee> employees) {
    for (final employee in employees) {
      _employeeCache[employee.id] = employee;
    }
  }

  EmployeesState _buildSuccessState({
    String? searchQuery,
    bool? hasMore,
    bool? isFetchingMore,
    bool? isRefreshing,
  }) {
    final query = searchQuery ?? state.searchQuery;
    final filtered = _filterEmployees(_allEmployees, query);
    final metrics = EmployeesMetrics.fromEmployees(filtered);
    final status = filtered.isEmpty ? EmployeesStatus.empty : EmployeesStatus.success;

    return state.copyWith(
      status: status,
      employees: _allEmployees,
      visibleEmployees: filtered,
      metrics: metrics,
      searchQuery: query,
      hasMore: hasMore ?? _hasMore,
      isFetchingMore: isFetchingMore ?? false,
      isRefreshing: isRefreshing ?? false,
      isCreateInProgress: false,
      errorMessage: state.clearError ? null : state.errorMessage,
      clearError: false,
    );
  }

  List<Employee> _filterEmployees(List<Employee> employees, String query) {
    final trimmedQuery = query.trim().toLowerCase();

    return employees.where((employee) {
      final matchesStatus = state.statusFilter == null ||
          state.statusFilter!.trim().isEmpty ||
          employee.status == state.statusFilter;

      final matchesRole = state.roleFilter == null ||
          state.roleFilter!.trim().isEmpty ||
          employee.roleId == state.roleFilter;

      if (!matchesStatus || !matchesRole) {
        return false;
      }

      if (trimmedQuery.isEmpty) {
        return true;
      }

      final digitsQuery = trimmedQuery.replaceAll(RegExp(r'[^0-9]'), '');

      final searchableStrings = <String?>[
        employee.nameLowercase,
        employee.contactEmail?.toLowerCase(),
        employee.contactPhone?.toLowerCase(),
        employee.roleId.toLowerCase(),
      ];

      if (searchableStrings.any((value) => value?.contains(trimmedQuery) ?? false)) {
        return true;
      }

      if (digitsQuery.isEmpty) {
        return false;
      }

      final phoneDigits = (employee.contactPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      return phoneDigits.contains(digitsQuery);
    }).toList(growable: false);
  }
}

