import 'package:equatable/equatable.dart';

class RolesEvent extends Equatable {
  const RolesEvent();

  @override
  List<Object?> get props => [];
}

class RolesRequested extends RolesEvent {
  const RolesRequested({required this.organizationId, this.forceRefresh = false});

  final String organizationId;
  final bool forceRefresh;

  @override
  List<Object?> get props => [organizationId, forceRefresh];
}

class RolesRefreshed extends RolesEvent {
  const RolesRefreshed();
}

class RolesSearchQueryChanged extends RolesEvent {
  const RolesSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class RolesClearSearch extends RolesEvent {
  const RolesClearSearch();
}

class RoleCreateRequested extends RolesEvent {
  const RoleCreateRequested({
    required this.organizationId,
    required this.name,
    required this.wageType,
    required this.compensationFrequency,
    this.description,
    this.permissions = const [],
    this.priority,
    this.quantity,
    this.wagePerQuantity,
    this.monthlySalary,
    this.monthlyBonus,
    this.createdBy,
  });

  final String organizationId;
  final String name;
  final String wageType;
  final String compensationFrequency;
  final String? description;
  final List<String> permissions;
  final int? priority;
  final double? quantity;
  final double? wagePerQuantity;
  final double? monthlySalary;
  final double? monthlyBonus;
  final String? createdBy;

  @override
  List<Object?> get props => [
        organizationId,
        name,
        wageType,
        compensationFrequency,
        description,
        permissions,
        priority,
        quantity,
        wagePerQuantity,
        monthlySalary,
        monthlyBonus,
        createdBy,
      ];
}

class RoleUpdateRequested extends RolesEvent {
  const RoleUpdateRequested({
    required this.organizationId,
    required this.roleId,
    this.name,
    this.description,
    this.permissions,
    this.priority,
    this.wageType,
    this.compensationFrequency,
    this.quantity,
    this.clearQuantity = false,
    this.wagePerQuantity,
    this.clearWagePerQuantity = false,
    this.monthlySalary,
    this.clearMonthlySalary = false,
    this.monthlyBonus,
    this.clearMonthlyBonus = false,
    this.updatedBy,
  });

  final String organizationId;
  final String roleId;
  final String? name;
  final String? description;
  final List<String>? permissions;
  final int? priority;
  final String? wageType;
  final String? compensationFrequency;
  final double? quantity;
  final bool clearQuantity;
  final double? wagePerQuantity;
  final bool clearWagePerQuantity;
  final double? monthlySalary;
  final bool clearMonthlySalary;
  final double? monthlyBonus;
  final bool clearMonthlyBonus;
  final String? updatedBy;

  @override
  List<Object?> get props => [
        organizationId,
        roleId,
        name,
        description,
        permissions,
        priority,
        wageType,
        compensationFrequency,
        quantity,
        clearQuantity,
        wagePerQuantity,
        clearWagePerQuantity,
        monthlySalary,
        clearMonthlySalary,
        monthlyBonus,
        clearMonthlyBonus,
        updatedBy,
      ];
}

class RoleDeleteRequested extends RolesEvent {
  const RoleDeleteRequested({
    required this.organizationId,
    required this.roleId,
  });

  final String organizationId;
  final String roleId;

  @override
  List<Object?> get props => [organizationId, roleId];
}

