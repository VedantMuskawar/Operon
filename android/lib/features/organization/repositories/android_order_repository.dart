import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import 'android_client_repository.dart';

class AndroidOrderRepository {
  final FirebaseFirestore _firestore;

  static const List<String> _activePendingStatuses = <String>[
    OrderStatus.pending,
    OrderStatus.confirmed,
  ];

  final AndroidClientRepository _clientRepository;

  AndroidOrderRepository({
    FirebaseFirestore? firestore,
    AndroidClientRepository? clientRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _clientRepository = clientRepository ?? AndroidClientRepository();

  /// Create a new order
  Future<String> createOrder(String organizationId, Order order, String userId) async {
    try {
      final fetchedClient = await _clientRepository.getClient(
        organizationId,
        order.clientId,
      );
      final fetchedName = fetchedClient?.name.trim() ?? '';
      final fallbackName = order.clientName?.trim() ?? '';
      final clientName = fetchedName.isNotEmpty ? fetchedName : fallbackName;

      final fetchedPhone = fetchedClient?.phoneNumber.trim() ?? '';
      final fallbackPhone = order.clientPhone?.trim() ?? '';
      final clientPhone =
          fetchedPhone.isNotEmpty ? fetchedPhone : fallbackPhone;

      final orderWithUser = Order(
        orderId: order.orderId,
        organizationId: organizationId,
        clientId: order.clientId,
        clientName: clientName.isNotEmpty ? clientName : null,
        clientPhone: clientPhone.isNotEmpty ? clientPhone : null,
        status: order.status,
        items: order.items,
        deliveryAddress: order.deliveryAddress,
        region: order.region,
        city: order.city,
        locationId: order.locationId,
        subtotal: order.subtotal,
        gstAmount: order.gstAmount,
        gstApplicable: order.gstApplicable,
        gstRate: order.gstRate,
        trips: order.trips,
        paymentType: order.paymentType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
        notes: order.notes,
        remainingTrips: order.remainingTrips,
        lastScheduledAt: order.lastScheduledAt,
        lastScheduledBy: order.lastScheduledBy,
        lastScheduledVehicleId: order.lastScheduledVehicleId,
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
          .where('status', whereIn: _activePendingStatuses)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final orders = snapshot.docs
            .map<Order>((doc) => Order.fromFirestore(doc))
            .where((order) => order.remainingTrips > 0)
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

      List<String>? statuses;
      if (status != null) {
        statuses = status == OrderStatus.pending
            ? _activePendingStatuses
            : <String>[status];
      }

      if (statuses != null) {
        if (statuses.length == 1) {
          query = query.where('status', isEqualTo: statuses.first);
        } else {
          query = query.where('status', whereIn: statuses);
        }
      }

      return query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final orders = snapshot.docs
            .map<Order>((doc) => Order.fromFirestore(doc))
            .where((order) {
          final shouldFilterRemainingTrips = statuses == null ||
              statuses.any((value) =>
                  value == OrderStatus.pending ||
                  value == OrderStatus.confirmed);
          return !shouldFilterRemainingTrips || order.remainingTrips > 0;
        }).toList();
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
          .where('status', whereIn: _activePendingStatuses)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(
            const GetOptions(source: Source.serverAndCache),
          );

      final orders = snapshot.docs
          .map<Order>((doc) => Order.fromFirestore(doc))
          .where((order) => order.remainingTrips > 0)
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

