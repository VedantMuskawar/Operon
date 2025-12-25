import 'package:dash_mobile/data/repositories/auth_repository.dart';
import 'package:dash_mobile/data/repositories/roles_repository.dart';
import 'package:dash_mobile/data/services/org_context_persistence_service.dart';
import 'package:dash_mobile/domain/entities/organization_role.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_selector/org_selector_cubit.dart';
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
    required RolesRepository rolesRepository,
  })  : _authRepository = authRepository,
        _orgContextCubit = orgContextCubit,
        _orgSelectorCubit = orgSelectorCubit,
        _rolesRepository = rolesRepository,
        super(const AppInitializationState()) {
    initialize();
  }

  final AuthRepository _authRepository;
  final OrganizationContextCubit _orgContextCubit;
  final OrgSelectorCubit _orgSelectorCubit;
  final RolesRepository _rolesRepository;

  Future<void> initialize() async {
    try {
      emit(state.copyWith(status: AppInitializationStatus.checkingAuth));

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
            fetchRole: (orgId, roleTitle) async {
              final roles = await _rolesRepository.fetchRoles(orgId);
              return roles.firstWhere(
                (role) => role.title.toUpperCase() == roleTitle.toUpperCase(),
                orElse: () => OrganizationRole(
                  id: '$orgId-$roleTitle',
                  title: roleTitle,
                  salaryType: SalaryType.salaryMonthly,
                  colorHex: '#6F4BFF',
                ),
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

