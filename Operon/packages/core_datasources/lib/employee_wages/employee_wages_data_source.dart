import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_models/core_models.dart'
    show Transaction, LedgerType, TransactionType, TransactionCategory;

class EmployeeWagesDataSource {
  EmployeeWagesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('TRANSACTIONS');

  CollectionReference<Map<String, dynamic>> get _employeeLedgersRef =>
      _firestore.collection('EMPLOYEE_LEDGERS');

  /// Calculate financial year label from a date
  /// Financial year starts in April (month 4)
  /// Format: FY2425 (for April 2024 - March 2025)
  String _getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    // Financial year starts in April (month 4)
    if (month >= 4) {
      final startYear = year % 100;
      final endYear = (year + 1) % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    } else {
      final startYear = (year - 1) % 100;
      final endYear = year % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    }
  }

  /// Create a salary credit transaction
  Future<String> createSalaryTransaction({
    required String organizationId,
    required String employeeId,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final financialYear = _getFinancialYear(paymentDate);
    final docRef = _transactionsRef.doc();
    
    final transaction = Transaction(
      id: docRef.id,
      organizationId: organizationId,
      clientId: '', // Not used for employee ledger
      employeeId: employeeId,
      ledgerType: LedgerType.employeeLedger,
      type: TransactionType.credit,
      category: TransactionCategory.salaryCredit,
      amount: amount,
      createdBy: createdBy,
      createdAt: paymentDate,
      updatedAt: paymentDate,
      financialYear: financialYear,
      paymentAccountId: paymentAccountId,
      paymentAccountType: paymentAccountType,
      referenceNumber: referenceNumber,
      description: description,
      metadata: metadata,
    );
    
    final transactionData = transaction.toJson();
    transactionData['transactionId'] = docRef.id;
    
    await docRef.set(transactionData);
    return docRef.id;
  }

  /// Create a bonus transaction
  Future<String> createBonusTransaction({
    required String organizationId,
    required String employeeId,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? bonusType,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    final financialYear = _getFinancialYear(paymentDate);
    final docRef = _transactionsRef.doc();
    
    final bonusMetadata = <String, dynamic>{
      if (bonusType != null) 'bonusType': bonusType,
      if (metadata != null) ...metadata,
    };
    
    final transaction = Transaction(
      id: docRef.id,
      organizationId: organizationId,
      clientId: '', // Not used for employee ledger
      employeeId: employeeId,
      ledgerType: LedgerType.employeeLedger,
      type: TransactionType.credit,
      category: TransactionCategory.bonus,
      amount: amount,
      createdBy: createdBy,
      createdAt: paymentDate,
      updatedAt: paymentDate,
      financialYear: financialYear,
      paymentAccountId: paymentAccountId,
      paymentAccountType: paymentAccountType,
      referenceNumber: referenceNumber,
      description: description,
      metadata: bonusMetadata.isEmpty ? null : bonusMetadata,
    );
    
    final transactionData = transaction.toJson();
    transactionData['transactionId'] = docRef.id;
    
    await docRef.set(transactionData);
    return docRef.id;
  }

  /// Calculate current financial year
  String getCurrentFinancialYear() {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    
    // FY starts in April (month 4)
    final fyStartYear = month >= 4 ? year : year - 1;
    final fyEndYear = fyStartYear + 1;
    
    final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
    final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
    
    return 'FY$startStr$endStr';
  }

  /// Fetch employee ledger for a financial year
  Future<Map<String, dynamic>?> fetchEmployeeLedger({
    required String employeeId,
    String? financialYear,
  }) async {
    final fy = financialYear ?? getCurrentFinancialYear();
    final ledgerId = '${employeeId}_$fy';
    final doc = await _employeeLedgersRef.doc(ledgerId).get();
    
    if (!doc.exists) return null;
    final data = doc.data()!;
    return {
      'id': doc.id,
      ...data,
    };
  }

  /// Watch employee ledger for current financial year
  Stream<Map<String, dynamic>?> watchEmployeeLedger({
    required String employeeId,
    String? financialYear,
  }) {
    final fy = financialYear ?? getCurrentFinancialYear();
    final ledgerId = '${employeeId}_$fy';
    
    return _employeeLedgersRef
        .doc(ledgerId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data()!;
      return {
        'id': snapshot.id,
        ...data,
      };
    });
  }

  /// Watch recent transactions from employee ledger subcollection (monthly documents)
  Stream<List<Map<String, dynamic>>> watchEmployeeLedgerTransactions({
    required String employeeId,
    String? financialYear,
    int limit = 100,
  }) {
    final fy = financialYear ?? getCurrentFinancialYear();
    final ledgerId = '${employeeId}_$fy';
    
    return _employeeLedgersRef
        .doc(ledgerId)
        .collection('TRANSACTIONS')
        .snapshots()
        .map((snapshot) {
      // Flatten transactions from all monthly documents
      final allTransactions = <Map<String, dynamic>>[];
      
      for (final monthlyDoc in snapshot.docs) {
        final monthlyData = monthlyDoc.data();
        final transactions = monthlyData['transactions'] as List<dynamic>?;
        
        if (transactions != null) {
          for (final tx in transactions) {
            if (tx is Map<String, dynamic>) {
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
    });
  }

  /// Helper to extract transaction date from transaction map
  DateTime _getTransactionDate(Map<String, dynamic> transaction) {
    final transactionDate = transaction['transactionDate'];
    // Check if it's a Firestore Timestamp by trying to call toDate()
    if (transactionDate != null) {
      try {
        return (transactionDate as dynamic).toDate() as DateTime;
      } catch (_) {
        // Not a Timestamp, continue to check if it's DateTime
      }
      if (transactionDate is DateTime) {
        return transactionDate;
      }
    }
    // Fallback to createdAt if transactionDate is missing
    final createdAt = transaction['createdAt'];
    if (createdAt != null) {
      try {
        return (createdAt as dynamic).toDate() as DateTime;
      } catch (_) {
        // Not a Timestamp, continue to check if it's DateTime
      }
      if (createdAt is DateTime) {
        return createdAt;
      }
    }
    return DateTime.now(); // Default fallback
  }

  /// Fetch employee transactions
  Future<List<Transaction>> fetchEmployeeTransactions({
    required String organizationId,
    required String employeeId,
    String? financialYear,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('ledgerType', isEqualTo: 'employeeLedger')
        .where('employeeId', isEqualTo: employeeId);

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

    // Apply date filters if provided
    if (startDate != null || endDate != null) {
      transactions = transactions.where((tx) {
        final txDate = tx.createdAt;
        if (txDate == null) return false;
        if (startDate != null && txDate.isBefore(startDate)) return false;
        if (endDate != null && txDate.isAfter(endDate)) return false;
        return true;
      }).toList();
    }

    return transactions;
  }

  /// Fetch all employee transactions for an organization
  Future<List<Transaction>> fetchOrganizationEmployeeTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
    TransactionCategory? category,
  }) async {
    Query<Map<String, dynamic>> query = _transactionsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('ledgerType', isEqualTo: 'employeeLedger');

    if (financialYear != null) {
      query = query.where('financialYear', isEqualTo: financialYear);
    }

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Transaction.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Check if salary already credited for a month
  /// Note: This is a client-side filter due to Firestore limitations on range queries
  Future<bool> isSalaryCreditedForMonth({
    required String organizationId,
    required String employeeId,
    required int year,
    required int month,
  }) async {
    final financialYear = _getFinancialYear(DateTime(year, month, 1));
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    // Fetch transactions and filter by date on client side
    // (Firestore doesn't support multiple range queries on different fields)
    final snapshot = await _transactionsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('ledgerType', isEqualTo: 'employeeLedger')
        .where('employeeId', isEqualTo: employeeId)
        .where('category', isEqualTo: TransactionCategory.salaryCredit.name)
        .where('financialYear', isEqualTo: financialYear)
        .orderBy('createdAt', descending: true)
        .limit(100) // Reasonable limit for monthly salary checks
        .get();

    // Filter by date range on client side
    final matchingTransactions = snapshot.docs.where((doc) {
      final createdAt = doc.data()['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final txDate = createdAt.toDate();
      return txDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
          txDate.isBefore(endOfMonth.add(const Duration(seconds: 1)));
    });

    return matchingTransactions.isNotEmpty;
  }

  /// Stream employee transactions
  Stream<List<Transaction>> watchEmployeeTransactions({
    required String organizationId,
    required String employeeId,
    String? financialYear,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _transactionsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('ledgerType', isEqualTo: 'employeeLedger')
        .where('employeeId', isEqualTo: employeeId);

    if (financialYear != null) {
      query = query.where('financialYear', isEqualTo: financialYear);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Transaction.fromJson(doc.data(), doc.id))
        .toList());
  }

  /// Stream organization employee transactions
  Stream<List<Transaction>> watchOrganizationEmployeeTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _transactionsRef
        .where('organizationId', isEqualTo: organizationId)
        .where('ledgerType', isEqualTo: 'employeeLedger');

    if (financialYear != null) {
      query = query.where('financialYear', isEqualTo: financialYear);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Transaction.fromJson(doc.data(), doc.id))
        .toList());
  }

  /// Delete a transaction
  /// Note: Deleting the transaction document will trigger Cloud Functions
  /// to automatically update the ledger balances
  Future<void> deleteTransaction(String transactionId) async {
    await _transactionsRef.doc(transactionId).delete();
  }
}

