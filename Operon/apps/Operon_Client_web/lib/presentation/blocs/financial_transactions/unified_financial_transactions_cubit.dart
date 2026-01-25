import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'unified_financial_transactions_state.dart';

class UnifiedFinancialTransactionsCubit
    extends Cubit<UnifiedFinancialTransactionsState> {
  UnifiedFinancialTransactionsCubit({
    required TransactionsRepository transactionsRepository,
    required VendorsRepository vendorsRepository,
    required String organizationId,
  })  : _transactionsRepository = transactionsRepository,
        _vendorsRepository = vendorsRepository,
        _organizationId = organizationId,
        super(UnifiedFinancialTransactionsState(
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        ));

  final TransactionsRepository _transactionsRepository;
  final VendorsRepository _vendorsRepository;
  final String _organizationId;

  String get organizationId => _organizationId;

  /// Load all financial data (transactions, purchases, expenses)
  Future<void> load({String? financialYear, DateTime? startDate, DateTime? endDate}) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();
      
      // Default to today if no dates provided
      final today = DateTime.now();
      final start = startDate ?? DateTime(today.year, today.month, today.day);
      final end = endDate ?? DateTime(today.year, today.month, today.day, 23, 59, 59);

      // Load all data in parallel
      final data = await _transactionsRepository.getUnifiedFinancialData(
        organizationId: _organizationId,
        financialYear: fy,
      );

      var transactions = data['transactions'] ?? [];
      var purchases = data['purchases'] ?? [];
      var expenses = data['expenses'] ?? [];

      // Always apply date filter
      final filteredTransactions = _filterByDateRange(transactions, start, end);
      final filteredPurchases = _filterByDateRange(purchases, start, end);
      final filteredExpenses = _filterByDateRange(expenses, start, end);

      // Enrich transactions with vendor names
      final enriched = await _enrichWithVendorNames(
        filteredTransactions,
        filteredPurchases,
        filteredExpenses,
      );

      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: enriched['transactions']!,
        purchases: enriched['purchases']!,
        expenses: enriched['expenses']!,
        financialYear: fy,
        startDate: start,
        endDate: end,
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
    DateTime startDate,
    DateTime endDate,
  ) {
    return transactions.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      // Compare only date part (ignore time)
      final txDateOnly = DateTime(txDate.year, txDate.month, txDate.day);
      final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      return (txDateOnly.isAtSameMomentAs(startDateOnly) || txDateOnly.isAfter(startDateOnly)) &&
             (txDateOnly.isAtSameMomentAs(endDateOnly) || txDateOnly.isBefore(endDateOnly));
    }).toList();
  }

  /// Select tab (transactions, purchases, expenses)
  void selectTab(TransactionTabType tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  /// Search transactions
  void search(String query) {
    emit(state.copyWith(searchQuery: query));
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

  /// Enrich transactions with vendor names from vendorId
  Future<Map<String, List<Transaction>>> _enrichWithVendorNames(
    List<Transaction> transactions,
    List<Transaction> purchases,
    List<Transaction> expenses,
  ) async {
    try {
      // Collect all unique vendor IDs
      final vendorIds = <String>{};
      for (final tx in [...transactions, ...purchases, ...expenses]) {
        if (tx.vendorId != null && tx.vendorId!.isNotEmpty) {
          vendorIds.add(tx.vendorId!);
        }
      }

      if (vendorIds.isEmpty) {
        return {
          'transactions': transactions,
          'purchases': purchases,
          'expenses': expenses,
        };
      }

      // Fetch all vendors in one call
      final vendors = await _vendorsRepository.fetchVendors(_organizationId);
      final vendorMap = <String, String>{};
      for (final vendor in vendors) {
        vendorMap[vendor.id] = vendor.name;
      }

      // Enrich transactions by updating metadata (create new transaction objects with enriched metadata)
      final enrichedTransactions = transactions.map((tx) {
        if (tx.vendorId != null && vendorMap.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = vendorMap[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      final enrichedPurchases = purchases.map((tx) {
        if (tx.vendorId != null && vendorMap.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = vendorMap[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      final enrichedExpenses = expenses.map((tx) {
        if (tx.vendorId != null && vendorMap.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = vendorMap[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      return {
        'transactions': enrichedTransactions,
        'purchases': enrichedPurchases,
        'expenses': enrichedExpenses,
      };
    } catch (e) {
      // Silently fail - vendor name enrichment is not critical
      // Transactions will still display with fallback names
      return {
        'transactions': transactions,
        'purchases': purchases,
        'expenses': expenses,
      };
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    // Validate transaction ID
    if (transactionId.isEmpty || transactionId.trim().isEmpty) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Cannot delete transaction: Invalid transaction ID',
      ));
      return;
    }

    try {
      await _transactionsRepository.cancelTransaction(
        transactionId: transactionId.trim(),
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
