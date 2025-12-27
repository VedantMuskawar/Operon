import 'package:dash_mobile/data/services/org_context_persistence_service.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationContextState {
  const OrganizationContextState({
    this.organization,
    this.financialYear,
    this.role,
    this.isRestoring = false,
  });

  final OrganizationMembership? organization;
  final String? financialYear;
  final OrganizationRole? role;
  final bool isRestoring;

  bool get hasSelection =>
      organization != null && (financialYear?.isNotEmpty ?? false);

  OrganizationContextState copyWith({
    OrganizationMembership? organization,
    String? financialYear,
    OrganizationRole? role,
    bool? isRestoring,
  }) {
    return OrganizationContextState(
      organization: organization ?? this.organization,
      financialYear: financialYear ?? this.financialYear,
      role: role ?? this.role,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

class OrganizationContextCubit extends Cubit<OrganizationContextState> {
  OrganizationContextCubit() : super(const OrganizationContextState()) {
    // Try to restore saved context on initialization
    _restoreContext();
  }

  /// Restore saved context from local storage
  Future<void> _restoreContext() async {
    final savedContext = await OrgContextPersistenceService.loadContext();
    if (savedContext != null) {
      emit(state.copyWith(isRestoring: true));
      // Context will be fully restored when organization details are loaded
      // This flag just indicates we're in the process of restoring
    }
  }

  /// Restore context from saved values (called after organizations are loaded)
  Future<void> restoreFromSaved({
    required String userId,
    required List<OrganizationMembership> availableOrganizations,
    required Future<OrganizationRole> Function(String orgId, String role) fetchRole,
  }) async {
    final savedContext = await OrgContextPersistenceService.loadContext();
    if (savedContext == null || savedContext.userId != userId) {
      emit(state.copyWith(isRestoring: false));
      return;
    }

    // Find if the saved org is still available for this user
    final matchingOrg = availableOrganizations.firstWhere(
      (org) => org.id == savedContext.orgId && org.role == savedContext.orgRole,
      orElse: () => availableOrganizations.isNotEmpty ? availableOrganizations.first : throw StateError('No organizations available'),
    );

    // If saved org is not found, just clear and return
    final hasSavedOrg = availableOrganizations.any(
      (org) => org.id == savedContext.orgId && org.role == savedContext.orgRole,
    );
    if (!hasSavedOrg) {
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    try {
      // Fetch the role details
      final role = await fetchRole(matchingOrg.id, matchingOrg.role);
      
      emit(
        OrganizationContextState(
          organization: matchingOrg,
          financialYear: savedContext.financialYear,
          role: role,
          isRestoring: false,
        ),
      );
    } catch (e) {
      // If restore fails, just clear the saved context
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
    }
  }

  void setContext({
    required String userId,
    required OrganizationMembership organization,
    required String financialYear,
    required OrganizationRole role,
  }) async {
    // Save to local storage
    await OrgContextPersistenceService.saveContext(
      userId: userId,
      orgId: organization.id,
      orgName: organization.name,
      orgRole: organization.role,
      financialYear: financialYear,
    );

    emit(
      OrganizationContextState(
        organization: organization,
        financialYear: financialYear,
        role: role,
        isRestoring: false,
      ),
    );
  }

  Future<void> clear() async {
    await OrgContextPersistenceService.clearContext();
    emit(const OrganizationContextState());
  }
}

