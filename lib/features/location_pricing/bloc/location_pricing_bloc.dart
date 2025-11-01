import 'package:flutter_bloc/flutter_bloc.dart';
import 'location_pricing_event.dart';
import 'location_pricing_state.dart';
import '../repositories/location_pricing_repository.dart';
import '../models/location_pricing.dart';

class LocationPricingBloc extends Bloc<LocationPricingEvent, LocationPricingState> {
  final LocationPricingRepository _locationPricingRepository;

  LocationPricingBloc({required LocationPricingRepository locationPricingRepository})
      : _locationPricingRepository = locationPricingRepository,
        super(const LocationPricingInitial()) {
    on<LoadLocationPricing>(_onLoadLocationPricing);
    on<AddLocationPricing>(_onAddLocationPricing);
    on<UpdateLocationPricing>(_onUpdateLocationPricing);
    on<DeleteLocationPricing>(_onDeleteLocationPricing);
    on<SearchLocationPricing>(_onSearchLocationPricing);
    on<ResetLocationPricingSearch>(_onResetSearch);
    on<RefreshLocationPricing>(_onRefreshLocationPricing);
  }

  Future<void> _onLoadLocationPricing(
    LoadLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingLoading());

      await emit.forEach(
        _locationPricingRepository.getLocationPricingStream(event.organizationId),
        onData: (List<LocationPricing> locations) {
          if (locations.isEmpty) {
            return const LocationPricingEmpty();
          }
          return LocationPricingLoaded(locations: locations);
        },
        onError: (error, stackTrace) {
          return LocationPricingError('Failed to load location pricing: $error');
        },
      );
    } catch (e) {
      emit(LocationPricingError('Failed to load location pricing: $e'));
    }
  }

  Future<void> _onAddLocationPricing(
    AddLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingOperating());

      await _locationPricingRepository.addLocationPricing(
        event.organizationId,
        event.locationPricing,
        event.userId,
      );

      emit(const LocationPricingOperationSuccess('Location pricing added successfully'));
    } catch (e) {
      emit(LocationPricingError('Failed to add location pricing: $e'));
    }
  }

  Future<void> _onUpdateLocationPricing(
    UpdateLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingOperating());

      await _locationPricingRepository.updateLocationPricing(
        event.organizationId,
        event.locationPricingId,
        event.locationPricing,
        event.userId,
      );

      emit(const LocationPricingOperationSuccess('Location pricing updated successfully'));
    } catch (e) {
      emit(LocationPricingError('Failed to update location pricing: $e'));
    }
  }

  Future<void> _onDeleteLocationPricing(
    DeleteLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingOperating());

      await _locationPricingRepository.deleteLocationPricing(
        event.organizationId,
        event.locationPricingId,
      );

      emit(const LocationPricingOperationSuccess('Location pricing deleted successfully'));
    } catch (e) {
      emit(LocationPricingError('Failed to delete location pricing: $e'));
    }
  }

  Future<void> _onSearchLocationPricing(
    SearchLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingLoading());

      await emit.forEach(
        _locationPricingRepository.searchLocationPricing(
          event.organizationId,
          event.query,
        ),
        onData: (List<LocationPricing> locations) {
          if (locations.isEmpty && event.query.isNotEmpty) {
            return LocationPricingEmpty(searchQuery: event.query);
          } else if (locations.isEmpty) {
            return const LocationPricingEmpty();
          }
          return LocationPricingLoaded(locations: locations, searchQuery: event.query);
        },
        onError: (error, stackTrace) {
          return LocationPricingError('Failed to search location pricing: $error');
        },
      );
    } catch (e) {
      emit(LocationPricingError('Failed to search location pricing: $e'));
    }
  }

  void _onResetSearch(
    ResetLocationPricingSearch event,
    Emitter<LocationPricingState> emit,
  ) {
    if (state is LocationPricingLoaded) {
      final currentState = state as LocationPricingLoaded;
      emit(currentState.copyWith(searchQueryReset: () => null));
    }
  }

  Future<void> _onRefreshLocationPricing(
    RefreshLocationPricing event,
    Emitter<LocationPricingState> emit,
  ) async {
    try {
      emit(const LocationPricingLoading());

      final locations = await _locationPricingRepository.getLocationPricing(
        event.organizationId,
      );

      if (locations.isEmpty) {
        emit(const LocationPricingEmpty());
      } else {
        emit(LocationPricingLoaded(locations: locations));
      }
    } catch (e) {
      emit(LocationPricingError('Failed to refresh location pricing: $e'));
    }
  }
}

