import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

enum TransactionTabType {
  transactions, // Client payments (income)
  orders,       // Trip payments
  purchases,    // Vendor purchases
  expenses,     // All expenses (vendor payments + salary + general)
}

class UnifiedFinancialTransactionsState extends BaseState {
  const UnifiedFinancialTransactionsState({
    super.status = ViewStatus.initial,
    this.transactions = const [],
    this.orders = const [],
    this.purchases = const [],
    this.expenses = const [],
    this.selectedTab = TransactionTabType.transactions,
    this.searchQuery = '',
    this.startDate,
    this.endDate,
    this.financialYear,
    this.message,
  }) : super(message: message);

  final List<Transaction> transactions;
  final List<Transaction> orders;
  final List<Transaction> purchases;
  final List<Transaction> expenses;
  final TransactionTabType selectedTab;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? financialYear;
  @override
  final String? message;

  List<Transaction> get currentTransactions {
    switch (selectedTab) {
      case TransactionTabType.transactions:
        return transactions;
      case TransactionTabType.orders:
        return orders;
      case TransactionTabType.purchases:
        return purchases;
      case TransactionTabType.expenses:
        return expenses;
    }
  }

  double get totalIncome {
    return transactions.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get totalPurchases {
    return purchases.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get totalExpenses {
    return expenses.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get netBalance {
    return totalIncome - totalPurchases - totalExpenses;
  }

  @override
  UnifiedFinancialTransactionsState copyWith({
    ViewStatus? status,
    List<Transaction>? transactions,
    List<Transaction>? orders,
    List<Transaction>? purchases,
    List<Transaction>? expenses,
    TransactionTabType? selectedTab,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? financialYear,
    String? message,
  }) {
    return UnifiedFinancialTransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      orders: orders ?? this.orders,
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
