import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/clients_page/client_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/utils/debouncer.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/standard_page_indicator.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  late final PageController _pageController;
  late final Debouncer _searchDebouncer;
  late final ScrollController _scrollController;
  double _currentPage = 0;
  _ClientFilterType _filterType = _ClientFilterType.all;
  List<ClientRecord>? _cachedFilteredClients;
  _ClientFilterType? _lastFilterType;
  int _currentLimit = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(duration: const Duration(milliseconds: 300));
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _currentPage = _pageController.page ?? 0;
          });
        }
      });
    _scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _currentLimit += 20;
    context.read<ClientsCubit>().subscribeToRecent(limit: _currentLimit);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
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

  List<ClientRecord> _applyFilter(List<ClientRecord> clients) {
    // Optimized filter with proper caching
    if (_lastFilterType == _filterType && 
        _cachedFilteredClients != null && 
        _cachedFilteredClients!.length == clients.length) {
      return _cachedFilteredClients!;
    }

    _lastFilterType = _filterType;
    
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
                      child: PageView(
                        controller: _pageController,
                        physics: const PageScrollPhysics(),
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
                      const SizedBox(height: 12),
                      StandardPageIndicator(
                        pageCount: 2,
                        currentIndex: _currentPage,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                QuickNavBar(
                  currentIndex: -1, // -1 means no selection when on this page
                  onTap: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
            // Floating Action Button - only visible on Clients page
            if (_currentPage.round() == 0)
              Positioned(
                right: 24,
                bottom: QuickActionMenu.standardBottom(context),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openContactPage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AuthColors.primary,
                            AuthColors.primaryVariant,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.fab,
                      ),
                      child: Icon(Icons.add, color: AuthColors.textMain, size: 24),
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
                const SizedBox(height: 16),
                _ClientFilterChips(
                  selectedFilter: filterType,
                  onFilterChanged: onFilterChanged,
                ),
                const SizedBox(height: 24),
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

        final allClients = state.recentClients;
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
                    const SizedBox(height: 16),
                    _ClientFilterChips(
                      selectedFilter: filterType,
                      onFilterChanged: onFilterChanged,
                    ),
                    const SizedBox(height: AppSpacing.itemSpacing),
                    if (state.searchQuery.isEmpty && !state.isRecentLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${filteredClients.length} ${filteredClients.length == 1 ? 'client' : 'clients'}',
                          style: TextStyle(
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
              SliverToBoxAdapter(
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
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.itemSpacing)),
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          if (index >= filteredClients.length) {
                                            return isLoadingMore
                                                ? const Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child: Center(child: CircularProgressIndicator()),
                                                  )
                                                : const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: AppSpacing.itemSpacing),
                                            child: _ClientTile(
                                              key: ValueKey(filteredClients[index].id),
                                              client: filteredClients[index],
                                            ),
                                          );
                                        },
                                        childCount: filteredClients.length + (isLoadingMore ? 1 : 0),
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
        color: AppColors.cardBackgroundElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AppColors.borderDefault),
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
                  style: AppTypography.h4,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.isSearchLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.searchResults.isEmpty)
            _EmptySearchState(query: state.searchQuery)
          else
            ...state.searchResults.map((client) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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

  static final _colorCache = <String, Color>{};

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
    return color;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final clientColor = _getClientColor();
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty ? (client.phones.first['e164'] as String?) ?? '-' : '-');
    final orderCount = (client.stats['orders'] as num?)?.toInt() ?? 0;
    final subtitleParts = <String>[];
    if (phoneLabel != '-') subtitleParts.add(phoneLabel);
    if (client.isCorporate) subtitleParts.add('Corporate');
    final subtitle = subtitleParts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
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
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AuthColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 12, color: AuthColors.success),
                      const SizedBox(width: 4),
                      Text(
                        orderCount.toString(),
                        style: TextStyle(
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
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  spacing: 4,
                  children: client.tags.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AuthColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
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

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No clients match "$query"',
            style: TextStyle(
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

