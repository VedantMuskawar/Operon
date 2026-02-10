import 'package:cloud_functions/cloud_functions.dart';
import 'package:dash_web/data/datasources/pending_orders_data_source.dart';

class PendingOrdersRepository {
  PendingOrdersRepository({
    required PendingOrdersDataSource dataSource,
    FirebaseFunctions? functions,
  })  : _dataSource = dataSource,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  final PendingOrdersDataSource _dataSource;
  final FirebaseFunctions _functions;

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

  Future<void> deleteOrder(String orderId) {
    return _dataSource.deleteOrder(orderId);
  }

  Future<Map<String, dynamic>> calculateEddForAllPendingOrders(
      String organizationId) async {
    final callable =
        _functions.httpsCallable('calculateEddForAllPendingOrders');
    final result = await callable.call({
      'organizationId': organizationId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
