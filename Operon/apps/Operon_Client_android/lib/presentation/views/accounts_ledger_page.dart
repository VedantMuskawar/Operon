import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AccountsLedgerPage extends StatefulWidget {
  const AccountsLedgerPage({super.key});

  @override
  State<AccountsLedgerPage> createState() => _AccountsLedgerPageState();
}

class _AccountsLedgerPageState extends State<AccountsLedgerPage> {
  bool _isRefreshing = false;
  List<_CombinedLedger> _ledgers = [];
  String? _selectedLedgerId;
  late final TextEditingController _searchController;
  String _query = '';
  _LedgerFilterType _filterType = _LedgerFilterType.all;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() => _query = _searchController.text);
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshSelected() async {
    if (_selectedLedgerId == null || _isRefreshing) return;
    final ledger = _ledgers.firstWhere(
      (l) => l.id == _selectedLedgerId,
      orElse: () => _CombinedLedger.empty(),
    );
    if (ledger.isEmpty) return;

    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    if (orgId == null) return;

    setState(() => _isRefreshing = true);
    try {
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('generateAccountsLedger');

      await callable.call({
        'organizationId': orgId,
        'financialYear': financialYear,
        'accountsLedgerId': ledger.id,
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
              (item) => item.id == _selectedLedgerId
                  ? item.copyWith(lastRefreshedAt: DateTime.now())
                  : item,
            )
            .toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ledger refreshed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh ledger: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _exportSelected() {
    if (_selectedLedgerId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export started')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final appAccessRole = orgState.appAccessRole;
    final canAccess = appAccessRole?.canAccessPage('accountsLedger') ?? false;

    if (!canAccess && !(appAccessRole?.isAdmin ?? false)) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Accounts',
        ),
        body: const Center(
          child: Text(
            'You do not have access to Accounts.',
            style: TextStyle(color: AuthColors.textMain),
          ),
        ),
      );
    }

    final filtered = _applyFilters(_ledgers);
    final totalAccounts = _ledgers.fold<int>(
      0,
      (sum, ledger) => sum + ledger.accounts.length,
    );
    final averageAccounts =
        _ledgers.isEmpty ? 0 : (totalAccounts / _ledgers.length).round();

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Accounts',
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.paddingLG),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LedgerStatsHeader(
                          totalAccounts: totalAccounts,
                          averageAccounts: averageAccounts,
                        ),
                        const SizedBox(height: AppSpacing.paddingXL),
                        const SizedBox(height: AppSpacing.paddingSM),
                        StandardSearchBar(
                          controller: _searchController,
                          hintText: 'Search ledgers by name or account...',
                          onClear: () => setState(() => _query = ''),
                        ),
                        const SizedBox(height: AppSpacing.paddingSM),
                        Wrap(
                          spacing: AppSpacing.paddingSM,
                          runSpacing: AppSpacing.paddingSM,
                          children: [
                            StandardChip(
                              label: 'All',
                              isSelected: _filterType == _LedgerFilterType.all,
                              onTap: () => setState(() {
                                _filterType = _LedgerFilterType.all;
                              }),
                            ),
                            StandardChip(
                              label: 'Employees',
                              isSelected:
                                  _filterType == _LedgerFilterType.employees,
                              onTap: () => setState(() {
                                _filterType = _LedgerFilterType.employees;
                              }),
                            ),
                            StandardChip(
                              label: 'Vendors',
                              isSelected:
                                  _filterType == _LedgerFilterType.vendors,
                              onTap: () => setState(() {
                                _filterType = _LedgerFilterType.vendors;
                              }),
                            ),
                            StandardChip(
                              label: 'Clients',
                              isSelected:
                                  _filterType == _LedgerFilterType.clients,
                              onTap: () => setState(() {
                                _filterType = _LedgerFilterType.clients;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.paddingLG),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.paddingLG,
                            vertical: AppSpacing.paddingSM,
                          ),
                          decoration: BoxDecoration(
                            color: AuthColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLG),
                            border: Border.all(
                              color: AuthColors.textMainWithOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            '${filtered.length} ${filtered.length == 1 ? 'ledger' : 'ledgers'}',
                            style: const TextStyle(
                              color: AuthColors.textSub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.paddingLG),
                        _buildLedgerList(filtered),
                        const SizedBox(height: AppSpacing.paddingXL),
                        _buildLedgerDetails(),
                      ],
                    ),
                  ),
                ),
                FloatingNavBar(
                  items: const [
                    NavBarItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      heroTag: 'nav_home',
                    ),
                    NavBarItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      heroTag: 'nav_pending',
                    ),
                    NavBarItem(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      heroTag: 'nav_schedule',
                    ),
                    NavBarItem(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      heroTag: 'nav_map',
                    ),
                    NavBarItem(
                      icon: Icons.event_available_rounded,
                      label: 'Cash Ledger',
                      heroTag: 'nav_cash_ledger',
                    ),
                  ],
                  currentIndex: -1,
                  onItemTapped: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
            if (_selectedLedgerId != null)
              Positioned(
                right: QuickActionMenu.standardRight,
                bottom: QuickActionMenu.standardBottom(context),
                child: QuickActionMenu(
                  actions: [
                    QuickActionItem(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      onTap: _refreshSelected,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_CombinedLedger> _applyFilters(List<_CombinedLedger> ledgers) {
    final query = _query.trim().toLowerCase();
    return ledgers.where((ledger) {
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
  }

  Widget _buildLedgerList(List<_CombinedLedger> ledgers) {
    if (ledgers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: const Text(
          'No combined ledgers available yet.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ledgers.map((ledger) {
        final isSelected = ledger.id == _selectedLedgerId;
        return GestureDetector(
          onTap: () => setState(() => _selectedLedgerId = ledger.id),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            decoration: BoxDecoration(
              color: isSelected
                  ? AuthColors.primaryWithOpacity(0.12)
                  : AuthColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              border: Border.all(
                color: isSelected
                    ? AuthColors.primary
                    : AuthColors.textMainWithOpacity(0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ledger.name,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ledger.accounts.length} accounts',
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLedgerDetails() {
    final ledger = _ledgers.firstWhere(
      (l) => l.id == _selectedLedgerId,
      orElse: () => _CombinedLedger.empty(),
    );

    if (ledger.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: const Text(
          'Select a combined ledger to view details.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ledger.name,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DashButton(
                label: 'Refresh',
                onPressed: _isRefreshing ? null : _refreshSelected,
                variant: DashButtonVariant.outlined,
                isLoading: _isRefreshing,
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              DashButton(
                label: 'Export',
                onPressed: _exportSelected,
                variant: DashButtonVariant.text,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'Last refreshed: ${_formatDateTime(ledger.lastRefreshedAt)}',
            style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
          const Text(
            'Accounts',
            style: TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Wrap(
            spacing: AppSpacing.paddingSM,
            runSpacing: AppSpacing.paddingSM,
            children: ledger.accounts.map((account) {
              return Chip(
                label: Text(account.name),
                backgroundColor: AuthColors.background,
                labelStyle: const TextStyle(color: AuthColors.textMain),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
}

enum _AccountType { employee, vendor, client }

enum _LedgerFilterType { all, employees, vendors, clients }

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
    required this.name,
    required this.accounts,
    required this.createdAt,
    required this.lastRefreshedAt,
  });

  final String id;
  final String name;
  final List<_AccountOption> accounts;
  final DateTime createdAt;
  final DateTime lastRefreshedAt;

  bool get isEmpty => id.isEmpty;

  _CombinedLedger copyWith({
    String? id,
    String? name,
    List<_AccountOption>? accounts,
    DateTime? createdAt,
    DateTime? lastRefreshedAt,
  }) {
    return _CombinedLedger(
      id: id ?? this.id,
      name: name ?? this.name,
      accounts: accounts ?? this.accounts,
      createdAt: createdAt ?? this.createdAt,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }

  factory _CombinedLedger.empty() => _CombinedLedger(
        id: '',
        name: '',
        accounts: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        lastRefreshedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
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
    return Wrap(
      spacing: AppSpacing.paddingLG,
      runSpacing: AppSpacing.paddingLG,
      children: [
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
      ],
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
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
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
                    fontSize: 16,
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
