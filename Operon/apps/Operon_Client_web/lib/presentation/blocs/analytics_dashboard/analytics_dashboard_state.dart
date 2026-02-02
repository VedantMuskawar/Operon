import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart'; // ClientsAnalytics, EmployeesAnalytics, VendorsAnalytics

/// Holds all analytics types for the dashboard.
class AnalyticsDashboardState extends BaseState {
  const AnalyticsDashboardState({
    super.status = ViewStatus.initial,
    this.clients,
    this.employees,
    this.vendors,
    this.transactions,
    this.deliveries,
    this.productions,
    this.tripWages,
    this.loadingTabs = const {},
    super.message,
  });

  final ClientsAnalytics? clients;
  final EmployeesAnalytics? employees;
  final VendorsAnalytics? vendors;
  final TransactionAnalytics? transactions;
  final DeliveriesAnalytics? deliveries;
  final ProductionsAnalytics? productions;
  final TripWagesAnalytics? tripWages;

  /// Tab indices currently loading (0=Transactions, 1=Clients, 2=Employees, etc.)
  final Set<int> loadingTabs;

  bool get hasAny =>
      clients != null ||
      employees != null ||
      vendors != null ||
      transactions != null ||
      deliveries != null ||
      productions != null ||
      tripWages != null;

  bool isLoadingTab(int index) => loadingTabs.contains(index);

  @override
  AnalyticsDashboardState copyWith({
    ViewStatus? status,
    ClientsAnalytics? clients,
    EmployeesAnalytics? employees,
    VendorsAnalytics? vendors,
    TransactionAnalytics? transactions,
    DeliveriesAnalytics? deliveries,
    ProductionsAnalytics? productions,
    TripWagesAnalytics? tripWages,
    Set<int>? loadingTabs,
    String? message,
  }) {
    return AnalyticsDashboardState(
      status: status ?? this.status,
      clients: clients ?? this.clients,
      employees: employees ?? this.employees,
      vendors: vendors ?? this.vendors,
      transactions: transactions ?? this.transactions,
      deliveries: deliveries ?? this.deliveries,
      productions: productions ?? this.productions,
      tripWages: tripWages ?? this.tripWages,
      loadingTabs: loadingTabs ?? this.loadingTabs,
      message: message ?? this.message,
    );
  }
}
