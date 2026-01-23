import 'package:dash_web/data/datasources/scheduled_trips_data_source.dart';

class ScheduledTripsRepository {
  ScheduledTripsRepository({ScheduledTripsDataSource? dataSource})
      : _dataSource = dataSource ?? ScheduledTripsDataSource();

  final ScheduledTripsDataSource _dataSource;

  Future<String> createScheduledTrip({
    required String organizationId,
    required String orderId,
    required String clientId,
    required String clientName,
    required String customerNumber,
    String? clientPhone,
    required String paymentType,
    required DateTime scheduledDate,
    required String scheduledDay,
    required String vehicleId,
    required String vehicleNumber,
    required String? driverId,
    required String? driverName,
    required String? driverPhone,
    required int slot,
    required String slotName,
    required Map<String, dynamic> deliveryZone,
    required List<dynamic> items,
    required Map<String, dynamic> pricing,
    required String priority,
    required String createdBy,
    int? itemIndex,
    String? productId,
  }) {
    return _dataSource.createScheduledTrip(
      organizationId: organizationId,
      orderId: orderId,
      clientId: clientId,
      clientName: clientName,
      customerNumber: customerNumber,
      clientPhone: clientPhone,
      paymentType: paymentType,
      scheduledDate: scheduledDate,
      scheduledDay: scheduledDay,
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
      driverId: driverId,
      driverName: driverName,
      driverPhone: driverPhone,
      slot: slot,
      slotName: slotName,
      deliveryZone: deliveryZone,
      items: items,
      pricing: pricing,
      priority: priority,
      createdBy: createdBy,
      itemIndex: itemIndex,
      productId: productId,
    );
  }

  Future<List<Map<String, dynamic>>> getScheduledTripsForDayAndVehicle({
    required String organizationId,
    required String scheduledDay,
    required DateTime scheduledDate,
    required String vehicleId,
  }) {
    return _dataSource.getScheduledTripsForDayAndVehicle(
      organizationId: organizationId,
      scheduledDay: scheduledDay,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
    );
  }

  Future<void> updateTripRescheduleReason({
    required String tripId,
    required String reason,
  }) {
    return _dataSource.updateTripRescheduleReason(
      tripId: tripId,
      reason: reason,
    );
  }

  Future<void> deleteScheduledTrip(String tripId) {
    return _dataSource.deleteScheduledTrip(tripId);
  }

  Future<List<Map<String, dynamic>>> getScheduledTripsForOrder(String orderId) {
    return _dataSource.getScheduledTripsForOrder(orderId);
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
    String? returnedBy,
    String? returnedByRole,
    List<Map<String, dynamic>>? paymentDetails,
    double? totalPaidOnReturn,
    String? paymentStatus,
    double? remainingAmount,
    List<String>? returnTransactions,
    bool clearPaymentInfo = false,
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
      returnedBy: returnedBy,
      returnedByRole: returnedByRole,
      paymentDetails: paymentDetails,
      totalPaidOnReturn: totalPaidOnReturn,
      paymentStatus: paymentStatus,
      remainingAmount: remainingAmount,
      returnTransactions: returnTransactions,
      clearPaymentInfo: clearPaymentInfo,
      source: source,
    );
  }

  Stream<List<Map<String, dynamic>>> watchScheduledTripsForDate({
    required String organizationId,
    required DateTime scheduledDate,
  }) {
    return _dataSource.watchScheduledTripsForDate(
      organizationId: organizationId,
      scheduledDate: scheduledDate,
    );
  }

  Future<bool> isSlotAvailable({
    required String organizationId,
    required DateTime scheduledDate,
    required String vehicleId,
    required int slot,
    String? excludeTripId,
  }) {
    return _dataSource.isSlotAvailable(
      organizationId: organizationId,
      scheduledDate: scheduledDate,
      vehicleId: vehicleId,
      slot: slot,
      excludeTripId: excludeTripId,
    );
  }
}
