import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/detail_modal_base.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AccountsLedgerPage extends StatefulWidget {
  const AccountsLedgerPage({super.key});

  @override
  State<AccountsLedgerPage> createState() => _AccountsLedgerPageState();
}

enum _LedgerSortOption {
  nameAsc,
  nameDesc,
  updatedNewest,
  updatedOldest,
  accountsHigh,
  accountsLow,
}

enum _LedgerFilterType {
  all,
  employees,
  vendors,
  clients,
}

class _AccountsLedgerPageState extends State<AccountsLedgerPage> {
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<_CombinedLedger> _ledgers = [];
  String _query = '';
  _LedgerSortOption _sortOption = _LedgerSortOption.updatedNewest;
  _LedgerFilterType _filterType = _LedgerFilterType.all;
  String? _refreshingLedgerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLedgers();
    });
  }

  Future<void> _loadLedgers() async {
    if (_isLoading) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    if (orgId == null) return;

    setState(() => _isLoading = true);
    try {
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      final snapshot = await FirebaseFirestore.instance
          .collection('ACCOUNTS_LEDGERS')
          .where('organizationId', isEqualTo: orgId)
          .where('financialYear', isEqualTo: financialYear)
          .orderBy('updatedAt', descending: true)
          .get();

      final ledgers = snapshot.docs.map((doc) {
        final data = doc.data();
        final accountsLedgerId =
            (data['accountsLedgerId'] as String?) ?? doc.id;
        final ledgerName = (data['ledgerName'] as String?) ?? 'Combined Ledger';
        final accountsData = (data['accounts'] as List<dynamic>?) ?? [];
        final accounts = accountsData
            .whereType<Map<String, dynamic>>()
            .map((account) {
              final typeRaw = (account['type'] as String?) ?? 'client';
              final id = account['id'] as String? ?? '';
              final name = account['name'] as String? ?? 'Unknown';
              final type = _accountTypeFromApi(typeRaw);
              return _AccountOption(
                key: '${type.name}:$id',
                id: id,
                name: name,
                type: type,
              );
            })
            .where((account) => account.id.isNotEmpty)
            .toList();

        final updatedAt =
            _dateFromTimestamp(data['updatedAt']) ?? DateTime.now();
        final createdAt = _dateFromTimestamp(data['createdAt']) ?? updatedAt;

        return _CombinedLedger(
          id: doc.id,
          accountsLedgerId: accountsLedgerId,
          name: ledgerName,
          accounts: accounts,
          createdAt: createdAt,
          lastRefreshedAt: updatedAt,
        );
      }).toList();

      setState(() {
        _ledgers = ledgers;
      });
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to load ledgers: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openCreateDialog() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    if (orgId == null) return;

    final result = await showDialog<_AccountsLedgerCreateResult>(
      context: context,
      builder: (dialogContext) {
        return _AccountsLedgerCreateDialog(orgId: orgId);
      },
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final accountsLedgerId = 'acc_${DateTime.now().microsecondsSinceEpoch}';
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('generateAccountsLedger');

      final response = await callable.call({
        'organizationId': orgId,
        'financialYear': financialYear,
        'accountsLedgerId': accountsLedgerId,
        'ledgerName': result.name,
        'accounts': result.selectedAccounts
            .map((account) => {
                  'type': _accountTypeToApi(account.type),
                  'id': account.id,
                  'name': account.name,
                })
            .toList(),
        'clearMissingMonths': true,
      });

      final data = response.data as Map<Object?, Object?>?;
      final ledgerId = (data?['ledgerId'] as String?) ?? accountsLedgerId;

      final ledger = _CombinedLedger(
        id: ledgerId,
        accountsLedgerId: accountsLedgerId,
        name: result.name,
        accounts: result.selectedAccounts,
        createdAt: DateTime.now(),
        lastRefreshedAt: DateTime.now(),
      );

      setState(() {
        _ledgers = [ledger, ..._ledgers];
      });

      DashSnackbar.show(context, message: 'Ledger created', isError: false);
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to create ledger: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final orgState = context.watch<OrganizationContextCubit>().state;
      final orgId = orgState.organization?.id;
      final appAccessRole = orgState.appAccessRole;
      final canAccess = appAccessRole?.canAccessPage('accountsLedger') ?? false;

      if (orgId == null) {
        return const Scaffold(
          body: Center(child: Text('No organization selected')),
        );
      }

      if (!canAccess && !(appAccessRole?.isAdmin ?? false)) {
        return SectionWorkspaceLayout(
          panelTitle: 'Accounts',
          currentIndex: -1,
          onNavTap: (value) => context.go('/home?section=$value'),
          child: const Center(
            child: Text(
              'You do not have access to Accounts.',
              style: TextStyle(color: AuthColors.textMain),
            ),
          ),
        );
      }

      final visibleSections = appAccessRole != null
          ? _computeVisibleSections(appAccessRole)
          : const [0, 1, 2, 3, 4];

      final content = _buildContentBody();

      return SectionWorkspaceLayout(
        panelTitle: 'Accounts',
        currentIndex: -1,
        onNavTap: (value) => context.go('/home?section=$value'),
        allowedSections: visibleSections,
        child: content,
      );
    } catch (e) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Accounts page failed to render: $e',
              style: const TextStyle(color: AuthColors.textMain),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContentBody() {
    final filtered = _applyFiltersAndSort(_ledgers);
    final totalAccounts = _ledgers.fold<int>(
      0,
      (sum, ledger) => sum + ledger.accounts.length,
    );
    final averageAccounts =
        _ledgers.isEmpty ? 0 : (totalAccounts / _ledgers.length).round();
    final latestRefresh = _ledgers.isEmpty
        ? null
        : _ledgers
            .map((ledger) => ledger.lastRefreshedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LedgerStatsHeader(
          totalAccounts: totalAccounts,
          averageAccounts: averageAccounts,
        ),
        const SizedBox(height: 32),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: AuthColors.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AuthColors.textSub.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: InputDecoration(
                    hintText: 'Search ledgers by name or account...',
                    hintStyle: const TextStyle(
                      color: AuthColors.textDisabled,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    prefixIcon:
                        const Icon(Icons.search, color: AuthColors.textSub),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AuthColors.textSub),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textSub.withOpacity(0.2),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _LedgerFilterChip(
                    label: 'All',
                    isSelected: _filterType == _LedgerFilterType.all,
                    onTap: () => setState(() {
                      _filterType = _LedgerFilterType.all;
                    }),
                  ),
                  _LedgerFilterChip(
                    label: 'Employees',
                    isSelected: _filterType == _LedgerFilterType.employees,
                    onTap: () => setState(() {
                      _filterType = _LedgerFilterType.employees;
                    }),
                  ),
                  _LedgerFilterChip(
                    label: 'Vendors',
                    isSelected: _filterType == _LedgerFilterType.vendors,
                    onTap: () => setState(() {
                      _filterType = _LedgerFilterType.vendors;
                    }),
                  ),
                  _LedgerFilterChip(
                    label: 'Clients',
                    isSelected: _filterType == _LedgerFilterType.clients,
                    onTap: () => setState(() {
                      _filterType = _LedgerFilterType.clients;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textSub.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 16, color: AuthColors.textSub),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_LedgerSortOption>(
                      value: _sortOption,
                      dropdownColor: AuthColors.surface,
                      style: const TextStyle(
                          color: AuthColors.textMain, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                          value: _LedgerSortOption.updatedNewest,
                          child: Text('Updated (Newest)'),
                        ),
                        DropdownMenuItem(
                          value: _LedgerSortOption.updatedOldest,
                          child: Text('Updated (Oldest)'),
                        ),
                        DropdownMenuItem(
                          value: _LedgerSortOption.nameAsc,
                          child: Text('Name (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: _LedgerSortOption.nameDesc,
                          child: Text('Name (Z-A)'),
                        ),
                        DropdownMenuItem(
                          value: _LedgerSortOption.accountsHigh,
                          child: Text('Accounts (High to Low)'),
                        ),
                        DropdownMenuItem(
                          value: _LedgerSortOption.accountsLow,
                          child: Text('Accounts (Low to High)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortOption = value);
                        }
                      },
                      icon: const Icon(Icons.arrow_drop_down,
                          color: AuthColors.textSub, size: 20),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textSub.withOpacity(0.2),
                ),
              ),
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? 'ledger' : 'ledgers'}',
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            DashButton(
              icon: Icons.add,
              label: 'Create Ledger',
              onPressed: _isLoading ? null : _openCreateDialog,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (filtered.isEmpty)
          _EmptyLedgerState(onCreate: _openCreateDialog)
        else
          _LedgerListView(
            ledgers: filtered,
            onOpen: _openLedgerDetail,
            onRefresh: _refreshLedgerById,
            refreshingId: _refreshingLedgerId,
            isRefreshing: _isRefreshing,
          ),
      ],
    );
  }

  List<_CombinedLedger> _applyFiltersAndSort(List<_CombinedLedger> ledgers) {
    final query = _query.trim().toLowerCase();
    final filtered = ledgers.where((ledger) {
      if (_filterType != _LedgerFilterType.all) {
        final matchType = switch (_filterType) {
          _LedgerFilterType.employees => _AccountType.employee,
          _LedgerFilterType.vendors => _AccountType.vendor,
          _LedgerFilterType.clients => _AccountType.client,
          _LedgerFilterType.all => null,
        };
        if (matchType != null &&
            !ledger.accounts.any((account) => account.type == matchType)) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      final matchesName = ledger.name.toLowerCase().contains(query);
      final matchesAccount = ledger.accounts
          .any((account) => account.name.toLowerCase().contains(query));
      return matchesName || matchesAccount;
    }).toList();

    switch (_sortOption) {
      case _LedgerSortOption.nameAsc:
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _LedgerSortOption.nameDesc:
        filtered.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _LedgerSortOption.updatedNewest:
        filtered.sort((a, b) => b.lastRefreshedAt.compareTo(a.lastRefreshedAt));
        break;
      case _LedgerSortOption.updatedOldest:
        filtered.sort((a, b) => a.lastRefreshedAt.compareTo(b.lastRefreshedAt));
        break;
      case _LedgerSortOption.accountsHigh:
        filtered.sort((a, b) => b.accounts.length.compareTo(a.accounts.length));
        break;
      case _LedgerSortOption.accountsLow:
        filtered.sort((a, b) => a.accounts.length.compareTo(b.accounts.length));
        break;
    }

    return filtered;
  }

  void _openLedgerDetail(_CombinedLedger ledger) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AccountLedgerDetailModal(ledger: ledger),
    );
  }

  Future<void> _refreshLedgerById(String ledgerId) async {
    if (_isRefreshing) return;
    final ledger = _ledgers.firstWhere(
      (l) => l.id == ledgerId,
      orElse: () => _CombinedLedger.empty(),
    );
    if (ledger.isEmpty) return;

    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    if (orgId == null) return;

    setState(() {
      _isRefreshing = true;
      _refreshingLedgerId = ledgerId;
    });
    try {
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('generateAccountsLedger');

      await callable.call({
        'organizationId': orgId,
        'financialYear': financialYear,
        'accountsLedgerId': ledger.accountsLedgerId,
        'ledgerName': ledger.name,
        'accounts': ledger.accounts
            .map((account) => {
                  'type': _accountTypeToApi(account.type),
                  'id': account.id,
                  'name': account.name,
                })
            .toList(),
        'clearMissingMonths': true,
      });

      setState(() {
        _ledgers = _ledgers
            .map(
              (item) => item.id == ledgerId
                  ? item.copyWith(lastRefreshedAt: DateTime.now())
                  : item,
            )
            .toList();
      });

      DashSnackbar.show(context, message: 'Ledger refreshed', isError: false);
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to refresh ledger: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _refreshingLedgerId = null;
        });
      }
    }
  }

  List<int> _computeVisibleSections(appAccessRole) {
    final visible = <int>[0];
    if (appAccessRole.canAccessSection('pendingOrders')) visible.add(1);
    if (appAccessRole.canAccessSection('scheduleOrders')) visible.add(2);
    if (appAccessRole.canAccessSection('ordersMap')) visible.add(3);
    if (appAccessRole.canAccessSection('analyticsDashboard')) visible.add(4);
    return visible;
  }

  String _accountTypeToApi(_AccountType type) {
    switch (type) {
      case _AccountType.employee:
        return 'employee';
      case _AccountType.vendor:
        return 'vendor';
      case _AccountType.client:
        return 'client';
    }
  }

  _AccountType _accountTypeFromApi(String type) {
    switch (type) {
      case 'employee':
        return _AccountType.employee;
      case 'vendor':
        return _AccountType.vendor;
      case 'client':
      default:
        return _AccountType.client;
    }
  }

  DateTime? _dateFromTimestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

