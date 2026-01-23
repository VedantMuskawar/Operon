import 'package:dash_web/data/datasources/organization_location_data_source.dart';
import 'package:core_models/core_models.dart';

class OrganizationLocationsRepository {
  OrganizationLocationsRepository({
    required OrganizationLocationDataSource dataSource,
  }) : _dataSource = dataSource;

  final OrganizationLocationDataSource _dataSource;

  Future<List<OrganizationLocation>> fetchLocations(String orgId) {
    return _dataSource.fetchLocations(orgId);
  }

  Future<String> createLocation({
    required String orgId,
    required OrganizationLocation location,
  }) {
    return _dataSource.createLocation(orgId: orgId, location: location);
  }

  Future<void> updateLocation({
    required String orgId,
    required OrganizationLocation location,
  }) {
    return _dataSource.updateLocation(orgId: orgId, location: location);
  }

  Future<void> deleteLocation({
    required String orgId,
    required String locationId,
  }) {
    return _dataSource.deleteLocation(orgId: orgId, locationId: locationId);
  }

  Future<void> setPrimaryLocation({
    required String orgId,
    required String locationId,
  }) {
    return _dataSource.setPrimaryLocation(orgId: orgId, locationId: locationId);
  }
}
