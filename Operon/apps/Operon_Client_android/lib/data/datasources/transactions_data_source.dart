import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class TransactionsDataSource {
  TransactionsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactionsRef() {
    return _firestore.collection('TRANSACTIONS');
  }

  /// Create a new transaction
  Future<String> createTransaction(Transaction transaction) async {
    final docRef = _transactionsRef().doc();
    final transactionData = transaction.toJson();
    transactionData['transactionId'] = docRef.id;
    
    await docRef.set(transactionData);
    return docRef.id;
  }

  /// Get transaction by ID
  Future<Transaction?> getTransaction(String transactionId) async {
    final doc = await _transactionsRef().doc(transactionId).get();
    if (!doc.exists) return null;
    return Transaction.fromJson(doc.data()!, doc.id);
  }

  /// Cancel a transaction (deletes it from database)
  Future<void> cancelTransaction({
    required String transactionId,
    String? cancelledBy,
    String? cancellationReason,
  }) async {
    // Delete the transaction document instead of marking as cancelled
    await _transactionsRef().doc(transactionId).delete();
  }

  /// Get transactions for a client in a financial year
  Future<List<Transaction>> getClientTransactions({
    required String organizationId,
    required String clientId,
    required String financialYear,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsRef()
        .where('organizationId', isEqualTo: organizationId)
        .where('clientId', isEqualTo: clientId)
        .where('financialYear', isEqualTo: financialYear)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Transaction.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Get all transactions for an organization
  Future<List<Transaction>> getOrganizationTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      debugPrint('[TransactionsDataSource] Querying transactions for org: $organizationId, FY: $financialYear');
      final snapshot = await query.get();
      debugPrint('[TransactionsDataSource] Query result: ${snapshot.docs.length} documents');
      
      final transactions = snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson(doc.data(), doc.id);
            } catch (e) {
              debugPrint('[TransactionsDataSource] Error parsing transaction ${doc.id}: $e');
              debugPrint('[TransactionsDataSource] Document data: ${doc.data()}');
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
      
      debugPrint('[TransactionsDataSource] Successfully parsed ${transactions.length} transactions');
      return transactions;
    } catch (e, stackTrace) {
      debugPrint('[TransactionsDataSource] Error in getOrganizationTransactions: $e');
      debugPrint('[TransactionsDataSource] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