class _AccountsLedgerCreateResult {
  const _AccountsLedgerCreateResult({
    required this.name,
    required this.selectedAccounts,
  });

  final String name;
  final List<_AccountOption> selectedAccounts;
}

class _AccountsLedgerCreateDialog extends StatefulWidget {
  const _AccountsLedgerCreateDialog({required this.orgId});

  final String orgId;

  @override
  State<_AccountsLedgerCreateDialog> createState() =>
      _AccountsLedgerCreateDialogState();
}

class _AccountsLedgerCreateDialogState
    extends State<_AccountsLedgerCreateDialog> {
  static const int _pageSize = 30;
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final Map<_AccountType, List<_AccountOption>> _pagedOptions = {
    _AccountType.employee: <_AccountOption>[],
    _AccountType.vendor: <_AccountOption>[],
    _AccountType.client: <_AccountOption>[],
  };
  final Map<_AccountType, DocumentSnapshot<Map<String, dynamic>>?> _lastDocs = {
    _AccountType.employee: null,
    _AccountType.vendor: null,
    _AccountType.client: null,
  };
  final Map<_AccountType, bool> _hasMore = {
    _AccountType.employee: true,
    _AccountType.vendor: true,
    _AccountType.client: true,
  };
  final Map<String, _AccountOption> _selectedOptions = {};

  _AccountType _activeType = _AccountType.employee;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSearching = false;
  List<_AccountOption> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searchQuery.trim().isNotEmpty) return;
    if (!(_hasMore[_activeType] ?? false) || _isLoading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoading) return;
    if (!reset && !(_hasMore[_activeType] ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final result = await _fetchPage(
        _activeType,
        reset ? null : _lastDocs[_activeType],
      );
      final existing =
          reset ? <_AccountOption>[] : _pagedOptions[_activeType] ?? [];
      final merged = [...existing, ...result.options];
      final hasMore =
          result.options.length >= _pageSize && result.lastDoc != null;

      setState(() {
        _pagedOptions[_activeType] = merged;
        _lastDocs[_activeType] = result.lastDoc;
        _hasMore[_activeType] = hasMore;
      });
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to load accounts: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<
      ({
        List<_AccountOption> options,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> _fetchPage(
    _AccountType type,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  ) async {
    final employeesRepo = context.read<EmployeesRepository>();
    final vendorsRepo = context.read<VendorsRepository>();
    final clientsRepo = context.read<ClientsRepository>();

    switch (type) {
      case _AccountType.employee:
        final result = await employeesRepo.fetchEmployeesPage(
          organizationId: widget.orgId,
          limit: _pageSize,
          startAfterDocument: startAfter,
        );
        final options = result.employees
            .map(
              (employee) => _AccountOption(
                key: 'employee:${employee.id}',
                id: employee.id,
                name: employee.name,
                type: _AccountType.employee,
              ),
            )
            .toList();
        return (options: options, lastDoc: result.lastDoc);
      case _AccountType.vendor:
        final result = await vendorsRepo.fetchVendorsPage(
          organizationId: widget.orgId,
          limit: _pageSize,
          startAfterDocument: startAfter,
        );
        final options = result.vendors
            .map(
              (vendor) => _AccountOption(
                key: 'vendor:${vendor.id}',
                id: vendor.id,
                name: vendor.name,
                type: _AccountType.vendor,
              ),
            )
            .toList();
        return (options: options, lastDoc: result.lastDoc);
      case _AccountType.client:
        final result = await clientsRepo.fetchClients(
          orgId: widget.orgId,
          limit: _pageSize,
          startAfterDocument: startAfter,
        );
        final options = result.clients
            .map(
              (client) => _AccountOption(
                key: 'client:${client.id}',
                id: client.id,
                name: client.name,
                type: _AccountType.client,
              ),
            )
            .toList();
        return (options: options, lastDoc: result.lastDoc);
    }
  }

  Future<void> _performSearch(String value) async {
    final trimmed = value.trim();
    setState(() {
      _searchQuery = trimmed;
      _isSearching = trimmed.isNotEmpty;
    });

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      final results = await _searchByType(_activeType, trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to search accounts: $e', isError: true);
        setState(() => _isSearching = false);
      }
    }
  }

  Future<List<_AccountOption>> _searchByType(
    _AccountType type,
    String query,
  ) async {
    final employeesRepo = context.read<EmployeesRepository>();
    final vendorsRepo = context.read<VendorsRepository>();
    final clientsRepo = context.read<ClientsRepository>();

    switch (type) {
      case _AccountType.employee:
        final results = await employeesRepo.searchEmployeesByName(
          widget.orgId,
          query,
          limit: _pageSize,
        );
        return results
            .map(
              (employee) => _AccountOption(
                key: 'employee:${employee.id}',
                id: employee.id,
                name: employee.name,
                type: _AccountType.employee,
              ),
            )
            .toList();
      case _AccountType.vendor:
        final results = await vendorsRepo.searchVendors(widget.orgId, query);
        return results
            .map(
              (vendor) => _AccountOption(
                key: 'vendor:${vendor.id}',
                id: vendor.id,
                name: vendor.name,
                type: _AccountType.vendor,
              ),
            )
            .toList();
      case _AccountType.client:
        final results = await clientsRepo.searchClients(widget.orgId, query);
        return results
            .map(
              (client) => _AccountOption(
                key: 'client:${client.id}',
                id: client.id,
                name: client.name,
                type: _AccountType.client,
              ),
            )
            .toList();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  void _switchType(_AccountType type) {
    if (_activeType == type) return;
    setState(() => _activeType = type);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_searchQuery.trim().isNotEmpty) {
      _performSearch(_searchQuery);
      return;
    }
    setState(() => _searchResults = []);
  }

  void _toggleSelection(_AccountOption option) {
    setState(() {
      if (_selectedOptions.containsKey(option.key)) {
        _selectedOptions.remove(option.key);
      } else {
        _selectedOptions[option.key] = option;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = _searchQuery.isNotEmpty
        ? _searchResults
        : (_pagedOptions[_activeType] ?? const <_AccountOption>[]);

    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Create Combined Ledger',
        style: TextStyle(color: AuthColors.textMain),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashFormField(
                controller: _nameController,
                label: 'Ledger Name',
                style: const TextStyle(color: AuthColors.textMain),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Account Type',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Employees'),
                    selected: _activeType == _AccountType.employee,
                    onSelected: (_) => _switchType(_AccountType.employee),
                  ),
                  ChoiceChip(
                    label: const Text('Vendors'),
                    selected: _activeType == _AccountType.vendor,
                    onSelected: (_) => _switchType(_AccountType.vendor),
                  ),
                  ChoiceChip(
                    label: const Text('Clients'),
                    selected: _activeType == _AccountType.client,
                    onSelected: (_) => _switchType(_AccountType.client),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: InputDecoration(
                  labelText: 'Search accounts',
                  labelStyle: const TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.background,
                  prefixIcon:
                      const Icon(Icons.search, color: AuthColors.textSub),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AuthColors.textMainWithOpacity(0.12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Accounts (2 or more)',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SizedBox(
                height: 280,
                child: _buildAccountsList(options),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected: ${_selectedOptions.length}',
                style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Create',
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              DashSnackbar.show(
                context,
                message: 'Enter a ledger name',
                isError: true,
              );
              return;
            }
            if (_selectedOptions.length < 2) {
              DashSnackbar.show(
                context,
                message: 'Select at least two accounts',
                isError: true,
              );
              return;
            }
            Navigator.of(context).pop(
              _AccountsLedgerCreateResult(
                name: name,
                selectedAccounts: _selectedOptions.values.toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountsList(List<_AccountOption> options) {
    if (_searchQuery.trim().isEmpty) {
      return const Center(
        child: Text(
          'Start typing to load accounts.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }
    if (_isLoading && options.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (options.isEmpty) {
      return const Center(
        child: Text(
          'No accounts found.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }

    final showLoader = _isLoading && _searchQuery.isEmpty;

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: options.length + (showLoader ? 1 : 0),
        itemBuilder: (context, index) {
          if (showLoader && index == options.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final option = options[index];
          final isSelected = _selectedOptions.containsKey(option.key);
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              option.name,
              style: const TextStyle(color: AuthColors.textMain),
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(option),
            ),
            onTap: () => _toggleSelection(option),
          );
        },
      ),
    );
  }
}

class _LedgerListView extends StatelessWidget {
  const _LedgerListView({
    required this.ledgers,
    required this.onOpen,
    required this.onRefresh,
    required this.refreshingId,
    required this.isRefreshing,
  });

  final List<_CombinedLedger> ledgers;
  final ValueChanged<_CombinedLedger> onOpen;
  final ValueChanged<String> onRefresh;
  final String? refreshingId;
  final bool isRefreshing;

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  Color _getLedgerColor(String name) {
    final hash = name.hashCode;
    const colors = [
      Color(0xFF5AD8A4),
      Color(0xFFFF9800),
      Color(0xFF2196F3),
      Color(0xFFE91E63),
      Color(0xFF6F4BFF),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatDateTime(DateTime dateTime) {
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return '${date.day}/${date.month}/${date.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ledgers.length,
        itemBuilder: (context, index) {
          final ledger = ledgers[index];
          final color = _getLedgerColor(ledger.name);
          final subtitle =
              '${ledger.accounts.length} accounts • Updated ${_formatDateTime(ledger.lastRefreshedAt)}';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AuthColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: DataList(
              title: ledger.name,
              subtitle: subtitle,
              leading: DataListAvatar(
                initial: _getInitials(ledger.name),
                radius: 28,
                statusRingColor: color,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined,
                        size: 20, color: AuthColors.textSub),
                    onPressed: () => onOpen(ledger),
                    tooltip: 'View Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  if (isRefreshing && refreshingId == ledger.id)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AuthColors.primary,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          size: 20, color: AuthColors.textSub),
                      onPressed: () => onRefresh(ledger.id),
                      tooltip: 'Refresh',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              onTap: () => onOpen(ledger),
            ),
          );
        },
      ),
    );
  }
}

class _LedgerStatsHeader extends StatelessWidget {
  const _LedgerStatsHeader({
    required this.totalAccounts,
    required this.averageAccounts,
  });

  final int totalAccounts;
  final int averageAccounts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        final cards = [
          _LedgerStatCard(
            icon: Icons.people_outline,
            label: 'Total Accounts',
            value: totalAccounts.toString(),
            color: AuthColors.success,
          ),
          _LedgerStatCard(
            icon: Icons.auto_graph,
            label: 'Avg Accounts',
            value: averageAccounts.toString(),
            color: AuthColors.secondary,
          ),
        ];

        return isWide
            ? Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: cards,
              );
      },
    );
  }
}

class _LedgerStatCard extends StatelessWidget {
  const _LedgerStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerFilterChip extends StatelessWidget {
  const _LedgerFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withOpacity(0.2)
              : AuthColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyLedgerState extends StatelessWidget {
  const _EmptyLedgerState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No combined ledgers yet',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a ledger to consolidate accounts and track shared balances.',
            style: TextStyle(color: AuthColors.textSub, fontSize: 13),
          ),
          const SizedBox(height: 16),
          DashButton(
            icon: Icons.add,
            label: 'Create Ledger',
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

enum _AccountType { employee, vendor, client }

class _AccountOption {
  const _AccountOption({
    required this.key,
    required this.id,
    required this.name,
    required this.type,
  });

  final String key;
  final String id;
  final String name;
  final _AccountType type;
}

class _CombinedLedger {
  const _CombinedLedger({
    required this.id,
    required this.accountsLedgerId,
    required this.name,
    required this.accounts,
    required this.createdAt,
    required this.lastRefreshedAt,
  });

  final String id;
  final String accountsLedgerId;
  final String name;
  final List<_AccountOption> accounts;
  final DateTime createdAt;
  final DateTime lastRefreshedAt;

  bool get isEmpty => id.isEmpty;

  _CombinedLedger copyWith({
    String? id,
    String? accountsLedgerId,
    String? name,
    List<_AccountOption>? accounts,
    DateTime? createdAt,
    DateTime? lastRefreshedAt,
  }) {
    return _CombinedLedger(
      id: id ?? this.id,
      accountsLedgerId: accountsLedgerId ?? this.accountsLedgerId,
      name: name ?? this.name,
      accounts: accounts ?? this.accounts,
      createdAt: createdAt ?? this.createdAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }

  factory _CombinedLedger.empty() => _CombinedLedger(
        id: '',
        accountsLedgerId: '',
        name: '',
        accounts: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastRefreshedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class _AccountLedgerDetailModal extends StatefulWidget {
  const _AccountLedgerDetailModal({required this.ledger});

  final _CombinedLedger ledger;

  @override
  State<_AccountLedgerDetailModal> createState() =>
      _AccountLedgerDetailModalState();
}

class _AccountLedgerDetailModalState extends State<_AccountLedgerDetailModal> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _ledger;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadLedgerData();
  }

  Future<void> _loadLedgerData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ledgerRef = FirebaseFirestore.instance
          .collection('ACCOUNTS_LEDGERS')
          .doc(widget.ledger.id);
      final ledgerDoc = await ledgerRef.get();
      if (!ledgerDoc.exists) {
        throw Exception('Ledger not found');
      }
      final ledgerData = ledgerDoc.data() ?? <String, dynamic>{};

      final transactionDocs = await ledgerRef
          .collection('TRANSACTIONS')
          .orderBy('yearMonth', descending: true)
          .get();

      final transactions = <Map<String, dynamic>>[];
      for (final doc in transactionDocs.docs) {
        final data = doc.data();
        final entries = data['transactions'];
        if (entries is List) {
          for (final entry in entries) {
            if (entry is Map) {
              transactions.add(Map<String, dynamic>.from(entry));
            }
          }
        }
      }

      setState(() {
        _ledger = ledgerData;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailModalBase(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AccountLedgerModalHeader(
            ledger: widget.ledger,
            onClose: () => Navigator.of(context).pop(),
            onReload: _loadLedgerData,
          ),
          Container(
            decoration: BoxDecoration(
              color: AuthColors.backgroundAlt,
              border: Border(
                bottom: BorderSide(
                  color: AuthColors.textMainWithOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LedgerTabButton(
                    label: 'Overview',
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                ),
                Expanded(
                  child: _LedgerTabButton(
                    label: 'Ledger',
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
                Expanded(
                  child: _LedgerTabButton(
                    label: 'Transactions',
                    isSelected: _selectedTabIndex == 2,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AuthColors.primary),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          'Failed to load ledger: $_error',
                          style: const TextStyle(color: AuthColors.textSub),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _AccountLedgerOverviewTab(
                            ledger: _ledger,
                            accounts: widget.ledger.accounts,
                            formatCurrency: _formatCurrency,
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _AccountLedgerTable(
                              openingBalance:
                                  (_ledger?['openingBalance'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                              transactions: _transactions,
                              formatCurrency: _formatCurrency,
                              formatDate: _formatDate,
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _AccountTransactionsTable(
                              transactions: _transactions,
                              formatCurrency: _formatCurrency,
                              formatDate: _formatDate,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _AccountLedgerModalHeader extends StatelessWidget {
  const _AccountLedgerModalHeader({
    required this.ledger,
    required this.onClose,
    required this.onReload,
  });

  final _CombinedLedger ledger;
  final VoidCallback onClose;
  final VoidCallback onReload;

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuthColors.primary.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AuthColors.primary.withOpacity(0.2),
                child: Text(
                  _getInitials(ledger.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${ledger.accounts.length} accounts',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onReload,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Reload',
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountLedgerOverviewTab extends StatelessWidget {
  const _AccountLedgerOverviewTab({
    required this.ledger,
    required this.accounts,
    required this.formatCurrency,
  });

  final Map<String, dynamic>? ledger;
  final List<_AccountOption> accounts;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance =
        (ledger?['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final totalCredits = (ledger?['totalCredits'] as num?)?.toDouble() ?? 0.0;
    final totalDebits = (ledger?['totalDebits'] as num?)?.toDouble() ?? 0.0;
    final transactionCount = ledger?['transactionCount'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                label: 'Current Balance',
                value: formatCurrency(currentBalance),
                accent: AuthColors.success,
              ),
              _StatCard(
                label: 'Total Credits',
                value: formatCurrency(totalCredits),
                accent: AuthColors.info,
              ),
              _StatCard(
                label: 'Total Debits',
                value: formatCurrency(totalDebits),
                accent: AuthColors.warning,
              ),
              _StatCard(
                label: 'Transactions',
                value: transactionCount.toString(),
                accent: AuthColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Accounts',
            style: TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: accounts
                .map((account) => Chip(
                      label: Text(account.name),
                      backgroundColor: AuthColors.background,
                      labelStyle: const TextStyle(color: AuthColors.textMain),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTransactionsTable extends StatelessWidget {
  const _AccountTransactionsTable({
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Text(
        'No transactions found.',
        style: TextStyle(color: AuthColors.textSub, fontSize: 13),
      );
    }

    final visible = List<Map<String, dynamic>>.from(transactions);
    visible.sort((a, b) {
      final aDate = a['transactionDate'];
      final bDate = b['transactionDate'];
      try {
        final ad = aDate is Timestamp ? aDate.toDate() : (aDate as DateTime);
        final bd = bDate is Timestamp ? bDate.toDate() : (bDate as DateTime);
        return bd.compareTo(ad);
      } catch (_) {
        return 0;
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          const _TransactionsTableHeader(),
          Divider(height: 1, color: AuthColors.textMain.withOpacity(0.12)),
          ...visible.take(120).map((tx) => _TransactionsTableRow(
                transaction: tx,
                formatCurrency: formatCurrency,
                formatDate: formatDate,
              )),
        ],
      ),
    );
  }
}

class _TransactionsTableHeader extends StatelessWidget {
  const _TransactionsTableHeader();

  static const _labelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Date',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Type',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Amount',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Balance',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            alignment: Alignment.center,
            child: const Text('Reference',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _TransactionsTableRow extends StatelessWidget {
  const _TransactionsTableRow({
    required this.transaction,
    required this.formatCurrency,
    required this.formatDate,
  });

  final Map<String, dynamic> transaction;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  static const _cellStyle = TextStyle(
    color: AuthColors.textMain,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final balanceAfter =
        (transaction['balanceAfter'] as num?)?.toDouble() ?? 0.0;
    final type = (transaction['type'] as String?) ?? '-';
    final reference = (transaction['referenceNumber'] as String?) ??
        (transaction['transactionId'] as String?) ??
        '-';

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              formatDate(transaction['transactionDate']),
              style: _cellStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              type,
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              formatCurrency(amount),
              style: _cellStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              formatCurrency(balanceAfter),
              style: _cellStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            alignment: Alignment.center,
            child: Text(
              reference,
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerTabButton extends StatelessWidget {
  const _LedgerTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.secondary : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LedgerRowModel {
  _LedgerRowModel({
    required this.date,
    required this.reference,
    required this.referenceBadgeColor,
    required this.credit,
    required this.debit,
    required this.balanceAfter,
    required this.type,
    required this.remarks,
    this.paymentParts = const [],
    this.category,
  });

  final dynamic date;
  final String reference;
  final Color? referenceBadgeColor;
  final double credit;
  final double debit;
  final double balanceAfter;
  final String type;
  final String remarks;
  final List<_PaymentPart> paymentParts;
  final String? category;
}

String _formatCategoryName(String? category) {
  if (category == null || category.isEmpty) return '';
  return category
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

bool _isLedgerType(String? value, String expected) {
  return (value ?? '').toLowerCase() == expected.toLowerCase();
}

String _resolveLedgerReference(
  Map<String, dynamic> transaction,
  String? ledgerType,
  String? dmNumber,
) {
  if (_isLedgerType(ledgerType, 'clientLedger')) {
    return dmNumber != null ? 'DM-$dmNumber' : '-';
  }
  if (_isLedgerType(ledgerType, 'vendorLedger')) {
    final metadata = transaction['metadata'] as Map<String, dynamic>? ?? {};
    return (transaction['referenceNumber'] as String?) ??
        (metadata['invoiceNumber'] as String?) ??
        '-';
  }
  if (_isLedgerType(ledgerType, 'employeeLedger')) {
    final desc = (transaction['description'] as String?)?.trim();
    return (desc != null && desc.isNotEmpty) ? desc : '-';
  }
  return (transaction['referenceNumber'] as String?) ?? '-';
}

class _PaymentPart {
  _PaymentPart({required this.amount, required this.accountType});
  final double amount;
  final String accountType;
}

class _AccountLedgerTable extends StatelessWidget {
  const _AccountLedgerTable({
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final visible = List<Map<String, dynamic>>.from(transactions);
    if (visible.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions found.',
            style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
                fontFamily: 'SF Pro Display'),
          ),
          const SizedBox(height: 20),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
      );
    }

    visible.sort((a, b) {
      final aDate = a['transactionDate'];
      final bDate = b['transactionDate'];
      try {
        final ad = aDate is Timestamp ? aDate.toDate() : (aDate as DateTime);
        final bd = bDate is Timestamp ? bDate.toDate() : (bDate as DateTime);
        return ad.compareTo(bd);
      } catch (_) {
        return 0;
      }
    });

    final List<_LedgerRowModel> rows = [];
    double running = openingBalance;

    int i = 0;
    while (i < visible.length) {
      final tx = visible[i];
      final type = (tx['type'] as String? ?? '').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final metadata = tx['metadata'] as Map<String, dynamic>? ?? {};
      final dmNumber = metadata['dmNumber'] ?? tx['dmNumber'];
      final category = tx['category'] as String?;
      final date = tx['transactionDate'];
      final ledgerType = tx['ledgerType'] as String?;
      final isClientLedger = _isLedgerType(ledgerType, 'clientLedger');

      if (isClientLedger && dmNumber != null) {
        double totalCredit = 0;
        double totalDebit = 0;
        dynamic earliestDate = date;
        final List<_PaymentPart> parts = [];
        int j = i;

        while (j < visible.length) {
          final next = visible[j];
          final nMeta = next['metadata'] as Map<String, dynamic>? ?? {};
          final nDm = nMeta['dmNumber'] ?? next['dmNumber'];
          final nextLedgerType = next['ledgerType'] as String?;
          if (nDm != dmNumber) break;
          if (!_isLedgerType(nextLedgerType, 'clientLedger')) break;

          final nt = (next['type'] as String? ?? '').toLowerCase();
          final nAmt = (next['amount'] as num?)?.toDouble() ?? 0.0;
          final nDate = next['transactionDate'];

          try {
            final currentDate = earliestDate is Timestamp
                ? earliestDate.toDate()
                : (earliestDate as DateTime);
            final nextDate =
                nDate is Timestamp ? nDate.toDate() : (nDate as DateTime);
            if (nextDate.isBefore(currentDate)) {
              earliestDate = nDate;
            }
          } catch (_) {}

          if (nt == 'credit') {
            totalCredit += nAmt;
          } else {
            totalDebit += nAmt;
            if (nt == 'payment') {
              final acctType = (next['paymentAccountType'] as String?) ?? '';
              parts.add(_PaymentPart(amount: nAmt, accountType: acctType));
            }
          }

          j++;
        }

        final delta = totalCredit - totalDebit;
        running += delta;

        final firstDesc = (visible[i]['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: earliestDate,
          reference: 'DM-$dmNumber',
          referenceBadgeColor: AuthColors.info,
          credit: totalCredit,
          debit: totalDebit,
          balanceAfter: running,
          type: 'Order',
          remarks:
              (firstDesc != null && firstDesc.isNotEmpty) ? firstDesc : '-',
          paymentParts: parts,
        ));

        i = j;
      } else {
        final isCredit = type == 'credit';
        final delta = isCredit ? amount : -amount;
        running += delta;

        final showCategoryBadge =
            isClientLedger && (category != null && category.isNotEmpty);
        final reference = showCategoryBadge
            ? _formatCategoryName(category)
            : _resolveLedgerReference(tx, ledgerType, dmNumber?.toString());

        final desc = (tx['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: date,
          reference: reference.isEmpty ? '-' : reference,
          referenceBadgeColor: showCategoryBadge ? AuthColors.secondary : null,
          credit: isCredit ? amount : 0,
          debit: isCredit ? 0 : amount,
          balanceAfter: running,
          type: _formatCategoryName(category ?? ''),
          remarks: (desc != null && desc.isNotEmpty) ? desc : '-',
          category: category,
        ));
        i++;
      }
    }

    final totalDebit = rows.fold<double>(0, (s, r) => s + r.debit);
    final totalCredit = rows.fold<double>(0, (s, r) => s + r.credit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Display',
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withOpacity(0.12)),
              ...rows.map((r) => _LedgerTableRow(
                    row: r,
                    formatCurrency: formatCurrency,
                    formatDate: formatDate,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _LedgerSummaryFooter(
          openingBalance: openingBalance,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          formatCurrency: formatCurrency,
        ),
      ],
    );
  }
}

class _LedgerTableHeader extends StatelessWidget {
  static const _labelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Date',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Reference',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Debit',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Credit',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Balance',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: const Text('Type',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            alignment: Alignment.center,
            child: const Text('Remarks',
                style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.row,
    required this.formatCurrency,
    required this.formatDate,
  });

  final _LedgerRowModel row;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  static const _cellStyle = TextStyle(
    color: AuthColors.textMain,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static const _badgeStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  Color _accountColor(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return AuthColors.info;
      case 'bank':
        return AuthColors.secondary;
      case 'cash':
        return AuthColors.success;
      default:
        return AuthColors.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              formatDate(row.date),
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: row.referenceBadgeColor != null
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: row.referenceBadgeColor!.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      row.reference,
                      style:
                          _badgeStyle.copyWith(color: row.referenceBadgeColor!),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    row.reference.isEmpty ? '-' : row.reference,
                    style: _cellStyle.copyWith(color: AuthColors.textSub),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: row.debit > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(formatCurrency(row.debit),
                          style: _cellStyle, textAlign: TextAlign.center),
                      if (row.paymentParts.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: row.paymentParts
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _accountColor(p.accountType)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      formatCurrency(p.amount),
                                      style: _badgeStyle.copyWith(
                                          color: _accountColor(p.accountType)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  )
                : Text('-',
                    style: _cellStyle.copyWith(color: AuthColors.textSub),
                    textAlign: TextAlign.center),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              row.credit > 0 ? formatCurrency(row.credit) : '-',
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              formatCurrency(row.balanceAfter),
              style: _cellStyle.copyWith(
                color: row.balanceAfter >= 0
                    ? AuthColors.warning
                    : AuthColors.success,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(border: _cellBorder),
            alignment: Alignment.center,
            child: Text(
              row.type.isEmpty ? '-' : row.type,
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            alignment: Alignment.center,
            child: Text(
              row.remarks,
              style: _cellStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerSummaryFooter extends StatelessWidget {
  const _LedgerSummaryFooter({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.formatCurrency,
  });

  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final String Function(double) formatCurrency;

  static const _footerLabelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static const _footerValueStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'SF Pro Display',
  );

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Opening Balance',
                  style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(openingBalance),
                  style: _footerValueStyle.copyWith(color: AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Debit',
                  style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalDebit),
                  style: _footerValueStyle.copyWith(color: AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Credit',
                  style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalCredit),
                  style: _footerValueStyle.copyWith(color: AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Current Balance',
                  style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(currentBalance),
                  style: _footerValueStyle.copyWith(color: AuthColors.success),
                  textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}
