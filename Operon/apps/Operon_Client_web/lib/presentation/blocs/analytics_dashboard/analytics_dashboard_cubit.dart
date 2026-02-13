import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'analytics_dashboard_state.dart';

/// Tab indices: 0=Transactions, 1=Clients, 2=Employees, 3=Vendors, 4=Deliveries, 5=Productions, 6=Trip Wages, 7=Fuel
const _tabTransactions = 0;
const _tabClients = 1;
const _tabEmployees = 2;
const _tabVendors = 3;
const _tabDeliveries = 4;
const _tabProductions = 5;
const _tabTripWages = 6;
const _tabFuel = 7;

/// Cached analytics for a given (orgId, fy). Used to avoid Firestore reads when switching months within same FY.
class _CachedData {
  ClientsAnalytics? clients;
  TransactionAnalytics? transactions;
  EmployeesAnalytics? employees;
  VendorsAnalytics? vendors;
  DeliveriesAnalytics? deliveries;
  ProductionsAnalytics? productions;
  TripWagesAnalytics? tripWages;
  FuelAnalytics? fuel;
}

class AnalyticsDashboardCubit extends Cubit<AnalyticsDashboardState> {
  AnalyticsDashboardCubit({
    required AnalyticsRepository analyticsRepository,
  })  : _repo = analyticsRepository,
        super(const AnalyticsDashboardState());

  final AnalyticsRepository _repo;

  String _cacheKey(String orgId, String fy) => '${orgId}_$fy';

  _CachedData _getOrCreateCache(String orgId, String fy) {
    final key = _cacheKey(orgId, fy);
    return _cache.putIfAbsent(key, () => _CachedData());
  }

  final Map<String, _CachedData> _cache = {};

  /// Clear cache for a specific org and financial year, or all cache if orgId is null
  void clearCache({String? orgId, String? financialYear}) {
    if (orgId != null && financialYear != null) {
      _cache.remove(_cacheKey(orgId, financialYear));
    } else if (orgId != null) {
      // Clear all cache entries for this org
      _cache.removeWhere((key, value) => key.startsWith('${orgId}_'));
    } else {
      // Clear all cache
      _cache.clear();
    }
  }

