import 'package:dash_mobile/data/datasources/delivery_memo_data_source.dart';

class DeliveryMemoRepository {
  DeliveryMemoRepository({DeliveryMemoDataSource? dataSource})
      : _dataSource = dataSource ?? DeliveryMemoDataSource();

  final DeliveryMemoDataSource _dataSource;

  /// Generate DM for a scheduled trip
  Future<String> generateDM({
    required String organizationId,
    required String tripId,
    required String scheduleTripId,
    required Map<String, dynamic> tripData,
    required String generatedBy,
  }) {
    return _dataSource.generateDM(
      organizationId: organizationId,
      tripId: tripId,
      scheduleTripId: scheduleTripId,
      tripData: tripData,
      generatedBy: generatedBy,
    );
  }

  /// Check if DM exists for a scheduleTripId
  Future<bool> dmExistsForScheduleTripId(String scheduleTripId) {
    return _dataSource.dmExistsForScheduleTripId(scheduleTripId);
  }

  /// Cancel DM: Remove DM fields from trip document
  /// Note: DM numbers are NOT reused - cancelled numbers remain in sequence for audit trail
  Future<void> cancelDM({
    required String tripId,
    required String cancelledBy,
  }) {
    return _dataSource.cancelDM(
      tripId: tripId,
      cancelledBy: cancelledBy,
    );
  }
}





