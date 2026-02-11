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
    this.allRows = const [],
    this.totalOrderTransactions = 0.0,
    this.totalPayments = 0.0,
    this.totalPurchases = 0.0,
    this.totalExpenses = 0.0,
    this.totalIncome = 0.0,
    this.totalOutcome = 0.0,
    this.netBalance = 0.0,
    this.paymentAccountDistribution = const [],
    this.totalCredit = 0.0,
    this.totalDebit = 0.0,
    this.clientCreditRows = const [],
    this.vendorCreditRows = const [],
    this.employeeCreditRows = const [],
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
  
  // Cached computed values (computed once in cubit)
  final List<Transaction> allRows;
  final double totalOrderTransactions;
  final double totalPayments;
  final double totalPurchases;
  final double totalExpenses;
  final double totalIncome;
  final double totalOutcome;
  final double netBalance;
  final List<PaymentAccountSummary> paymentAccountDistribution;
  final double totalCredit;
  final double totalDebit;
  final List<Transaction> clientCreditRows;
  final List<Transaction> vendorCreditRows;
  final List<Transaction> employeeCreditRows;

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
    List<Transaction>? allRows,
    double? totalOrderTransactions,
    double? totalPayments,
    double? totalPurchases,
    double? totalExpenses,
    double? totalIncome,
    double? totalOutcome,
    double? netBalance,
    List<PaymentAccountSummary>? paymentAccountDistribution,
    double? totalCredit,
    double? totalDebit,
    List<Transaction>? clientCreditRows,
    List<Transaction>? vendorCreditRows,
    List<Transaction>? employeeCreditRows,
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
      allRows: allRows ?? this.allRows,
      totalOrderTransactions: totalOrderTransactions ?? this.totalOrderTransactions,
      totalPayments: totalPayments ?? this.totalPayments,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalIncome: totalIncome ?? this.totalIncome,
      totalOutcome: totalOutcome ?? this.totalOutcome,
      netBalance: netBalance ?? this.netBalance,
      paymentAccountDistribution: paymentAccountDistribution ?? this.paymentAccountDistribution,
      totalCredit: totalCredit ?? this.totalCredit,
      totalDebit: totalDebit ?? this.totalDebit,
      clientCreditRows: clientCreditRows ?? this.clientCreditRows,
      vendorCreditRows: vendorCreditRows ?? this.vendorCreditRows,
      employeeCreditRows: employeeCreditRows ?? this.employeeCreditRows,
    );
  }
}
