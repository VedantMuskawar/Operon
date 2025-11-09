import 'package:equatable/equatable.dart';

import '../../../core/models/employee_role_definition.dart';

enum RolesStatus { initial, loading, success, empty, failure }

class RolesState extends Equatable {
  const RolesState({
    this.status = RolesStatus.initial,
    this.roles = const [],
    this.visibleRoles = const [],
    this.searchQuery = '',
    this.isRefreshing = false,
    this.isMutating = false,
    this.errorMessage,
    this.clearError = false,
  });

  final RolesStatus status;
  final List<EmployeeRoleDefinition> roles;
  final List<EmployeeRoleDefinition> visibleRoles;
  final String searchQuery;
  final bool isRefreshing;
  final bool isMutating;
  final String? errorMessage;
  final bool clearError;

  RolesState copyWith({
    RolesStatus? status,
    List<EmployeeRoleDefinition>? roles,
    List<EmployeeRoleDefinition>? visibleRoles,
    String? searchQuery,
    bool? isRefreshing,
    bool? isMutating,
    String? errorMessage,
    bool? clearError,
  }) {
    return RolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      visibleRoles: visibleRoles ?? this.visibleRoles,
      searchQuery: searchQuery ?? this.searchQuery,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: errorMessage ?? this.errorMessage,
      clearError: clearError ?? false,
    );
  }

  RolesState copyWithError(String? message) {
    return RolesState(
      status: status,
      roles: roles,
      visibleRoles: visibleRoles,
      searchQuery: searchQuery,
      isRefreshing: isRefreshing,
      isMutating: isMutating,
      errorMessage: message,
      clearError: false,
    );
  }

  @override
  List<Object?> get props => [
        status,
        roles,
        visibleRoles,
        searchQuery,
        isRefreshing,
        isMutating,
        errorMessage,
        clearError,
      ];
}


