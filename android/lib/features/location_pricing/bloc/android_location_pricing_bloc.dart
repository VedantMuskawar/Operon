import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/android_location_pricing_repository.dart';
import '../models/location_pricing.dart';

abstract class AndroidLocationPricingEvent extends Equatable {
  const AndroidLocationPricingEvent();
  @override
  List<Object?> get props => [];
}

class AndroidLoadLocationPricing extends AndroidLocationPricingEvent {
  final String organizationId;
  const AndroidLoadLocationPricing(this.organizationId);
  @override
  List<Object?> get props => [organizationId];
}

class AndroidAddLocationPricing extends AndroidLocationPricingEvent {
  final String organizationId;
  final LocationPricing locationPricing;
  final String userId;
  const AndroidAddLocationPricing({
    required this.organizationId,
    required this.locationPricing,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, locationPricing, userId];
}

class AndroidUpdateLocationPricing extends AndroidLocationPricingEvent {
  final String organizationId;
  final String locationId;
  final LocationPricing locationPricing;
  final String userId;
  const AndroidUpdateLocationPricing({
    required this.organizationId,
    required this.locationId,
    required this.locationPricing,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, locationId, locationPricing, userId];
}

class AndroidDeleteLocationPricing extends AndroidLocationPricingEvent {
  final String organizationId;
  final String locationId;
  const AndroidDeleteLocationPricing({
    required this.organizationId,
    required this.locationId,
  });
  @override
  List<Object?> get props => [organizationId, locationId];
}

abstract class AndroidLocationPricingState extends Equatable {
  const AndroidLocationPricingState();
  @override
  List<Object?> get props => [];
}

class AndroidLocationPricingInitial extends AndroidLocationPricingState {}
class AndroidLocationPricingLoading extends AndroidLocationPricingState {}
class AndroidLocationPricingLoaded extends AndroidLocationPricingState {
  final List<LocationPricing> locations;
  const AndroidLocationPricingLoaded({required this.locations});
  @override
  List<Object?> get props => [locations];
}
class AndroidLocationPricingOperating extends AndroidLocationPricingState {}
class AndroidLocationPricingOperationSuccess extends AndroidLocationPricingState {
  final String message;
  const AndroidLocationPricingOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidLocationPricingError extends AndroidLocationPricingState {
  final String message;
  const AndroidLocationPricingError(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidLocationPricingEmpty extends AndroidLocationPricingState {}

class AndroidLocationPricingBloc extends Bloc<AndroidLocationPricingEvent, AndroidLocationPricingState> {
  final AndroidLocationPricingRepository _repository;

  AndroidLocationPricingBloc({required AndroidLocationPricingRepository repository})
      : _repository = repository,
        super(AndroidLocationPricingInitial()) {
    on<AndroidLoadLocationPricing>(_onLoadLocationPricing);
    on<AndroidAddLocationPricing>(_onAddLocationPricing);
    on<AndroidUpdateLocationPricing>(_onUpdateLocationPricing);
    on<AndroidDeleteLocationPricing>(_onDeleteLocationPricing);
  }

  Future<void> _onLoadLocationPricing(
    AndroidLoadLocationPricing event,
    Emitter<AndroidLocationPricingState> emit,
  ) async {
    try {
      emit(AndroidLocationPricingLoading());
      await emit.forEach(
        _repository.getLocationPricingStream(event.organizationId),
        onData: (List<LocationPricing> locations) {
          print('Location pricing stream received ${locations.length} locations');
          final state = locations.isEmpty 
              ? AndroidLocationPricingEmpty() 
              : AndroidLocationPricingLoaded(locations: locations);
          print('Emitting location pricing state: ${state.runtimeType}');
          emit(state);
          return state;
        },
        onError: (error, stackTrace) {
          print('Error in location pricing stream: $error');
          final errorState = AndroidLocationPricingError('Failed to load locations: $error');
          emit(errorState);
          return errorState;
        },
      );
    } catch (e) {
      emit(AndroidLocationPricingError('Failed to load locations: $e'));
    }
  }

  Future<void> _onAddLocationPricing(
    AndroidAddLocationPricing event,
    Emitter<AndroidLocationPricingState> emit,
  ) async {
    try {
      emit(AndroidLocationPricingOperating());
      await _repository.addLocationPricing(event.organizationId, event.locationPricing, event.userId);
      emit(AndroidLocationPricingOperationSuccess('Location pricing added successfully'));
    } catch (e) {
      emit(AndroidLocationPricingError('Failed to add location pricing: $e'));
    }
  }

  Future<void> _onUpdateLocationPricing(
    AndroidUpdateLocationPricing event,
    Emitter<AndroidLocationPricingState> emit,
  ) async {
    try {
      emit(AndroidLocationPricingOperating());
      await _repository.updateLocationPricing(
        event.organizationId,
        event.locationId,
        event.locationPricing,
        event.userId,
      );
      emit(AndroidLocationPricingOperationSuccess('Location pricing updated successfully'));
    } catch (e) {
      emit(AndroidLocationPricingError('Failed to update location pricing: $e'));
    }
  }

  Future<void> _onDeleteLocationPricing(
    AndroidDeleteLocationPricing event,
    Emitter<AndroidLocationPricingState> emit,
  ) async {
    try {
      emit(AndroidLocationPricingOperating());
      await _repository.deleteLocationPricing(event.organizationId, event.locationId);
      emit(AndroidLocationPricingOperationSuccess('Location pricing deleted successfully'));
    } catch (e) {
      emit(AndroidLocationPricingError('Failed to delete location pricing: $e'));
    }
  }
}

