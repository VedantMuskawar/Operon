import 'package:dash_web/data/services/org_context_persistence_service.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationContextState {
  const OrganizationContextState({
    this.organization,
    this.financialYear,
    this.appAccessRole, // ✅ Changed from role to appAccessRole
    this.isRestoring = false,
  });

  final OrganizationMembership? organization;
  final String? financialYear;
  final AppAccessRole? appAccessRole; // ✅ Changed from OrganizationRole to AppAccessRole
  final bool isRestoring;

  bool get hasSelection =>
      organization != null && (financialYear?.isNotEmpty ?? false);

  // Helper for backward compatibility (if needed temporarily)
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
    required Future<AppAccessRole> Function(String orgId, String appAccessRoleId) fetchAppAccessRole,
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
      // Fetch the app access role details
      // Use appAccessRoleId if available, otherwise fallback to role
      final roleId = matchingOrg.appAccessRoleId ?? matchingOrg.role;
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
      // If restore fails, just clear the saved context
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
    }
  }

  Future<void> setContext({
    required String userId,
    required OrganizationMembership organization,
    required String financialYear,
    required AppAccessRole appAccessRole, // ✅ Changed from OrganizationRole to AppAccessRole
  }) async {
    // Emit state immediately so navigation can proceed
    emit(
      OrganizationContextState(
        organization: organization,
        financialYear: financialYear,
        appAccessRole: appAccessRole,
        isRestoring: false,
      ),
    );
    
    // Save to local storage in background
    // Use appAccessRoleId if available, otherwise fallback to role
    final roleId = organization.appAccessRoleId ?? organization.role;
    await OrgContextPersistenceService.saveContext(
      userId: userId,
      orgId: organization.id,
      orgName: organization.name,
      orgRole: roleId,
      financialYear: financialYear,
    );
  }

  Future<void> clear() async {
    await OrgContextPersistenceService.clearContext();
    emit(const OrganizationContextState());
  }
}
