import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/models/combined_ledger_model.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class AccountsLedgerPage extends StatefulWidget {
  const AccountsLedgerPage({super.key});

  @override
  State<AccountsLedgerPage> createState() => _AccountsLedgerPageState();
}

class _AccountsLedgerPageState extends State<AccountsLedgerPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  late final ScrollController _scrollController;
  double _currentPage = 0;
  _LedgerFilterType _filterType = _LedgerFilterType.all;
  List<CombinedLedger>? _cachedFilteredLedgers;
  _LedgerFilterType? _lastFilterType;
  List<CombinedLedger> _ledgers = [];
  bool _isLoading = false;
  final bool _isRefreshing = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() => setState(() => _query = _searchController.text));
    _pageController = PageController()..addListener(_onPageChanged);
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLedgers());
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    final newPage = _pageController.page ?? 0;
    final roundedPage = newPage.round();
    if (roundedPage != _currentPage.round()) {
      setState(() => _currentPage = newPage);
    }
  }

  Future<void> _loadLedgers() async {
    if (_isLoading) return;
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    if (orgId == null) return;

    setState(() => _isLoading = true);
    try {
        final snapshot = await FirebaseFirestore.instance
          .collection('COMBINED_ACCOUNTS')
          .where('organizationId', isEqualTo: orgId)
          .orderBy('updatedAt', descending: true)
          .get();

      final ledgers = snapshot.docs.map((doc) {
        final data = doc.data();
        final accountsLedgerId = (data['accountId'] as String?) ?? doc.id;
        final ledgerName = (data['accountName'] as String?) ??
          (data['ledgerName'] as String?) ??
          'Combined Ledger';
        final accountsData = (data['accounts'] as List<dynamic>?) ?? [];
        final accounts = accountsData
            .whereType<Map<String, dynamic>>()
            .map((account) {
              final typeRaw = (account['type'] as String?) ?? 'client';
              final id = account['id'] as String? ?? '';
              final name = account['name'] as String? ?? 'Unknown';
              final type = _accountTypeFromApi(typeRaw);
              return AccountOption(
                key: '${type.name}:$id',
                id: id,
                name: name,
                type: type,
              );
            })
            .where((account) => account.id.isNotEmpty)
            .toList();

        final updatedAt = _dateFromTimestamp(data['updatedAt']) ?? DateTime.now();
        final createdAt = _dateFromTimestamp(data['createdAt']) ?? updatedAt;
        final lastLedgerRefreshAt =
          _dateFromTimestamp(data['lastLedgerRefreshAt']);
        final lastLedgerId = data['lastLedgerId'] as String?;

        return CombinedLedger(
          id: doc.id,
          accountsLedgerId: accountsLedgerId,
          name: ledgerName,
          accounts: accounts,
          createdAt: createdAt,
          lastRefreshedAt: lastLedgerRefreshAt ?? updatedAt,
          lastLedgerId: lastLedgerId,
        );
      }).toList();

      setState(() {
        _ledgers = ledgers;
        _cachedFilteredLedgers = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load ledgers: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<CombinedLedger> _applyFilter(List<CombinedLedger> ledgers) {
    if (_lastFilterType == _filterType &&
        _cachedFilteredLedgers != null &&
        _cachedFilteredLedgers!.length == ledgers.length) {
      return _cachedFilteredLedgers!;
    }

    _lastFilterType = _filterType;

    var filtered = ledgers;
    if (_filterType != _LedgerFilterType.all) {
      final matchType = switch (_filterType) {
        _LedgerFilterType.employees => AccountType.employee,
        _LedgerFilterType.vendors => AccountType.vendor,
        _LedgerFilterType.clients => AccountType.client,
        _LedgerFilterType.all => null,
      };
      if (matchType != null) {
        filtered = ledgers
            .where((ledger) =>
                ledger.accounts.any((account) => account.type == matchType))
            .toList();
      }
    }

    if (_query.isNotEmpty) {
      final query = _query.trim().toLowerCase();
      filtered = filtered.where((ledger) {
        final matchesName = ledger.name.toLowerCase().contains(query);
        final matchesAccount = ledger.accounts
            .any((account) => account.name.toLowerCase().contains(query));
        return matchesName || matchesAccount;
      }).toList();
    }

    _cachedFilteredLedgers = filtered;
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final appAccessRole = orgState.appAccessRole;
    final canAccess = appAccessRole?.canAccessPage('accountsLedger') ?? false;

    if (!canAccess && !(appAccessRole?.isAdmin ?? false)) {
      return const Scaffold(
        backgroundColor: AuthColors.background,
        appBar: ModernPageHeader(title: 'Accounts'),
        body: Center(
          child: Text('You do not have access to Accounts.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(title: 'Accounts'),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const PageScrollPhysics(),
                    children: [
                      _AccountsListView(
                        ledgers: _ledgers,
                        isLoading: _isLoading,
                        filterType: _filterType,
                        onFilterChanged: (filter) {
                          setState(() {
                            _filterType = filter;
                            _cachedFilteredLedgers = null;
                            _lastFilterType = null;
                          });
                        },
                        onApplyFilter: _applyFilter,
                        searchController: _searchController,
                        scrollController: _scrollController,
                        onClearSearch: () => setState(() => _query = ''),
                      ),
                      _AccountsAnalyticsPage(ledgers: _ledgers),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
                _CompactPageIndicator(
                  pageCount: 2,
                  currentIndex: _currentPage,
                ),
                const SizedBox(height: AppSpacing.paddingLG),
              ],
            ),
            Positioned(
              right: QuickActionMenu.standardRight,
              bottom: QuickActionMenu.standardBottom(context),
              child: QuickActionMenu(
                actions: [
                  QuickActionItem(
                    icon: Icons.refresh,
                    label: 'Refresh',
                    onTap: _isRefreshing ? () {} : _loadLedgers,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AccountType _accountTypeFromApi(String value) {
    return switch (value) {
      'employee' => AccountType.employee,
      'vendor' => AccountType.vendor,
      _ => AccountType.client,
    };
  }

  DateTime? _dateFromTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _AccountsListView extends StatelessWidget {
  const _AccountsListView({
    required this.ledgers,
    required this.isLoading,
    required this.filterType,
    required this.onFilterChanged,
    required this.onApplyFilter,
    required this.searchController,
    required this.scrollController,
    required this.onClearSearch,
  });

  final List<CombinedLedger> ledgers;
  final bool isLoading;
  final _LedgerFilterType filterType;
  final ValueChanged<_LedgerFilterType> onFilterChanged;
  final List<CombinedLedger> Function(List<CombinedLedger>) onApplyFilter;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (isLoading && ledgers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredLedgers = onApplyFilter(ledgers);
    final totalAccounts = ledgers.fold<int>(0, (total, ledger) => total + ledger.accounts.length);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LedgerStatsHeader(totalAccounts: totalAccounts),
                const SizedBox(height: AppSpacing.paddingLG),
                StandardSearchBar(
                  controller: searchController,
                  hintText: 'Search ledgers...',
                  onClear: onClearSearch,
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                _LedgerFilterChips(
                  selectedFilter: filterType,
                  onFilterChanged: onFilterChanged,
                ),
                const SizedBox(height: AppSpacing.itemSpacing),
                Text(
                  '${filteredLedgers.length} ${filteredLedgers.length == 1 ? 'ledger' : 'ledgers'}',
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filteredLedgers.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'No ledgers found.',
                style: TextStyle(color: AuthColors.textSub),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            sliver: AnimationLimiter(
              child: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 200),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        curve: Curves.easeOut,
                        child: _LedgerTile(
                          key: ValueKey(filteredLedgers[index].id),
                          ledger: filteredLedgers[index],
                          onTap: () => _openAccountDetail(
                            context,
                            filteredLedgers[index],
                          ),
                        ),
                      ),
                    ),
                  ),
                  childCount: filteredLedgers.length,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openAccountDetail(BuildContext context, CombinedLedger ledger) {
    context.push(
      '/account-detail',
      extra: ledger,
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({
    super.key,
    required this.ledger,
    required this.onTap,
  });

  final CombinedLedger ledger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ledger.name,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${ledger.accounts.length} accounts',
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerFilterChips extends StatelessWidget {
  const _LedgerFilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final _LedgerFilterType selectedFilter;
  final ValueChanged<_LedgerFilterType> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.paddingSM,
      runSpacing: AppSpacing.paddingSM,
      children: [
        StandardChip(
          label: 'All',
          isSelected: selectedFilter == _LedgerFilterType.all,
          onTap: () => onFilterChanged(_LedgerFilterType.all),
        ),
        StandardChip(
          label: 'Employees',
          isSelected: selectedFilter == _LedgerFilterType.employees,
          onTap: () => onFilterChanged(_LedgerFilterType.employees),
        ),
        StandardChip(
          label: 'Vendors',
          isSelected: selectedFilter == _LedgerFilterType.vendors,
          onTap: () => onFilterChanged(_LedgerFilterType.vendors),
        ),
        StandardChip(
          label: 'Clients',
          isSelected: selectedFilter == _LedgerFilterType.clients,
          onTap: () => onFilterChanged(_LedgerFilterType.clients),
        ),
      ],
    );
  }
}

class _LedgerStatsHeader extends StatelessWidget {
  const _LedgerStatsHeader({required this.totalAccounts});

  final int totalAccounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              color: AuthColors.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance, color: AuthColors.secondary),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Accounts',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                ),
                Text(
                  totalAccounts.toString(),
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

class _AccountsAnalyticsPage extends StatelessWidget {
  const _AccountsAnalyticsPage({required this.ledgers});

  final List<CombinedLedger> ledgers;

  @override
  Widget build(BuildContext context) {
    final totalLedgers = ledgers.length;
    final totalAccounts = ledgers.fold<int>(0, (total, ledger) => total + ledger.accounts.length);
    final avgAccounts = totalLedgers > 0 ? (totalAccounts / totalLedgers).round() : 0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ledger Analytics',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingXL),
                Wrap(
                  spacing: AppSpacing.paddingLG,
                  runSpacing: AppSpacing.paddingLG,
                  children: [
                    _AnalyticsCard(
                      title: 'Total Ledgers',
                      value: totalLedgers.toString(),
                      icon: Icons.list,
                      color: AuthColors.primary,
                    ),
                    _AnalyticsCard(
                      title: 'Total Accounts',
                      value: totalAccounts.toString(),
                      icon: Icons.people,
                      color: AuthColors.secondary,
                    ),
                    _AnalyticsCard(
                      title: 'Avg Accounts',
                      value: avgAccounts.toString(),
                      icon: Icons.trending_up,
                      color: AuthColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            title,
            style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
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
    );
  }
}

class _CompactPageIndicator extends StatelessWidget {
  const _CompactPageIndicator({
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (currentIndex.round() == index)
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.2),
          ),
        ),
      ),
    );
  }
}

enum _LedgerFilterType { all, employees, vendors, clients }
