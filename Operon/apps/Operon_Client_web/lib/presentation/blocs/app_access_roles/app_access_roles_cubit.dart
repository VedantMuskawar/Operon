import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
part 'app_access_roles_state.dart';

class AppAccessRolesCubit extends Cubit<AppAccessRolesState> {
  AppAccessRolesCubit({
    required AppAccessRolesRepository repository,
    required String orgId,
  })  : _repository = repository,
        _orgId = orgId,
        super(const AppAccessRolesState()) {
    load();
  }

  final AppAccessRolesRepository _repository;
  final String _orgId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final roles = await _repository.fetchAppAccessRoles(_orgId);
      emit(state.copyWith(status: ViewStatus.success, roles: roles));
    } catch (error) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load app access roles. Please try again.',
        ),
      );
    }
  }

  Future<void> createAppAccessRole(AppAccessRole role) async {
    try {
      await _repository.createAppAccessRole(_orgId, role);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create app access role.',
      ));
    }
  }

  Future<void> updateAppAccessRole(AppAccessRole role) async {
    try {
      await _repository.updateAppAccessRole(_orgId, role);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update app access role.',
      ));
    }
  }

  Future<void> deleteAppAccessRole(String roleId) async {
    try {
      await _repository.deleteAppAccessRole(_orgId, roleId);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete app access role.',
      ));
    }
  }
}
