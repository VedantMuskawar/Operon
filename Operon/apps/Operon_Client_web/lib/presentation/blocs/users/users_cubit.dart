import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_user.dart';
import 'package:dash_web/domain/exceptions/duplicate_phone_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UsersState extends BaseState {
  const UsersState({
    super.status = ViewStatus.initial,
    this.users = const [],
    this.appAccessRoles = const [], // ✅ NEW: Available app access roles
    this.message,
  }) : super(message: message);

  final List<OrganizationUser> users;
  final List<AppAccessRole> appAccessRoles; // ✅ NEW: For dropdowns/selection
  @override
  final String? message;

  @override
  UsersState copyWith({
    ViewStatus? status,
    List<OrganizationUser>? users,
    List<AppAccessRole>? appAccessRoles,
    String? message,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      appAccessRoles: appAccessRoles ?? this.appAccessRoles,
      message: message ?? this.message,
    );
  }
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit({
    required UsersRepository repository,
    required AppAccessRolesRepository appAccessRolesRepository,
    required String organizationId,
    required String organizationName,
  })  : _repository = repository,
        _appAccessRolesRepository = appAccessRolesRepository,
        _organizationId = organizationId,
        _organizationName = organizationName,
        super(const UsersState());

  final UsersRepository _repository;
  final AppAccessRolesRepository _appAccessRolesRepository;
  final String _organizationId;
  final String _organizationName;

  String get organizationId => _organizationId;
  String get organizationName => _organizationName;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      // Load users and app access roles in parallel
      final usersFuture = _repository.fetchOrgUsers(_organizationId);
      final appRolesFuture = _appAccessRolesRepository.fetchAppAccessRoles(_organizationId);
      
      final results = await Future.wait([usersFuture, appRolesFuture]);
      final users = results[0] as List<OrganizationUser>;
      final appAccessRoles = results[1] as List<AppAccessRole>;
      
      // Enrich users with app access role objects
      final enrichedUsers = users.map((user) {
        if (user.appAccessRoleId == null) return user;
        final appRole = appAccessRoles.firstWhere(
          (role) => role.id == user.appAccessRoleId,
          orElse: () => appAccessRoles.firstWhere(
            (role) => role.isAdmin,
            orElse: () => appAccessRoles.first,
          ),
        );
        return user.copyWith(appAccessRole: appRole);
      }).toList();
      
      emit(state.copyWith(
        status: ViewStatus.success,
        users: enrichedUsers,
        appAccessRoles: appAccessRoles,
      ));
    } catch (err) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load users. Please try again.',
        ),
      );
    }
  }
  
  Future<void> loadAppAccessRoles() async {
    try {
      final appAccessRoles = await _appAccessRolesRepository.fetchAppAccessRoles(_organizationId);
      emit(state.copyWith(appAccessRoles: appAccessRoles));
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load app access roles.',
      ));
    }
  }

  Future<void> upsertUser(OrganizationUser user) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.upsertOrgUser(
        orgId: _organizationId,
        orgName: _organizationName,
        user: user,
      );
      await load();
    } on DuplicatePhoneNumberException catch (e) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: e.message,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to save user. ${err.toString()}',
        ),
      );
    }
  }

  Future<void> deleteUser(String userId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.removeOrgUser(
        orgId: _organizationId,
        userId: userId,
      );
      await load();
    } catch (err) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to remove user. ${err.toString()}',
        ),
      );
    }
  }
}
