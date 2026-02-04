import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'expenses_state.dart';

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit({
    required TransactionsDataSource transactionsDataSource,
    required VendorsRepository vendorsRepository,
    required EmployeesRepository employeesRepository,
    required ExpenseSubCategoriesRepository subCategoriesRepository,
    required PaymentAccountsDataSource paymentAccountsDataSource,
    required String organizationId,
    required String userId,
  })  : _transactionsDataSource = transactionsDataSource,
        _vendorsRepository = vendorsRepository,
        _employeesRepository = employeesRepository,
        _subCategoriesRepository = subCategoriesRepository,
        _paymentAccountsDataSource = paymentAccountsDataSource,
        _organizationId = organizationId,
        _userId = userId,
        super(const ExpensesState());

  final TransactionsDataSource _transactionsDataSource;
  final VendorsRepository _vendorsRepository;
  final EmployeesRepository _employeesRepository;
  final ExpenseSubCategoriesRepository _subCategoriesRepository;
  final PaymentAccountsDataSource _paymentAccountsDataSource;
  final String _organizationId;
  final String _userId;

  String get organizationId => _organizationId;

  /// Load all expenses and related data
  Future<void> load({String? financialYear}) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();

      // Load all expense types in parallel (limit 100 per type for safety)
      final vendorExpenses = await _transactionsDataSource.getVendorExpenses(
        organizationId: _organizationId,
        financialYear: fy,
        limit: 100,
      );

      final employeeExpenses = await _transactionsDataSource.getEmployeeExpenses(
        organizationId: _organizationId,
        financialYear: fy,
        limit: 100,
      );

      final generalExpenses = await _transactionsDataSource.getGeneralExpenses(
        organizationId: _organizationId,
        financialYear: fy,
        limit: 100,
      );

      // Load related data
      final vendors = await _vendorsRepository.fetchVendors(_organizationId);
      final employees = await _employeesRepository.fetchEmployees(_organizationId);
      final subCategories = await _subCategoriesRepository.fetchSubCategories(_organizationId);
      final paymentAccounts = await _paymentAccountsDataSource.fetchAccounts(_organizationId);

      // Combine all expenses
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

      emit(state.copyWith(
        status: ViewStatus.success,
        vendorExpenses: vendorExpenses,
        employeeExpenses: employeeExpenses,
        generalExpenses: generalExpenses,
        allExpenses: allExpenses,
        vendors: vendors,
        employees: employees,
        subCategories: subCategories,
        paymentAccounts: paymentAccounts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load expenses: $e',
      ));
    }
  }

  /// Select expense type (filter view)
  void selectExpenseType(ExpenseType? type) {
    emit(state.copyWith(selectedExpenseType: type));
  }

  /// Search expenses
  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Filter by sub-category (for general expenses)
  void filterBySubCategory(String? subCategoryId) {
    emit(state.copyWith(selectedSubCategoryId: subCategoryId));
  }

  /// Create a vendor payment expense
  Future<void> createVendorPayment({
    required String vendorId,
    required double amount,
    required String paymentAccountId,
    required DateTime date,
    String? description,
    String? referenceNumber,
    List<String>? linkedInvoiceIds,
    String? paymentMode,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final financialYear = FinancialYearUtils.getFinancialYear(date);

      // Build metadata for invoice linking
      Map<String, dynamic>? metadata;
      if (linkedInvoiceIds != null && linkedInvoiceIds.isNotEmpty) {
        metadata = {
          'linkedInvoiceIds': linkedInvoiceIds,
          'paymentMode': paymentMode ?? 'manualSelection',
        };
        if (dateRangeStart != null && dateRangeEnd != null) {
          metadata['dateRange'] = {
            'startDate': dateRangeStart.toIso8601String(),
            'endDate': dateRangeEnd.toIso8601String(),
          };
        }
      }

      final transaction = Transaction(
        id: '', // Will be set by data source
        organizationId: _organizationId,
        clientId: '', // Not needed for vendor payments
        vendorId: vendorId,
        ledgerType: LedgerType.vendorLedger,
        type: TransactionType.debit,
        category: TransactionCategory.vendorPayment,
        amount: amount,
        createdBy: _userId,
        createdAt: date,
        updatedAt: DateTime.now(),
        financialYear: financialYear,
        paymentAccountId: paymentAccountId,
        description: description,
        referenceNumber: referenceNumber,
        metadata: metadata,
      );

      await _transactionsDataSource.createTransaction(transaction);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create vendor payment: $e',
      ));
    }
  }

  /// Create a salary debit expense. Returns the created transaction ID, or null on failure.
  Future<String?> createSalaryDebit({
    required String employeeId,
    required double amount,
    required String paymentAccountId,
    required DateTime date,
    String? description,
    String? referenceNumber,
    String? employeeName,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final financialYear = FinancialYearUtils.getFinancialYear(date);

      final transaction = Transaction(
        id: '', // Will be set by data source
        organizationId: _organizationId,
        clientId: '', // Not needed for salary debits
        employeeId: employeeId,
        ledgerType: LedgerType.employeeLedger,
        type: TransactionType.debit,
        category: TransactionCategory.salaryDebit,
        amount: amount,
        createdBy: _userId,
        createdAt: date,
        updatedAt: DateTime.now(),
        financialYear: financialYear,
        paymentAccountId: paymentAccountId,
        description: description,
        referenceNumber: referenceNumber,
        metadata: employeeName != null && employeeName.isNotEmpty
            ? {'employeeName': employeeName}
            : null,
      );

      final transactionId = await _transactionsDataSource.createTransaction(transaction);
      await load();
      return transactionId;
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create salary payment: $e',
      ));
      return null;
    }
  }

  /// Create a general expense
  Future<void> createGeneralExpense({
    required String subCategoryId,
    required double amount,
    required String paymentAccountId,
    required DateTime date,
    required String description,
    String? referenceNumber,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final financialYear = FinancialYearUtils.getFinancialYear(date);
      final subCategory = state.subCategories.firstWhere((sc) => sc.id == subCategoryId);

      final transaction = Transaction(
        id: '', // Will be set by data source
        organizationId: _organizationId,
        clientId: _organizationId, // Use orgId as placeholder
        ledgerType: LedgerType.organizationLedger,
        type: TransactionType.debit,
        category: TransactionCategory.generalExpense,
        amount: amount,
        createdBy: _userId,
        createdAt: date,
        updatedAt: DateTime.now(),
        financialYear: financialYear,
        paymentAccountId: paymentAccountId,
        description: description,
        referenceNumber: referenceNumber,
        metadata: {
          'expenseCategory': 'general',
          'subCategoryId': subCategoryId,
          'subCategoryName': subCategory.name,
        },
      );

      await _transactionsDataSource.createTransaction(transaction);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create general expense: $e',
      ));
    }
  }

  /// Refresh expenses
  Future<void> refresh() async {
    await load();
  }
}

