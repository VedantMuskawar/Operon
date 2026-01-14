import 'dart:async';
import 'dart:convert';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/user_organization_repository.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

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
    // #region agent log
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_orgs_start",
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "location": "org_selector_cubit.dart:loadOrganizations",
          "message": "Loading organizations start",
          "data": {"userId": userId, "phoneNumber": phoneNumber},
          "sessionId": "debug-session",
          "runId": "run1",
          "hypothesisId": "A"
        }),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (_) {}
    // #endregion
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final orgs = await _repository.loadOrganizationsForUser(
        userId: userId,
        phoneNumber: phoneNumber,
      );
      // #region agent log
      try {
        await http.post(
          Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_orgs_success",
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "location": "org_selector_cubit.dart:loadOrganizations",
            "message": "Organizations loaded",
            "data": {"orgCount": orgs.length, "orgIds": orgs.map((o) => o.id).toList()},
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "A"
          }),
        ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
      } catch (_) {}
      // #endregion
      emit(
        state.copyWith(
          status: ViewStatus.success,
          organizations: orgs,
          message: orgs.isEmpty ? 'No organizations found.' : null,
        ),
      );
    } catch (error) {
      // #region agent log
      try {
        await http.post(
          Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_orgs_error",
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "location": "org_selector_cubit.dart:loadOrganizations",
            "message": "Organizations load failed",
            "data": {"error": error.toString()},
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "A"
          }),
        ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
      } catch (_) {}
      // #endregion
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
