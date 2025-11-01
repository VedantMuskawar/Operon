import 'package:equatable/equatable.dart';
import '../models/vehicle.dart';

abstract class VehicleEvent extends Equatable {
  const VehicleEvent();

  @override
  List<Object?> get props => [];
}

// Load vehicles for an organization
class LoadVehicles extends VehicleEvent {
  final String organizationId;

  const LoadVehicles(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Add a new vehicle
class AddVehicle extends VehicleEvent {
  final String organizationId;
  final Vehicle vehicle;
  final String userId;

  const AddVehicle({
    required this.organizationId,
    required this.vehicle,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, vehicle, userId];
}

// Update an existing vehicle
class UpdateVehicle extends VehicleEvent {
  final String organizationId;
  final String vehicleId;
  final Vehicle vehicle;
  final String userId;

  const UpdateVehicle({
    required this.organizationId,
    required this.vehicleId,
    required this.vehicle,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, vehicleId, vehicle, userId];
}

// Delete a vehicle
class DeleteVehicle extends VehicleEvent {
  final String organizationId;
  final String vehicleId;

  const DeleteVehicle({
    required this.organizationId,
    required this.vehicleId,
  });

  @override
  List<Object?> get props => [organizationId, vehicleId];
}

// Search vehicles
class SearchVehicles extends VehicleEvent {
  final String organizationId;
  final String query;

  const SearchVehicles({
    required this.organizationId,
    required this.query,
  });

  @override
  List<Object?> get props => [organizationId, query];
}

// Reset search
class ResetSearch extends VehicleEvent {
  const ResetSearch();
}

// Refresh vehicles
class RefreshVehicles extends VehicleEvent {
  final String organizationId;

  const RefreshVehicles(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

