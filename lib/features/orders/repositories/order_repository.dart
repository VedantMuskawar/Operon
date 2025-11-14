import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../../core/constants/app_constants.dart';
import '../../../core/models/order.dart';
import '../../../core/repositories/client_repository.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../crm/services/crm_messaging_service.dart';

class OrderRepository {
  OrderRepository({
    FirebaseFirestore? firestore,
    ClientRepository? clientRepository,
    CrmMessagingService? crmMessagingService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _clientRepository = clientRepository ?? ClientRepository(),
        _crmMessagingService =
            crmMessagingService ?? CrmMessagingService();

  final FirebaseFirestore _firestore;
  final ClientRepository _clientRepository;
  final CrmMessagingService _crmMessagingService;

  CollectionReference<Map<String, dynamic>> get _ordersCollection =>
      _firestore.collection(AppConstants.ordersCollection);

  Future<String> createOrder({
    required String organizationId,
    required Order order,
    required String userId,
  }) async {
    try {
      final now = DateTime.now();
      final sanitizedOrderId = order.orderId.trim();

      final productIds =
          order.items.map((item) => item.productId.trim()).where((id) => id.isNotEmpty).toSet();
      final gstRates = await _fetchProductGstRates(
        organizationId: organizationId,
        productIds: productIds,
      );

      final client = await _clientRepository.fetchClientById(
        organizationId: organizationId,
        clientId: order.clientId,
      );
      final fetchedClientName = client?.name;
      final candidateName =
          (fetchedClientName ?? order.clientName)?.trim();
      final clientName =
          (candidateName != null && candidateName.isNotEmpty)
              ? candidateName
              : order.clientName;

      final updatedItems = order.items
          .map(
            (item) => item.copyWith(
              gstRate: gstRates[item.productId] ??
                  (item.gstRate.isNaN ? 0 : item.gstRate),
            ),
          )
          .toList(growable: false);

      final gstApplicable =
          updatedItems.any((item) => (item.gstRate).toDouble() > 0);
      final double gstRate = gstApplicable
          ? updatedItems
              .map((item) => item.gstRate)
              .where((rate) => rate > 0)
              .fold<double>(
                0,
                (previousValue, element) => math.max(previousValue, element),
              )
          : 0;

      final adjustedOrder = order.copyWith(
        organizationId: organizationId,
        orderId: sanitizedOrderId.isNotEmpty ? sanitizedOrderId : order.orderId,
        createdBy: order.createdBy ?? userId,
        updatedBy: userId,
        createdAt: order.createdAt,
        updatedAt: now,
        remainingTrips:
            order.remainingTrips > 0 ? order.remainingTrips : order.trips,
        items: updatedItems,
        gstApplicable: gstApplicable,
        gstRate: gstRate.toDouble(),
        clientName: clientName,
      );

      final docRef =
          await _ordersCollection.add(adjustedOrder.toFirestore());

      if (sanitizedOrderId.isEmpty) {
        await docRef.update({'orderId': docRef.id});
      }

      await _trySendOrderConfirmation(
        organizationId: organizationId,
        order: adjustedOrder,
        documentId: docRef.id,
      );

      return docRef.id;
    } catch (error) {
      throw Exception('Failed to create order: $error');
    }
  }

  Future<Map<String, double>> _fetchProductGstRates({
    required String organizationId,
    required Set<String> productIds,
  }) async {
    if (productIds.isEmpty) {
      return const {};
    }

    final Map<String, double> rates = {};

    await Future.wait(productIds.map((productId) async {
      try {
        final snapshot = await _firestore
            .collection('ORGANIZATIONS')
            .doc(organizationId)
            .collection('PRODUCTS')
            .where('productId', isEqualTo: productId)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final rate = (data['gstRate'] is num)
              ? (data['gstRate'] as num).toDouble()
              : double.tryParse('${data['gstRate']}') ?? 0;
          rates[productId] = rate;
        }
      } catch (error) {
        dev.log(
          'Failed to fetch GST rate for product $productId: $error',
          name: 'OrderRepository',
          level: 900,
        );
      }
    }));

    return rates;
  }

  Future<List<Order>> fetchPendingOrders({
    required String organizationId,
    int limit = 50,
  }) async {
    try {
      final pendingFuture = _ordersCollection
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: OrderStatus.pending)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));

