import 'package:dash_mobile/data/datasources/pending_orders_data_source.dart';

class PendingOrdersRepository {
  PendingOrdersRepository({required PendingOrdersDataSource dataSource})
      : _dataSource = dataSource;

  final PendingOrdersDataSource _dataSource;

  Future<String> createOrder(String orgId, Map<String, dynamic> orderData) {
    return _dataSource.createOrder(orgId, orderData);
  }

  Future<int> getPendingOrdersCount(String orgId) {
    return _dataSource.getPendingOrdersCount(orgId);
  }

  Future<int> getTotalPendingTrips(String orgId) {
    return _dataSource.getTotalPendingTrips(orgId);
  }

  Future<List<Map<String, dynamic>>> fetchPendingOrders(String orgId) {
    return _dataSource.fetchPendingOrders(orgId);
  }

  Stream<List<Map<String, dynamic>>> watchPendingOrders(String orgId) {
    return _dataSource.watchPendingOrders(orgId);
  }

  Future<void> updateOrderTrips({
    required String orderId,
    required String productId,
    required int newTrips,
  }) {
    return _dataSource.updateOrderTrips(
      orderId: orderId,
      productId: productId,
      newTrips: newTrips,
    );
  }

  Stream<Map<String, dynamic>?> watchOrder(String orderId) {
    return _dataSource.watchOrder(orderId);
  }

  Future<void> updateOrder({
    required String orderId,
    String? priority,
    Map<String, dynamic>? deliveryZone,
    double? advanceAmount,
    String? advancePaymentAccountId,
    Map<String, dynamic>? notes,
  }) {
    return _dataSource.updateOrder(
      orderId: orderId,
      priority: priority,
      deliveryZone: deliveryZone,
      advanceAmount: advanceAmount,
      advancePaymentAccountId: advancePaymentAccountId,
      notes: notes,
    );
  }

  Future<void> deleteOrder(String orderId) {
    return _dataSource.deleteOrder(orderId);
  }
}

