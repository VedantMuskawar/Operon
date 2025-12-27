import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';

class VehiclesRepository {
  VehiclesRepository({required VehiclesDataSource dataSource}) : _dataSource = dataSource;

  final VehiclesDataSource _dataSource;

  Future<List<Vehicle>> fetchVehicles(String orgId) {
    return _dataSource.fetchVehicles(orgId);
  }

  Future<void> createVehicle(String orgId, Vehicle vehicle) {
    return _dataSource.createVehicle(orgId, vehicle);
  }

  Future<void> updateVehicle(String orgId, Vehicle vehicle) {
    return _dataSource.updateVehicle(orgId, vehicle);
  }

  Future<void> deleteVehicle(String orgId, String vehicleId) {
    return _dataSource.deleteVehicle(orgId, vehicleId);
  }
}

