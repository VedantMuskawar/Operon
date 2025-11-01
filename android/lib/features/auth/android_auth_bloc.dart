import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/android_auth_repository.dart';

// Events
abstract class AndroidAuthEvent extends Equatable {
  const AndroidAuthEvent();

  @override
  List<Object?> get props => [];
}

class AndroidAuthCheckRequested extends AndroidAuthEvent {}

class AndroidAuthLoginRequested extends AndroidAuthEvent {
  final String phoneNumber;
  final String otp;

  const AndroidAuthLoginRequested({
    required this.phoneNumber,
    required this.otp,
  });

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class AndroidAuthSendOTPRequested extends AndroidAuthEvent {
  final String phoneNumber;

  const AndroidAuthSendOTPRequested({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AndroidAuthLogoutRequested extends AndroidAuthEvent {}

// States
abstract class AndroidAuthState extends Equatable {
  const AndroidAuthState();

  @override
  List<Object?> get props => [];
}

class AndroidAuthInitial extends AndroidAuthState {}

class AndroidAuthLoading extends AndroidAuthState {}

class AndroidAuthAuthenticated extends AndroidAuthState {
  final User firebaseUser;

  const AndroidAuthAuthenticated({required this.firebaseUser});

  @override
  List<Object?> get props => [firebaseUser];
}

class AndroidAuthUnauthenticated extends AndroidAuthState {}

class AndroidAuthOTPSent extends AndroidAuthState {
  final String phoneNumber;

  const AndroidAuthOTPSent({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class AndroidAuthFailure extends AndroidAuthState {
  final String message;

  const AndroidAuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class AndroidAuthBloc extends Bloc<AndroidAuthEvent, AndroidAuthState> {
  final AndroidAuthRepository authRepository;

  AndroidAuthBloc({required this.authRepository}) : super(AndroidAuthInitial()) {
    on<AndroidAuthCheckRequested>(_onAuthCheckRequested);
    on<AndroidAuthSendOTPRequested>(_onAuthSendOTPRequested);
    on<AndroidAuthLoginRequested>(_onAuthLoginRequested);
    on<AndroidAuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AndroidAuthCheckRequested event,
    Emitter<AndroidAuthState> emit,
  ) async {
    emit(AndroidAuthLoading());
    
    if (authRepository.isAuthenticated()) {
      final user = authRepository.getCurrentUser();
      if (user != null) {
        emit(AndroidAuthAuthenticated(firebaseUser: user));
      } else {
        emit(AndroidAuthUnauthenticated());
      }
    } else {
      emit(AndroidAuthUnauthenticated());
    }
  }

  Future<void> _onAuthSendOTPRequested(
    AndroidAuthSendOTPRequested event,
    Emitter<AndroidAuthState> emit,
  ) async {
    emit(AndroidAuthLoading());
    
    try {
      await authRepository.sendOTP(event.phoneNumber);
      emit(AndroidAuthOTPSent(phoneNumber: event.phoneNumber));
    } catch (e) {
      emit(AndroidAuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLoginRequested(
    AndroidAuthLoginRequested event,
    Emitter<AndroidAuthState> emit,
  ) async {
    emit(AndroidAuthLoading());
    
    try {
      final user = await authRepository.verifyOTPAndSignIn(event.otp);
      if (user != null) {
        emit(AndroidAuthAuthenticated(firebaseUser: user));
      } else {
        emit(const AndroidAuthFailure(message: 'Authentication failed'));
      }
    } catch (e) {
      emit(AndroidAuthFailure(message: e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AndroidAuthLogoutRequested event,
    Emitter<AndroidAuthState> emit,
  ) async {
    emit(AndroidAuthLoading());
    
    try {
      await authRepository.signOut();
      emit(AndroidAuthUnauthenticated());
    } catch (e) {
      emit(AndroidAuthFailure(message: e.toString()));
    }
  }
}



