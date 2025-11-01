import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/android_organization_repository.dart';
import 'dart:typed_data';

// Events
abstract class AndroidOrganizationSettingsEvent extends Equatable {
  const AndroidOrganizationSettingsEvent();
  @override
  List<Object?> get props => [];
}

class AndroidLoadOrganizationDetails extends AndroidOrganizationSettingsEvent {
  final String orgId;
  const AndroidLoadOrganizationDetails(this.orgId);
  @override
  List<Object?> get props => [orgId];
}

class AndroidUpdateOrganizationDetails extends AndroidOrganizationSettingsEvent {
  final String orgId;
  final AndroidOrganization organization;
  final Uint8List? logoFile;
  final String? logoFileName;
  
  const AndroidUpdateOrganizationDetails({
    required this.orgId,
    required this.organization,
    this.logoFile,
    this.logoFileName,
  });
  
  @override
  List<Object?> get props => [orgId, organization, logoFile, logoFileName];
}

// States
abstract class AndroidOrganizationSettingsState extends Equatable {
  const AndroidOrganizationSettingsState();
  @override
  List<Object?> get props => [];
}

class AndroidOrganizationSettingsInitial extends AndroidOrganizationSettingsState {}

class AndroidOrganizationSettingsLoading extends AndroidOrganizationSettingsState {}

class AndroidOrganizationDetailsLoaded extends AndroidOrganizationSettingsState {
  final AndroidOrganization organization;
  final AndroidSubscription? subscription;

  const AndroidOrganizationDetailsLoaded({
    required this.organization,
    this.subscription,
  });

  @override
  List<Object?> get props => [organization, subscription];
}

class AndroidOrganizationSettingsOperating extends AndroidOrganizationSettingsState {}

class AndroidOrganizationSettingsSuccess extends AndroidOrganizationSettingsState {
  final String message;
  const AndroidOrganizationSettingsSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class AndroidOrganizationSettingsError extends AndroidOrganizationSettingsState {
  final String message;
  const AndroidOrganizationSettingsError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class AndroidOrganizationSettingsBloc
    extends Bloc<AndroidOrganizationSettingsEvent, AndroidOrganizationSettingsState> {
  final AndroidOrganizationRepository _repository;

  AndroidOrganizationSettingsBloc({required AndroidOrganizationRepository repository})
      : _repository = repository,
        super(AndroidOrganizationSettingsInitial()) {
    on<AndroidLoadOrganizationDetails>(_onLoadOrganizationDetails);
    on<AndroidUpdateOrganizationDetails>(_onUpdateOrganizationDetails);
  }

  Future<void> _onLoadOrganizationDetails(
    AndroidLoadOrganizationDetails event,
    Emitter<AndroidOrganizationSettingsState> emit,
  ) async {
    try {
      emit(AndroidOrganizationSettingsLoading());
      
      final result = await _repository.getOrganizationWithSubscription(event.orgId);
      
      emit(AndroidOrganizationDetailsLoaded(
        organization: result['organization'] as AndroidOrganization,
        subscription: result['subscription'] as AndroidSubscription?,
      ));
    } catch (e) {
      emit(AndroidOrganizationSettingsError('Failed to load organization details: $e'));
    }
  }

  Future<void> _onUpdateOrganizationDetails(
    AndroidUpdateOrganizationDetails event,
    Emitter<AndroidOrganizationSettingsState> emit,
  ) async {
    try {
      emit(AndroidOrganizationSettingsOperating());
      
      await _repository.updateOrganizationDetails(
        orgId: event.orgId,
        organization: event.organization,
        logoFile: event.logoFile,
        logoFileName: event.logoFileName,
      );
      
      emit(const AndroidOrganizationSettingsSuccess('Organization updated successfully'));
    } catch (e) {
      emit(AndroidOrganizationSettingsError('Failed to update organization: $e'));
    }
  }
}

