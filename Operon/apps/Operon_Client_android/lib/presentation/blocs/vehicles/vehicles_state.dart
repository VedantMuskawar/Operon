part of 'vehicles_cubit.dart';

class VehiclesState extends BaseState {
  const VehiclesState({
    super.status = ViewStatus.initial,
    this.vehicles = const [],
    this.message,
  }) : super(message: message);

  final List<Vehicle> vehicles;
  @override
  final String? message;

  @override
  VehiclesState copyWith({
    ViewStatus? status,
    List<Vehicle>? vehicles,
    String? message,
  }) {
    return VehiclesState(
      status: status ?? this.status,
      vehicles: vehicles ?? this.vehicles,
      message: message ?? this.message,
    );
  }
}

