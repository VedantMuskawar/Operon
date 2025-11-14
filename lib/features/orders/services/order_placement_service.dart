import '../../../core/models/order.dart';
import '../repositories/order_repository.dart';

class OrderPlacementService {
  OrderPlacementService({
    OrderRepository? orderRepository,
  }) : _orderRepository = orderRepository ?? OrderRepository();

  final OrderRepository _orderRepository;

  Future<String> createOrderAndNotify({
    required String organizationId,
    required Order order,
    required String userId,
  }) async {
    return _orderRepository.createOrder(
      organizationId: organizationId,
      order: order,
      userId: userId,
    );
  }
}

