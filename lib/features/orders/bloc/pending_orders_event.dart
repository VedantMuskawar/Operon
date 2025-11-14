import 'package:equatable/equatable.dart';

import '../../../core/models/order.dart';

abstract class PendingOrdersEvent extends Equatable {
  const PendingOrdersEvent();

  @override
  List<Object?> get props => [];
}

class PendingOrdersRequested extends PendingOrdersEvent {
  const PendingOrdersRequested({
    required this.organizationId,
    this.forceRefresh = false,
  });

  final String organizationId;
  final bool forceRefresh;

  @override
  List<Object?> get props => [organizationId, forceRefresh];
}

class PendingOrdersRefreshed extends PendingOrdersEvent {
  const PendingOrdersRefreshed();
}

class PendingOrderScheduleRequested extends PendingOrdersEvent {
  const PendingOrderScheduleRequested({
    required this.order,
    required this.userId,
  });

  final Order order;
  final String userId;

  @override
  List<Object?> get props => [order, userId];
}

class PendingOrderDeleteRequested extends PendingOrdersEvent {
  const PendingOrderDeleteRequested({
    required this.order,
  });

  final Order order;

  @override
  List<Object?> get props => [order];
}

class PendingOrdersMessageCleared extends PendingOrdersEvent {
  const PendingOrdersMessageCleared();
}

