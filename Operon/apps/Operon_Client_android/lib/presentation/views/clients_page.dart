import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/clients_page/client_analytics_page.dart';
import 'package:dash_mobile/presentation/utils/debouncer.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

enum _ClientFilterType {
  all,
  corporate,
  individual,
}

class _ClientsPageState extends State<ClientsPage> {
  late final TextEditingController _searchController;
  late final Debouncer _searchDebouncer;
  late final ScrollController _scrollController;
  double _currentPage = 0;
  _ClientFilterType _filterType = _ClientFilterType.all;
  List<ClientRecord>? _cachedFilteredClients;
  _ClientFilterType? _lastFilterType;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 300));
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    final cubit = context.read<ClientsCubit>();
    // Don't paginate when searching (server-side search returns all results)
    if (!cubit.hasMore || cubit.state.searchQuery.isNotEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      await cubit.loadMoreClients(limit: _pageSize);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _searchDebouncer.run(() {
      if (mounted) {
        context.read<ClientsCubit>().search(_searchController.text);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<ClientsCubit>().search('');
  }

  void _openContactPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ContactPage(),
        fullscreenDialog: true,
      ),
    );
  }

  int? _cachedClientsListHash;

  List<ClientRecord> _applyFilter(List<ClientRecord> clients) {
    // Optimized filter with proper caching including clients list hash
    final clientsHash = clients.length;
    if (_lastFilterType == _filterType && 
        _cachedFilteredClients != null && 
        _cachedFilteredClients!.length == clients.length &&
        _cachedClientsListHash == clientsHash) {
      return _cachedFilteredClients!;
    }

    _lastFilterType = _filterType;
    _cachedClientsListHash = clientsHash;
    
    switch (_filterType) {
      case _ClientFilterType.corporate:
        _cachedFilteredClients = clients.where((c) => c.isCorporate).toList();
        break;
      case _ClientFilterType.individual:
        _cachedFilteredClients = clients.where((c) => !c.isCorporate).toList();
        break;
      case _ClientFilterType.all:
        _cachedFilteredClients = clients;
        break;
    }
    
    return _cachedFilteredClients!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: const ModernPageHeader(
        title: 'Clients',
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                      child: IndexedStack(
                        index: _currentPage.round(),
                        children: [
                          _ClientsListView(
                            filterType: _filterType,
                            scrollController: _scrollController,
                            isLoadingMore: _isLoadingMore,
                            onFilterChanged: (filter) {
                              setState(() {
                                _filterType = filter;
                                _cachedFilteredClients = null;
                                _lastFilterType = null;
                              });
                            },
                            onApplyFilter: _applyFilter,
                            searchController: _searchController,
                            onClearSearch: _clearSearch,
                            onOpenContactPage: _openContactPage,
                          ),
                          const ClientAnalyticsPage(),
                        ],
                      ),
                    ),
                      const SizedBox(height: AppSpacing.paddingSM),
                      _CompactPageIndicator(
                        pageCount: 2,
                        currentIndex: _currentPage,
                        onPageSelected: (index) {
                          setState(() {
                            _currentPage = index.toDouble();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.paddingLG),
                    ],
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
                  currentIndex: -1, // -1 means no selection when on this page
                  onItemTapped: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
            // Floating Action Button - only visible on Clients page
            if (_currentPage.round() == 0)
              Positioned(
                right: 24,
                bottom: QuickActionMenu.standardBottom(context),
                child: Material(
                  color: AuthColors.transparent,
                  child: InkWell(
                    onTap: _openContactPage,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AuthColors.primary,
                            AuthColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                        boxShadow: [
                          BoxShadow(
                            color: AuthColors.primaryWithOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: AuthColors.textMain, size: 24),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientsListView extends StatelessWidget {
  const _ClientsListView({
    required this.filterType,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onFilterChanged,
    required this.onApplyFilter,
    required this.searchController,
    required this.onClearSearch,
    required this.onOpenContactPage,
  });

  final _ClientFilterType filterType;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final ValueChanged<_ClientFilterType> onFilterChanged;
  final List<ClientRecord> Function(List<ClientRecord>) onApplyFilter;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenContactPage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      buildWhen: (previous, current) {
        // Only rebuild when relevant state changes
        return previous.recentClients != current.recentClients ||
            previous.status != current.status ||
            previous.searchQuery != current.searchQuery ||
            previous.searchResults != current.searchResults ||
            previous.isRecentLoading != current.isRecentLoading ||
            previous.isSearchLoading != current.isSearchLoading;
      },
      builder: (context, state) {
        // Error state
        if (state.status == ViewStatus.failure) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                _buildSearchBar(context, state),
                const SizedBox(height: AppSpacing.paddingLG),
                _ClientFilterChips(
                  selectedFilter: filterType,
                  onFilterChanged: onFilterChanged,
                ),
                const SizedBox(height: AppSpacing.paddingXXL),
                ErrorStateWidget(
                  message: state.message ?? 'Failed to load clients',
                  errorType: ErrorType.network,
                  onRetry: () {
                    context.read<ClientsCubit>().subscribeToRecent();
                  },
                ),
              ],
            ),
          );
        }

        // Use server-side search results if query exists, otherwise use recent clients
        final allClients = state.searchQuery.isNotEmpty
            ? state.searchResults
            : state.recentClients;
        final filteredClients = onApplyFilter(allClients);

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
                    _buildSearchBar(context, state),
                    const SizedBox(height: AppSpacing.paddingLG),
                    _ClientFilterChips(
                      selectedFilter: filterType,
                      onFilterChanged: onFilterChanged,
                    ),
                    const SizedBox(height: AppSpacing.itemSpacing),
                    if (state.searchQuery.isEmpty && !state.isRecentLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                        child: Text(
                          '${filteredClients.length} ${filteredClients.length == 1 ? 'client' : 'clients'}',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (state.isRecentLoading && allClients.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: _SearchResultsCard(
                  state: state,
                  onClear: onClearSearch,
                ),
              )
            else if (filteredClients.isEmpty && !state.isRecentLoading)
              SliverFillRemaining(
                child: _EmptyClientsState(
                  onAddClient: onOpenContactPage,
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recently added clients',
                          style: TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (state.isRecentLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.itemSpacing)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                sliver: AnimationLimiter(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= filteredClients.length) {
                          return isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSpacing.paddingLG),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: _ClientTile(
                                key: ValueKey(filteredClients[index].id),
                                client: filteredClients[index],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredClients.length + (isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context, ClientsState state) {
    return StandardSearchBar(
      controller: searchController,
      hintText: 'Search clients by name or phone',
      onChanged: (value) {
        // The debouncer in the parent handles the actual search
      },
      onClear: onClearSearch,
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.state,
    required this.onClear,
  });

  final ClientsState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
                const Expanded(
                  child: Text(
                    'Search Results',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.textMain,
                    ),
                  ),
                ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          if (state.isSearchLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingXL),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.searchResults.isEmpty)
            _EmptySearchState(query: state.searchQuery)
          else
            ...state.searchResults.map((client) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                  child: _ClientTile(
                    key: ValueKey(client.id),
                    client: client,
                  ),
                )),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({super.key, required this.client});

  final ClientRecord client;

  // Max cache size to prevent unbounded memory growth
  static const int _maxCacheSize = 500;
  static final _colorCache = <String, Color>{};
  static final _initialsCache = <String, String>{};
  static final _subtitleCache = <String, String>{};

  void _maintainCacheSize<K, V>(Map<K, V> cache) {
    if (cache.length > _maxCacheSize) {
      // Clear cache if it grows too large to prevent memory leaks
      cache.clear();
    }
  }

  Color _getClientColor() {
    if (client.isCorporate) {
      return AuthColors.primary;
    }
    
    final cacheKey = client.id;
    if (_colorCache.containsKey(cacheKey)) {
      return _colorCache[cacheKey]!;
    }
    
    final hash = client.name.hashCode;
    final colors = [
      AuthColors.success,
      AuthColors.secondary,
      AuthColors.primary,
      AuthColors.error,
    ];
    final color = colors[hash.abs() % colors.length];
    _colorCache[cacheKey] = color;
    _maintainCacheSize(_colorCache);
    return color;
  }

  String _getInitials(String name) {
    if (_initialsCache.containsKey(name)) {
      return _initialsCache[name]!;
    }
    
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase());
    _initialsCache[name] = initials;
    _maintainCacheSize(_initialsCache);
    return initials;
  }

  String _getSubtitle() {
    final cacheKey = '${client.id}_${client.primaryPhone}_${client.isCorporate}';
    if (_subtitleCache.containsKey(cacheKey)) {
      return _subtitleCache[cacheKey]!;
    }
    
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty ? (client.phones.first['e164'] as String?) ?? '-' : '-');
    final subtitleParts = <String>[];
    if (phoneLabel != '-') subtitleParts.add(phoneLabel);
    if (client.isCorporate) subtitleParts.add('Corporate');
    final subtitle = subtitleParts.join(' • ');
    _subtitleCache[cacheKey] = subtitle;
    _maintainCacheSize(_subtitleCache);
    return subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final clientColor = _getClientColor();
    final subtitle = _getSubtitle();
    final orderCount = (client.stats['orders'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      ),
      child: DataList(
        title: client.name,
        subtitle: subtitle.isNotEmpty ? subtitle : null,
        leading: DataListAvatar(
          initial: _getInitials(client.name),
          radius: 28,
          statusRingColor: clientColor,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (orderCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM, vertical: AppSpacing.paddingXS),
                  decoration: BoxDecoration(
                    color: AuthColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 12, color: AuthColors.success),
                      const SizedBox(width: AppSpacing.paddingXS),
                      Text(
                        orderCount.toString(),
                        style: const TextStyle(
                          color: AuthColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (client.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.paddingSM),
                child: Wrap(
                  spacing: 4,
                  children: client.tags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapSM, vertical: AppSpacing.paddingXS / 2),
                      decoration: BoxDecoration(
                        color: AuthColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingLG),
        onTap: () => context.pushNamed('client-detail', extra: client),
      ),
    );
  }
}

class _ClientFilterChips extends StatelessWidget {
  const _ClientFilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final _ClientFilterType selectedFilter;
  final ValueChanged<_ClientFilterType> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          StandardChip(
            label: 'All',
            icon: Icons.people,
            isSelected: selectedFilter == _ClientFilterType.all,
            onTap: () => onFilterChanged(_ClientFilterType.all),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          StandardChip(
            label: 'Corporate',
            icon: Icons.business,
            isSelected: selectedFilter == _ClientFilterType.corporate,
            onTap: () => onFilterChanged(_ClientFilterType.corporate),
          ),
          const SizedBox(width: AppSpacing.paddingSM),
          StandardChip(
            label: 'Individual',
            icon: Icons.person,
            isSelected: selectedFilter == _ClientFilterType.individual,
            onTap: () => onFilterChanged(_ClientFilterType.individual),
          ),
        ],
      ),
    );
  }
}


class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState({required this.onAddClient});

  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.people_outline,
      title: 'No clients yet',
      message: 'Start by adding your first client to the system',
      actionLabel: 'Add Client',
      onAction: onAddClient,
      iconColor: AuthColors.primary,
    );
  }
}

class _CompactPageIndicator extends StatelessWidget {
  const _CompactPageIndicator({
    required this.pageCount,
    required this.currentIndex,
    this.onPageSelected,
  });

  final int pageCount;
  final double currentIndex;
  final ValueChanged<int>? onPageSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Allow clicking on empty space to cycle pages
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          pageCount,
          (index) {
            final isActive = currentIndex.round() == index;
            return GestureDetector(
              onTap: () => onPageSelected?.call(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 24 : 6,
                height: 3,
                decoration: BoxDecoration(
                  color: isActive ? AuthColors.primary : AuthColors.textMainWithOpacity(0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingXXXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withValues(alpha: 0.5),
          ),
                    const SizedBox(height: AppSpacing.paddingLG),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'No clients match "$query"',
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

