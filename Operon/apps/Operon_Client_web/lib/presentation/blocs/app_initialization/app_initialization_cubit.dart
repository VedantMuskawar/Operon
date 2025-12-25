import 'package:core_services/core_services.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/services/org_context_persistence_service.dart';
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

      // Wait a bit for Firebase Auth to restore session (especially on web)
      // This ensures auth state is fully restored before checking
      await Future.delayed(const Duration(milliseconds: 200));

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

      // Check if we have saved context for this user
      final savedContext = await OrgContextPersistenceService.loadContext();
      final hasSavedContext = savedContext != null && savedContext.userId == user.id;

      emit(state.copyWith(hasSavedContext: hasSavedContext));

      // Load organizations
      emit(state.copyWith(status: AppInitializationStatus.loadingOrganizations));
      
      await _orgSelectorCubit.loadOrganizations(
        user.id,
        phoneNumber: user.phoneNumber,
      );

      final orgState = _orgSelectorCubit.state;
      if (orgState.organizations.isEmpty) {
        emit(state.copyWith(
          status: AppInitializationStatus.ready,
        ));
        return;
      }

      // If we have saved context, try to restore it
      if (hasSavedContext) {
        emit(state.copyWith(status: AppInitializationStatus.restoringContext));

        try {
          await _orgContextCubit.restoreFromSaved(
            userId: user.id,
            availableOrganizations: orgState.organizations,
            fetchAppAccessRole: (orgId, appAccessRoleId) async {
              final appRoles = await _appAccessRolesRepository.fetchAppAccessRoles(orgId);
              return appRoles.firstWhere(
                (role) => role.id == appAccessRoleId || role.name.toUpperCase() == appAccessRoleId.toUpperCase(),
                orElse: () {
                  // Fallback: try to find admin role, or create a default one
                  return appRoles.firstWhere(
                    (role) => role.isAdmin,
                    orElse: () => appRoles.isNotEmpty 
                        ? appRoles.first 
                        : AppAccessRole(
                            id: '$orgId-$appAccessRoleId',
                            name: appAccessRoleId,
                            description: 'Default role',
                            colorHex: '#6F4BFF',
                            isAdmin: appAccessRoleId.toUpperCase() == 'ADMIN',
                          ),
                  );
                },
              );
            },
          );

          final restoredState = _orgContextCubit.state;
          if (restoredState.hasSelection && !restoredState.isRestoring) {
            emit(state.copyWith(
              status: AppInitializationStatus.contextRestored,
            ));
          } else {
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
      }

      emit(state.copyWith(status: AppInitializationStatus.ready));
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