  /// Load transactions and clients only (initial load). Uses cache when same FY.
  /// Set [forceReload] to true to bypass cache and force fresh data fetch.
  Future<void> loadInitial({
    required String orgId,
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    bool forceReload = false,
  }) async {
    final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();
    if (orgId.isEmpty) {
      emit(state.copyWith(status: ViewStatus.success, loadingTabs: {}));
      return;
    }

    final cached = forceReload ? null : _cache[_cacheKey(orgId, fy)];
    final hasTransactions = cached?.transactions != null;
    final hasClients = cached?.clients != null;

    if (!forceReload && hasTransactions && hasClients) {
      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: cached!.transactions,
        clients: cached.clients,
        loadingTabs: {},
        message: null,
      ));
      return;
    }

    emit(state.copyWith(
      status: ViewStatus.loading,
      loadingTabs: {...state.loadingTabs, _tabTransactions, _tabClients},
      message: null,
    ));

    try {
      final results = await Future.wait([
        hasTransactions ? Future.value(cached!.transactions) : _repo.fetchTransactionAnalytics(
          orgId,
          financialYear: fy,
          startDate: startDate,
          endDate: endDate,
        ),
        hasClients ? Future.value(cached!.clients) : _repo.fetchClientsAnalytics(
          organizationId: orgId,
          financialYear: fy,
          startDate: startDate,
          endDate: endDate,
        ),
      ]);

      final transactions = results[0] as TransactionAnalytics?;
      final clients = results[1] as ClientsAnalytics?;

      if (kDebugMode) {
        debugPrint('[AnalyticsDashboard] loadInitial: orgId=$orgId fy=$fy');
        if (transactions != null) {
          debugPrint('[AnalyticsDashboard] transactions: totalIncome=${transactions.totalIncome} totalReceivables=${transactions.totalReceivables} '
              'incomeMonthlyKeys=${transactions.incomeMonthly.keys.length} incomeDailyKeys=${transactions.incomeDaily.keys.length}');
        } else {
          debugPrint('[AnalyticsDashboard] transactions: null');
        }
        if (clients != null) {
          debugPrint('[AnalyticsDashboard] clients: totalActive=${clients.totalActiveClients} onboardingMonthlyKeys=${clients.onboardingMonthly.keys.length}');
        } else {
          debugPrint('[AnalyticsDashboard] clients: null');
        }
      }

      final c = _getOrCreateCache(orgId, fy);
      if (transactions != null) c.transactions = transactions;
      if (clients != null) c.clients = clients;

      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: transactions,
        clients: clients,
        loadingTabs: state.loadingTabs.difference({_tabTransactions, _tabClients}),
        message: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        loadingTabs: state.loadingTabs.difference({_tabTransactions, _tabClients}),
        message: e.toString(),
      ));
    }
  }

  /// Load analytics for a specific tab on-demand. Uses cache when available.
  /// For Productions tab (5), also loads Deliveries so the overlay can be shown.
  /// Set [forceReload] to true to bypass cache and force fresh data fetch.
  Future<void> loadTabData({
    required String orgId,
    required String financialYear,
    required int tabIndex,
    DateTime? startDate,
    DateTime? endDate,
    bool forceReload = false,
  }) async {
    if (orgId.isEmpty) return;

    final fy = financialYear;
    final cached = forceReload ? null : _cache[_cacheKey(orgId, fy)];

    dynamic existing;
    if (!forceReload) {
      switch (tabIndex) {
        case _tabTransactions:
          existing = cached?.transactions;
          break;
        case _tabClients:
          existing = cached?.clients;
          break;
        case _tabEmployees:
          existing = cached?.employees;
          break;
        case _tabVendors:
          existing = cached?.vendors;
          break;
        case _tabDeliveries:
          existing = cached?.deliveries;
          break;
        case _tabProductions:
          existing = cached?.productions;
          break;
        case _tabTripWages:
          existing = cached?.tripWages;
          break;
        case _tabFuel:
          existing = cached?.fuel;
          break;
        default:
          return;
      }

      if (existing != null) {
        _emitTabData(tabIndex, existing, null);
        return;
      }
    }

    final loadingTabs = {...state.loadingTabs, tabIndex};
    if (tabIndex == _tabProductions) {
      loadingTabs.add(_tabDeliveries);
    }
    emit(state.copyWith(loadingTabs: loadingTabs));

    try {
      switch (tabIndex) {
        case _tabTransactions:
          final r = await _repo.fetchTransactionAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          if (kDebugMode && r != null) {
            debugPrint('[AnalyticsDashboard] loadTabData(Transactions): totalIncome=${r.totalIncome} incomeMonthly=${r.incomeMonthly.keys.length} incomeDaily=${r.incomeDaily.keys.length}');
          }
          _getOrCreateCache(orgId, fy).transactions = r;
          _emitTabData(_tabTransactions, r, loadingTabs);
          break;
        case _tabClients:
          final r = await _repo.fetchClientsAnalytics(
            organizationId: orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          if (kDebugMode && r != null) {
            debugPrint('[AnalyticsDashboard] loadTabData(Clients): totalActive=${r.totalActiveClients} onboardingMonthly=${r.onboardingMonthly.keys.length}');
          }
          _getOrCreateCache(orgId, fy).clients = r;
          _emitTabData(_tabClients, r, loadingTabs);
          break;
        case _tabEmployees:
          final r = await _repo.fetchEmployeesAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          _getOrCreateCache(orgId, fy).employees = r;
          _emitTabData(_tabEmployees, r, loadingTabs);
          break;
        case _tabVendors:
          final r = await _repo.fetchVendorsAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          _getOrCreateCache(orgId, fy).vendors = r;
          _emitTabData(_tabVendors, r, loadingTabs);
          break;
        case _tabDeliveries:
          final r = await _repo.fetchDeliveriesAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          _getOrCreateCache(orgId, fy).deliveries = r;
          _emitTabData(_tabDeliveries, r, loadingTabs);
          break;
        case _tabProductions:
          final results = await Future.wait([
            _repo.fetchProductionsAnalytics(
              orgId,
              financialYear: fy,
              startDate: startDate,
              endDate: endDate,
            ),
            cached?.deliveries != null ? Future.value(cached!.deliveries) : _repo.fetchDeliveriesAnalytics(
              orgId,
              financialYear: fy,
              startDate: startDate,
              endDate: endDate,
            ),
          ]);
          final prod = results[0] as ProductionsAnalytics?;
          final del = results[1] as DeliveriesAnalytics?;
          _getOrCreateCache(orgId, fy).productions = prod;
          if (del != null) _getOrCreateCache(orgId, fy).deliveries = del;
          final newLoading = loadingTabs.difference({_tabProductions, _tabDeliveries});
          emit(state.copyWith(
            productions: prod,
            deliveries: del ?? state.deliveries,
            loadingTabs: newLoading,
          ));
          break;
        case _tabTripWages:
          final r = await _repo.fetchTripWagesAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          _getOrCreateCache(orgId, fy).tripWages = r;
          _emitTabData(_tabTripWages, r, loadingTabs);
          break;
        case _tabFuel:
          final r = await _repo.fetchFuelAnalytics(
            orgId,
            financialYear: fy,
            startDate: startDate,
            endDate: endDate,
          );
          _getOrCreateCache(orgId, fy).fuel = r;
          _emitTabData(_tabFuel, r, loadingTabs);
          break;
      }
    } catch (e) {
      final newLoading = loadingTabs.difference({tabIndex, if (tabIndex == _tabProductions) _tabDeliveries});
      emit(state.copyWith(
        status: ViewStatus.failure,
        loadingTabs: newLoading,
        message: e.toString(),
      ));
    }
  }

  void _emitTabData(int tabIndex, dynamic data, Set<int>? loadingTabs) {
    final newLoading = loadingTabs ?? state.loadingTabs.difference({tabIndex});
    switch (tabIndex) {
      case _tabTransactions:
        emit(state.copyWith(transactions: data as TransactionAnalytics?, loadingTabs: newLoading));
        break;
      case _tabClients:
        emit(state.copyWith(clients: data as ClientsAnalytics?, loadingTabs: newLoading));
        break;
      case _tabEmployees:
        emit(state.copyWith(employees: data as EmployeesAnalytics?, loadingTabs: newLoading));
        break;
      case _tabVendors:
        emit(state.copyWith(vendors: data as VendorsAnalytics?, loadingTabs: newLoading));
        break;
      case _tabDeliveries:
        emit(state.copyWith(deliveries: data as DeliveriesAnalytics?, loadingTabs: newLoading));
        break;
      case _tabProductions:
        emit(state.copyWith(productions: data as ProductionsAnalytics?, loadingTabs: newLoading));
        break;
      case _tabTripWages:
        emit(state.copyWith(tripWages: data as TripWagesAnalytics?, loadingTabs: newLoading));
        break;
      case _tabFuel:
        emit(state.copyWith(fuel: data as FuelAnalytics?, loadingTabs: newLoading));
        break;
    }
  }

  /// Legacy load: fetches all types. Kept for compatibility; prefer loadInitial + loadTabData.
  Future<void> load({required String orgId, String? financialYear}) async {
    await loadInitial(orgId: orgId, financialYear: financialYear);
  }
}
