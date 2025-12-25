import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_superadmin/data/datasources/firestore_user_checker.dart';
import 'package:dash_superadmin/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    required FirestoreUserChecker userChecker,
  })  : _authRepository = authRepository,
        _userChecker = userChecker,
        super(const AuthState()) {
    on<PhoneNumberSubmitted>(_onPhoneSubmitted);
    on<OtpSubmitted>(_onOtpSubmitted);
    on<AuthReset>(_onReset);
    on<AuthStatusRequested>(_onStatusRequested);
  }

  final AuthRepository _authRepository;
  final FirestoreUserChecker _userChecker;

  Future<void> _onPhoneSubmitted(
    PhoneNumberSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      phoneNumber: event.phoneNumber,
      message: null,
    ));
    final session = await _authRepository.sendOtp(phoneNumber: event.phoneNumber);
    emit(state.copyWith(
      status: ViewStatus.success,
      session: session,
      isAuthorized: true,
    ));
  }

  Future<void> _onOtpSubmitted(
    OtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final profile = await _authRepository.verifyOtp(
        verificationId: event.verificationId,
        smsCode: event.code,
      );

      final normalizedPhone = profile.phoneNumber.trim();
      final record =
          await _userChecker.fetchSuperAdminByPhone(normalizedPhone);

      if (record == null || !record.isSuperAdmin) {
        await _authRepository.signOut();
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Unauthorized User',
        ));
        return;
      }

      if ((record.uid == null || record.uid!.isEmpty) && record.id.isNotEmpty) {
        await _userChecker.updateUserUid(
          documentId: record.id,
          uid: profile.id,
        );
      }

      emit(state.copyWith(
        status: ViewStatus.success,
        userProfile: profile,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'OTP verification failed. Please retry.',
      ));
    }
  }

  Future<void> _onReset(AuthReset event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    emit(const AuthState());
  }

  Future<void> _onStatusRequested(
    AuthStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = await _authRepository.currentUser();
    emit(state.copyWith(userProfile: user));
  }
}
