import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/order.dart';
import '../repositories/order_repository.dart';
import 'pending_orders_event.dart';
import 'pending_orders_state.dart';

class PendingOrdersBloc
    extends Bloc<PendingOrdersEvent, PendingOrdersState> {
  PendingOrdersBloc({
    required OrderRepository orderRepository,
  })  : _orderRepository = orderRepository,
        super(const PendingOrdersState()) {
    on<PendingOrdersRequested>(_onOrdersRequested);
    on<PendingOrdersRefreshed>(_onOrdersRefreshed);
    on<PendingOrderScheduleRequested>(_onScheduleRequested);
    on<PendingOrderDeleteRequested>(_onDeleteRequested);
    on<PendingOrdersMessageCleared>(_onMessageCleared);
  }

  final OrderRepository _orderRepository;

  String? _organizationId;

  Future<void> _onOrdersRequested(
    PendingOrdersRequested event,
    Emitter<PendingOrdersState> emit,
  ) async {
    if (_organizationId == event.organizationId &&
        !event.forceRefresh &&
        state.status == PendingOrdersStatus.success) {
      return;
    }

    _organizationId = event.organizationId;

    emit(state.copyWith(
      status: PendingOrdersStatus.loading,
      orders: const [],
      isRefreshing: false,
      processingOrderIds: const {},
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final orders = await _orderRepository.fetchPendingOrders(
        organizationId: event.organizationId,
      );

      if (orders.isEmpty) {
        emit(state.copyWith(
          status: PendingOrdersStatus.empty,
          orders: const [],
          processingOrderIds: const {},
          clearSuccess: true,
        ));
        return;
      }

      emit(state.copyWith(
        status: PendingOrdersStatus.success,
        orders: orders,
        processingOrderIds: const {},
        clearSuccess: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PendingOrdersStatus.failure,
        errorMessage: 'Failed to load pending orders: $error',
      ));
    }
  }

  Future<void> _onOrdersRefreshed(
    PendingOrdersRefreshed event,
    Emitter<PendingOrdersState> emit,
  ) async {
    final orgId = _organizationId;
    if (orgId == null) {
      return;
    }

    emit(state.copyWith(
      isRefreshing: true,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final orders = await _orderRepository.fetchPendingOrders(
        organizationId: orgId,
      );

      if (orders.isEmpty) {
        emit(state.copyWith(
          status: PendingOrdersStatus.empty,
          orders: const [],
          isRefreshing: false,
          processingOrderIds: const {},
          clearSuccess: true,
        ));
        return;
      }

      emit(state.copyWith(
        status: PendingOrdersStatus.success,
        orders: orders,
        isRefreshing: false,
        processingOrderIds: const {},
        clearSuccess: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: PendingOrdersStatus.failure,
        isRefreshing: false,
        errorMessage: 'Failed to refresh pending orders: $error',
      ));
    }
  }

  Future<void> _onScheduleRequested(
    PendingOrderScheduleRequested event,
    Emitter<PendingOrdersState> emit,
  ) async {
    final orgId = _organizationId;
    if (orgId == null) {
      return;
    }

    final processingIds = Set<String>.from(state.processingOrderIds)
      ..add(event.order.id);
    emit(state.copyWith(
      processingOrderIds: processingIds,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final updatedOrder = event.order.copyWith(
        status: OrderStatus.confirmed,
        updatedAt: DateTime.now(),
        updatedBy: event.userId,
      );

      await _orderRepository.updateOrder(
        organizationId: orgId,
        orderId: event.order.orderId,
        order: updatedOrder,
      );

      final remainingOrders = state.orders
          .where((order) => order.id != event.order.id)
          .toList(growable: false);

      emit(state.copyWith(
        orders: remainingOrders,
        status: remainingOrders.isEmpty
            ? PendingOrdersStatus.empty
            : PendingOrdersStatus.success,
        processingOrderIds: processingIds..remove(event.order.id),
        successMessage: 'Order scheduled successfully',
      ));
    } catch (error) {
      processingIds.remove(event.order.id);
      emit(state.copyWith(
        processingOrderIds: processingIds,
        errorMessage: 'Failed to schedule order: $error',
      ));
    }
  }

  Future<void> _onDeleteRequested(
    PendingOrderDeleteRequested event,
    Emitter<PendingOrdersState> emit,
  ) async {
    final orgId = _organizationId;
    if (orgId == null) {
      return;
    }

    final processingIds = Set<String>.from(state.processingOrderIds)
      ..add(event.order.id);
    emit(state.copyWith(
      processingOrderIds: processingIds,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      await _orderRepository.deleteOrder(
        organizationId: orgId,
        orderId: event.order.orderId,
      );

      final remainingOrders = state.orders
          .where((order) => order.id != event.order.id)
          .toList(growable: false);

      emit(state.copyWith(
        orders: remainingOrders,
        status: remainingOrders.isEmpty
            ? PendingOrdersStatus.empty
            : PendingOrdersStatus.success,
        processingOrderIds: processingIds..remove(event.order.id),
        successMessage: 'Order deleted successfully',
      ));
    } catch (error) {
      processingIds.remove(event.order.id);
      emit(state.copyWith(
        processingOrderIds: processingIds,
        errorMessage: 'Failed to delete order: $error',
      ));
    }
  }

  void _onMessageCleared(
    PendingOrdersMessageCleared event,
    Emitter<PendingOrdersState> emit,
  ) {
    if (state.successMessage != null || state.errorMessage != null) {
      emit(state.copyWith(
        clearSuccess: true,
        clearError: true,
      ));
    }
  }
}

