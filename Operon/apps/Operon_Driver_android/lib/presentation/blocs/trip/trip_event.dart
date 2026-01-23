part of 'trip_bloc.dart';

abstract class TripEvent {
  const TripEvent();
}

class StartTrip extends TripEvent {
  const StartTrip({
    required this.tripId,
    required this.clientId,
  });

  final String tripId;
  final String clientId;
}

class EndTrip extends TripEvent {
  const EndTrip();
}

