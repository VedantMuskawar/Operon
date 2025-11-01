import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'vehicle_event.dart';
import 'vehicle_state.dart';
import '../repositories/vehicle_repository.dart';
import '../models/vehicle.dart';

class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  final VehicleRepository _vehicleRepository;

  VehicleBloc({required VehicleRepository vehicleRepository})
      : _vehicleRepository = vehicleRepository,
        super(const VehicleInitial()) {
    on<LoadVehicles>(_onLoadVehicles);
    on<AddVehicle>(_onAddVehicle);
    on<UpdateVehicle>(_onUpdateVehicle);
    on<DeleteVehicle>(_onDeleteVehicle);
    on<SearchVehicles>(_onSearchVehicles);
    on<ResetSearch>(_onResetSearch);
    on<RefreshVehicles>(_onRefreshVehicles);
  }

  Future<void> _onLoadVehicles(
    LoadVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    try {
      emit(const VehicleLoading());

      await emit.forEach(
        _vehicleRepository.getVehiclesStream(event.organizationId),
        onData: (List<Vehicle> vehicles) {
          if (vehicles.isEmpty) {
            return const VehicleEmpty();
          }
          return VehicleLoaded(vehicles: vehicles);
        },
        onError: (error, stackTrace) {
          return VehicleError('Failed to load vehicles: $error');
        },
      );
    } catch (e) {
      emit(VehicleError('Failed to load vehicles: $e'));
    }
  }

  Future<void> _onAddVehicle(
    AddVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    try {
      emit(const VehicleOperating());

      await _vehicleRepository.addVehicle(
        event.organizationId,
        event.vehicle,
        event.userId,
      );

      emit(const VehicleOperationSuccess('Vehicle added successfully'));
    } catch (e) {
      emit(VehicleError('Failed to add vehicle: $e'));
    }
  }

  Future<void> _onUpdateVehicle(
    UpdateVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    try {
      emit(const VehicleOperating());

      await _vehicleRepository.updateVehicle(
        event.organizationId,
        event.vehicleId,
        event.vehicle,
        event.userId,
      );

      emit(const VehicleOperationSuccess('Vehicle updated successfully'));
    } catch (e) {
      emit(VehicleError('Failed to update vehicle: $e'));
    }
  }

  Future<void> _onDeleteVehicle(
    DeleteVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    try {
      emit(const VehicleOperating());

      await _vehicleRepository.deleteVehicle(
        event.organizationId,
        event.vehicleId,
      );

      emit(const VehicleOperationSuccess('Vehicle deleted successfully'));
    } catch (e) {
      emit(VehicleError('Failed to delete vehicle: $e'));
    }
  }

  Future<void> _onSearchVehicles(
    SearchVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    try {
      emit(const VehicleLoading());

      await emit.forEach(
        _vehicleRepository.searchVehicles(
          event.organizationId,
          event.query,
        ),
        onData: (List<Vehicle> vehicles) {
          if (vehicles.isEmpty && event.query.isNotEmpty) {
            return VehicleEmpty(searchQuery: event.query);
          } else if (vehicles.isEmpty) {
            return const VehicleEmpty();
          }
          return VehicleLoaded(vehicles: vehicles, searchQuery: event.query);
        },
        onError: (error, stackTrace) {
          return VehicleError('Failed to search vehicles: $error');
        },
      );
    } catch (e) {
      emit(VehicleError('Failed to search vehicles: $e'));
    }
  }

  Future<void> _onResetSearch(
    ResetSearch event,
    Emitter<VehicleState> emit,
  ) async {
    // Reset to initial state - this will be handled by the page to reload
    emit(const VehicleInitial());
  }

  Future<void> _onRefreshVehicles(
    RefreshVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    add(LoadVehicles(event.organizationId));
  }
}

