import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/organization_locations_repository.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationLocationsState extends BaseState {
  const OrganizationLocationsState({
    super.status = ViewStatus.initial,
    this.locations = const [],
    this.message,
  }) : super(message: message);

  final List<OrganizationLocation> locations;
  @override
  final String? message;

  @override
  OrganizationLocationsState copyWith({
    ViewStatus? status,
    List<OrganizationLocation>? locations,
    String? message,
  }) {
    return OrganizationLocationsState(
      status: status ?? this.status,
      locations: locations ?? this.locations,
      message: message ?? this.message,
    );
  }
}

class OrganizationLocationsCubit extends Cubit<OrganizationLocationsState> {
  OrganizationLocationsCubit({
    required OrganizationLocationsRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const OrganizationLocationsState());

  final OrganizationLocationsRepository _repository;
  final String _organizationId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final locations = await _repository.fetchLocations(_organizationId);
      emit(state.copyWith(
        status: ViewStatus.success,
        locations: locations,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load locations. Please try again.',
      ));
    }
  }

  Future<void> createLocation(OrganizationLocation location) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.createLocation(
        orgId: _organizationId,
        location: location,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create location. Please try again.',
      ));
    }
  }

  Future<void> updateLocation(OrganizationLocation location) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateLocation(
        orgId: _organizationId,
        location: location,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update location. Please try again.',
      ));
    }
  }

  Future<void> deleteLocation(String locationId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.deleteLocation(
        orgId: _organizationId,
        locationId: locationId,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete location. Please try again.',
      ));
    }
  }

  Future<void> setPrimaryLocation(String locationId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.setPrimaryLocation(
        orgId: _organizationId,
        locationId: locationId,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to set primary location. Please try again.',
      ));
    }
  }
}
