import 'package:equatable/equatable.dart';

import '../../../core/models/employee.dart';
import '../../../core/models/employee_role_definition.dart';

enum EmployeesStatus { initial, loading, success, empty, failure }

class EmployeesMetrics extends Equatable {
  const EmployeesMetrics({
    required this.total,
    required this.active,
    required this.inactive,
    required this.newHires,
  });

  final int total;
  final int active;
  final int inactive;
  final int newHires;

  factory EmployeesMetrics.fromEmployees(List<Employee> employees) {
    final now = DateTime.now();
    final threshold = now.subtract(const Duration(days: 30));

    int active = 0;
    int inactive = 0;
    int newHires = 0;

    for (final employee in employees) {
      switch (employee.status) {
        case 'active':
          active += 1;
          break;
        case 'inactive':
          inactive += 1;
          break;
        default:
          break;
      }

      if (employee.startDate.isAfter(threshold)) {
        newHires += 1;
      }
    }

    return EmployeesMetrics(
      total: employees.length,
      active: active,
      inactive: inactive,
      newHires: newHires,
    );
  }

  static const empty = EmployeesMetrics(total: 0, active: 0, inactive: 0, newHires: 0);

  @override
  List<Object?> get props => [total, active, inactive, newHires];
}

class EmployeesState extends Equatable {
  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.employees = const [],
    this.visibleEmployees = const [],
    this.metrics = EmployeesMetrics.empty,
    this.searchQuery = '',
    this.statusFilter,
    this.roleFilter,
    this.roles = const [],
    this.hasMore = false,
    this.isFetchingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.isCreateInProgress = false,
    this.clearError = false,
  });

  final EmployeesStatus status;
  final List<Employee> employees;
  final List<Employee> visibleEmployees;
  final EmployeesMetrics metrics;
  final String searchQuery;
  final String? statusFilter;
  final String? roleFilter;
  final List<EmployeeRoleDefinition> roles;
  final bool hasMore;
  final bool isFetchingMore;
  final bool isRefreshing;
  final String? errorMessage;
  final bool isCreateInProgress;
  final bool clearError;

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<Employee>? employees,
    List<Employee>? visibleEmployees,
    EmployeesMetrics? metrics,
    String? searchQuery,
    String? statusFilter,
    String? roleFilter,
    List<EmployeeRoleDefinition>? roles,
    bool? hasMore,
    bool? isFetchingMore,
    bool? isRefreshing,
    String? errorMessage,
    bool? isCreateInProgress,
    bool? clearError,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      visibleEmployees: visibleEmployees ?? this.visibleEmployees,
      metrics: metrics ?? this.metrics,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      roleFilter: roleFilter ?? this.roleFilter,
      roles: roles ?? this.roles,
      hasMore: hasMore ?? this.hasMore,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage ?? this.errorMessage,
      isCreateInProgress: isCreateInProgress ?? this.isCreateInProgress,
      clearError: clearError ?? false,
    );
  }

  EmployeesState copyWithError(String? message) {
    return EmployeesState(
      status: status,
      employees: employees,
      visibleEmployees: visibleEmployees,
      metrics: metrics,
      searchQuery: searchQuery,
      statusFilter: statusFilter,
      roleFilter: roleFilter,
      roles: roles,
      hasMore: hasMore,
      isFetchingMore: isFetchingMore,
      isRefreshing: isRefreshing,
      errorMessage: message,
      isCreateInProgress: isCreateInProgress,
      clearError: false,
    );
  }

  @override
  List<Object?> get props => [
        status,
        employees,
        visibleEmployees,
        metrics,
        searchQuery,
        statusFilter,
        roleFilter,
        roles,
        hasMore,
        isFetchingMore,
        isRefreshing,
        errorMessage,
        isCreateInProgress,
        clearError,
      ];
}


