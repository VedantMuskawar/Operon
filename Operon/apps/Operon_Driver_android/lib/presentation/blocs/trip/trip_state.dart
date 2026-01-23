part of 'trip_bloc.dart';

class TripState extends BaseState {
  const TripState({
    super.status = ViewStatus.initial,
    super.message,
    this.activeTrip,
    this.isTracking = false,
    this.lastStatusChangeSource,
    this.isManualDispatch = false,
  });

  final Trip? activeTrip;
  final bool isTracking;
  
  /// Source of the last trip status change ('driver' or 'client')
  final String? lastStatusChangeSource;
  
  /// True if trip was dispatched by client (manual dispatch, no tracking)
  final bool isManualDispatch;

  @override
  TripState copyWith({
    ViewStatus? status,
    String? message,
    Trip? activeTrip,
    bool? isTracking,
    String? lastStatusChangeSource,
    bool? isManualDispatch,
  }) {
    return TripState(
      status: status ?? this.status,
      message: message ?? this.message,
      activeTrip: activeTrip ?? this.activeTrip,
      isTracking: isTracking ?? this.isTracking,
      lastStatusChangeSource: lastStatusChangeSource ?? this.lastStatusChangeSource,
      isManualDispatch: isManualDispatch ?? this.isManualDispatch,
    );
  }
}

