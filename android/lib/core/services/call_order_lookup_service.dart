import 'package:shared_preferences/shared_preferences.dart';
import '../../features/organization/repositories/android_client_repository.dart';
import '../../features/organization/repositories/android_order_repository.dart';
import '../../features/organization/models/order.dart';

class CallOrderInfo {
  final String phoneNumber;
  final String? clientName;
  final List<OrderInfo> orders;

  CallOrderInfo({
    required this.phoneNumber,
    this.clientName,
    required this.orders,
  });
}

class OrderInfo {
  final String orderId;
  final DateTime placedDate;
  final String location;
  final int trips;

  OrderInfo({
    required this.orderId,
    required this.placedDate,
    required this.location,
    required this.trips,
  });
}

class CallOrderLookupService {
  static const String _orgIdKey = 'current_organization_id';
  
  final AndroidClientRepository _clientRepository = AndroidClientRepository();
  final AndroidOrderRepository _orderRepository = AndroidOrderRepository();

  /// Store current organization ID for use in background service
  Future<void> setCurrentOrganizationId(String organizationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_orgIdKey, organizationId);
  }

  /// Get current organization ID
  Future<String?> getCurrentOrganizationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_orgIdKey);
  }

  /// Look up pending orders for a phone number
  Future<CallOrderInfo> lookupPendingOrders(String phoneNumber) async {
    try {
      // Get current organization ID
      final organizationId = await getCurrentOrganizationId();
      if (organizationId == null || organizationId.isEmpty) {
        print('CallOrderLookupService: No organization ID set');
        return CallOrderInfo(
          phoneNumber: phoneNumber,
          orders: [],
        );
      }

      // Normalize phone number
      final normalizedPhone = AndroidClientRepository.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone.isEmpty) {
        return CallOrderInfo(
          phoneNumber: phoneNumber,
          orders: [],
        );
      }

      // Look up client by phone number
      final client = await _clientRepository.getClientByPhoneNumber(
        organizationId,
        normalizedPhone,
      );

      if (client == null) {
        return CallOrderInfo(
          phoneNumber: phoneNumber,
          orders: [],
        );
      }

      // Get pending orders for this client
      final orders = await _orderRepository.getOrdersByClient(
        organizationId,
        client.clientId,
        status: OrderStatus.pending,
      );

      // Convert to OrderInfo list
      final orderInfos = orders.map((order) {
        final location = order.city.isNotEmpty
            ? '${order.city}${order.region.isNotEmpty ? ', ${order.region}' : ''}'
            : order.region.isNotEmpty
                ? order.region
                : 'Unknown';
        
        return OrderInfo(
          orderId: order.orderId,
          placedDate: order.createdAt,
          location: location,
          trips: order.trips,
        );
      }).toList();

      return CallOrderInfo(
        phoneNumber: phoneNumber,
        clientName: client.name,
        orders: orderInfos,
      );
    } catch (e) {
      // Return empty result on error
      print('CallOrderLookupService: Error looking up orders: $e');
      return CallOrderInfo(
        phoneNumber: phoneNumber,
        orders: [],
      );
    }
  }
}
