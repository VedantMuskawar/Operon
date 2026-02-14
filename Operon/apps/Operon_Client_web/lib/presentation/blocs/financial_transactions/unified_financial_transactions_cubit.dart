import 'dart:async';

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
  Timer? _searchDebounce;
  final Map<String, String> _vendorNameCache = {};

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

      // Load all data in parallel (date filtering is done server-side)
      final data = await _transactionsRepository.getUnifiedFinancialData(
        organizationId: _organizationId,
        financialYear: fy,
        startDate: start,
        endDate: end,
        limit: 50,
      );

      final transactions = data['transactions'] ?? [];
      final orders = data['orders'] ?? [];
      final purchases = data['purchases'] ?? [];
      final expenses = data['expenses'] ?? [];

      // Enrich transactions with vendor names
      final enriched = await _enrichWithVendorNames(
        transactions,
        orders,
        purchases,
        expenses,
      );

      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: enriched['transactions']!,
        orders: enriched['orders']!,
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

  /// Enrich transactions with vendor names from vendorId
  Future<Map<String, List<Transaction>>> _enrichWithVendorNames(
    List<Transaction> transactions,
    List<Transaction> orders,
    List<Transaction> purchases,
    List<Transaction> expenses,
  ) async {
    try {
      // Collect all unique vendor IDs
      final vendorIds = <String>{};
      for (final tx in [...transactions, ...orders, ...purchases, ...expenses]) {
        if (tx.vendorId != null && tx.vendorId!.isNotEmpty) {
          final hasVendorName =
              (tx.metadata?['vendorName'] as String?)?.trim().isNotEmpty == true;
          if (!hasVendorName) {
            vendorIds.add(tx.vendorId!);
          }
        }
      }

      if (vendorIds.isNotEmpty) {
        final missingIds =
            vendorIds.where((id) => !_vendorNameCache.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          final vendors = await _vendorsRepository.fetchVendorsByIds(missingIds);
          for (final vendor in vendors) {
            _vendorNameCache[vendor.id] = vendor.name;
          }
        }
      }

      if (_vendorNameCache.isEmpty) {
        return {
          'transactions': transactions,
          'orders': orders,
          'purchases': purchases,
          'expenses': expenses,
        };
      }

      // Enrich transactions by updating metadata (create new transaction objects with enriched metadata)
      final enrichedTransactions = transactions.map((tx) {
        if (tx.vendorId != null && _vendorNameCache.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = _vendorNameCache[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      final enrichedOrders = orders.map((tx) {
        if (tx.vendorId != null && _vendorNameCache.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = _vendorNameCache[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      final enrichedPurchases = purchases.map((tx) {
        if (tx.vendorId != null && _vendorNameCache.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = _vendorNameCache[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      final enrichedExpenses = expenses.map((tx) {
        if (tx.vendorId != null && _vendorNameCache.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = _vendorNameCache[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }).toList();

      return {
        'transactions': enrichedTransactions,
        'orders': enrichedOrders,
        'purchases': enrichedPurchases,
        'expenses': enrichedExpenses,
      };
    } catch (e) {
      // Silently fail - vendor name enrichment is not critical
      // Transactions will still display with fallback names
      return {
        'transactions': transactions,
        'orders': orders,
        'purchases': purchases,
        'expenses': expenses,
      };
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
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
