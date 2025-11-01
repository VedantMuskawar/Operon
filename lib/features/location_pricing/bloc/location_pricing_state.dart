import 'package:equatable/equatable.dart';
import '../models/location_pricing.dart';

abstract class LocationPricingState extends Equatable {
  const LocationPricingState();

  @override
  List<Object?> get props => [];
}

// Initial state
class LocationPricingInitial extends LocationPricingState {
  const LocationPricingInitial();
}

// Loading state
class LocationPricingLoading extends LocationPricingState {
  const LocationPricingLoading();
}

// Location pricing loaded successfully
class LocationPricingLoaded extends LocationPricingState {
  final List<LocationPricing> locations;
  final String? searchQuery;

  const LocationPricingLoaded({
    required this.locations,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [locations, searchQuery];

  LocationPricingLoaded copyWith({
    List<LocationPricing>? locations,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return LocationPricingLoaded(
      locations: locations ?? this.locations,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

// Operation in progress (add/update/delete)
class LocationPricingOperating extends LocationPricingState {
  const LocationPricingOperating();
}

// Operation successful
class LocationPricingOperationSuccess extends LocationPricingState {
  final String message;

  const LocationPricingOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error state
class LocationPricingError extends LocationPricingState {
  final String message;

  const LocationPricingError(this.message);

  @override
  List<Object?> get props => [message];
}

// Empty state (no location pricing found)
class LocationPricingEmpty extends LocationPricingState {
  final String? searchQuery;

  const LocationPricingEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

