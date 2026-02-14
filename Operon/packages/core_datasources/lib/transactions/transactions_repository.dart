import 'package:core_models/core_models.dart';
import 'transactions_data_source.dart';

class TransactionsRepository {
  TransactionsRepository({required TransactionsDataSource dataSource})
      : _dataSource = dataSource;

  final TransactionsDataSource _dataSource;

  /// Create a new transaction
  Future<String> createTransaction(Transaction transaction) {
    return _dataSource.createTransaction(transaction);
  }

  /// Get transaction by ID
  Future<Transaction?> getTransaction(String transactionId) {
    return _dataSource.getTransaction(transactionId);
  }

  /// Cancel a transaction
  Future<void> cancelTransaction({
    required String transactionId,
    String? cancelledBy,
    String? cancellationReason,
  }) {
    return _dataSource.cancelTransaction(
      transactionId: transactionId,
      cancelledBy: cancelledBy,
      cancellationReason: cancellationReason,
    );
  }

  /// Get transactions for a client in a financial year
  Future<List<Transaction>> getClientTransactions({
    required String organizationId,
    required String clientId,
    required String financialYear,
    int? limit,
  }) {
    return _dataSource.getClientTransactions(
      organizationId: organizationId,
      clientId: clientId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get all transactions for an organization
  Future<List<Transaction>> getOrganizationTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getOrganizationTransactions(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get all vendor ledger transactions (purchases and payments) for a vendor
  Future<List<Transaction>> getVendorLedgerTransactions({
    required String organizationId,
    required String vendorId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getVendorLedgerTransactions(
      organizationId: organizationId,
      vendorId: vendorId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get fuel vendor purchases (credit transactions on vendorLedger)
  Future<List<Transaction>> getFuelVendorPurchases({
    required String organizationId,
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _dataSource.getFuelVendorPurchases(
      organizationId: organizationId,
      vendorId: vendorId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get vendor payment expenses
  Future<List<Transaction>> getVendorExpenses({
    required String organizationId,
    String? financialYear,
    String? vendorId,
    int? limit,
  }) {
    return _dataSource.getVendorExpenses(
      organizationId: organizationId,
      financialYear: financialYear,
      vendorId: vendorId,
      limit: limit,
    );
  }

  /// Get employee salary debit expenses
  Future<List<Transaction>> getEmployeeExpenses({
    required String organizationId,
    String? financialYear,
    String? employeeId,
    int? limit,
  }) {
    return _dataSource.getEmployeeExpenses(
      organizationId: organizationId,
      financialYear: financialYear,
      employeeId: employeeId,
      limit: limit,
    );
  }

  /// Get general expenses
  Future<List<Transaction>> getGeneralExpenses({
    required String organizationId,
    String? financialYear,
    String? subCategoryId,
    int? limit,
  }) {
    return _dataSource.getGeneralExpenses(
      organizationId: organizationId,
      financialYear: financialYear,
      subCategoryId: subCategoryId,
      limit: limit,
    );
  }

  /// Get expenses by sub-category ID
  Future<List<Transaction>> getExpensesBySubCategory({
    required String organizationId,
    required String subCategoryId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getExpensesBySubCategory(
      organizationId: organizationId,
      subCategoryId: subCategoryId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get all expenses (vendor payments + salary debits + general expenses)
  Future<List<Transaction>> getAllExpenses({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getAllExpenses(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get all client payment transactions (income)
  Future<List<Transaction>> getClientPayments({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getClientPayments(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get all trip payment transactions (orders)
  Future<List<Transaction>> getTripPayments({
    required String organizationId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _dataSource.getTripPayments(
      organizationId: organizationId,
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get all vendor purchases
  Future<List<Transaction>> getVendorPurchases({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getVendorPurchases(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Get order-related transactions (advance + trip payment)
  Future<List<Transaction>> getOrderTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getOrderTransactions(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Update verification status of a transaction
  Future<void> updateVerification({
    required String transactionId,
    required bool verified,
    required String verifiedBy,
  }) {
    return _dataSource.updateVerification(
      transactionId: transactionId,
      verified: verified,
      verifiedBy: verifiedBy,
    );
  }

  /// Merge metadata into an existing transaction (e.g. cashVoucherPhotoUrl).
  Future<void> updateTransactionMetadata(
    String transactionId,
    Map<String, dynamic> metadataPatch,
  ) {
    return _dataSource.updateTransactionMetadata(
      transactionId,
      metadataPatch,
    );
  }

  /// Get cash ledger data (order transactions, payments, purchases, expenses)
  Future<Map<String, List<Transaction>>> getCashLedgerData({
    required String organizationId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.getCashLedgerData(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Real-time stream of cash ledger data. Emits when transactions change.
  Stream<Map<String, List<Transaction>>> watchCashLedgerData({
    required String organizationId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _dataSource.watchCashLedgerData(
      organizationId: organizationId,
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get unpaid vendor purchase invoices (optionally verified only)
  Future<List<Transaction>> fetchUnpaidVendorInvoices({
    required String organizationId,
    required String vendorId,
    DateTime? startDate,
    DateTime? endDate,
    bool verifiedOnly = false,
  }) {
    return _dataSource.fetchUnpaidVendorInvoices(
      organizationId: organizationId,
      vendorId: vendorId,
      startDate: startDate,
      endDate: endDate,
      verifiedOnly: verifiedOnly,
    );
  }

  /// Get unified financial data (payments, orders, purchases, and expenses)
  /// Returns a map with keys: 'transactions', 'orders', 'purchases', 'expenses'
  Future<Map<String, List<Transaction>>> getUnifiedFinancialData({
    required String organizationId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _dataSource.getUnifiedFinancialData(
      organizationId: organizationId,
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }
}

