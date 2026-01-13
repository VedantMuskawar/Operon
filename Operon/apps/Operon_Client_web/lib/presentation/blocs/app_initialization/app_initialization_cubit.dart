import 'package:core_services/core_services.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/services/org_context_persistence_service.dart';
import 'package:dash_web/data/services/org_context_persistence_service.dart' show SavedOrgContext;
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/org_selector/org_selector_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AppInitializationStatus {
  initial,
  checkingAuth,
  authenticated,
  notAuthenticated,
  loadingOrganizations,
  restoringContext,
  contextRestored,
  contextRestoreFailed,
  ready,
  error,
}

class AppInitializationState {
  const AppInitializationState({
    this.status = AppInitializationStatus.initial,
    this.errorMessage,
    this.userId,
    this.hasSavedContext = false,
  });

  final AppInitializationStatus status;
  final String? errorMessage;
  final String? userId;
  final bool hasSavedContext;

  AppInitializationState copyWith({
    AppInitializationStatus? status,
    String? errorMessage,
    String? userId,
    bool? hasSavedContext,
  }) {
    return AppInitializationState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
      hasSavedContext: hasSavedContext ?? this.hasSavedContext,
    );
  }
}

class AppInitializationCubit extends Cubit<AppInitializationState> {
  AppInitializationCubit({
    required AuthRepository authRepository,
    required OrganizationContextCubit orgContextCubit,
    required OrgSelectorCubit orgSelectorCubit,
    required AppAccessRolesRepository appAccessRolesRepository,
  })  : _authRepository = authRepository,
        _orgContextCubit = orgContextCubit,
        _orgSelectorCubit = orgSelectorCubit,
        _appAccessRolesRepository = appAccessRolesRepository,
        super(const AppInitializationState()) {
    // Don't auto-initialize - let splash screen or OTP verification trigger it
    // This prevents initialization before authentication
  }

  final AuthRepository _authRepository;
  final OrganizationContextCubit _orgContextCubit;
  final OrgSelectorCubit _orgSelectorCubit;
  final AppAccessRolesRepository _appAccessRolesRepository;

  Future<void> initialize() async {
    try {
      emit(state.copyWith(status: AppInitializationStatus.checkingAuth));

      // Minimal delay for Firebase Auth to restore session (reduced from 200ms)
      // Only wait if absolutely necessary - most of the time auth is already ready
      await Future.delayed(const Duration(milliseconds: 50));

      // Check if user is authenticated
      final user = await _authRepository.currentUser();
      
      if (user == null) {
        emit(state.copyWith(
          status: AppInitializationStatus.notAuthenticated,
        ));
        return;
      }

      emit(state.copyWith(
        status: AppInitializationStatus.authenticated,
        userId: user.id,
      ));

      // PARALLEL LOADING: Load saved context and organizations simultaneously
      emit(state.copyWith(status: AppInitializationStatus.loadingOrganizations));
      
      final results = await Future.wait([
        OrgContextPersistenceService.loadContext(),
        _orgSelectorCubit.loadOrganizations(
          user.id,
          phoneNumber: user.phoneNumber,
        ),
      ]);

      final savedContext = results[0] as SavedOrgContext?;
      final hasSavedContext = savedContext != null && savedContext.userId == user.id;

      emit(state.copyWith(hasSavedContext: hasSavedContext));

      final orgState = _orgSelectorCubit.state;
      if (orgState.organizations.isEmpty) {
        emit(state.copyWith(
          status: AppInitializationStatus.ready,
        ));
        return;
      }

      // If we have saved context, try to restore it (optimistic)
      if (hasSavedContext) {
        emit(state.copyWith(status: AppInitializationStatus.restoringContext));

        try {
          // Optimistic restoration - restore immediately, validate in background
          await _orgContextCubit.restoreFromSaved(
            userId: user.id,
            availableOrganizations: orgState.organizations,
            fetchAppAccessRole: (orgId, appAccessRoleId) async {
              // Try to fetch from cache first (repository has caching)
              final appAccessRole = await _appAccessRolesRepository.fetchAppAccessRole(orgId, appAccessRoleId);
              
              if (appAccessRole != null) {
                return appAccessRole;
              }

              // If not in cache, fetch all roles and find the matching one
              final appRoles = await _appAccessRolesRepository.fetchAppAccessRoles(orgId);
              
              // Try to find by ID first
              try {
                return appRoles.firstWhere(
                  (role) => role.id == appAccessRoleId,
                );
              } catch (_) {
                // Try by name (case-insensitive)
                try {
                  return appRoles.firstWhere(
                    (role) => role.name.toUpperCase() == appAccessRoleId.toUpperCase(),
                  );
                } catch (_) {
                  // Fallback: try admin role or first role
                  try {
                    return appRoles.firstWhere((role) => role.isAdmin);
                  } catch (_) {
                    // Last resort: create a default role
                    return appRoles.isNotEmpty
                        ? appRoles.first
                        : AppAccessRole(
                            id: '$orgId-$appAccessRoleId',
                            name: appAccessRoleId,
                            description: 'Default role',
                            colorHex: '#6F4BFF',
                            isAdmin: appAccessRoleId.toUpperCase() == 'ADMIN',
                          );
                  }
                }
              }
            },
          );

          // Check state after restoration - the optimistic emit should have already happened
          // Give a tiny delay to ensure state is propagated
          await Future.delayed(const Duration(milliseconds: 10));
          final restoredState = _orgContextCubit.state;
          
          // If we have a selection (org + financial year), consider it restored
          // appAccessRole can be null initially (loaded in background) but that's OK
          if (restoredState.hasSelection && !restoredState.isRestoring) {
            emit(state.copyWith(
              status: AppInitializationStatus.contextRestored,
            ));
          } else {
            // If restoration failed, check if we should clear context
            // Only clear if there's definitely no valid saved context
            if (!restoredState.hasSelection) {
              await OrgContextPersistenceService.clearContext();
            }
            emit(state.copyWith(
              status: AppInitializationStatus.contextRestoreFailed,
            ));
          }
        } catch (e) {
          // If restore fails, clear the saved context and continue
          await OrgContextPersistenceService.clearContext();
          emit(state.copyWith(
            status: AppInitializationStatus.contextRestoreFailed,
          ));
        }
      } else {
        emit(state.copyWith(status: AppInitializationStatus.ready));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AppInitializationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Retry initialization after an error
  Future<void> retry() async {
    await initialize();
  }
}
