import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

/// Income and expense totals per payment account.
class PaymentAccountSummary {
  const PaymentAccountSummary({
    required this.displayName,
    required this.income,
    required this.expense,
  });
  final String displayName;
  final double income;
  final double expense;
  double get net => income - expense;
}

enum CashLedgerTabType {
  orderTransactions,
  payments,
  purchases,
  expenses,
}

class CashLedgerState extends BaseState {
  const CashLedgerState({
    super.status = ViewStatus.initial,
    this.orderTransactions = const [],
    this.payments = const [],
    this.purchases = const [],
    this.expenses = const [],
    this.selectedTab = CashLedgerTabType.orderTransactions,
    this.searchQuery = '',
    this.startDate,
    this.endDate,
    this.financialYear,
    this.message,
  }) : super(message: message);

  final List<Transaction> orderTransactions;
  final List<Transaction> payments;
  final List<Transaction> purchases;
  final List<Transaction> expenses;
  final CashLedgerTabType selectedTab;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? financialYear;
  @override
  final String? message;

  List<Transaction> get currentList {
    switch (selectedTab) {
      case CashLedgerTabType.orderTransactions:
        return orderTransactions;
      case CashLedgerTabType.payments:
        return payments;
      case CashLedgerTabType.purchases:
        return purchases;
      case CashLedgerTabType.expenses:
        return expenses;
    }
  }

  /// All transactions in one list, sorted by date (newest first).
  /// Each transaction carries a row type for display (Orders, Payments, Purchases, Expenses).
  List<Transaction> get allRows {
    final list = <Transaction>[
      ...orderTransactions,
      ...payments,
      ...purchases,
      ...expenses,
    ];
    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  double get totalOrderTransactions =>
      orderTransactions.fold(0.0, (sum, tx) => sum + tx.amount);
  // For order transactions, only debit (actual payments) counts as income
  double get totalOrderIncome => orderTransactions
      .where((tx) => tx.type == TransactionType.debit)
      .fold(0.0, (sum, tx) => sum + tx.amount);
  double get totalPayments => payments.fold(0.0, (sum, tx) => sum + tx.amount);
  double get totalPurchases =>
      purchases.fold(0.0, (sum, tx) => sum + tx.amount);
  double get totalExpenses => expenses.fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalIncome => totalOrderIncome + totalPayments;
  double get totalOutcome => totalPurchases + totalExpenses;
  double get netBalance => totalIncome - totalOutcome;

  /// Calculate total credit and debit from all transactions
  double get totalCredit {
    var total = 0.0;
    for (final tx in allRows) {
      // For grouped transactions, always use cumulative credit (even if net is debit)
      final transactionCount = tx.metadata?['transactionCount'] as int?;
      if (transactionCount != null && transactionCount > 1) {
        total += (tx.metadata?['cumulativeCredit'] as num?)?.toDouble() ?? 0.0;
      } else if (tx.type == TransactionType.credit) {
        total += tx.amount;
      }
    }
    return total;
  }

  double get totalDebit {
    var total = 0.0;
    for (final tx in allRows) {
      // For grouped transactions, always use cumulative debit (even if net is credit)
      final transactionCount = tx.metadata?['transactionCount'] as int?;
      if (transactionCount != null && transactionCount > 1) {
        total += (tx.metadata?['cumulativeDebit'] as num?)?.toDouble() ?? 0.0;
      } else if (tx.type == TransactionType.debit) {
        total += tx.amount;
      }
    }
    return total;
  }

  /// Per-account income and expense for display below the table.
  List<PaymentAccountSummary> get paymentAccountDistribution {
    final map = <String, PaymentAccountSummary>{};
    void add(String? id, String? name, double income, double expense) {
      final key = (id?.trim().isEmpty ?? true) ? (name ?? '') : id!;
      final displayName =
          name?.trim().isEmpty != true ? name! : (id ?? 'Unknown');
      if (!map.containsKey(key)) {
        map[key] = PaymentAccountSummary(
            displayName: displayName, income: 0, expense: 0);
      }
      final cur = map[key]!;
      map[key] = PaymentAccountSummary(
        displayName: cur.displayName,
        income: cur.income + income,
        expense: cur.expense + expense,
      );
    }

    // For order transactions, only debit (actual payments) counts as income
    for (final t in orderTransactions) {
      final transactionCount = t.metadata?['transactionCount'] as int?;
      final isGrouped = transactionCount != null && transactionCount > 1;
      if (isGrouped) {
        final debitAccounts = t.metadata?['debitPaymentAccounts'] as List?;
        if (debitAccounts != null) {
          for (final account in debitAccounts) {
            final accountMap = account as Map<String, dynamic>?;
            final name = accountMap?['name']?.toString().trim() ?? 'Unknown';
            final amount = (accountMap?['amount'] as num?)?.toDouble() ?? 0.0;
            if (amount > 0) {
              add(null, name, amount, 0);
            }
          }
        }
      } else if (t.type == TransactionType.debit) {
        add(
            t.paymentAccountId,
            t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown',
            t.amount,
            0);
      }
      // Credit transactions (clientCredit/PayLater) don't count as income
    }
    for (final t in payments) {
      add(t.paymentAccountId,
          t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', t.amount, 0);
    }
    for (final t in purchases) {
      add(t.paymentAccountId,
          t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', 0, t.amount);
    }
    for (final t in expenses) {
      add(t.paymentAccountId,
          t.paymentAccountName ?? t.paymentAccountId ?? 'Unknown', 0, t.amount);
    }
    final list = map.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  @override
  CashLedgerState copyWith({
    ViewStatus? status,
    List<Transaction>? orderTransactions,
    List<Transaction>? payments,
    List<Transaction>? purchases,
    List<Transaction>? expenses,
    CashLedgerTabType? selectedTab,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? financialYear,
    String? message,
  }) {
    return CashLedgerState(
      status: status ?? this.status,
      orderTransactions: orderTransactions ?? this.orderTransactions,
      payments: payments ?? this.payments,
      purchases: purchases ?? this.purchases,
      expenses: expenses ?? this.expenses,
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      financialYear: financialYear ?? this.financialYear,
      message: message ?? this.message,
    );
  }
}
