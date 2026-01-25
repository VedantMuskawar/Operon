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
    // Validate transaction ID
    if (transactionId.isEmpty || transactionId.trim().isEmpty) {
      throw ArgumentError('Transaction ID cannot be empty');
    }

    final trimmedId = transactionId.trim();
    // Delete the transaction document instead of marking as cancelled
    await _transactionsRef().doc(trimmedId).delete();
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

  /// Get all client payment transactions (income)
  Future<List<Transaction>> getClientPayments({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: TransactionCategory.clientPayment.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson(doc.data(), doc.id);
            } catch (e) {
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all vendor purchases
  Future<List<Transaction>> getVendorPurchases({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.vendorLedger.name)
          .where('category', isEqualTo: TransactionCategory.vendorPurchase.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      query = query.orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson(doc.data(), doc.id);
            } catch (e) {
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get unified financial data (all transactions, purchases, and expenses)
  /// Returns a map with keys: 'transactions', 'purchases', 'expenses'
  Future<Map<String, List<Transaction>>> getUnifiedFinancialData({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      final transactions = await getClientPayments(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      final purchases = await getVendorPurchases(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      final expenses = await getAllExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );

      return {
        'transactions': transactions,
        'purchases': purchases,
        'expenses': expenses,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get unpaid vendor purchase invoices (credit transactions on vendorLedger)
  /// Filters by vendorId, category vendorPurchase, and paidStatus != 'paid'
  Future<List<Transaction>> fetchUnpaidVendorInvoices({
    required String organizationId,
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('vendorId', isEqualTo: vendorId)
          .where('ledgerType', isEqualTo: LedgerType.vendorLedger.name)
          .where('category', isEqualTo: TransactionCategory.vendorPurchase.name)
          .where('type', isEqualTo: TransactionType.credit.name);

      // Filter by date range if provided
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        // Add one day to endDate to include the entire day
        final endDateInclusive = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDateInclusive));
      }

      query = query.orderBy('createdAt', descending: false); // Oldest first for invoice selection

      final snapshot = await query.get();
      
      // Filter by paidStatus in memory (metadata field, can't query directly)
      final allInvoices = snapshot.docs
          .map((doc) {
            try {
              return Transaction.fromJson(doc.data(), doc.id);
            } catch (e) {
              return null;
            }
          })
          .whereType<Transaction>()
          .toList();

      // Filter out fully paid invoices
      final unpaidInvoices = allInvoices.where((invoice) {
        final metadata = invoice.metadata;
        if (metadata == null) {
          // No metadata = no paidStatus = unpaid (backward compatibility)
          return true;
        }
        final paidStatus = metadata['paidStatus'] as String?;
        // Return true if paidStatus is null, 'unpaid', or 'partial'
        return paidStatus != 'paid';
      }).toList();

      return unpaidInvoices;
    } catch (e) {
      rethrow;
    }
  }
}

