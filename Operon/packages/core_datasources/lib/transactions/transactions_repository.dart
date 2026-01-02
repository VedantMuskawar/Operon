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
}

