import 'package:core_models/core_models.dart';
import 'package:core_datasources/trip_wages/trip_wages_data_source.dart';

class TripWagesRepository {
  TripWagesRepository({required TripWagesDataSource dataSource})
      : _dataSource = dataSource;

  final TripWagesDataSource _dataSource;

  Future<String> createTripWage(TripWage tripWage) {
    return _dataSource.createTripWage(tripWage);
  }

  Future<List<TripWage>> fetchTripWages(
    String organizationId, {
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) {
    return _dataSource.fetchTripWages(
      organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      dmId: dmId,
      limit: limit,
    );
  }

  Stream<List<TripWage>> watchTripWages(
    String organizationId, {
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) {
    return _dataSource.watchTripWages(
      organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      dmId: dmId,
      limit: limit,
    );
  }

  Future<TripWage?> getTripWage(String tripWageId) {
    return _dataSource.getTripWage(tripWageId);
  }

  Future<TripWage?> fetchTripWageByDmId(String dmId) {
    return _dataSource.fetchTripWageByDmId(dmId);
  }

  Future<void> updateTripWage(
    String tripWageId,
    Map<String, dynamic> updates,
  ) {
    return _dataSource.updateTripWage(tripWageId, updates);
  }

  Future<void> deleteTripWage(String tripWageId) {
    return _dataSource.deleteTripWage(tripWageId);
  }
}

