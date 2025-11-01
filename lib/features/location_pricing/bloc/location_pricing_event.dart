import 'package:equatable/equatable.dart';
import '../models/location_pricing.dart';

abstract class LocationPricingEvent extends Equatable {
  const LocationPricingEvent();

  @override
  List<Object?> get props => [];
}

// Load location pricing for an organization
class LoadLocationPricing extends LocationPricingEvent {
  final String organizationId;

  const LoadLocationPricing(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Add a new location pricing
class AddLocationPricing extends LocationPricingEvent {
  final String organizationId;
  final LocationPricing locationPricing;
  final String userId;

  const AddLocationPricing({
    required this.organizationId,
    required this.locationPricing,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, locationPricing, userId];
}

// Update an existing location pricing
class UpdateLocationPricing extends LocationPricingEvent {
  final String organizationId;
  final String locationPricingId;
  final LocationPricing locationPricing;
  final String userId;

  const UpdateLocationPricing({
    required this.organizationId,
    required this.locationPricingId,
    required this.locationPricing,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, locationPricingId, locationPricing, userId];
}

// Delete a location pricing
class DeleteLocationPricing extends LocationPricingEvent {
  final String organizationId;
  final String locationPricingId;

  const DeleteLocationPricing({
    required this.organizationId,
    required this.locationPricingId,
  });

  @override
  List<Object?> get props => [organizationId, locationPricingId];
}

// Search location pricing
class SearchLocationPricing extends LocationPricingEvent {
  final String organizationId;
  final String query;

  const SearchLocationPricing({
    required this.organizationId,
    required this.query,
  });

  @override
  List<Object?> get props => [organizationId, query];
}

// Reset search
class ResetLocationPricingSearch extends LocationPricingEvent {
  const ResetLocationPricingSearch();
}

// Refresh location pricing
class RefreshLocationPricing extends LocationPricingEvent {
  final String organizationId;

  const RefreshLocationPricing(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

