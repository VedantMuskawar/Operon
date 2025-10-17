import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/repositories/organization_repository.dart';
import '../../../core/models/organization.dart';
import '../../../core/models/subscription.dart';
import '../../../core/widgets/custom_snackbar.dart';
import 'dart:io';

// Events
abstract class OrganizationEvent extends Equatable {
  const OrganizationEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrganizations extends OrganizationEvent {
  final String? searchQuery;
  final String? statusFilter;

  const LoadOrganizations({
    this.searchQuery,
    this.statusFilter,
  });

  @override
  List<Object?> get props => [searchQuery, statusFilter];
}

class CreateOrganization extends OrganizationEvent {
  final String orgName;
  final String email;
  final String gstNo;
  final String adminName;
  final String adminPhone;
  final String adminEmail;
  final Subscription subscription;
  final File? logoFile;

  const CreateOrganization({
    required this.orgName,
    required this.email,
    required this.gstNo,
    required this.adminName,
    required this.adminPhone,
    required this.adminEmail,
    required this.subscription,
    this.logoFile,
  });

  @override
  List<Object?> get props => [
        orgName,
        email,
        gstNo,
        adminName,
        adminPhone,
        adminEmail,
        subscription,
        logoFile,
      ];
}

class UpdateOrganization extends OrganizationEvent {
  final String orgId;
  final Organization organization;

  const UpdateOrganization({
    required this.orgId,
    required this.organization,
  });

  @override
  List<Object?> get props => [orgId, organization];
}

class DeleteOrganization extends OrganizationEvent {
  final String orgId;

  const DeleteOrganization({required this.orgId});

  @override
  List<Object?> get props => [orgId];
}

// States
abstract class OrganizationState extends Equatable {
  const OrganizationState();

  @override
  List<Object?> get props => [];
}

class OrganizationInitial extends OrganizationState {
  const OrganizationInitial();
}

class OrganizationLoading extends OrganizationState {
  const OrganizationLoading();
}

class OrganizationsLoaded extends OrganizationState {
  final List<Organization> organizations;

  const OrganizationsLoaded({required this.organizations});

  @override
  List<Object?> get props => [organizations];
}

class OrganizationCreated extends OrganizationState {
  final String orgId;

  const OrganizationCreated({required this.orgId});

  @override
  List<Object?> get props => [orgId];
}

class OrganizationUpdated extends OrganizationState {
  const OrganizationUpdated();
}

class OrganizationDeleted extends OrganizationState {
  const OrganizationDeleted();
}

class OrganizationFailure extends OrganizationState {
  final String message;

  const OrganizationFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final OrganizationRepository organizationRepository;

  OrganizationBloc({required this.organizationRepository}) : super(const OrganizationInitial()) {
    on<LoadOrganizations>(_onLoadOrganizations);
    on<CreateOrganization>(_onCreateOrganization);
    on<UpdateOrganization>(_onUpdateOrganization);
    on<DeleteOrganization>(_onDeleteOrganization);
  }

  Future<void> _onLoadOrganizations(
    LoadOrganizations event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());
    
    try {
      final organizations = await organizationRepository.getOrganizations(
        searchQuery: event.searchQuery,
        statusFilter: event.statusFilter,
      );
      emit(OrganizationsLoaded(organizations: organizations));
    } catch (e) {
      emit(OrganizationFailure(message: e.toString()));
    }
  }

  Future<void> _onCreateOrganization(
    CreateOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());
    
    try {
      final orgId = await organizationRepository.createOrganization(
        orgName: event.orgName,
        email: event.email,
        gstNo: event.gstNo,
        adminName: event.adminName,
        adminPhone: event.adminPhone,
        adminEmail: event.adminEmail,
        subscription: event.subscription,
        logoFile: event.logoFile,
      );
      
      emit(OrganizationCreated(orgId: orgId));
    } catch (e) {
      emit(OrganizationFailure(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrganization(
    UpdateOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());
    
    try {
      await organizationRepository.updateOrganization(
        event.orgId,
        event.organization,
      );
      emit(const OrganizationUpdated());
    } catch (e) {
      emit(OrganizationFailure(message: e.toString()));
    }
  }

  Future<void> _onDeleteOrganization(
    DeleteOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());
    
    try {
      await organizationRepository.deleteOrganization(event.orgId);
      emit(const OrganizationDeleted());
    } catch (e) {
      emit(OrganizationFailure(message: e.toString()));
    }
  }
}
