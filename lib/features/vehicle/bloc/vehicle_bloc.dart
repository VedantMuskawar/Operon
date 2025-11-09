import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'vehicle_event.dart';
import 'vehicle_state.dart';
import '../repositories/vehicle_repository.dart';
import '../models/vehicle.dart';

class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  final VehicleRepository _vehicleRepository;
  StreamSubscription<List<Vehicle>>? _vehiclesSubscription;

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
    on<AssignDriverToVehicle>(_onAssignDriverToVehicle);
    on<VehiclesStreamUpdated>(_onVehiclesStreamUpdated);
    on<VehiclesStreamError>(_onVehiclesStreamError);
  }

  Future<void> _onLoadVehicles(
    LoadVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    await _vehiclesSubscription?.cancel();
    emit(const VehicleLoading());

    _vehiclesSubscription = _vehicleRepository
        .getVehiclesStream(event.organizationId)
        .listen(
      (vehicles) {
        add(
          VehiclesStreamUpdated(
            vehicles: vehicles,
          ),
        );
      },
      onError: (error, stackTrace) {
        add(
          VehiclesStreamError('Failed to load vehicles: $error'),
        );
      },
    );
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
    await _vehiclesSubscription?.cancel();
    emit(const VehicleLoading());

    _vehiclesSubscription = _vehicleRepository
        .searchVehicles(
      event.organizationId,
      event.query,
    )
        .listen(
      (vehicles) {
        add(
          VehiclesStreamUpdated(
            vehicles: vehicles,
            searchQuery: event.query,
          ),
        );
      },
      onError: (error, stackTrace) {
        add(
          VehiclesStreamError('Failed to search vehicles: $error'),
        );
      },
    );
  }

  Future<void> _onResetSearch(
    ResetSearch event,
    Emitter<VehicleState> emit,
  ) async {
    await _vehiclesSubscription?.cancel();
    emit(const VehicleInitial());
  }

  Future<void> _onRefreshVehicles(
    RefreshVehicles event,
    Emitter<VehicleState> emit,
  ) async {
    add(LoadVehicles(event.organizationId));
  }

  Future<void> _onAssignDriverToVehicle(
    AssignDriverToVehicle event,
    Emitter<VehicleState> emit,
  ) async {
    final previousState = state;
    VehicleLoaded? previousLoaded;
    Vehicle? originalVehicle;
    VehicleLoaded? optimisticState;
    final now = DateTime.now();

    if (state is VehicleLoaded) {
      previousLoaded = state as VehicleLoaded;
      final vehicles = List<Vehicle>.from(previousLoaded.vehicles);
      final index = vehicles.indexWhere((vehicle) => vehicle.id == event.vehicleId);
      if (index != -1) {
        originalVehicle = vehicles[index];
        vehicles[index] = vehicles[index].copyWith(
          assignedDriverId: event.driverId,
          assignedDriverName: event.driverName,
          assignedDriverContact: event.driverContact,
          assignedDriverAt: event.driverId != null ? now : null,
          assignedDriverBy: event.driverId != null ? event.userId : null,
        );
        optimisticState = VehicleLoaded(
          vehicles: vehicles,
          searchQuery: previousLoaded.searchQuery,
        );
        emit(optimisticState);
      }
    } else {
      emit(const VehicleOperating());
    }

    try {
      await _vehicleRepository.assignDriver(
        organizationId: event.organizationId,
        vehicleId: event.vehicleId,
        driverId: event.driverId,
        driverName: event.driverName,
        driverContact: event.driverContact,
        userId: event.userId,
        force: event.force,
      );

      final message = event.driverId == null
          ? 'Driver unassigned successfully'
          : 'Driver assigned successfully';

      emit(VehicleOperationSuccess(message));
      if (optimisticState != null) {
        emit(optimisticState);
      } else if (previousState is VehicleLoaded) {
        emit(previousState);
      }
    } on DriverAssignmentConflictException catch (conflict) {
      if (previousLoaded != null && originalVehicle != null) {
        final vehicles = List<Vehicle>.from(previousLoaded.vehicles);
        final index = vehicles.indexWhere((vehicle) => vehicle.id == originalVehicle!.id);
        if (index != -1) {
          vehicles[index] = originalVehicle!;
        }
        emit(VehicleLoaded(vehicles: vehicles, searchQuery: previousLoaded.searchQuery));
      } else if (previousState is VehicleLoaded) {
        emit(previousState);
      }

      emit(
        VehicleAssignmentConflict(
          organizationId: event.organizationId,
          vehicleId: event.vehicleId,
          driverId: event.driverId,
          driverName: event.driverName,
          driverContact: event.driverContact,
          conflictingVehicleNo: conflict.vehicleNo,
        ),
      );
    } catch (e) {
      if (previousLoaded != null && originalVehicle != null) {
        final vehicles = List<Vehicle>.from(previousLoaded.vehicles);
        final index = vehicles.indexWhere((vehicle) => vehicle.id == originalVehicle!.id);
        if (index != -1) {
          vehicles[index] = originalVehicle!;
        }
        emit(VehicleLoaded(vehicles: vehicles, searchQuery: previousLoaded.searchQuery));
      } else if (previousState is VehicleLoaded) {
        emit(previousState);
      }

      emit(VehicleError('Failed to update driver assignment: $e'));
    }
  }

  void _onVehiclesStreamUpdated(
    VehiclesStreamUpdated event,
    Emitter<VehicleState> emit,
  ) {
    if (event.vehicles.isEmpty) {
      if (event.searchQuery != null && event.searchQuery!.isNotEmpty) {
        emit(VehicleEmpty(searchQuery: event.searchQuery));
      } else {
        emit(const VehicleEmpty());
      }
      return;
    }

    emit(
      VehicleLoaded(
        vehicles: event.vehicles,
        searchQuery: event.searchQuery,
      ),
    );
  }

  void _onVehiclesStreamError(
    VehiclesStreamError event,
    Emitter<VehicleState> emit,
  ) {
    emit(VehicleError(event.message));
  }

  @override
  Future<void> close() async {
    await _vehiclesSubscription?.cancel();
    return super.close();
  }
}

