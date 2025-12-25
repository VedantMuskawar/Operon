part of 'auth_bloc.dart';

class AuthState extends BaseState {
  const AuthState({
    super.status = ViewStatus.initial,
    this.phoneNumber,
    this.session,
    this.userProfile,
    this.logs = const <String>[],
    String? errorMessage,
  }) : super(message: errorMessage);

  final String? phoneNumber;
  final PhoneAuthSession? session;
  final UserProfile? userProfile;
  final List<String> logs;

  String? get errorMessage => message;

  @override
  AuthState copyWith({
    ViewStatus? status,
    String? message,
    String? phoneNumber,
    PhoneAuthSession? session,
    UserProfile? userProfile,
    List<String>? logs,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      session: session ?? this.session,
      userProfile: userProfile ?? this.userProfile,
      logs: logs ?? this.logs,
      errorMessage: message ?? errorMessage,
    );
  }
}
