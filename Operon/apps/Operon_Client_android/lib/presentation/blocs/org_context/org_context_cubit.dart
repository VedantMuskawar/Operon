import 'package:dash_mobile/data/services/org_context_persistence_service.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';
import 'package:dash_mobile/domain/entities/app_access_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationContextState {
  const OrganizationContextState({
    this.organization,
    this.financialYear,
    this.appAccessRole,
    this.isRestoring = false,
  });

  final OrganizationMembership? organization;
  final String? financialYear;
  final AppAccessRole? appAccessRole; // Changed from OrganizationRole to AppAccessRole
  final bool isRestoring;

  bool get hasSelection =>
      organization != null && (financialYear?.isNotEmpty ?? false);

  // Helper methods for backward compatibility and convenience
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
    // If userId is null (old saved context), allow it for backward compatibility
    if (savedContext.userId != null && savedContext.userId != userId) {
      // Different user - clear the saved context
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    // Find if the saved org is still available for this user
    // Match by org ID only - user can only have one membership per org
    final matchingOrg = availableOrganizations.firstWhere(
      (org) => org.id == savedContext.orgId,
      orElse: () => availableOrganizations.isNotEmpty 
          ? availableOrganizations.first 
          : throw StateError('No organizations available'),
    );

    // If saved org is not found, just clear and return
    final hasSavedOrg = availableOrganizations.any(
      (org) => org.id == savedContext.orgId,
    );
    if (!hasSavedOrg) {
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }

    // OPTIMISTIC RESTORATION: Restore immediately from saved context
    // This allows instant navigation while validation happens in background
    // Ensure financialYear is not empty
    final financialYear = savedContext.financialYear.isNotEmpty 
        ? savedContext.financialYear 
        : null;
    
    if (financialYear == null) {
      // Invalid saved context - missing financial year
      await OrgContextPersistenceService.clearContext();
      emit(state.copyWith(isRestoring: false));
      return;
    }
    
    emit(
      OrganizationContextState(
        organization: matchingOrg,
        financialYear: financialYear,
        appAccessRole: null, // Will be loaded in background
        isRestoring: false, // Set to false so navigation can proceed
      ),
    );

    // Background validation: Fetch and validate App Access Role
    try {
      // Use appAccessRoleId if available, otherwise fallback to role
      final roleId = savedContext.appAccessRoleId ?? 
                     matchingOrg.appAccessRoleId ?? 
                     matchingOrg.role;
      final appAccessRole = await fetchAppAccessRole(matchingOrg.id, roleId);
      
      // Update with validated role
      emit(
        OrganizationContextState(
          organization: matchingOrg,
          financialYear: savedContext.financialYear,
          appAccessRole: appAccessRole,
          isRestoring: false,
        ),
      );
    } catch (e) {
      // If validation fails, don't clear context - just log and continue
      // The user is already on home with the org context, which is better than nothing
      // The role will be null, but basic navigation should still work
      // In production, you might want to show a subtle warning
      print('Warning: Failed to restore App Access Role: $e');
      // Keep the context but with null role - better than clearing everything
      emit(
        OrganizationContextState(
          organization: matchingOrg,
          financialYear: savedContext.financialYear,
          appAccessRole: null, // Role fetch failed, but keep the org context
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
    // Emit state immediately for instant UI update
    emit(
      OrganizationContextState(
        organization: organization,
        financialYear: financialYear,
        appAccessRole: appAccessRole,
        isRestoring: false,
      ),
    );

    // Save to local storage in background (non-blocking)
    // Save the actual AppAccessRole ID that was fetched, not the organization's role field
    await OrgContextPersistenceService.saveContext(
      userId: userId,
      orgId: organization.id,
      orgName: organization.name,
      orgRole: organization.role, // Keep for backward compatibility
      appAccessRoleId: appAccessRole.id, // Save the actual AppAccessRole ID
      financialYear: financialYear,
    );
  }

  Future<void> clear() async {
    await OrgContextPersistenceService.clearContext();
    emit(const OrganizationContextState());
  }
}

