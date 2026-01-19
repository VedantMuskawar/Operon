import 'dart:async';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeliveryMemosState extends BaseState {
  const DeliveryMemosState({
    super.status = ViewStatus.initial,
    this.deliveryMemos = const [],
    this.searchQuery = '',
    this.statusFilter, // 'active' or 'cancelled'
    this.startDate,
    this.endDate,
    this.message,
  }) : super(message: message);

  final List<Map<String, dynamic>> deliveryMemos;
  final String searchQuery;
  final String? statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  @override
  final String? message;

  List<Map<String, dynamic>> get filteredDeliveryMemos {
    var filtered = deliveryMemos;

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((dm) {
        final dmId = (dm['dmId'] as String? ?? '').toLowerCase();
        final dmNumberStr = (dm['dmNumber'] as int? ?? 0).toString();
        final clientName = (dm['clientName'] as String? ?? '').toLowerCase();
        final vehicleNumber = (dm['vehicleNumber'] as String? ?? '').toLowerCase();
        return dmId.contains(query) ||
            dmNumberStr.contains(query) ||
            clientName.contains(query) ||
            vehicleNumber.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  DeliveryMemosState copyWith({
    ViewStatus? status,
    List<Map<String, dynamic>>? deliveryMemos,
    String? searchQuery,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? message,
  }) {
    return DeliveryMemosState(
      status: status ?? this.status,
      deliveryMemos: deliveryMemos ?? this.deliveryMemos,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      message: message ?? this.message,
    );
  }
}

class DeliveryMemosCubit extends Cubit<DeliveryMemosState> {
  DeliveryMemosCubit({
    required DeliveryMemoRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const DeliveryMemosState());

  final DeliveryMemoRepository _repository;
  final String _organizationId;
  StreamSubscription<List<Map<String, dynamic>>>? _deliveryMemosSubscription;

  String get organizationId => _organizationId;

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
    // Reload with appropriate limit when search changes
    _subscribeToDeliveryMemos();
  }

  void setStatusFilter(String? status) {
    emit(state.copyWith(statusFilter: status));
    _subscribeToDeliveryMemos();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate: start, endDate: end));
    _subscribeToDeliveryMemos();
  }

  void clearFilters() {
    emit(state.copyWith(
      statusFilter: null,
      startDate: null,
      endDate: null,
      searchQuery: '',
    ));
    _subscribeToDeliveryMemos();
  }

  void _subscribeToDeliveryMemos() {
    _deliveryMemosSubscription?.cancel();

    // When searching, load all DMs (no limit). Otherwise, show top 10 by DM number
    final limit = state.searchQuery.isNotEmpty ? null : 10;

    _deliveryMemosSubscription = _repository
        .watchDeliveryMemos(
          organizationId: _organizationId,
          status: state.statusFilter,
          startDate: state.startDate,
          endDate: state.endDate,
          limit: limit, // Show top 10 when no search, all DMs when searching
        )
        .listen(
      (deliveryMemos) {
        emit(state.copyWith(
          status: ViewStatus.success,
          deliveryMemos: deliveryMemos,
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Unable to load delivery memos. Please try again.',
        ));
      },
    );

    emit(state.copyWith(status: ViewStatus.loading));
  }

  void load() {
    _subscribeToDeliveryMemos();
  }

  Future<void> cancelDM({
    required String tripId,
    String? dmId,
    required String cancelledBy,
    String? cancellationReason,
  }) async {
    try {
      await _repository.cancelDM(
        tripId: tripId,
        dmId: dmId,
        cancelledBy: cancelledBy,
        cancellationReason: cancellationReason,
      );
      // The subscription will automatically update the list
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to cancel DM: ${error.toString()}',
      ));
      rethrow;
    }
  }

  @override
  Future<void> close() {
    _deliveryMemosSubscription?.cancel();
    return super.close();
  }
}

