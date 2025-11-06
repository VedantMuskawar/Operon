import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';

class AndroidOrderRepository {
  final FirebaseFirestore _firestore;

  AndroidOrderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new order
  Future<String> createOrder(String organizationId, Order order, String userId) async {
    try {
      final orderWithUser = Order(
        orderId: order.orderId,
        organizationId: organizationId,
        clientId: order.clientId,
        status: order.status,
        items: order.items,
        deliveryAddress: order.deliveryAddress,
        region: order.region,
        city: order.city,
        locationId: order.locationId,
        subtotal: order.subtotal,
        totalAmount: order.totalAmount,
        trips: order.trips,
        paymentType: order.paymentType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
        notes: order.notes,
      );

      final docRef = await _firestore
          .collection('ORDERS')
          .add(orderWithUser.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  /// Get orders for a specific client with status filter
  Future<List<Order>> getOrdersByClient(
    String organizationId,
    String clientId, {
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('ORDERS')
          .where('organizationId', isEqualTo: organizationId)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );

      final orders = snapshot.docs
          .map<Order>((doc) => Order.fromFirestore(doc))
          .toList();

      return orders;
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Stream of all pending orders for organization (real-time)
  Stream<List<Order>> watchPendingOrders(String organizationId, {int limit = 50}) {
    try {
      return _firestore
          .collection('ORDERS')
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: OrderStatus.pending)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final orders = snapshot.docs
            .map<Order>((doc) => Order.fromFirestore(doc))
            .toList();
        return orders;
      });
    } catch (e) {
      throw Exception('Failed to watch pending orders: $e');
    }
  }

  /// Stream of orders for a specific client with status filter (real-time)
  Stream<List<Order>> watchOrdersByClient(
    String organizationId,
    String clientId, {
    String? status,
    int limit = 50,
  }) {
    try {
      Query query = _firestore
          .collection('ORDERS')
          .where('organizationId', isEqualTo: organizationId)
          .where('clientId', isEqualTo: clientId);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      return query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final orders = snapshot.docs
            .map<Order>((doc) => Order.fromFirestore(doc))
            .toList();
        return orders;
      });
    } catch (e) {
      throw Exception('Failed to watch orders: $e');
    }
  }

  /// Get all pending orders for organization
  Future<List<Order>> getPendingOrders(String organizationId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('ORDERS')
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: OrderStatus.pending)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(
            const GetOptions(source: Source.serverAndCache),
          );

      final orders = snapshot.docs
          .map<Order>((doc) => Order.fromFirestore(doc))
          .toList();

      return orders;
    } catch (e) {
      throw Exception('Failed to fetch pending orders: $e');
    }
  }

  /// Update an existing order
  Future<void> updateOrder(
    String organizationId,
    String orderId,
    Order order,
    String userId,
  ) async {
    try {
      final orderWithUser = order.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      final snapshot = await _firestore
          .collection('ORDERS')
          .where('orderId', isEqualTo: orderId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Fallback: use document ID
        final doc = await _firestore
            .collection('ORDERS')
            .doc(orderId)
            .get();

        if (!doc.exists) {
          throw Exception('Order not found');
        }

        final existingOrder = Order.fromFirestore(doc);
        if (existingOrder.organizationId != organizationId) {
          throw Exception('Order does not belong to this organization');
        }

        await doc.reference.update(orderWithUser.toFirestore());
      } else {
        await snapshot.docs.first.reference.update(orderWithUser.toFirestore());
      }
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  /// Delete an order
  Future<void> deleteOrder(
    String organizationId,
    String orderId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORDERS')
          .where('orderId', isEqualTo: orderId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Fallback: use document ID
        final doc = await _firestore
            .collection('ORDERS')
            .doc(orderId)
            .get();

        if (!doc.exists) {
          throw Exception('Order not found');
        }

        final existingOrder = Order.fromFirestore(doc);
        if (existingOrder.organizationId != organizationId) {
          throw Exception('Order does not belong to this organization');
        }

        await doc.reference.delete();
      } else {
        await snapshot.docs.first.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  /// Get a single order by ID
  Future<Order?> getOrderById(
    String organizationId,
    String orderId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORDERS')
          .where('orderId', isEqualTo: orderId)
          .where('organizationId', isEqualTo: organizationId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Fallback: use document ID
        final doc = await _firestore
            .collection('ORDERS')
            .doc(orderId)
            .get();

        if (!doc.exists) {
          return null;
        }

        final order = Order.fromFirestore(doc);
        if (order.organizationId != organizationId) {
          return null;
        }

        return order;
      } else {
        return Order.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }
}

