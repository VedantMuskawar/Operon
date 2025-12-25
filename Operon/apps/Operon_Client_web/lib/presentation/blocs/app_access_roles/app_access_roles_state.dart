part of 'app_access_roles_cubit.dart';

class AppAccessRolesState extends BaseState {
  const AppAccessRolesState({
    super.status = ViewStatus.initial,
    this.roles = const [],
    this.message,
  }) : super(message: message);

  final List<AppAccessRole> roles;
  @override
  final String? message;

  @override
  AppAccessRolesState copyWith({
    ViewStatus? status,
    List<AppAccessRole>? roles,
    String? message,
  }) {
    return AppAccessRolesState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      message: message ?? this.message,
    );
  }
}
