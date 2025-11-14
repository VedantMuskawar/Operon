import 'package:equatable/equatable.dart';

abstract class DepotEvent extends Equatable {
  const DepotEvent();

  @override
  List<Object?> get props => [];
}

class LoadDepotLocation extends DepotEvent {
  final String orgId;

  const LoadDepotLocation(this.orgId);

  @override
  List<Object?> get props => [orgId];
}

class SaveDepotLocation extends DepotEvent {
  final String orgId;
  final double latitude;
  final double longitude;
  final String? label;
  final String? address;

  const SaveDepotLocation({
    required this.orgId,
    required this.latitude,
    required this.longitude,
    this.label,
    this.address,
  });

  @override
  List<Object?> get props => [
        orgId,
        latitude,
        longitude,
        label,
        address,
      ];
}

class ClearDepotStatus extends DepotEvent {
  const ClearDepotStatus();
}


