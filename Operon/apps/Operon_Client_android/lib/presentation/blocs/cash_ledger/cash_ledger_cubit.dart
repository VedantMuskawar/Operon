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
          startDate: _getTodayStart(),
          endDate: _getTodayEnd(),
        ));

  static DateTime _getTodayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _getTodayEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

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

    final enrichedOrderTransactions = enriched['orderTransactions']!;
    final enrichedPayments = enriched['payments']!;
    final enrichedPurchases = enriched['purchases']!;
    final enrichedExpenses = enriched['expenses']!;

    // Compute totals
    final totalOrderTransactions = enrichedOrderTransactions.fold(0.0, (sum, tx) => sum + tx.amount);
    // For order transactions, only debit (actual payments) counts as income
    final totalOrderIncome = enrichedOrderTransactions
        .where((tx) => tx.type == TransactionType.debit)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalPayments = enrichedPayments.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalPurchases = enrichedPurchases.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalExpenses = enrichedExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalIncome = totalOrderIncome + totalPayments;
    final totalOutcome = totalPurchases + totalExpenses;
    final netBalance = totalIncome - totalOutcome;

    // Compute allRows (filtered and sorted)
    final allRows = _computeAllRows(
      enrichedOrderTransactions,
      enrichedPayments,
      enrichedPurchases,
      enrichedExpenses,
      state.searchQuery,
    );

    // Compute payment account distribution (single-pass optimization)
    final paymentAccountDistribution = _computePaymentAccountDistribution(
      enrichedOrderTransactions,
      enrichedPayments,
      enrichedPurchases,
      enrichedExpenses,
    );

    // Compute total credit and debit from allRows
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    for (final tx in allRows) {
      if (tx.type == TransactionType.credit) {
        totalCredit += tx.amount;
      } else {
        totalDebit += tx.amount;
      }
    }

    emit(state.copyWith(
      status: ViewStatus.success,
      orderTransactions: enrichedOrderTransactions,
      payments: enrichedPayments,
      purchases: enrichedPurchases,
      expenses: enrichedExpenses,
      allRows: allRows,
      totalOrderTransactions: totalOrderTransactions,
      totalPayments: totalPayments,
      totalPurchases: totalPurchases,
      totalExpenses: totalExpenses,
      totalIncome: totalIncome,
      totalOutcome: totalOutcome,
      netBalance: netBalance,
      paymentAccountDistribution: paymentAccountDistribution,
      totalCredit: totalCredit,
      totalDebit: totalDebit,
    ));
  }

  List<Transaction> _computeAllRows(
    List<Transaction> orderTransactions,
    List<Transaction> payments,
    List<Transaction> purchases,
    List<Transaction> expenses,
    String searchQuery,
  ) {
    // Combine all transaction lists
    final list = <Transaction>[
      ...orderTransactions,
      ...payments,
      ...purchases,
      ...expenses,
    ];

    // Apply search filter if query exists
    final filtered = searchQuery.trim().isEmpty
        ? list
        : () {
            // Cache lowercased query once, outside the loop
            final queryLower = searchQuery.toLowerCase();
            return list.where((tx) {
              final title = _getTransactionTitle(tx).toLowerCase();
              final refNumber = (tx.referenceNumber ?? '').toLowerCase();
              final vendorName = (tx.metadata?['vendorName']?.toString() ?? '').toLowerCase();
              final description = (tx.description ?? '').toLowerCase();
              final clientName = (tx.clientName ?? '').toLowerCase();
              final dmNumber = _getDmNumber(tx);
              final dmNumberStr = dmNumber != null ? 'dm-$dmNumber' : '';

              return title.contains(queryLower) ||
                  refNumber.contains(queryLower) ||
                  vendorName.contains(queryLower) ||
                  description.contains(queryLower) ||
                  clientName.contains(queryLower) ||
                  dmNumberStr.contains(queryLower);
            }).toList();
          }();

    // Group transactions by DM number
    final grouped = _groupTransactionsByDmNumber(filtered);

    // Sort by date descending (newest first)
    grouped.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return grouped;
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

  static String _getTransactionTitle(Transaction tx) {
    switch (tx.category) {
      case TransactionCategory.advance:
        return tx.clientName?.trim().isNotEmpty == true ? tx.clientName! : 'Advance';
      case TransactionCategory.tripPayment:
        return tx.clientName?.trim().isNotEmpty == true ? tx.clientName! : 'Trip Payment';
      case TransactionCategory.clientCredit:
        return tx.clientName?.trim().isNotEmpty == true ? tx.clientName! : 'Pay Later Order';
      case TransactionCategory.clientPayment:
        return tx.clientName?.trim().isNotEmpty == true ? tx.clientName! : 'Payment';
      case TransactionCategory.vendorPurchase:
        return tx.metadata?['vendorName']?.toString() ?? 'Purchase';
      case TransactionCategory.vendorPayment:
        return tx.metadata?['vendorName']?.toString() ?? 'Vendor Payment';
      default:
        return tx.description ?? 'Transaction';
    }
  }

  List<PaymentAccountSummary> _computePaymentAccountDistribution(
    List<Transaction> orderTransactions,
    List<Transaction> payments,
    List<Transaction> purchases,
    List<Transaction> expenses,
  ) {
    final map = <String, PaymentAccountSummary>{};
    
    void add(String? id, String? name, double income, double expense) {
      final key = (id?.trim().isEmpty ?? true) ? (name ?? '') : id!;
      final displayName = name?.trim().isNotEmpty != true ? name! : (id ?? 'Unknown');
      if (!map.containsKey(key)) {
        map[key] = PaymentAccountSummary(displayName: displayName, income: 0, expense: 0);
      }
      final cur = map[key]!;
      map[key] = PaymentAccountSummary(
        displayName: cur.displayName,
        income: cur.income + income,
        expense: cur.expense + expense,
      );
    }

    // Single-pass iteration: process all transactions in one loop
    // For order transactions, only debit (actual payments) counts as income
    for (final t in orderTransactions) {
      if (t.type == TransactionType.debit) {
        add(t.paymentAccountId, t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', t.amount, 0);
      }
      // Credit transactions (clientCredit/PayLater) don't count as income
    }
    for (final t in payments) {
      add(t.paymentAccountId, t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', t.amount, 0);
    }
    for (final t in purchases) {
      add(t.paymentAccountId, t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', 0, t.amount);
    }
    for (final t in expenses) {
      add(t.paymentAccountId, t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', 0, t.amount);
    }

    final list = map.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
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
    // Recompute allRows with new search query
    final allRows = _computeAllRows(
      state.orderTransactions,
      state.payments,
      state.purchases,
      state.expenses,
      query,
    );

    // Recompute total credit and debit from filtered allRows
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    for (final tx in allRows) {
      if (tx.type == TransactionType.credit) {
        totalCredit += tx.amount;
      } else {
        totalDebit += tx.amount;
      }
    }

    emit(state.copyWith(
      searchQuery: query,
      allRows: allRows,
      totalCredit: totalCredit,
      totalDebit: totalDebit,
    ));
  }

  /// Update date range and reload data with new filter
  Future<void> setDateRange(DateTime? startDate, DateTime? endDate) async {
    final today = DateTime.now();
    final start = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : state.startDate ?? DateTime(today.year, today.month, today.day);
    final end = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
        : state.endDate ?? DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    await load(
      startDate: start,
      endDate: end,
    );
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
