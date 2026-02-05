import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
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

  /// Start real-time listener for cash ledger data. Call once when page is shown.
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

    // Group order transactions by DM number
    final groupedOrderTransactions = _groupTransactionsByDmNumber(enriched['orderTransactions']!);

    emit(state.copyWith(
      status: ViewStatus.success,
      orderTransactions: groupedOrderTransactions,
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

  void setDateRange(DateTime? startDate, DateTime? endDate) {
    final today = DateTime.now();
    final start = startDate ?? state.startDate ?? DateTime(today.year, today.month, today.day);
    final end = endDate ?? state.endDate ?? DateTime(today.year, today.month, today.day, 23, 59, 59);
    emit(state.copyWith(startDate: start, endDate: end));
    _applyFilterAndEmit();
  }

  Future<void> refresh() async {
    _applyFilterAndEmit();
  }

  /// Update verification status (admin-only in UI). Stream will update UI.
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

  /// Delete a transaction (only when not verified). Stream will update UI.
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

  /// Extract DM number from transaction metadata or return null
  int? _getDmNumber(Transaction tx) {
    final dmNumber = tx.metadata?['dmNumber'];
    if (dmNumber == null) return null;
    if (dmNumber is int) return dmNumber;
    if (dmNumber is num) return dmNumber.toInt();
    return null;
  }

  /// Group transactions by DM number and create cumulative transaction rows
  List<Transaction> _groupTransactionsByDmNumber(List<Transaction> transactions) {
    // Separate transactions with DM numbers and without
    final withDmNumber = <int, List<Transaction>>{};
    final withoutDmNumber = <Transaction>[];

    for (final tx in transactions) {
      final dmNumber = _getDmNumber(tx);
      if (dmNumber != null) {
        withDmNumber.putIfAbsent(dmNumber, () => []).add(tx);
      } else {
        withoutDmNumber.add(tx);
      }
    }

    final result = <Transaction>[];

    // Process grouped transactions (by DM number)
    for (final entry in withDmNumber.entries) {
      final dmNumber = entry.key;
      final group = entry.value;
      
      if (group.length == 1) {
        // Single transaction, add as-is
        result.add(group.first);
      } else {
        // Multiple transactions with same DM number - create cumulative transaction
        final cumulativeTx = _createCumulativeTransaction(group, dmNumber);
        result.add(cumulativeTx);
      }
    }

    // Add transactions without DM numbers as-is
    result.addAll(withoutDmNumber);

    return result;
  }

  /// Create a cumulative transaction from multiple transactions with the same DM number
  Transaction _createCumulativeTransaction(List<Transaction> group, int dmNumber) {
    // Use the first transaction as base (for most fields)
    final baseTx = group.first;
    
    // Calculate cumulative amounts
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    DateTime? earliestDate;
    DateTime? latestDate;
    final Set<String> transactionIds = {};
    
    // Collect payment accounts for credit and debit transactions separately
    // Store both name and amount per payment account
    final creditPaymentAccounts = <String, Map<String, dynamic>>{}; // Map of id -> {name, amount}
    final debitPaymentAccounts = <String, Map<String, dynamic>>{}; // Map of id -> {name, amount}
    
    for (final tx in group) {
      if (tx.type == TransactionType.credit) {
        totalCredit += tx.amount;
        // Store payment account info with amount for credit transactions
        final accountId = tx.paymentAccountId ?? '';
        final accountName = tx.paymentAccountName ?? accountId;
        if (accountId.isNotEmpty || accountName.isNotEmpty) {
          final key = accountId.isNotEmpty ? accountId : accountName;
          final existing = creditPaymentAccounts[key];
          final currentAmount = existing?['amount'] as double? ?? 0.0;
          creditPaymentAccounts[key] = {
            'name': accountName.isNotEmpty ? accountName : accountId,
            'amount': currentAmount + tx.amount,
          };
        }
      } else {
        totalDebit += tx.amount;
        // Store payment account info with amount for debit transactions
        final accountId = tx.paymentAccountId ?? '';
        final accountName = tx.paymentAccountName ?? accountId;
        if (accountId.isNotEmpty || accountName.isNotEmpty) {
          final key = accountId.isNotEmpty ? accountId : accountName;
          final existing = debitPaymentAccounts[key];
          final currentAmount = existing?['amount'] as double? ?? 0.0;
          debitPaymentAccounts[key] = {
            'name': accountName.isNotEmpty ? accountName : accountId,
            'amount': currentAmount + tx.amount,
          };
        }
      }
      
      transactionIds.add(tx.id);
      
      final txDate = tx.createdAt;
      if (txDate != null) {
        if (earliestDate == null || txDate.isBefore(earliestDate)) {
          earliestDate = txDate;
        }
        if (latestDate == null || txDate.isAfter(latestDate)) {
          latestDate = txDate;
        }
      }
    }

    // Determine transaction type based on net amount (for display purposes)
    final netAmount = totalCredit - totalDebit;
    final transactionType = netAmount >= 0 ? TransactionType.credit : TransactionType.debit;
    final finalAmount = netAmount.abs();

    // Create metadata with DM number, cumulative amounts, and grouped transaction IDs
    final metadata = Map<String, dynamic>.from(baseTx.metadata ?? {});
    metadata['dmNumber'] = dmNumber;
    metadata['groupedTransactionIds'] = transactionIds.toList();
    metadata['transactionCount'] = group.length;
    metadata['cumulativeCredit'] = totalCredit;
    metadata['cumulativeDebit'] = totalDebit;
    
    // Store payment account information with amounts for grouped transactions
    if (creditPaymentAccounts.isNotEmpty) {
      metadata['creditPaymentAccounts'] = creditPaymentAccounts.values.map((acc) => {
        'name': acc['name'] as String,
        'amount': acc['amount'] as double,
      }).toList();
    }
    if (debitPaymentAccounts.isNotEmpty) {
      metadata['debitPaymentAccounts'] = debitPaymentAccounts.values.map((acc) => {
        'name': acc['name'] as String,
        'amount': acc['amount'] as double,
      }).toList();
    }
    
    if (earliestDate != null) {
      metadata['earliestDate'] = earliestDate.toIso8601String();
    }
    if (latestDate != null) {
      metadata['latestDate'] = latestDate.toIso8601String();
    }

    // Create cumulative transaction
    // Store net amount in amount field, but metadata has separate credit/debit
    return baseTx.copyWith(
      id: 'grouped_${dmNumber}_${transactionIds.join('_')}',
      amount: finalAmount,
      type: transactionType,
      createdAt: earliestDate ?? baseTx.createdAt,
      updatedAt: latestDate ?? baseTx.updatedAt,
      metadata: metadata,
      description: baseTx.description != null 
          ? '${baseTx.description} (${group.length} transactions)'
          : 'DM-$dmNumber (${group.length} transactions)',
    );
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
        debugPrint('[CashLedgerCubit] Enrich error: $e');
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
