import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/android_vehicle_repository.dart';
import '../models/vehicle.dart';

// Events
abstract class AndroidVehicleEvent extends Equatable {
  const AndroidVehicleEvent();

  @override
  List<Object?> get props => [];
}

class AndroidLoadVehicles extends AndroidVehicleEvent {
  final String organizationId;

  const AndroidLoadVehicles(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

class AndroidAddVehicle extends AndroidVehicleEvent {
  final String organizationId;
  final Vehicle vehicle;
  final String userId;

  const AndroidAddVehicle({
    required this.organizationId,
    required this.vehicle,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, vehicle, userId];
}

class AndroidUpdateVehicle extends AndroidVehicleEvent {
  final String organizationId;
  final String vehicleId;
  final Vehicle vehicle;
  final String userId;

  const AndroidUpdateVehicle({
    required this.organizationId,
    required this.vehicleId,
    required this.vehicle,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, vehicleId, vehicle, userId];
}

class AndroidDeleteVehicle extends AndroidVehicleEvent {
  final String organizationId;
  final String vehicleId;

  const AndroidDeleteVehicle({
    required this.organizationId,
    required this.vehicleId,
  });

  @override
  List<Object?> get props => [organizationId, vehicleId];
}

// States
abstract class AndroidVehicleState extends Equatable {
  const AndroidVehicleState();

  @override
  List<Object?> get props => [];
}

class AndroidVehicleInitial extends AndroidVehicleState {
  const AndroidVehicleInitial();
}

class AndroidVehicleLoading extends AndroidVehicleState {
  const AndroidVehicleLoading();
}

class AndroidVehicleLoaded extends AndroidVehicleState {
  final List<Vehicle> vehicles;

  const AndroidVehicleLoaded({required this.vehicles});

  @override
  List<Object?> get props => [vehicles];
}

class AndroidVehicleOperating extends AndroidVehicleState {
  const AndroidVehicleOperating();
}

class AndroidVehicleOperationSuccess extends AndroidVehicleState {
  final String message;

  const AndroidVehicleOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AndroidVehicleError extends AndroidVehicleState {
  final String message;

  const AndroidVehicleError(this.message);

  @override
  List<Object?> get props => [message];
}

class AndroidVehicleEmpty extends AndroidVehicleState {
  const AndroidVehicleEmpty();
}

// BLoC
class AndroidVehicleBloc extends Bloc<AndroidVehicleEvent, AndroidVehicleState> {
  final AndroidVehicleRepository _vehicleRepository;

  AndroidVehicleBloc({required AndroidVehicleRepository vehicleRepository})
      : _vehicleRepository = vehicleRepository,
        super(const AndroidVehicleInitial()) {
    on<AndroidLoadVehicles>(_onLoadVehicles);
    on<AndroidAddVehicle>(_onAddVehicle);
    on<AndroidUpdateVehicle>(_onUpdateVehicle);
    on<AndroidDeleteVehicle>(_onDeleteVehicle);
  }

  Future<void> _onLoadVehicles(
    AndroidLoadVehicles event,
    Emitter<AndroidVehicleState> emit,
  ) async {
    try {
      emit(AndroidVehicleLoading());
      print('Loading vehicles for organization: ${event.organizationId}');

      // Use stream with emit.forEach for real-time updates
      await emit.forEach(
        _vehicleRepository.getVehiclesStream(event.organizationId),
        onData: (List<Vehicle> vehicles) {
          print('Stream received ${vehicles.length} vehicles');
          final state = vehicles.isEmpty 
              ? AndroidVehicleEmpty() 
              : AndroidVehicleLoaded(vehicles: vehicles);
          print('Emitting state: ${state.runtimeType}');
          emit(state);
          return state;
        },
        onError: (error, stackTrace) {
          print('Error in vehicles stream: $error');
          print('StackTrace: $stackTrace');
          final errorState = AndroidVehicleError('Failed to load vehicles: $error');
          emit(errorState);
          return errorState;
        },
      );
    } catch (e, stackTrace) {
      print('Exception in _onLoadVehicles: $e');
      print('StackTrace: $stackTrace');
      emit(AndroidVehicleError('Failed to load vehicles: $e'));
    }
  }

  Future<void> _onAddVehicle(
    AndroidAddVehicle event,
    Emitter<AndroidVehicleState> emit,
  ) async {
    try {
      emit(const AndroidVehicleOperating());

      await _vehicleRepository.addVehicle(
        event.organizationId,
        event.vehicle,
        event.userId,
      );

      emit(const AndroidVehicleOperationSuccess('Vehicle added successfully'));
    } catch (e) {
      emit(AndroidVehicleError('Failed to add vehicle: $e'));
    }
  }

  Future<void> _onUpdateVehicle(
    AndroidUpdateVehicle event,
    Emitter<AndroidVehicleState> emit,
  ) async {
    try {
      emit(const AndroidVehicleOperating());

      await _vehicleRepository.updateVehicle(
        event.organizationId,
        event.vehicleId,
        event.vehicle,
        event.userId,
      );

      emit(const AndroidVehicleOperationSuccess('Vehicle updated successfully'));
    } catch (e) {
      emit(AndroidVehicleError('Failed to update vehicle: $e'));
    }
  }

  Future<void> _onDeleteVehicle(
    AndroidDeleteVehicle event,
    Emitter<AndroidVehicleState> emit,
  ) async {
    try {
      emit(const AndroidVehicleOperating());

      await _vehicleRepository.deleteVehicle(
        event.organizationId,
        event.vehicleId,
      );

      emit(const AndroidVehicleOperationSuccess('Vehicle deleted successfully'));
    } catch (e) {
      emit(AndroidVehicleError('Failed to delete vehicle: $e'));
    }
  }
}

