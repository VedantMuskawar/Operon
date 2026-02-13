import 'delivery_memo_data_source.dart';

class DeliveryMemoRepository {
  DeliveryMemoRepository({DeliveryMemoDataSource? dataSource})
      : _dataSource = dataSource ?? DeliveryMemoDataSource();

  final DeliveryMemoDataSource _dataSource;

  /// Get a single delivery memo by ID
  Future<Map<String, dynamic>?> getDeliveryMemo(String dmId) {
    return _dataSource.getDeliveryMemo(dmId);
  }

  /// Get a single delivery memo by DM number (fast lookup)
  Future<Map<String, dynamic>?> getDeliveryMemoByDmNumber({
    required String organizationId,
    required int dmNumber,
  }) {
    return _dataSource.getDeliveryMemoByDmNumber(
      organizationId: organizationId,
      dmNumber: dmNumber,
    );
  }

  /// Fetch delivery memos by DM number range (inclusive)
  Future<List<Map<String, dynamic>>> getDeliveryMemosByDmNumberRange({
    required String organizationId,
    required int fromDmNumber,
    required int toDmNumber,
  }) {
    return _dataSource.getDeliveryMemosByDmNumberRange(
      organizationId: organizationId,
      fromDmNumber: fromDmNumber,
      toDmNumber: toDmNumber,
    );
  }

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

  /// Watch delivery memos for a specific client
  Stream<List<Map<String, dynamic>>> watchDeliveryMemosByClientId({
    required String organizationId,
    required String clientId,
    String? status,
    int? limit,
  }) {
    return _dataSource.watchDeliveryMemosByClientId(
      organizationId: organizationId,
      clientId: clientId,
      status: status,
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

  /// Get returned delivery memos for a specific vehicle from past 3 days
  Future<List<Map<String, dynamic>>> getReturnedDMsForVehicle({
    required String organizationId,
    required String vehicleNumber,
  }) {
    return _dataSource.getReturnedDMsForVehicle(
      organizationId: organizationId,
      vehicleNumber: vehicleNumber,
    );
  }

  /// Update multiple delivery memos with fuel voucher ID (batch update)
  Future<void> updateMultipleDMsWithFuelVoucher({
    required List<String> dmIds,
    required String fuelVoucherId,
  }) {
    return _dataSource.updateMultipleDMsWithFuelVoucher(
      dmIds: dmIds,
      fuelVoucherId: fuelVoucherId,
    );
  }

  /// Update a single delivery memo with fuel voucher ID
  Future<void> updateDeliveryMemoWithFuelVoucher({
    required String dmId,
    required String fuelVoucherId,
  }) {
    return _dataSource.updateDeliveryMemoWithFuelVoucher(
      dmId: dmId,
      fuelVoucherId: fuelVoucherId,
    );
  }
}

