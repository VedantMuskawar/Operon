import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/src/models/app_access_role.dart';
import 'package:operon_auth_flow/src/models/organization_membership.dart';
import 'package:operon_auth_flow/src/services/org_context_persistence_service.dart';

class OrganizationContextState {
  const OrganizationContextState({
    this.organization,
    this.financialYear,
    this.appAccessRole,
    this.isRestoring = false,
  });

  final OrganizationMembership? organization;
  final String? financialYear;
  final AppAccessRole? appAccessRole;
  final bool isRestoring;

  bool get hasSelection => organization != null && (financialYear?.isNotEmpty ?? false);

  // Convenience helpers
  bool get isAdmin => appAccessRole?.isAdmin ?? false;
  bool canAccessSection(String sectionName) => appAccessRole?.canAccessSection(sectionName) ?? false;
  bool canCreate(String pageName) => appAccessRole?.canCreate(pageName) ?? false;
  bool canEdit(String pageName) => appAccessRole?.canEdit(pageName) ?? false;
  bool canDelete(String pageName) => appAccessRole?.canDelete(pageName) ?? false;
  bool canAccessPage(String pageName) => appAccessRole?.canAccessPage(pageName) ?? false;

  OrganizationContextState copyWith({
    OrganizationMembership? organization,
    String? financialYear,
    AppAccessRole? appAccessRole,
    bool? isRestoring,
  }) {
    return OrganizationContextState(
      organization: organization ?? this.organization,
      financialYear: financialYear ?? this.financialYear,
      appAccessRole: appAccessRole ?? this.appAccessRole,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

class OrganizationContextCubit extends Cubit<OrganizationContextState> {
  OrganizationContextCubit() : super(const OrganizationContextState()) {
    _restoreContext();
  }

  /// Restore saved context from local storage
  Future<void> _restoreContext() async {
    final savedContext = await OrgContextPersistenceService.loadContext();
    if (savedContext != null) {
      emit(state.copyWith(isRestoring: true));
    }
  }

  /// Restore context from saved values (called after organizations are loaded)
  /// Uses optimistic restoration: restores immediately, validates in background
  Future<void> restoreFromSaved({
    required String userId,
    required List<OrganizationMembership> availableOrganizations,
    required Future<AppAccessRole> Function(String orgId, String appAccessRoleId) fetchAppAccessRole,
  }) async {
    final savedContext = await OrgContextPersistenceService.loadContext();
    if (savedContext == null) {
      emit(state.copyWith(isRestoring: false));
      return;
    }

    // If userId is set in saved context, it must match current user
    if (savedContext.userId != null && savedContext.userId != userId) {
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    final hasSavedOrg = availableOrganizations.any((org) => org.id == savedContext.orgId);
    if (!hasSavedOrg) {
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    final matchingOrg = availableOrganizations.firstWhere(
      (org) => org.id == savedContext.orgId,
      orElse: () => availableOrganizations.isNotEmpty ? availableOrganizations.first : throw StateError('No organizations available'),
    );

    final financialYear = savedContext.financialYear.isNotEmpty ? savedContext.financialYear : null;
    if (financialYear == null) {
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    // OPTIMISTIC RESTORATION: restore immediately (role loaded in background)
    emit(
      OrganizationContextState(
        organization: matchingOrg,
        financialYear: financialYear,
        appAccessRole: null,
        isRestoring: false,
      ),
    );

    // Background validation: Fetch and validate App Access Role
    try {
      final roleId = savedContext.appAccessRoleId ?? matchingOrg.appAccessRoleId ?? matchingOrg.role;
      final appAccessRole = await fetchAppAccessRole(matchingOrg.id, roleId);

      emit(
        OrganizationContextState(
          organization: matchingOrg,
          financialYear: savedContext.financialYear,
          appAccessRole: appAccessRole,
          isRestoring: false,
        ),
      );
    } catch (e) {
      // Keep context; role may be null but better than clearing everything.
      // ignore: avoid_print
      print('Warning: Failed to restore App Access Role: $e');
      emit(
        OrganizationContextState(
          organization: matchingOrg,
          financialYear: savedContext.financialYear,
          appAccessRole: null,
          isRestoring: false,
        ),
      );
    }
  }

  Future<void> setContext({
    required String userId,
    required OrganizationMembership organization,
    required String financialYear,
    required AppAccessRole appAccessRole,
  }) async {
    emit(
      OrganizationContextState(
        organization: organization,
        financialYear: financialYear,
        appAccessRole: appAccessRole,
        isRestoring: false,
      ),
    );

    await OrgContextPersistenceService.saveContext(
      userId: userId,
      orgId: organization.id,
      orgName: organization.name,
      orgRole: organization.role,
      appAccessRoleId: appAccessRole.id,
      financialYear: financialYear,
    );
  }

  Future<void> clear() async {
    await OrgContextPersistenceService.clearContext();
    emit(const OrganizationContextState());
  }
}

