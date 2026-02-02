import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'unified_financial_transactions_state.dart';

class UnifiedFinancialTransactionsCubit
    extends Cubit<UnifiedFinancialTransactionsState> {
  UnifiedFinancialTransactionsCubit({
    required TransactionsRepository transactionsRepository,
    required String organizationId,
  })  : _transactionsRepository = transactionsRepository,
        _organizationId = organizationId,
        super(const UnifiedFinancialTransactionsState());

  final TransactionsRepository _transactionsRepository;
  final String _organizationId;
  Timer? _searchDebounce;

  String get organizationId => _organizationId;

  /// Load all financial data (transactions, purchases, expenses)
  Future<void> load({String? financialYear, DateTime? startDate, DateTime? endDate}) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();

      // Load all data in parallel
      final data = await _transactionsRepository.getUnifiedFinancialData(
        organizationId: _organizationId,
        financialYear: fy,
      );

      var transactions = data['transactions'] ?? [];
      var purchases = data['purchases'] ?? [];
      var expenses = data['expenses'] ?? [];

      // Apply date filter if provided
      if (startDate != null || endDate != null) {
        transactions = _filterByDateRange(transactions, startDate, endDate);
        purchases = _filterByDateRange(purchases, startDate, endDate);
        expenses = _filterByDateRange(expenses, startDate, endDate);
      }

      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: transactions,
        purchases: purchases,
        expenses: expenses,
        financialYear: fy,
        startDate: startDate,
        endDate: endDate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load financial data: $e',
      ));
    }
  }

  /// Filter transactions by date range
  List<Transaction> _filterByDateRange(
    List<Transaction> transactions,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) return transactions;

    return transactions.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      final start = startDate ?? DateTime(1970);
      final end = endDate ?? DateTime.now();

      return txDate.isAfter(start.subtract(const Duration(days: 1))) &&
             txDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Select tab (transactions, purchases, expenses)
  void selectTab(TransactionTabType tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  /// Search transactions (debounced 300ms to avoid UI jank on every keystroke)
  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      emit(state.copyWith(searchQuery: query));
    });
  }

  /// Set date range filter
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    load(
      financialYear: state.financialYear,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Refresh data
  Future<void> refresh() async {
    await load(
      financialYear: state.financialYear,
      startDate: state.startDate,
      endDate: state.endDate,
    );
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _transactionsRepository.cancelTransaction(
        transactionId: transactionId,
      );
      await refresh();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete transaction: $e',
      ));
    }
  }
}
