import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
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

class AuthOrganizationSelectionRequired extends AuthState {
  final User firebaseUser;
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> organizations;
  final bool isSuperAdmin;

  const AuthOrganizationSelectionRequired({
    required this.firebaseUser,
    required this.userData,
    required this.organizations,
    required this.isSuperAdmin,
  });

  @override
  List<Object?> get props => [firebaseUser, userData, organizations, isSuperAdmin];
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
        // Get user data and organizations to show organization selection
        try {
          final userData = await authRepository.getUserDocument(user.uid);
          final organizations = await authRepository.getUserOrganizations(user.uid);
          
          // Check if user is SuperAdmin by looking for SuperAdmin organization with role 0
          final isSuperAdmin = organizations.any((org) => 
            org['orgId'] == AppConstants.superAdminOrgId && org['role'] == 0);
          
          if (userData != null) {
            emit(AuthOrganizationSelectionRequired(
              firebaseUser: user,
              userData: userData,
              organizations: organizations,
              isSuperAdmin: isSuperAdmin,
            ));
          } else {
            emit(AuthUnauthenticated());
          }
        } catch (e) {
          // If there's an error getting user data, sign out and show login
          await authRepository.signOut();
          emit(AuthUnauthenticated());
        }
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
        // Get user data and organizations
        final userData = await authRepository.getUserDocument(user.uid);
        final organizations = await authRepository.getUserOrganizations(user.uid);
        
        // Check if user is SuperAdmin by looking for SuperAdmin organization with role 0
        final isSuperAdmin = organizations.any((org) => 
          org['orgId'] == AppConstants.superAdminOrgId && org['role'] == 0);
        
        print('🔍 AuthBloc: Checking SuperAdmin status...');
        print('🔍 AuthBloc: Organizations: ${organizations.map((org) => '${org['orgId']}:${org['role']}').join(', ')}');
        print('🔍 AuthBloc: SuperAdmin Org ID: ${AppConstants.superAdminOrgId}');
        print('🔍 AuthBloc: Is SuperAdmin: $isSuperAdmin');
        
        if (userData != null) {
          emit(AuthOrganizationSelectionRequired(
            firebaseUser: user,
            userData: userData,
            organizations: organizations,
            isSuperAdmin: isSuperAdmin,
          ));
        } else {
          emit(const AuthFailure(message: 'User data not found'));
        }
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
