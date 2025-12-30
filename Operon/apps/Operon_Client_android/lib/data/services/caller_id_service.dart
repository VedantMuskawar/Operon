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

  /// Fetch recent completed orders from client ledger (from monthly documents)
  Future<List<Map<String, dynamic>>> _fetchRecentCompletedOrders(
    String organizationId,
    String clientId, {
    int limit = 3,
  }) async {
    try {
      final financialYear = _clientLedgerRepository.getCurrentFinancialYear();
      final ledgerId = '${clientId}_$financialYear';

      // Get all monthly transaction documents
      final monthlyDocsSnapshot = await FirebaseFirestore.instance
          .collection('CLIENT_LEDGERS')
          .doc(ledgerId)
          .collection('TRANSACTIONS')
          .get();

      // Flatten transactions from all monthly documents
      final allTransactions = <Map<String, dynamic>>[];
      
      for (final monthlyDoc in monthlyDocsSnapshot.docs) {
        final monthlyData = monthlyDoc.data();
        final transactions = monthlyData['transactions'] as List<dynamic>?;
        
        if (transactions != null) {
          for (final tx in transactions) {
            if (tx is Map<String, dynamic>) {
              // Filter by category if needed (e.g., clientCredit for order credits)
              // Since status field is removed, we'll include all transactions
              allTransactions.add(tx);
            }
          }
        }
      }

      // Sort by transactionDate descending (most recent first)
      allTransactions.sort((a, b) {
        final dateA = _getTransactionDate(a);
        final dateB = _getTransactionDate(b);
        return dateB.compareTo(dateA); // Descending order
      });

      // Return only the requested limit
      return allTransactions.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
  
  /// Helper to extract transaction date from transaction map
  DateTime _getTransactionDate(Map<String, dynamic> transaction) {
    final transactionDate = transaction['transactionDate'];
    if (transactionDate is Timestamp) {
      return transactionDate.toDate();
    } else if (transactionDate is DateTime) {
      return transactionDate;
    }
    // Fallback to createdAt if transactionDate is missing
    final createdAt = transaction['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    } else if (createdAt is DateTime) {
      return createdAt;
    }
    return DateTime.now(); // Default fallback
  }
}

