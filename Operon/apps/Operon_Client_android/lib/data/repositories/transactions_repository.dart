import 'package:dash_mobile/data/datasources/transactions_data_source.dart';
import 'package:dash_mobile/domain/entities/transaction.dart';

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
    required String cancelledBy,
    required String cancellationReason,
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
    TransactionStatus? status,
    int? limit,
  }) {
    return _dataSource.getOrganizationTransactions(
      organizationId: organizationId,
      financialYear: financialYear,
      status: status,
      limit: limit,
    );
  }
}

