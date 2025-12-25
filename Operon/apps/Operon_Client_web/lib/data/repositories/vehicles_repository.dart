import 'package:dash_web/data/datasources/vehicles_data_source.dart';
import 'package:dash_web/domain/entities/vehicle.dart';

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