      final confirmedFuture = _ordersCollection
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: OrderStatus.confirmed)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));

      final results = await Future.wait([pendingFuture, confirmedFuture]);

      final orders = results
          .expand((snapshot) => snapshot.docs.map(Order.fromFirestore))
          .where((order) =>
              order.remainingTrips > 0 &&
              (order.status == OrderStatus.pending ||
                  order.status == OrderStatus.confirmed))
          .toList();

      orders.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      if (orders.length > limit) {
        return orders.sublist(0, limit);
      }

      return orders;
    } catch (error) {
      throw Exception('Failed to fetch pending orders: $error');
    }
  }

  Future<void> updateOrder({
    required String organizationId,
    required String orderId,
    required Order order,
  }) async {
    try {
      final docRef = await _findOrderDocument(
        organizationId: organizationId,
        orderId: orderId,
      );

      await docRef.update(order.toFirestore());
    } catch (error) {
      throw Exception('Failed to update order: $error');
    }
  }

  Future<void> deleteOrder({
    required String organizationId,
    required String orderId,
  }) async {
    try {
      final docRef = await _findOrderDocument(
        organizationId: organizationId,
        orderId: orderId,
      );

      await docRef.delete();
    } catch (error) {
      throw Exception('Failed to delete order: $error');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _findOrderDocument({
    required String organizationId,
    required String orderId,
  }) async {
    final snapshot = await _ordersCollection
        .where('orderId', isEqualTo: orderId)
        .where('organizationId', isEqualTo: organizationId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.reference;
    }

    final doc = await _ordersCollection.doc(orderId).get();
    if (!doc.exists) {
      throw Exception('Order not found');
    }

    final order = Order.fromFirestore(doc);
    if (order.organizationId != organizationId) {
      throw Exception('Order does not belong to this organization');
    }

    return doc.reference;
  }

  Future<Order?> fetchOrderById({
    required String organizationId,
    required String orderId,
  }) async {
    try {
      final docRef = await _findOrderDocument(
        organizationId: organizationId,
        orderId: orderId,
      );

      final doc = await docRef.get();
      if (!doc.exists) {
        return null;
      }

      final order = Order.fromFirestore(doc);

      if (order.organizationId != organizationId) {
        return null;
      }
      return order;
    } catch (_) {
      return null;
    }
  }

  Future<void> _trySendOrderConfirmation({
    required String organizationId,
    required Order order,
    required String documentId,
  }) async {
    try {
      final client = await _clientRepository.fetchClientById(
        organizationId: organizationId,
        clientId: order.clientId,
      );

      final phoneNumber = client?.phoneNumber.trim();
      if (phoneNumber == null || phoneNumber.isEmpty) {
        dev.log(
          'Skipping WhatsApp notification: Missing client phone number.',
          name: 'CRM',
        );
        return;
      }

      final templateVariables = {
        'clientname': client?.name ?? 'Customer',
        'ordernumber': order.orderId.trim().isNotEmpty
            ? order.orderId.trim()
            : documentId,
        'orderquantity': order.totalQuantity.toString(),
        'deliverydate': order.lastScheduledAt != null
            ? order.lastScheduledAt!.toIso8601String()
            : 'To be scheduled',
      };

      final result = await _crmMessagingService.sendOrderConfirmation(
        organizationId: organizationId,
        recipientPhoneNumber: phoneNumber,
        templateVariables: templateVariables,
      );

      if (result == null) {
        dev.log(
          'CRM messaging disabled for organization $organizationId.',
          name: 'CRM',
        );
      } else {
        dev.log(
          'WhatsApp confirmation sent for order ${templateVariables['ordernumber']} (messageId: ${result.responseId ?? 'n/a'}).',
          name: 'CRM',
        );
      }
    } on CrmMessagingConfigurationException catch (error) {
      dev.log(
        'WhatsApp configuration incomplete: ${error.message}',
        name: 'CRM',
        level: 900,
      );
    } on WhatsAppSendException catch (error) {
      dev.log(
        'WhatsApp API failure (${error.statusCode ?? 'n/a'}): ${error.body ?? error.message}',
        name: 'CRM',
        level: 1000,
      );
    } catch (error, stackTrace) {
      dev.log(
        'Unexpected error sending WhatsApp message: $error',
        name: 'CRM',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    }
  }
}

