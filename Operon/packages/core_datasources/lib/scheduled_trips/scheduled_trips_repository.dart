import 'scheduled_trips_data_source.dart';

class ScheduledTripsRepository {
  ScheduledTripsRepository({ScheduledTripsDataSource? dataSource})
      : _dataSource = dataSource ?? ScheduledTripsDataSource();

  final ScheduledTripsDataSource _dataSource;

  Stream<List<Map<String, dynamic>>> watchDriverScheduledTripsForDate({
    required String organizationId,
    required String driverPhone,
    required DateTime scheduledDate,
  }) {
    return _dataSource.watchDriverScheduledTripsForDate(
      organizationId: organizationId,
      driverPhone: driverPhone,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> updateTripStatus({
    required String tripId,
    required String tripStatus,
    DateTime? completedAt,
    DateTime? cancelledAt,
    double? initialReading,
    String? deliveryPhotoUrl,
    String? deliveredBy,
    String? deliveredByRole,
    double? finalReading,
    double? distanceTravelled,
    double? computedTravelledDistance,
    String? returnedBy,
    String? returnedByRole,
    bool clearDeliveryInfo = false,
    String? source,
  }) {
    return _dataSource.updateTripStatus(
      tripId: tripId,
      tripStatus: tripStatus,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      initialReading: initialReading,
      deliveryPhotoUrl: deliveryPhotoUrl,
      deliveredBy: deliveredBy,
      deliveredByRole: deliveredByRole,
      finalReading: finalReading,
      distanceTravelled: distanceTravelled,
      computedTravelledDistance: computedTravelledDistance,
      returnedBy: returnedBy,
      returnedByRole: returnedByRole,
      clearDeliveryInfo: clearDeliveryInfo,
      source: source,
    );
  }
}

