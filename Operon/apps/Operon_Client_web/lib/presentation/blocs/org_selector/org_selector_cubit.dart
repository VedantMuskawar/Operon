import 'dart:async';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/user_organization_repository.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrgSelectorState extends BaseState {
  const OrgSelectorState({
    super.status = ViewStatus.initial,
    this.organizations = const [],
    this.selectedOrganization,
    this.financialYear,
    this.isFinancialYearLocked = false,
    super.message,
  });

  final List<OrganizationMembership> organizations;
  final OrganizationMembership? selectedOrganization;
  final String? financialYear;
  final bool isFinancialYearLocked;

  String? get errorMessage => message;

  @override
  OrgSelectorState copyWith({
    ViewStatus? status,
    String? message,
    List<OrganizationMembership>? organizations,
    OrganizationMembership? selectedOrganization,
    String? financialYear,
    bool? isFinancialYearLocked,
  }) {
    return OrgSelectorState(
      status: status ?? this.status,
      message: message ?? errorMessage,
      organizations: organizations ?? this.organizations,
      selectedOrganization: selectedOrganization ?? this.selectedOrganization,
      financialYear: financialYear ?? this.financialYear,
      isFinancialYearLocked:
          isFinancialYearLocked ?? this.isFinancialYearLocked,
    );
  }
}

class OrgSelectorCubit extends Cubit<OrgSelectorState> {
  OrgSelectorCubit({
    required UserOrganizationRepository repository,
  })  : _repository = repository,
        super(
          OrgSelectorState(
            financialYear: _currentFinancialYearLabel(),
          ),
        );

  final UserOrganizationRepository _repository;

  Future<void> loadOrganizations(
    String userId, {
    String? phoneNumber,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final orgs = await _repository.loadOrganizationsForUser(
        userId: userId,
        phoneNumber: phoneNumber,
      );
      emit(
        state.copyWith(
          status: ViewStatus.success,
          organizations: orgs,
          message: orgs.isEmpty ? 'No organizations found.' : null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load organizations. Please try again.',
        ),
      );
    }
  }

  void selectOrganization(OrganizationMembership organization) {
    final isAdmin =
        organization.role.toUpperCase() == 'ADMIN';
    emit(
      state.copyWith(
        selectedOrganization: organization,
        isFinancialYearLocked: !isAdmin,
        financialYear: isAdmin
            ? state.financialYear ?? _currentFinancialYearLabel()
            : _currentFinancialYearLabel(),
      ),
    );
  }

  void selectFinancialYear(String year) {
    if (state.isFinancialYearLocked) return;
    emit(state.copyWith(financialYear: year));
  }

  static String _currentFinancialYearLabel() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return 'FY $startYear-$endYear';
  }
}
