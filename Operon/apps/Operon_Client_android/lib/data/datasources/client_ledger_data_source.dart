import 'package:cloud_firestore/cloud_firestore.dart';

class ClientLedgerDataSource {
  ClientLedgerDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'CLIENT_LEDGERS';

  /// Calculate current financial year
  /// Financial year starts in April (month 3, 0-indexed)
  String getCurrentFinancialYear() {
    final now = DateTime.now();
    final month = now.month; // 1-based
    final year = now.year;
    
    // FY starts in April (month 4)
    final fyStartYear = month >= 4 ? year : year - 1;
    final fyEndYear = fyStartYear + 1;
    
    // Format: FY2425 (for 2024-2025)
    final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
    final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
    
    return 'FY$startStr$endStr';
  }

  /// Get ledger ID for a client and financial year
  String _getLedgerId(String clientId, String financialYear) {
    return '${clientId}_$financialYear';
  }

  /// Watch client ledger for current financial year
  Stream<Map<String, dynamic>?> watchClientLedger(
    String organizationId,
    String clientId,
  ) {
    final financialYear = getCurrentFinancialYear();
    final ledgerId = _getLedgerId(clientId, financialYear);
    
    return _firestore
        .collection(_collection)
        .doc(ledgerId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data()!;
      return {
        'id': snapshot.id,
        ...data,
      };
    });
  }

  /// Fetch client ledger for current financial year
  Future<Map<String, dynamic>?> fetchClientLedger(
    String organizationId,
    String clientId,
  ) async {
    final financialYear = getCurrentFinancialYear();
    final ledgerId = _getLedgerId(clientId, financialYear);
    
    final doc = await _firestore.collection(_collection).doc(ledgerId).get();
    
    if (!doc.exists) {
      return null;
    }
    
    final data = doc.data()!;
    return {
      'id': doc.id,
      ...data,
    };
  }

  /// Watch last N transactions from ledger subcollection
  Stream<List<Map<String, dynamic>>> watchRecentTransactions(
    String organizationId,
    String clientId,
    int limit,
  ) {
    final financialYear = getCurrentFinancialYear();
    final ledgerId = _getLedgerId(clientId, financialYear);
    
    return _firestore
        .collection(_collection)
        .doc(ledgerId)
        .collection('TRANSACTIONS')
        .orderBy('transactionDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }
}

