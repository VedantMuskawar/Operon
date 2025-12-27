import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallerIdData {
  CallerIdData({
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.pendingOrders,
    required this.completedOrders,
  });

  final String clientId;
  final String clientName;
  final String clientPhone;
  final List<Map<String, dynamic>> pendingOrders;
  final List<Map<String, dynamic>> completedOrders;
}

class CallerIdService {
  CallerIdService({
    required ClientService clientService,
    required PendingOrdersRepository pendingOrdersRepository,
    required ClientLedgerRepository clientLedgerRepository,
  })  : _clientService = clientService,
        _pendingOrdersRepository = pendingOrdersRepository,
        _clientLedgerRepository = clientLedgerRepository;

  final ClientService _clientService;
  final PendingOrdersRepository _pendingOrdersRepository;
  final ClientLedgerRepository _clientLedgerRepository;

  /// Find client and fetch order data by phone number
  Future<CallerIdData?> getCallerData(
    String phoneNumber,
    String organizationId,
  ) async {
    try {
      // Normalize phone number (remove spaces, dashes, etc.)
      final normalizedNumber = phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      if (normalizedNumber.isEmpty) {
        return null;
      }
      
      // Find client by phone number
      final client = await _clientService.findClientByPhone(normalizedNumber);
      if (client == null) {
        return null;
      }

      // Fetch pending orders for this client
      final allPendingOrders = await _pendingOrdersRepository
          .fetchPendingOrders(organizationId);
      final pendingOrders = allPendingOrders
          .where((order) => order['clientId'] == client.id)
          .toList();

      // Fetch recent completed orders (2-3 orders)
      final completedOrders = await _fetchRecentCompletedOrders(
        organizationId,
        client.id,
        limit: 3,
      );

      return CallerIdData(
        clientId: client.id,
        clientName: client.name,
        clientPhone: normalizedNumber,
        pendingOrders: pendingOrders,
        completedOrders: completedOrders,
      );
    } catch (e) {
      return null;
    }
  }

  /// Fetch recent completed orders from client ledger
  Future<List<Map<String, dynamic>>> _fetchRecentCompletedOrders(
    String organizationId,
    String clientId, {
    int limit = 3,
  }) async {
    try {
      final financialYear = _clientLedgerRepository.getCurrentFinancialYear();
      final ledgerId = '${clientId}_$financialYear';

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('CLIENT_LEDGERS')
          .doc(ledgerId)
          .collection('TRANSACTIONS')
          .where('status', isEqualTo: 'completed')
          .orderBy('transactionDate', descending: true)
          .limit(limit)
          .get();

      return transactionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}

