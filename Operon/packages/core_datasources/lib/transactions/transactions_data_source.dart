import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_models/core_models.dart';

class TransactionsDataSource {
  TransactionsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactionsRef() {
    return _firestore.collection('TRANSACTIONS');
  }

  static DateTime _endOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  }

  /// Create a new transaction
  Future<String> createTransaction(Transaction transaction) async {
    final docRef = _transactionsRef().doc();
    final transactionData = transaction.toJson();
    transactionData['transactionId'] = docRef.id;

    final metadata = Map<String, dynamic>.from(
      transactionData['metadata'] as Map<String, dynamic>? ?? {},
    );

    void syncName({required String idKey, required String nameKey}) {
      final idValue = transactionData[idKey];
      if (idValue is! String || idValue.trim().isEmpty) return;

      final nameFromData = (transactionData[nameKey] as String?)?.trim();
      final nameFromMetadata = (metadata[nameKey] as String?)?.trim();
      final resolvedName =
          (nameFromData != null && nameFromData.isNotEmpty)
              ? nameFromData
              : (nameFromMetadata != null && nameFromMetadata.isNotEmpty)
                  ? nameFromMetadata
                  : null;
      if (resolvedName == null) return;

      transactionData[nameKey] = resolvedName;
      metadata[nameKey] = resolvedName;
    }

    syncName(idKey: 'clientId', nameKey: 'clientName');
    syncName(idKey: 'vendorId', nameKey: 'vendorName');
    syncName(idKey: 'employeeId', nameKey: 'employeeName');

    if (metadata.isNotEmpty) {
      transactionData['metadata'] = metadata;
    }
    
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

  /// Get all vendor ledger transactions (purchases and payments) for a vendor.
  /// Filter by voucher range or date range in the caller.
  Future<List<Transaction>> getVendorLedgerTransactions({
    required String organizationId,
    required String vendorId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('vendorId', isEqualTo: vendorId)
          .where('ledgerType', isEqualTo: LedgerType.vendorLedger.name)
          .orderBy('createdAt', descending: true);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

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

  /// Get vendor payment expenses (debit transactions on vendorLedger)
  Future<List<Transaction>> getVendorExpenses({
    required String organizationId,
    String? financialYear,
    String? vendorId,
    DateTime? startDate,
    DateTime? endDate,
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

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)));
      }

      query = query.orderBy('createdAt', descending: true);

      final effectiveLimit = limit ?? 50;
      query = query.limit(effectiveLimit);

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
    DateTime? startDate,
    DateTime? endDate,
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

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)));
      }

      query = query.orderBy('createdAt', descending: true);

      final effectiveLimit = limit ?? 50;
      query = query.limit(effectiveLimit);

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
    DateTime? startDate,
    DateTime? endDate,
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

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)));
      }

      query = query.orderBy('createdAt', descending: true);

      final effectiveLimit = limit ?? 50;
      query = query.limit(effectiveLimit);

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
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      // Get all three types of expenses
      final vendorExpenses = await getVendorExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      final employeeExpenses = await getEmployeeExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      final generalExpenses = await getGeneralExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
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

  /// Get order-related transactions (advance + trip payment, clientLedger)
  Future<List<Transaction>> getOrderTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      final advanceQuery = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.clientLedger.name)
          .where('category', isEqualTo: TransactionCategory.advance.name)
          .orderBy('createdAt', descending: true);
      final tripPaymentQuery = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.clientLedger.name)
          .where('category', isEqualTo: TransactionCategory.tripPayment.name)
          .orderBy('createdAt', descending: true);
      final clientCreditQuery = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('ledgerType', isEqualTo: LedgerType.clientLedger.name)
          .where('category', isEqualTo: TransactionCategory.clientCredit.name)
          .orderBy('createdAt', descending: true);

      Query<Map<String, dynamic>> advanceQ = advanceQuery;
      Query<Map<String, dynamic>> tripQ = tripPaymentQuery;
      Query<Map<String, dynamic>> clientCreditQ = clientCreditQuery;
      if (financialYear != null) {
        advanceQ = advanceQuery.where('financialYear', isEqualTo: financialYear);
        tripQ = tripPaymentQuery.where('financialYear', isEqualTo: financialYear);
        clientCreditQ = clientCreditQuery.where('financialYear', isEqualTo: financialYear);
      }
      if (limit != null) {
        advanceQ = advanceQ.limit(limit);
        tripQ = tripQ.limit(limit);
        clientCreditQ = clientCreditQ.limit(limit);
      }

      final results = await Future.wait([advanceQ.get(), tripQ.get(), clientCreditQ.get()]);
      final advanceDocs = results[0].docs;
      final tripDocs = results[1].docs;
      final clientCreditDocs = results[2].docs;
      final list = <Transaction>[
        ...advanceDocs.map((doc) => Transaction.fromJson(doc.data(), doc.id)),
        ...tripDocs.map((doc) => Transaction.fromJson(doc.data(), doc.id)),
        ...clientCreditDocs.map((doc) => Transaction.fromJson(doc.data(), doc.id)),
      ];
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(1970);
        final bDate = b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      if (limit != null && list.length > limit) {
        return list.take(limit).toList();
      }
      return list;
    } catch (e) {
      rethrow;
    }
  }

  /// Update verification status of a transaction
  Future<void> updateVerification({
    required String transactionId,
    required bool verified,
    required String verifiedBy,
  }) async {
    if (transactionId.isEmpty || transactionId.trim().isEmpty) {
      throw ArgumentError('Transaction ID cannot be empty');
    }
    final ref = _transactionsRef().doc(transactionId.trim());
    await ref.update({
      'verified': verified,
      'verifiedBy': verified ? verifiedBy : null,
      'verifiedAt': verified ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Merge metadata into an existing transaction (e.g. cashVoucherPhotoUrl).
  Future<void> updateTransactionMetadata(
    String transactionId,
    Map<String, dynamic> metadataPatch,
  ) async {
    if (transactionId.isEmpty || transactionId.trim().isEmpty) {
      throw ArgumentError('Transaction ID cannot be empty');
    }
    final ref = _transactionsRef().doc(transactionId.trim());
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) {
      throw ArgumentError('Transaction not found: $transactionId');
    }
    final data = doc.data()!;
    final currentMetadata = Map<String, dynamic>.from(
      data['metadata'] as Map<String, dynamic>? ?? {},
    );
    currentMetadata.addAll(metadataPatch);
    await ref.update({
      'metadata': currentMetadata,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all client payment transactions (income)
  Future<List<Transaction>> getClientPayments({
    required String organizationId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _transactionsRef()
          .where('organizationId', isEqualTo: organizationId)
          .where('category', isEqualTo: TransactionCategory.clientPayment.name);

      if (financialYear != null) {
        query = query.where('financialYear', isEqualTo: financialYear);
      }

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)));
      }

      query = query.orderBy('createdAt', descending: true);

      final effectiveLimit = limit ?? 50;
      query = query.limit(effectiveLimit);

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
    DateTime? startDate,
    DateTime? endDate,
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

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(endDate)));
      }

      query = query.orderBy('createdAt', descending: true);

      final effectiveLimit = limit ?? 50;
      query = query.limit(effectiveLimit);

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

  /// Get cash ledger data (order transactions, payments, purchases, expenses)
  /// Returns a map with keys: 'orderTransactions', 'payments', 'purchases', 'expenses'
  Future<Map<String, List<Transaction>>> getCashLedgerData({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) async {
    try {
      final orderTransactions = await getOrderTransactions(
        organizationId: organizationId,
        financialYear: financialYear,
        limit: limit,
      );
      final payments = await getClientPayments(
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
        'orderTransactions': orderTransactions,
        'payments': payments,
        'purchases': purchases,
        'expenses': expenses,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Real-time stream of cash ledger data (order transactions, payments, purchases, expenses).
  /// Emits whenever TRANSACTIONS for the org (and optional financial year) change.
  Stream<Map<String, List<Transaction>>> watchCashLedgerData({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _transactionsRef()
        .where('organizationId', isEqualTo: organizationId);

    if (financialYear != null && financialYear.isNotEmpty) {
      query = query.where('financialYear', isEqualTo: financialYear);
    }
    final effectiveLimit = limit ?? 500;
    query = query.orderBy('createdAt', descending: true).limit(effectiveLimit);

    return query.snapshots().map((snapshot) {
      final orderTransactions = <Transaction>[];
      final payments = <Transaction>[];
      final purchases = <Transaction>[];
      final expenses = <Transaction>[];

      for (final doc in snapshot.docs) {
        try {
          final tx = Transaction.fromJson(doc.data(), doc.id);
          if (tx.ledgerType == LedgerType.clientLedger &&
              (tx.category == TransactionCategory.advance ||
                  tx.category == TransactionCategory.tripPayment ||
                  tx.category == TransactionCategory.clientCredit)) {
            orderTransactions.add(tx);
          } else if (tx.category == TransactionCategory.clientPayment ||
              tx.category == TransactionCategory.refund) {
            payments.add(tx);
          } else if (tx.ledgerType == LedgerType.vendorLedger &&
              tx.category == TransactionCategory.vendorPurchase) {
            purchases.add(tx);
          } else if ((tx.ledgerType == LedgerType.vendorLedger &&
                  tx.category == TransactionCategory.vendorPayment) ||
              (tx.ledgerType == LedgerType.employeeLedger &&
                  tx.category == TransactionCategory.salaryDebit) ||
              (tx.ledgerType == LedgerType.organizationLedger &&
                  tx.category == TransactionCategory.generalExpense)) {
            expenses.add(tx);
          }
        } catch (_) {
          // Skip invalid docs
        }
      }

      return <String, List<Transaction>>{
        'orderTransactions': orderTransactions,
        'payments': payments,
        'purchases': purchases,
        'expenses': expenses,
      };
    });
  }

  /// Get unified financial data (all transactions, purchases, and expenses)
  /// Returns a map with keys: 'transactions', 'purchases', 'expenses'
  Future<Map<String, List<Transaction>>> getUnifiedFinancialData({
    required String organizationId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final effectiveLimit = limit ?? 50;
      final transactions = await getClientPayments(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
        limit: effectiveLimit,
      );

      final purchases = await getVendorPurchases(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
        limit: effectiveLimit,
      );

      final expenses = await getAllExpenses(
        organizationId: organizationId,
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
        limit: effectiveLimit,
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
  /// If [verifiedOnly] is true, only returns purchases with verified == true
  Future<List<Transaction>> fetchUnpaidVendorInvoices({
    required String organizationId,
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
    bool verifiedOnly = false,
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
      var unpaidInvoices = allInvoices.where((invoice) {
        final metadata = invoice.metadata;
        if (metadata == null) {
          // No metadata = no paidStatus = unpaid (backward compatibility)
          return true;
        }
        final paidStatus = metadata['paidStatus'] as String?;
        // Return true if paidStatus is null, 'unpaid', or 'partial'
        return paidStatus != 'paid';
      }).toList();

      if (verifiedOnly) {
        unpaidInvoices = unpaidInvoices.where((invoice) => invoice.verified).toList();
      }

      return unpaidInvoices;
    } catch (e) {
      rethrow;
    }
  }
}

