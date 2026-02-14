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
    required VendorsRepository vendorsRepository,
    required String organizationId,
  })  : _transactionsRepository = transactionsRepository,
        _vendorsRepository = vendorsRepository,
        _organizationId = organizationId,
        super(const UnifiedFinancialTransactionsState());

  final TransactionsRepository _transactionsRepository;
  final VendorsRepository _vendorsRepository;
  final String _organizationId;
  Timer? _searchDebounce;
  final Map<String, String> _vendorNameCache = {};
  final Map<String, Map<String, List<Transaction>>> _rangeCache = {};

  String get organizationId => _organizationId;

  String _buildCacheKey(
    String financialYear,
    DateTime startDate,
    DateTime endDate,
  ) {
    return '$financialYear|${startDate.millisecondsSinceEpoch}|${endDate.millisecondsSinceEpoch}';
  }

  /// Load all financial data (transactions, purchases, expenses)
  Future<void> load({
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    try {
      final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();

      // Set default date range to Today to Today if not provided
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      final effectiveStartDate = startDate ?? todayStart;
      final effectiveEndDate = endDate ?? todayEnd;

      final cacheKey = _buildCacheKey(
        fy,
        effectiveStartDate,
        effectiveEndDate,
      );

      if (!forceRefresh && _rangeCache.containsKey(cacheKey)) {
        final cached = _rangeCache[cacheKey]!;
        emit(state.copyWith(
          status: ViewStatus.success,
          transactions: cached['transactions'] ?? const [],
          orders: cached['orders'] ?? const [],
          purchases: cached['purchases'] ?? const [],
          expenses: cached['expenses'] ?? const [],
          financialYear: fy,
          startDate: effectiveStartDate,
          endDate: effectiveEndDate,
          message: null,
        ));
        return;
      }

      emit(state.copyWith(status: ViewStatus.loading, message: null));

      // Load all data in parallel with server-side date filtering
      final data = await _transactionsRepository.getUnifiedFinancialData(
        organizationId: _organizationId,
        financialYear: fy,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
        limit: 50,
      );

      final transactions = data['transactions'] ?? [];
      final orders = data['orders'] ?? [];
      final purchases = data['purchases'] ?? [];
      final expenses = data['expenses'] ?? [];

      // Enrich vendor names with minimal reads
      final enriched = await _enrichWithVendorNames(
        transactions,
        orders,
        purchases,
        expenses,
      );

      _rangeCache[cacheKey] = {
        'transactions': enriched['transactions']!,
        'orders': enriched['orders']!,
        'purchases': enriched['purchases']!,
        'expenses': enriched['expenses']!,
      };

      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: enriched['transactions']!,
        orders: enriched['orders']!,
        purchases: enriched['purchases']!,
        expenses: enriched['expenses']!,
        financialYear: fy,
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load financial data: $e',
      ));
    }
  }

  /// Enrich transactions with vendor names from vendorId (minimal reads)
  Future<Map<String, List<Transaction>>> _enrichWithVendorNames(
    List<Transaction> transactions,
    List<Transaction> orders,
    List<Transaction> purchases,
    List<Transaction> expenses,
  ) async {
    try {
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
    } catch (_) {
      return {
        'transactions': transactions,
        'orders': orders,
        'purchases': purchases,
        'expenses': expenses,
      };
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
      forceRefresh: true,
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
      _rangeCache.clear();
      await refresh();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete transaction: $e',
      ));
    }
  }
}
