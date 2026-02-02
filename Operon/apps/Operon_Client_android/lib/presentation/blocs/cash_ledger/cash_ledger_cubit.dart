import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cash_ledger_state.dart';

class CashLedgerCubit extends Cubit<CashLedgerState> {
  CashLedgerCubit({
    required TransactionsRepository transactionsRepository,
    required VendorsRepository vendorsRepository,
    required String organizationId,
  })  : _transactionsRepository = transactionsRepository,
        _vendorsRepository = vendorsRepository,
        _organizationId = organizationId,
        super(CashLedgerState(
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        ));

  final TransactionsRepository _transactionsRepository;
  final VendorsRepository _vendorsRepository;
  final String _organizationId;
  StreamSubscription<Map<String, List<Transaction>>>? _subscription;
  Map<String, List<Transaction>>? _lastRawData;

  String get organizationId => _organizationId;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  /// Start real-time listener for cash ledger data. Call once when section is shown.
  Future<void> load({
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _subscription?.cancel();
    final fy =
        financialYear ?? state.financialYear ?? FinancialYearUtils.getCurrentFinancialYear();
    final today = DateTime.now();
    final start =
        startDate ?? state.startDate ?? DateTime(today.year, today.month, today.day);
    final end =
        endDate ?? state.endDate ?? DateTime(today.year, today.month, today.day, 23, 59, 59);

    emit(state.copyWith(
      status: ViewStatus.loading,
      message: null,
      financialYear: fy,
      startDate: start,
      endDate: end,
    ));

    _subscription = _transactionsRepository
        .watchCashLedgerData(
          organizationId: _organizationId,
          financialYear: fy,
        )
        .listen(
          (data) {
            _lastRawData = data;
            _applyFilterAndEmit();
          },
          onError: (e) {
            emit(state.copyWith(
              status: ViewStatus.failure,
              message: 'Unable to load cash ledger: $e',
            ));
          },
        );
  }

  Future<void> _applyFilterAndEmit() async {
    if (_lastRawData == null) return;
    final start = state.startDate ?? DateTime.now();
    final end = state.endDate ?? DateTime.now();
    final orderTransactions =
        _filterByDateRange(_lastRawData!['orderTransactions'] ?? [], start, end);
    final payments = _filterByDateRange(_lastRawData!['payments'] ?? [], start, end);
    final purchases = _filterByDateRange(_lastRawData!['purchases'] ?? [], start, end);
    final expenses = _filterByDateRange(_lastRawData!['expenses'] ?? [], start, end);

    final enriched = await _enrichWithVendorNames(
      orderTransactions,
      payments,
      purchases,
      expenses,
    );

    emit(state.copyWith(
      status: ViewStatus.success,
      orderTransactions: enriched['orderTransactions']!,
      payments: enriched['payments']!,
      purchases: enriched['purchases']!,
      expenses: enriched['expenses']!,
    ));
  }

  List<Transaction> _filterByDateRange(
    List<Transaction> list,
    DateTime startDate,
    DateTime endDate,
  ) {
    return list.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      final txDateOnly = DateTime(txDate.year, txDate.month, txDate.day);
      final startOnly =
          DateTime(startDate.year, startDate.month, startDate.day);
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      return (txDateOnly.isAtSameMomentAs(startOnly) ||
              txDateOnly.isAfter(startOnly)) &&
          (txDateOnly.isAtSameMomentAs(endOnly) ||
              txDateOnly.isBefore(endOnly));
    }).toList();
  }

  void selectTab(CashLedgerTabType tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  Future<void> refresh() async {
    _applyFilterAndEmit();
  }

  /// Stream will update UI after verification change.
  Future<void> updateVerification({
    required String transactionId,
    required bool verified,
    required String verifiedBy,
  }) async {
    try {
      await _transactionsRepository.updateVerification(
        transactionId: transactionId,
        verified: verified,
        verifiedBy: verifiedBy,
      );
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update verification: $e',
      ));
    }
  }

  /// Stream will update UI after delete.
  Future<void> deleteTransaction(String transactionId) async {
    if (transactionId.isEmpty || transactionId.trim().isEmpty) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Cannot delete: Invalid transaction ID',
      ));
      return;
    }
    try {
      await _transactionsRepository.cancelTransaction(
        transactionId: transactionId.trim(),
      );
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete transaction: $e',
      ));
    }
  }

  Future<Map<String, List<Transaction>>> _enrichWithVendorNames(
    List<Transaction> orderTransactions,
    List<Transaction> payments,
    List<Transaction> purchases,
    List<Transaction> expenses,
  ) async {
    try {
      final vendorIds = <String>{};
      for (final tx in [
        ...orderTransactions,
        ...payments,
        ...purchases,
        ...expenses,
      ]) {
        if (tx.vendorId != null && tx.vendorId!.isNotEmpty) {
          vendorIds.add(tx.vendorId!);
        }
      }

      if (vendorIds.isEmpty) {
        return {
          'orderTransactions': orderTransactions,
          'payments': payments,
          'purchases': purchases,
          'expenses': expenses,
        };
      }

      final vendors =
          await _vendorsRepository.fetchVendors(_organizationId);
      final vendorMap = <String, String>{};
      for (final vendor in vendors) {
        vendorMap[vendor.id] = vendor.name;
      }

      Transaction enrich(Transaction tx) {
        if (tx.vendorId != null && vendorMap.containsKey(tx.vendorId)) {
          final metadata = Map<String, dynamic>.from(tx.metadata ?? {});
          if (!metadata.containsKey('vendorName')) {
            metadata['vendorName'] = vendorMap[tx.vendorId];
            return tx.copyWith(metadata: metadata);
          }
        }
        return tx;
      }

      return {
        'orderTransactions': orderTransactions.map(enrich).toList(),
        'payments': payments.map(enrich).toList(),
        'purchases': purchases.map(enrich).toList(),
        'expenses': expenses.map(enrich).toList(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('[CashLedgerCubit] Enrich error: $e');
      }
      return {
        'orderTransactions': orderTransactions,
        'payments': payments,
        'purchases': purchases,
        'expenses': expenses,
      };
    }
  }
}
