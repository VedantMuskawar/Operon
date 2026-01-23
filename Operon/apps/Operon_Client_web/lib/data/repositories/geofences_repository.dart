import 'package:dash_web/data/datasources/geofence_data_source.dart';
import 'package:core_models/core_models.dart';

class GeofencesRepository {
  GeofencesRepository({
    required GeofenceDataSource dataSource,
  }) : _dataSource = dataSource;

  final GeofenceDataSource _dataSource;

  Future<List<Geofence>> fetchGeofences(String orgId) {
    return _dataSource.fetchGeofences(orgId);
  }

  Future<List<Geofence>> fetchActiveGeofences(String orgId) {
    return _dataSource.fetchActiveGeofences(orgId);
  }

  Future<Geofence?> fetchGeofence({
    required String orgId,
    required String geofenceId,
  }) {
    return _dataSource.fetchGeofence(orgId: orgId, geofenceId: geofenceId);
  }

  Future<String> createGeofence({
    required String orgId,
    required Geofence geofence,
  }) {
    return _dataSource.createGeofence(orgId: orgId, geofence: geofence);
  }

  Future<void> updateGeofence({
    required String orgId,
    required Geofence geofence,
  }) {
    return _dataSource.updateGeofence(orgId: orgId, geofence: geofence);
  }

  Future<void> deleteGeofence({
    required String orgId,
    required String geofenceId,
  }) {
    return _dataSource.deleteGeofence(orgId: orgId, geofenceId: geofenceId);
  }

  Future<void> updateNotificationRecipients({
    required String orgId,
    required String geofenceId,
    required List<String> recipientIds,
  }) {
    return _dataSource.updateNotificationRecipients(
      orgId: orgId,
      geofenceId: geofenceId,
      recipientIds: recipientIds,
    );
  }

  Future<void> toggleActive({
    required String orgId,
    required String geofenceId,
    required bool isActive,
  }) {
    return _dataSource.toggleActive(
      orgId: orgId,
      geofenceId: geofenceId,
      isActive: isActive,
    );
  }
}
