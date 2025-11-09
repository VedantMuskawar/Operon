import 'package:equatable/equatable.dart';

class EmployeesEvent extends Equatable {
  const EmployeesEvent();

  @override
  List<Object?> get props => [];
}

class EmployeesRequested extends EmployeesEvent {
  const EmployeesRequested({
    required this.organizationId,
    this.forceRefresh = false,
  });

  final String organizationId;
  final bool forceRefresh;

  @override
  List<Object?> get props => [organizationId, forceRefresh];
}

class EmployeesRefreshed extends EmployeesEvent {
  const EmployeesRefreshed();
}

class EmployeesLoadMore extends EmployeesEvent {
  const EmployeesLoadMore();
}

class EmployeesSearchQueryChanged extends EmployeesEvent {
  const EmployeesSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class EmployeesClearSearch extends EmployeesEvent {
  const EmployeesClearSearch();
}

class EmployeesStatusFilterChanged extends EmployeesEvent {
  const EmployeesStatusFilterChanged(this.status);

  final String? status;

  @override
  List<Object?> get props => [status];
}

class EmployeesRoleFilterChanged extends EmployeesEvent {
  const EmployeesRoleFilterChanged(this.roleId);

  final String? roleId;

  @override
  List<Object?> get props => [roleId];
}

class EmployeesRolesRequested extends EmployeesEvent {
  const EmployeesRolesRequested();
}

class EmployeeCreateRequested extends EmployeesEvent {
  const EmployeeCreateRequested({
    required this.organizationId,
    required this.name,
    required this.roleId,
    required this.startDate,
    required this.openingBalance,
    required this.currency,
    this.status,
    this.contactEmail,
    this.contactPhone,
    this.notes,
    this.requestedBy,
  });

  final String organizationId;
  final String name;
  final String roleId;
  final DateTime startDate;
  final double openingBalance;
  final String currency;
  final String? status;
  final String? contactEmail;
  final String? contactPhone;
  final String? notes;
  final String? requestedBy;

  @override
  List<Object?> get props => [
        organizationId,
        name,
        roleId,
        startDate,
        openingBalance,
        currency,
        status,
        contactEmail,
        contactPhone,
        notes,
        requestedBy,
      ];
}


