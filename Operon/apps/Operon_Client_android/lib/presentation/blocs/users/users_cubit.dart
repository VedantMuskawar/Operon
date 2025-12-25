import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/data/repositories/users_repository.dart';
import 'package:dash_mobile/domain/entities/organization_user.dart';
import 'package:dash_mobile/domain/exceptions/duplicate_phone_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UsersState extends BaseState {
  const UsersState({
    super.status = ViewStatus.initial,
    this.users = const [],
    this.message,
  }) : super(message: message);

  final List<OrganizationUser> users;
  @override
  final String? message;

  @override
  UsersState copyWith({
    ViewStatus? status,
    List<OrganizationUser>? users,
    String? message,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      message: message ?? this.message,
    );
  }
}

class UsersCubit extends Cubit<UsersState> {
  UsersCubit({
    required UsersRepository repository,
    required String organizationId,
    required String organizationName,
  })  : _repository = repository,
        _organizationId = organizationId,
        _organizationName = organizationName,
        super(const UsersState());

  final UsersRepository _repository;
  final String _organizationId;
  final String _organizationName;

  String get organizationId => _organizationId;
  String get organizationName => _organizationName;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final users = await _repository.fetchOrgUsers(_organizationId);
      emit(state.copyWith(status: ViewStatus.success, users: users));
    } catch (err) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load users. Please try again.',
        ),
      );
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

