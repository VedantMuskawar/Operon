import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const AuthState()) {
    on<PhoneNumberSubmitted>(_onPhoneSubmitted);
    on<OtpSubmitted>(_onOtpSubmitted);
    on<AuthReset>(_onReset);
    on<AuthStatusRequested>(_onStatusRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onPhoneSubmitted(
    PhoneNumberSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      phoneNumber: event.phoneNumber,
      message: null,
    ));
    try {
      final session = await _authRepository.sendOtp(
        phoneNumber: event.phoneNumber,
        forceResendingToken: state.session?.resendToken as dynamic,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        session: session,
      ));
    } catch (e) {
      debugPrint('[AuthBloc] sendOtp failed for ${event.phoneNumber}: $e');
      
      String errorMessage = 'Failed to send OTP. Please try again.';
      if (e is FirebaseAuthException) {
        debugPrint('[AuthBloc] FirebaseAuth error: ${e.code} - ${e.message}');
        switch (e.code) {
          case 'invalid-phone-number':
            errorMessage = 'Invalid phone number. Please check and try again.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many requests. Please try again later.';
            break;
          case 'quota-exceeded':
            errorMessage = 'SMS quota exceeded. Please try again later.';
            break;
          case 'app-not-authorized':
            errorMessage = 'App not authorized. Please check Firebase configuration.';
            break;
          default:
            errorMessage = 'Failed to send OTP: ${e.message ?? e.code}';
        }
      } else if (e is TimeoutException) {
        errorMessage = e.message ?? 'Request timed out. Please check your network.';
      }
      
      emit(
        state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
        ),
      );
    }
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

      emit(state.copyWith(
        status: ViewStatus.success,
        userProfile: profile,
        message: null,
      ));
    } catch (e) {
      await _authRepository.signOut();
      String errorMessage = 'OTP verification failed. Please retry.';
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? e.code;
      }
      emit(
        state.copyWith(
        status: ViewStatus.failure,
          message: errorMessage,
          userProfile: null,
        ),
      );
    }
  }

  Future<void> _onReset(AuthReset event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    // Note: Phone number is kept in storage for convenience
    // User can still use saved phone number after logout
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

