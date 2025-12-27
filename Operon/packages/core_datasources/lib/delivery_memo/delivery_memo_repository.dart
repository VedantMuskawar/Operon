import 'delivery_memo_data_source.dart';

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

  /// Fetch delivery memos with optional filters
  Stream<List<Map<String, dynamic>>> watchDeliveryMemos({
    required String organizationId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _dataSource.watchDeliveryMemos(
      organizationId: organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Cancel DM: Call cloud function to cancel DM
  Future<void> cancelDM({
    required String tripId,
    String? dmId,
    required String cancelledBy,
    String? cancellationReason,
  }) {
    return _dataSource.cancelDM(
      tripId: tripId,
      dmId: dmId,
      cancelledBy: cancelledBy,
      cancellationReason: cancellationReason,
    );
  }
}

