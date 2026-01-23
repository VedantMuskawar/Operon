import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GeofencesState extends BaseState {
  const GeofencesState({
    super.status = ViewStatus.initial,
    this.geofences = const [],
    this.message,
  }) : super(message: message);

  final List<Geofence> geofences;
  @override
  final String? message;

  @override
  GeofencesState copyWith({
    ViewStatus? status,
    List<Geofence>? geofences,
    String? message,
  }) {
    return GeofencesState(
      status: status ?? this.status,
      geofences: geofences ?? this.geofences,
      message: message ?? this.message,
    );
  }
}

class GeofencesCubit extends Cubit<GeofencesState> {
  GeofencesCubit({
    required GeofencesRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const GeofencesState());

  final GeofencesRepository _repository;
  final String _organizationId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final geofences = await _repository.fetchGeofences(_organizationId);
      emit(state.copyWith(
        status: ViewStatus.success,
        geofences: geofences,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load geofences. Please try again.',
      ));
    }
  }

  Future<void> createGeofence(Geofence geofence) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.createGeofence(
        orgId: _organizationId,
        geofence: geofence,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create geofence. Please try again.',
      ));
    }
  }

  Future<void> updateGeofence(Geofence geofence) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateGeofence(
        orgId: _organizationId,
        geofence: geofence,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update geofence. Please try again.',
      ));
    }
  }

  Future<void> deleteGeofence(String geofenceId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.deleteGeofence(
        orgId: _organizationId,
        geofenceId: geofenceId,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete geofence. Please try again.',
      ));
    }
  }

  Future<void> updateNotificationRecipients({
    required String geofenceId,
    required List<String> recipientIds,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateNotificationRecipients(
        orgId: _organizationId,
        geofenceId: geofenceId,
        recipientIds: recipientIds,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update notification recipients. Please try again.',
      ));
    }
  }

  Future<void> toggleActive({
    required String geofenceId,
    required bool isActive,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.toggleActive(
        orgId: _organizationId,
        geofenceId: geofenceId,
        isActive: isActive,
      );
      await load();
    } catch (err) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update geofence status. Please try again.',
      ));
    }
  }
}
