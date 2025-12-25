import 'package:cloud_firestore/cloud_firestore.dart';

class PendingOrdersDataSource {
  PendingOrdersDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ordersRef() {
    return _firestore.collection('PENDING_ORDERS');
  }

  Future<String> createOrder(String orgId, Map<String, dynamic> orderData) async {
    final docRef = _ordersRef().doc();
    final normalizedClientPhone =
        _normalizePhone(orderData['clientPhone'] as String? ?? '');
    final clientName = (orderData['clientName'] as String?)?.trim() ?? '';
    final nameLc = clientName.toLowerCase();

    await docRef.set({
      ...orderData,
      'orderId': docRef.id,
      'organizationId': orgId,
      'clientPhone': normalizedClientPhone.isNotEmpty
          ? normalizedClientPhone
          : orderData['clientPhone'],
      'name_lc': nameLc,
      'tripIds': orderData['tripIds'] ?? <dynamic>[],
      'totalScheduledTrips': orderData['totalScheduledTrips'] ?? 0,
      'scheduledQuantity': orderData['scheduledQuantity'],
      'unscheduledQuantity': orderData['unscheduledQuantity'],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<int> getPendingOrdersCount(String orgId) async {
    final snapshot = await _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      final items = data['items'] as List<dynamic>? ?? [];
      final firstItem = items.isNotEmpty ? items[0] as Map<String, dynamic>? : null;
      final estimatedTrips = firstItem?['estimatedTrips'] as int? ?? 0;
      final hasAvailableTrips = estimatedTrips > 0;

      if ((status == null || status == 'pending') && hasAvailableTrips) {
        count++;
      }
    }
    return count;
  }

  Future<int> getTotalPendingTrips(String orgId) async {
    final snapshot = await _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .get();

    int totalTrips = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      if (status == null || status == 'pending') {
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final trips = itemMap['estimatedTrips'] as int? ?? 0;
          totalTrips += trips;
        }
      }
    }
    return totalTrips;
  }

  Future<List<Map<String, dynamic>>> fetchPendingOrders(String orgId) async {
    final snapshot = await _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();

    final orders = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      final items = data['items'] as List<dynamic>? ?? [];
      final firstItem = items.isNotEmpty ? items[0] as Map<String, dynamic>? : null;
      final estimatedTrips = firstItem?['estimatedTrips'] as int? ?? 0;
      final hasAvailableTrips = estimatedTrips > 0;

      if ((status == null || status == 'pending') && hasAvailableTrips) {
        orders.add({
          'id': doc.id,
          ...data,
        });
      }
    }
    return orders;
  }

  Stream<List<Map<String, dynamic>>> watchPendingOrders(String orgId) {
    return _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final orders = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] as String?;

            final items = data['items'] as List<dynamic>? ?? [];
            final firstItem = items.isNotEmpty ? items[0] as Map<String, dynamic>? : null;
            final estimatedTrips = firstItem?['estimatedTrips'] as int? ?? 0;
            final hasAvailableTrips = estimatedTrips > 0;

            if ((status == null || status == 'pending') && hasAvailableTrips) {
              orders.add({
                'id': doc.id,
                ...data,
              });
            }
          }
          return orders;
        });
  }

  Future<void> updateOrderTrips({
    required String orderId,
    required String productId,
    required int newTrips,
  }) async {
    final orderRef = _ordersRef().doc(orderId);
    final orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final data = orderDoc.data()!;
    final items = (data['items'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();

    bool itemFound = false;
    for (int i = 0; i < items.length; i++) {
      if (items[i]['productId'] == productId) {
        final fixedQty = items[i]['fixedQuantityPerTrip'] as int;
        final unitPrice = (items[i]['unitPrice'] as num).toDouble();
        final gstPercent = (items[i]['gstPercent'] as num?)?.toDouble();

        final totalQuantity = newTrips * fixedQty;
        final subtotal = totalQuantity * unitPrice;
        final gstAmount = gstPercent != null ? subtotal * (gstPercent / 100) : 0.0;
        final total = subtotal + gstAmount;

        items[i] = {
          ...items[i],
          'estimatedTrips': newTrips,
          'totalQuantity': totalQuantity,
          'subtotal': subtotal,
          'gstAmount': gstAmount,
          'total': total,
        };
        itemFound = true;
        break;
      }
    }

    if (!itemFound) {
      throw Exception('Product not found in order');
    }

    double orderSubtotal = 0;
    double orderGst = 0;
    for (final item in items) {
      orderSubtotal += (item['subtotal'] as num).toDouble();
      orderGst += (item['gstAmount'] as num).toDouble();
    }
    final orderTotal = orderSubtotal + orderGst;

    await orderRef.update({
      'items': items,
      'pricing.subtotal': orderSubtotal,
      'pricing.totalGst': orderGst,
      'pricing.totalAmount': orderTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteOrder(String orderId) async {
    await _ordersRef().doc(orderId).delete();
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
}
