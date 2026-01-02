import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_models/core_models.dart';

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

      final snapshot = await query.get();
      
      final transactions = snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson(doc.data(), doc.id);
            } catch (e) {
              // Skip invalid transactions instead of failing
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
      
      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get vendor payment expenses (debit transactions on vendorLedger)
  Future<List<Transaction>> getVendorExpenses({
    required String organizationId,
    String? financialYear,
    String? vendorId,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.vendorLedger.name)
          .where('category', isEqualTo: TransactionCategory.vendorPayment.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      if (vendorId != null) {
        query = query.where('vendorId', isEqualTo: vendorId);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get employee salary debit expenses (debit transactions on employeeLedger)
  Future<List<Transaction>> getEmployeeExpenses({
    required String organizationId,
    String? financialYear,
    String? employeeId,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.employeeLedger.name)
          .where('category', isEqualTo: TransactionCategory.salaryDebit.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      if (employeeId != null) {
        query = query.where('employeeId', isEqualTo: employeeId);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get general expenses (debit transactions on organizationLedger)
  Future<List<Transaction>> getGeneralExpenses({
    required String organizationId,
    String? financialYear,
    String? subCategoryId,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.organizationLedger.name)
          .where('category', isEqualTo: TransactionCategory.generalExpense.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      var transactions = snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();

      // Filter by sub-category if provided (stored in metadata)
      if (subCategoryId != null) {
        transactions = transactions.where((tx) {
          final metadata = tx.metadata;
          if (metadata == null) return false;
          return metadata['subCategoryId'] == subCategoryId;
        }).toList();
      }

      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  /// Get expenses by sub-category ID
  Future<List<Transaction>> getExpensesBySubCategory({
    required String organizationId,
    required String subCategoryId,
    String? financialYear,
    int? limit,
  }) async {
    return getGeneralExpenses(
      organizationId: organizationId,
      financialYear: financialYear,
      subCategoryId: subCategoryId,
      limit: limit,
    );
  }

  /// Get all expenses (vendor payments + salary debits + general expenses)
  Future<List<Transaction>> getAllExpenses({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      // Get all three types of expenses
      final vendorExpenses = await getVendorExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      final employeeExpenses = await getEmployeeExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      final generalExpenses = await getGeneralExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      // Combine and sort by date
      final allExpenses = [
        ...vendorExpenses,
        ...employeeExpenses,
        ...generalExpenses,
      ];

      allExpenses.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate); // Descending order
      });

      if (limit != null && allExpenses.length > limit) {
        return allExpenses.take(limit).toList();
      }

      return allExpenses;
    } catch (e) {
      rethrow;
    }
  }
}

