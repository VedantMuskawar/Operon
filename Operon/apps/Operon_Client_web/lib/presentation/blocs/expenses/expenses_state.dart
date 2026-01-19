import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/domain/entities/payment_account.dart';

enum ExpenseType {
  vendorPayment,
  salaryDebit,
  generalExpense,
}

class ExpensesState extends BaseState {
  const ExpensesState({
    super.status = ViewStatus.initial,
    this.vendorExpenses = const [],
    this.employeeExpenses = const [],
    this.generalExpenses = const [],
    this.allExpenses = const [],
    this.selectedExpenseType,
    this.searchQuery = '',
    this.selectedSubCategoryId,
    this.vendors = const [],
    this.employees = const [],
    this.subCategories = const [],
    this.paymentAccounts = const [],
    this.message,
  }) : super(message: message);

  final List<Transaction> vendorExpenses;
  final List<Transaction> employeeExpenses;
  final List<Transaction> generalExpenses;
  final List<Transaction> allExpenses;
  final ExpenseType? selectedExpenseType;
  final String searchQuery;
  final String? selectedSubCategoryId;
  final List<Vendor> vendors;
  final List<OrganizationEmployee> employees;
  final List<ExpenseSubCategory> subCategories;
  final List<PaymentAccount> paymentAccounts;
  @override
  final String? message;

  bool get isSearching => searchQuery.isNotEmpty;
  bool get isFiltered => selectedSubCategoryId != null;

  List<Transaction> get currentExpenses {
    switch (selectedExpenseType) {
      case ExpenseType.vendorPayment:
        return vendorExpenses;
      case ExpenseType.salaryDebit:
        return employeeExpenses;
      case ExpenseType.generalExpense:
        return generalExpenses;
      case null:
        return allExpenses;
    }
  }

  double get totalVendorExpenses {
    return vendorExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get totalEmployeeExpenses {
    return employeeExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get totalGeneralExpenses {
    return generalExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  double get totalAllExpenses {
    return allExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  @override
  ExpensesState copyWith({
    ViewStatus? status,
    List<Transaction>? vendorExpenses,
    List<Transaction>? employeeExpenses,
    List<Transaction>? generalExpenses,
    List<Transaction>? allExpenses,
    ExpenseType? selectedExpenseType,
    String? searchQuery,
    String? selectedSubCategoryId,
    List<Vendor>? vendors,
    List<OrganizationEmployee>? employees,
    List<ExpenseSubCategory>? subCategories,
    List<PaymentAccount>? paymentAccounts,
    String? message,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      vendorExpenses: vendorExpenses ?? this.vendorExpenses,
      employeeExpenses: employeeExpenses ?? this.employeeExpenses,
      generalExpenses: generalExpenses ?? this.generalExpenses,
      allExpenses: allExpenses ?? this.allExpenses,
      selectedExpenseType: selectedExpenseType ?? this.selectedExpenseType,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSubCategoryId: selectedSubCategoryId ?? this.selectedSubCategoryId,
      vendors: vendors ?? this.vendors,
      employees: employees ?? this.employees,
      subCategories: subCategories ?? this.subCategories,
      paymentAccounts: paymentAccounts ?? this.paymentAccounts,
      message: message ?? this.message,
    );
  }
}

