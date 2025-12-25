import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/domain/entities/vehicle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'vehicles_state.dart';

class VehiclesCubit extends Cubit<VehiclesState> {
  VehiclesCubit({
    required VehiclesRepository repository,
    required String orgId,
  })  : _repository = repository,
        _orgId = orgId,
        super(const VehiclesState());

  final VehiclesRepository _repository;
  final String _orgId;

  Future<void> loadVehicles() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final vehicles = await _repository.fetchVehicles(_orgId);
      emit(state.copyWith(status: ViewStatus.success, vehicles: vehicles));
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load vehicles. Please try again.',
      ));
    }
  }

  Future<void> createVehicle(Vehicle vehicle) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.createVehicle(_orgId, vehicle);
      await loadVehicles();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create vehicle.',
      ));
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateVehicle(_orgId, vehicle);
      await loadVehicles();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update vehicle.',
      ));
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.deleteVehicle(_orgId, vehicleId);
      await loadVehicles();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete vehicle.',
      ));
    }
  }

  Future<void> updateDriver(String vehicleId, VehicleDriverInfo? driver) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final vehicle = state.vehicles.firstWhere((v) => v.id == vehicleId);
      final updatedVehicle = vehicle.copyWith(driver: driver);
      await _repository.updateVehicle(_orgId, updatedVehicle);
      await loadVehicles();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update driver assignment.',
      ));
    }
  }
}
