import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'trip_wages_state.dart';

class TripWagesCubit extends Cubit<TripWagesState> {
  TripWagesCubit({
    required TripWagesRepository repository,
    required DeliveryMemoRepository deliveryMemoRepository,
    required String organizationId,
  })  : _repository = repository,
        _deliveryMemoRepository = deliveryMemoRepository,
        _organizationId = organizationId,
        super(const TripWagesState());

  final TripWagesRepository _repository;
  final DeliveryMemoRepository _deliveryMemoRepository;
  final String _organizationId;
  StreamSubscription<List<TripWage>>? _tripWagesSubscription;

  @override
  Future<void> close() {
    _tripWagesSubscription?.cancel();
    return super.close();
  }

  /// Load trip wages
  Future<void> loadTripWages({
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final tripWages = await _repository.fetchTripWages(
        _organizationId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        methodId: methodId,
        dmId: dmId,
        limit: limit,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        tripWages: tripWages,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading trip wages: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load trip wages: ${e.toString()}',
      ));
    }
  }

  /// Watch trip wages stream for real-time updates
  void watchTripWages({
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) {
    _tripWagesSubscription?.cancel();
    _tripWagesSubscription = _repository
        .watchTripWages(
      _organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      dmId: dmId,
      limit: limit,
    )
        .listen(
      (tripWages) {
        emit(state.copyWith(
          status: ViewStatus.success,
          tripWages: tripWages,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint('[TripWagesCubit] Error in trip wages stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load trip wages: ${error.toString()}',
        ));
      },
    );
  }

  /// Load returned delivery memos (for assignment)
  Future<void> loadReturnedDMs() async {
    try {
      // Get all active DMs (stream first value)
      final memos = await _deliveryMemoRepository
          .watchDeliveryMemos(
            organizationId: _organizationId,
            status: 'active',
          )
          .first;

      // Filter to only returned memos and get those without trip wage records
      final returnedMemos = <Map<String, dynamic>>[];
      for (final memo in memos) {
        // Check if tripStatus is 'returned' (this is in the memo data)
        final tripStatus = memo['tripStatus'] as String?;
        if (tripStatus == 'returned') {
          final dmId = memo['dmId'] as String?;
          if (dmId != null) {
            // Check if trip wage already exists
            final existingWage = await _repository.fetchTripWageByDmId(dmId);
            if (existingWage == null) {
              returnedMemos.add(memo);
            }
          }
        }
      }

      emit(state.copyWith(returnedDMs: returnedMemos));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading returned DMs: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load returned delivery memos: ${e.toString()}',
      ));
    }
  }

  /// Create trip wage
  Future<String> createTripWage(TripWage tripWage) async {
    try {
      final tripWageId = await _repository.createTripWage(tripWage);
      await loadTripWages();
      return tripWageId;
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error creating trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Update trip wage
  Future<void> updateTripWage(String tripWageId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateTripWage(tripWageId, updates);
      await loadTripWages();
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error updating trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Delete trip wage
  Future<void> deleteTripWage(String tripWageId) async {
    try {
      await _repository.deleteTripWage(tripWageId);
      await loadTripWages();
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error deleting trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Get trip wage by ID
  Future<TripWage?> getTripWage(String tripWageId) async {
    try {
      return await _repository.getTripWage(tripWageId);
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error getting trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to get trip wage: ${e.toString()}',
      ));
      return null;
    }
  }

  /// Get trip wage by DM ID
  Future<TripWage?> getTripWageByDmId(String dmId) async {
    try {
      return await _repository.fetchTripWageByDmId(dmId);
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error getting trip wage by DM ID: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      return null;
    }
  }
}

