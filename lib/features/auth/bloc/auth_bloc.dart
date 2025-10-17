import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repository/auth_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phoneNumber;
  final String otp;

  const AuthLoginRequested({
    required this.phoneNumber,
    required this.otp,
  });

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class AuthSendOTPRequested extends AuthEvent {
  final String phoneNumber;

  const AuthSendOTPRequested({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User firebaseUser;

  const AuthAuthenticated({required this.firebaseUser});

  @override
  List<Object?> get props => [firebaseUser];
}

class AuthUnauthenticated extends AuthState {}

class AuthOTPSent extends AuthState {
  final String phoneNumber;

  const AuthOTPSent({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSendOTPRequested>(_onAuthSendOTPRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    if (authRepository.isAuthenticated()) {
      final user = authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(firebaseUser: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthSendOTPRequested(
    AuthSendOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await authRepository.sendOTP(event.phoneNumber);
      emit(AuthOTPSent(phoneNumber: event.phoneNumber));
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await authRepository.verifyOTPAndSignIn(event.otp);
      if (user != null) {
        emit(AuthAuthenticated(firebaseUser: user));
      } else {
        emit(const AuthFailure(message: 'Authentication failed'));
      }
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthFailure(message: e.toString()));
    }
  }
}
