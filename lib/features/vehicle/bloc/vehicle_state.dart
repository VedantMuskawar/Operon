import 'package:equatable/equatable.dart';
import '../models/vehicle.dart';

abstract class VehicleState extends Equatable {
  const VehicleState();

  @override
  List<Object?> get props => [];
}

// Initial state
class VehicleInitial extends VehicleState {
  const VehicleInitial();
}

// Loading state
class VehicleLoading extends VehicleState {
  const VehicleLoading();
}

// Vehicles loaded successfully
class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  final String? searchQuery;

  const VehicleLoaded({
    required this.vehicles,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [vehicles, searchQuery];

  VehicleLoaded copyWith({
    List<Vehicle>? vehicles,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return VehicleLoaded(
      vehicles: vehicles ?? this.vehicles,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

// Operation in progress (add/update/delete)
class VehicleOperating extends VehicleState {
  const VehicleOperating();
}

// Operation successful
class VehicleOperationSuccess extends VehicleState {
  final String message;

  const VehicleOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error state
class VehicleError extends VehicleState {
  final String message;

  const VehicleError(this.message);

  @override
  List<Object?> get props => [message];
}

// Empty state (no vehicles found)
class VehicleEmpty extends VehicleState {
  final String? searchQuery;

  const VehicleEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

