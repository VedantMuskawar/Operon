import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/services/android_auth_repository.dart';

// Events
abstract class AndroidOrganizationEvent extends Equatable {
  const AndroidOrganizationEvent();

  @override
  List<Object?> get props => [];
}

class AndroidOrganizationLoadRequested extends AndroidOrganizationEvent {
  final String userId;

  const AndroidOrganizationLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class AndroidOrganizationSelected extends AndroidOrganizationEvent {
  final Map<String, dynamic> organization;

  const AndroidOrganizationSelected({required this.organization});

  @override
  List<Object?> get props => [organization];
}

// States
abstract class AndroidOrganizationState extends Equatable {
  const AndroidOrganizationState();

  @override
  List<Object?> get props => [];
}

class AndroidOrganizationInitial extends AndroidOrganizationState {}

class AndroidOrganizationLoading extends AndroidOrganizationState {}

class AndroidOrganizationLoaded extends AndroidOrganizationState {
  final List<Map<String, dynamic>> organizations;
  final bool isSuperAdmin;

  const AndroidOrganizationLoaded({
    required this.organizations,
    this.isSuperAdmin = false,
  });

  @override
  List<Object?> get props => [organizations, isSuperAdmin];
}

class AndroidOrganizationError extends AndroidOrganizationState {
  final String message;

  const AndroidOrganizationError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AndroidOrganizationSelectedState extends AndroidOrganizationState {
  final Map<String, dynamic> organization;

  const AndroidOrganizationSelectedState({required this.organization});

  @override
  List<Object?> get props => [organization];
}

// BLoC
class AndroidOrganizationBloc extends Bloc<AndroidOrganizationEvent, AndroidOrganizationState> {
  final AndroidAuthRepository authRepository;

  AndroidOrganizationBloc({required this.authRepository}) : super(AndroidOrganizationInitial()) {
    on<AndroidOrganizationLoadRequested>(_onOrganizationLoadRequested);
    on<AndroidOrganizationSelected>(_onOrganizationSelected);
  }

  Future<void> _onOrganizationLoadRequested(
    AndroidOrganizationLoadRequested event,
    Emitter<AndroidOrganizationState> emit,
  ) async {
    emit(AndroidOrganizationLoading());
    
    try {
      final organizations = await authRepository.getUserOrganizations(event.userId);
      
      // Check if user is super admin
      bool isSuperAdmin = false;
      for (var org in organizations) {
        if (org['role'] == 0) { // Super Admin role
          isSuperAdmin = true;
          break;
        }
      }
      
      emit(AndroidOrganizationLoaded(
        organizations: organizations,
        isSuperAdmin: isSuperAdmin,
      ));
    } catch (e) {
      emit(AndroidOrganizationError(message: e.toString()));
    }
  }

  Future<void> _onOrganizationSelected(
    AndroidOrganizationSelected event,
    Emitter<AndroidOrganizationState> emit,
  ) async {
    emit(AndroidOrganizationSelectedState(organization: event.organization));
  }
}
