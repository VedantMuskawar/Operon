import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/data/repositories/roles_repository.dart';
import 'package:dash_mobile/domain/entities/organization_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RolesState extends BaseState {
  const RolesState({
    super.status = ViewStatus.initial,
    this.roles = const [],
    this.message,
  }) : super(message: message);

  final List<OrganizationRole> roles;
  @override
  final String? message;

  @override
  RolesState copyWith({
    ViewStatus? status,
    List<OrganizationRole>? roles,
    String? message,
  }) {
    return RolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      message: message ?? this.message,
    );
  }
}

class RolesCubit extends Cubit<RolesState> {
  RolesCubit({
    required RolesRepository repository,
    required String orgId,
  })  : _repository = repository,
        _orgId = orgId,
        super(const RolesState());

  final RolesRepository _repository;
  final String _orgId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final roles = await _repository.fetchRoles(_orgId);
      emit(state.copyWith(status: ViewStatus.success, roles: roles));
    } catch (error) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load roles. Please try again.',
        ),
      );
    }
  }

  Future<void> createRole(OrganizationRole role) async {
    try {
      await _repository.createRole(_orgId, role);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create role.',
      ));
    }
  }

  Future<void> updateRole(OrganizationRole role) async {
    try {
      await _repository.updateRole(_orgId, role);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update role.',
      ));
    }
  }

  Future<void> deleteRole(String roleId) async {
    try {
      await _repository.deleteRole(_orgId, roleId);
      await load();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete role.',
      ));
    }
  }
}

