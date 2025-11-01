import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/repositories/user_organization_repository.dart';

// Events
abstract class OrganizationSelectEvent extends Equatable {
  const OrganizationSelectEvent();

  @override
  List<Object?> get props => [];
}

class OrganizationSelected extends OrganizationSelectEvent {
  final String orgId;
  final String orgName;
  final String? orgLogoUrl;
  final int role;
  final List<String> permissions;

  const OrganizationSelected({
    required this.orgId,
    required this.orgName,
    this.orgLogoUrl,
    required this.role,
    required this.permissions,
  });

  @override
  List<Object?> get props => [orgId, orgName, orgLogoUrl, role, permissions];
}

class SuperAdminDashboardSelected extends OrganizationSelectEvent {}

// States
abstract class OrganizationSelectState extends Equatable {
  const OrganizationSelectState();

  @override
  List<Object?> get props => [];
}

class OrganizationSelectInitial extends OrganizationSelectState {}

class OrganizationSelectLoading extends OrganizationSelectState {}

class OrganizationSelectSuccess extends OrganizationSelectState {
  final User firebaseUser;
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> organizations;
  final bool isSuperAdmin;

  const OrganizationSelectSuccess({
    required this.firebaseUser,
    required this.userData,
    required this.organizations,
    required this.isSuperAdmin,
  });

  @override
  List<Object?> get props => [firebaseUser, userData, organizations, isSuperAdmin];
}

class OrganizationSelectFailure extends OrganizationSelectState {
  final String message;

  const OrganizationSelectFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class OrganizationSelectBloc extends Bloc<OrganizationSelectEvent, OrganizationSelectState> {
  final UserOrganizationRepository userOrganizationRepository;

  OrganizationSelectBloc({required this.userOrganizationRepository}) : super(OrganizationSelectInitial()) {
    on<OrganizationSelected>(_onOrganizationSelected);
    on<SuperAdminDashboardSelected>(_onSuperAdminDashboardSelected);
  }

  Future<void> _onOrganizationSelected(
    OrganizationSelected event,
    Emitter<OrganizationSelectState> emit,
  ) async {
    emit(OrganizationSelectLoading());
    
    try {
      // Store selected organization in user preferences or state
      // For now, we'll just emit success - the main app will handle navigation
      emit(OrganizationSelectSuccess(
        firebaseUser: FirebaseAuth.instance.currentUser!,
        userData: {}, // Will be populated by the calling component
        organizations: [], // Will be populated by the calling component
        isSuperAdmin: false, // Will be determined by the calling component
      ));
    } catch (e) {
      emit(OrganizationSelectFailure(message: e.toString()));
    }
  }

  Future<void> _onSuperAdminDashboardSelected(
    SuperAdminDashboardSelected event,
    Emitter<OrganizationSelectState> emit,
  ) async {
    emit(OrganizationSelectLoading());
    
    try {
      // Navigate to Super Admin dashboard
      emit(OrganizationSelectSuccess(
        firebaseUser: FirebaseAuth.instance.currentUser!,
        userData: {}, // Will be populated by the calling component
        organizations: [], // Will be populated by the calling component
        isSuperAdmin: true, // Will be determined by the calling component
      ));
    } catch (e) {
      emit(OrganizationSelectFailure(message: e.toString()));
    }
  }
}
