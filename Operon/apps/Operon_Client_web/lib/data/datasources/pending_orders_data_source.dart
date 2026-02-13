import 'package:cloud_firestore/cloud_firestore.dart';

class PendingOrdersDataSource {
  PendingOrdersDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _ordersRef() {
    return _firestore.collection('PENDING_ORDERS');
  }

  Future<String> createOrder(
      String orgId, Map<String, dynamic> orderData) async {
    final docRef = _ordersRef().doc();
    final normalizedClientPhone =
        _normalizePhone(orderData['clientPhone'] as String? ?? '');
    final clientName = (orderData['clientName'] as String?)?.trim() ?? '';
    final nameLc = clientName.toLowerCase();
    final items = (orderData['items'] as List<dynamic>?) ?? [];
    final status = (orderData['status'] as String?)?.trim();
    final resolvedStatus =
        status == null || status.isEmpty ? 'pending' : status;
    final hasAvailableTrips = _hasAvailableTrips(items);

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
      'status': resolvedStatus,
      'hasAvailableTrips': hasAvailableTrips,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Returns count of pending orders for the org using Firestore count aggregation.
  /// Note: Filters by hasAvailableTrips to align with schedule-ready orders.
  Future<int> getPendingOrdersCount(String orgId) async {
    final query = _ordersRef()
      .where('organizationId', isEqualTo: orgId)
      .where('status', isEqualTo: 'pending')
      .where('hasAvailableTrips', isEqualTo: true);
    final snapshot = await query.aggregate(count()).get();
    return snapshot.count ?? 0;
  }

  /// Sum of estimated trips across pending orders. Uses .limit(500) to cap reads.
  Future<int> getTotalPendingTrips(String orgId) async {
    final snapshot = await _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .where('hasAvailableTrips', isEqualTo: true)
        .limit(500)
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
      .where('status', isEqualTo: 'pending')
      .where('hasAvailableTrips', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> watchPendingOrders(String orgId) {
    return _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'pending')
        .where('hasAvailableTrips', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingOrdersForClient(
    String orgId,
    String clientId, {
    int limit = 50,
  }) {
    return _ordersRef()
        .where('organizationId', isEqualTo: orgId)
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: 'pending')
        .where('hasAvailableTrips', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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
    final items = (data['items'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    bool itemFound = false;
    for (int i = 0; i < items.length; i++) {
      if (items[i]['productId'] == productId) {
        final fixedQty = items[i]['fixedQuantityPerTrip'] as int;
        final unitPrice = (items[i]['unitPrice'] as num).toDouble();
        final gstPercent = (items[i]['gstPercent'] as num?)?.toDouble();

        final subtotal = (newTrips * fixedQty) * unitPrice;
        bool hasGst = false;
        if (gstPercent != null) {
          hasGst = gstPercent > 0;
        }
        double gstAmount = 0.0;
        if (hasGst && gstPercent != null) {
          gstAmount = subtotal * (gstPercent / 100);
        }
        final total = subtotal + gstAmount;

        final updatedItem = <String, dynamic>{
          ...items[i],
          'estimatedTrips': newTrips,
          'subtotal': subtotal,
          'total': total,
        };

        if (hasGst) {
          updatedItem['gstPercent'] = gstPercent;
          updatedItem['gstAmount'] = gstAmount;
        } else {
          updatedItem.remove('gstPercent');
          updatedItem.remove('gstAmount');
        }

        items[i] = updatedItem;
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
      final itemGst = (item['gstAmount'] as num?)?.toDouble() ?? 0.0;
      orderGst += itemGst;
    }
    final orderTotal = orderSubtotal + orderGst;

    final pricingUpdate = <String, dynamic>{
      'subtotal': orderSubtotal,
      'totalAmount': orderTotal,
    };

    if (orderGst > 0) {
      pricingUpdate['totalGst'] = orderGst;
    }

    final hasAvailableTrips = _hasAvailableTrips(items);
    final currentStatus = (data['status'] as String?)?.trim();
    final statusAllowsUpdate = currentStatus == null ||
        currentStatus == 'pending' ||
        currentStatus == 'fully_scheduled';
    final nextStatus = statusAllowsUpdate
        ? (hasAvailableTrips ? 'pending' : 'fully_scheduled')
        : currentStatus;

    await orderRef.update({
      'items': items,
      'pricing': pricingUpdate,
      'hasAvailableTrips': hasAvailableTrips,
      if (statusAllowsUpdate) 'status': nextStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteOrder(String orderId) async {
    await _ordersRef().doc(orderId).delete();
  }

  String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  bool _hasAvailableTrips(List<dynamic> items) {
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>?;
      if (itemMap == null) continue;
      final estimatedTrips = itemMap['estimatedTrips'] as int? ?? 0;
      final scheduledTrips = itemMap['scheduledTrips'] as int? ?? 0;
      if (estimatedTrips > scheduledTrips) {
        return true;
      }
    }
    return false;
  }
}
