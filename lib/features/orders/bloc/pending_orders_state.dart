import 'package:equatable/equatable.dart';

import '../../../core/models/order.dart';

enum PendingOrdersStatus { initial, loading, success, empty, failure }

class PendingOrdersState extends Equatable {
  const PendingOrdersState({
    this.status = PendingOrdersStatus.initial,
    this.orders = const [],
    this.isRefreshing = false,
    this.processingOrderIds = const {},
    this.errorMessage,
    this.successMessage,
  });

  final PendingOrdersStatus status;
  final List<Order> orders;
  final bool isRefreshing;
  final Set<String> processingOrderIds;
  final String? errorMessage;
  final String? successMessage;

  PendingOrdersState copyWith({
    PendingOrdersStatus? status,
    List<Order>? orders,
    bool? isRefreshing,
    Set<String>? processingOrderIds,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return PendingOrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      processingOrderIds: processingOrderIds ?? this.processingOrderIds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        isRefreshing,
        processingOrderIds,
        errorMessage,
        successMessage,
      ];
}

