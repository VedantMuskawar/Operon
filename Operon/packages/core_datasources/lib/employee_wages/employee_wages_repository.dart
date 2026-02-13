import 'package:core_models/core_models.dart';
import 'employee_wages_data_source.dart';

class EmployeeWagesRepository {
  EmployeeWagesRepository({required EmployeeWagesDataSource dataSource})
      : _dataSource = dataSource;

  final EmployeeWagesDataSource _dataSource;

  /// Create a salary credit transaction
  Future<String> createSalaryTransaction({
    required String organizationId,
    required String employeeId,
    String? employeeName,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return _dataSource.createSalaryTransaction(
      organizationId: organizationId,
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      paymentDate: paymentDate,
      createdBy: createdBy,
      paymentAccountId: paymentAccountId,
      paymentAccountType: paymentAccountType,
      referenceNumber: referenceNumber,
      description: description,
      metadata: metadata,
    );
  }

  /// Create a bonus transaction
  Future<String> createBonusTransaction({
    required String organizationId,
    required String employeeId,
    String? employeeName,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? bonusType,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return _dataSource.createBonusTransaction(
      organizationId: organizationId,
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      paymentDate: paymentDate,
      createdBy: createdBy,
      bonusType: bonusType,
      paymentAccountId: paymentAccountId,
      paymentAccountType: paymentAccountType,
      referenceNumber: referenceNumber,
      description: description,
      metadata: metadata,
    );
  }

  /// Fetch employee ledger for a financial year
  Future<Map<String, dynamic>?> fetchEmployeeLedger({
    required String employeeId,
    String? financialYear,
  }) {
    return _dataSource.fetchEmployeeLedger(
      employeeId: employeeId,
      financialYear: financialYear,
    );
  }

  /// Watch employee ledger for current financial year
  Stream<Map<String, dynamic>?> watchEmployeeLedger({
    required String employeeId,
    String? financialYear,
  }) {
    return _dataSource.watchEmployeeLedger(
      employeeId: employeeId,
      financialYear: financialYear,
    );
  }

  /// Watch recent transactions from employee ledger subcollection
  Stream<List<Map<String, dynamic>>> watchEmployeeLedgerTransactions({
    required String employeeId,
    String? financialYear,
    int limit = 100,
  }) {
    return _dataSource.watchEmployeeLedgerTransactions(
      employeeId: employeeId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Fetch employee transactions
  Future<List<Transaction>> fetchEmployeeTransactions({
    required String organizationId,
    required String employeeId,
    String? financialYear,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _dataSource.fetchEmployeeTransactions(
      organizationId: organizationId,
      employeeId: employeeId,
      financialYear: financialYear,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Fetch all employee transactions for an organization
  Future<List<Transaction>> fetchOrganizationEmployeeTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
    TransactionCategory? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _dataSource.fetchOrganizationEmployeeTransactions(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
      category: category,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Check if salary already credited for a month
  Future<bool> isSalaryCreditedForMonth({
    required String organizationId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    return _dataSource.isSalaryCreditedForMonth(
      organizationId: organizationId,
      employeeId: employeeId,
      year: year,
      month: month,
    );
  }

  /// Check if bonus already credited for a month
  Future<bool> isBonusCreditedForMonth({
    required String organizationId,
    required String employeeId,
    required int year,
    required int month,
  }) {
    return _dataSource.isBonusCreditedForMonth(
      organizationId: organizationId,
      employeeId: employeeId,
      year: year,
      month: month,
    );
  }

  /// Fetch employeeIds that already received a category credit in a month.
  Future<Set<String>> fetchCreditedEmployeeIdsForMonth({
    required String organizationId,
    required TransactionCategory category,
    required int year,
    required int month,
  }) {
    return _dataSource.fetchCreditedEmployeeIdsForMonth(
      organizationId: organizationId,
      category: category,
      year: year,
      month: month,
    );
  }

  /// Stream employee transactions
  Stream<List<Transaction>> watchEmployeeTransactions({
    required String organizationId,
    required String employeeId,
    String? financialYear,
    int? limit,
  }) {
    return _dataSource.watchEmployeeTransactions(
      organizationId: organizationId,
      employeeId: employeeId,
      financialYear: financialYear,
      limit: limit,
    );
  }

  /// Stream organization employee transactions
  Stream<List<Transaction>> watchOrganizationEmployeeTransactions({
    required String organizationId,
    String? financialYear,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _dataSource.watchOrganizationEmployeeTransactions(
      organizationId: organizationId,
      financialYear: financialYear,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Delete a transaction
  /// Note: Deleting the transaction document will trigger Cloud Functions
  /// to automatically update the ledger balances
  Future<void> deleteTransaction(String transactionId) {
    return _dataSource.deleteTransaction(transactionId);
  }

  /// Fetch monthly transaction document from EMPLOYEE_LEDGERS subcollection
  /// Returns the transactions array from the monthly document, or empty list if not found
  Future<List<Map<String, dynamic>>> fetchMonthlyTransactions({
    required String employeeId,
    required String financialYear,
    required String yearMonth,
  }) {
    return _dataSource.fetchMonthlyTransactions(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
    );
  }
}

