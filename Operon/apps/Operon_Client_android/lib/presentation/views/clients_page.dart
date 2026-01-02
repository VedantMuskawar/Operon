import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/clients_page/client_analytics_page.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
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
  double _currentPage = 0;
  _ClientFilterType _filterType = _ClientFilterType.all;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _pageController = PageController()
      ..addListener(() {
        setState(() {
          _currentPage = _pageController.page ?? 0;
        });
      });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<ClientsCubit>().search(_searchController.text);
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
    switch (_filterType) {
      case _ClientFilterType.corporate:
        return clients.where((c) => c.isCorporate).toList();
      case _ClientFilterType.individual:
        return clients.where((c) => !c.isCorporate).toList();
      case _ClientFilterType.all:
        return clients;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageWorkspaceLayout(
          title: 'Clients',
          currentIndex: 4,
          onBack: () => context.go('/home'),
          onNavTap: (value) => context.go('/home', extra: value),
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final screenHeight = media.size.height;
              // Approximate available height: screen height minus status bar, header, nav, and padding
              final availableHeight = screenHeight - media.padding.top - 72 - media.padding.bottom - 80 - 24 - 48;
              // Reserve space for page indicator (24px) + spacing (16px) + scroll padding (48px)
              final pageViewHeight = (availableHeight - 24 - 16 - 48).clamp(400.0, 600.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Indicator (dots)
                  _PageIndicator(
                    pageCount: 2,
                    currentIndex: _currentPage,
                    onPageTap: (index) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: pageViewHeight,
                    child: PageView(
                      controller: _pageController,
                      children: [
                        BlocBuilder<ClientsCubit, ClientsState>(
                          builder: (context, state) {
                            final allClients = state.recentClients;
                            final filteredClients = _applyFilter(allClients);
                            
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Search Bar
                                  _buildSearchBar(state),
                                  const SizedBox(height: 16),
                                  // Filter Chips
                                  _ClientFilterChips(
                                    selectedFilter: _filterType,
                                    onFilterChanged: (filter) {
                                      setState(() => _filterType = filter);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Results count
                                  if (state.searchQuery.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        '${filteredClients.length} ${filteredClients.length == 1 ? 'client' : 'clients'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  // Search Results or Recent Clients
                                  if (state.searchQuery.isNotEmpty)
                                    _SearchResultsCard(
                                      state: state,
                                      onClear: _clearSearch,
                                    )
                                  else if (filteredClients.isEmpty && !state.isRecentLoading)
                                    _EmptyClientsState(
                                      onAddClient: _openContactPage,
                                    )
                                  else
                                    _RecentClientsList(
                                      state: state,
                                      clients: filteredClients,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SingleChildScrollView(
                          child: ClientAnalyticsPage(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Floating Action Button - only visible on Clients page
        if (_currentPage.round() == 0)
          Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final bottomPadding = media.padding.bottom;
              // Nav bar height (~80px) + safe area bottom + spacing (20px)
              final bottomOffset = 80 + bottomPadding + 20;
              return Positioned(
            right: 40,
                bottom: bottomOffset,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openContactPage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F4BFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6F4BFF).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSearchBar(ClientsState state) {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: state.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: _clearSearch,
              )
            : null,
        hintText: 'Search clients by name or phone',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1B1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final client = state.searchResults[index];
                return _ClientTile(client: client);
              },
            ),
        ],
      ),
    );
  }
}

class _RecentClientsList extends StatelessWidget {
  const _RecentClientsList({
    required this.state,
    required this.clients,
  });

  final ClientsState state;
  final List<ClientRecord> clients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recently added clients',
                style: TextStyle(
                  color: Colors.white,
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
        const SizedBox(height: 12),
        if (clients.isEmpty && !state.isRecentLoading)
          const SizedBox.shrink()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final client = clients[index];
              return _ClientTile(client: client);
            },
          ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client});

  final ClientRecord client;

  Color _getClientColor() {
    if (client.isCorporate) {
      return const Color(0xFF6F4BFF);
    }
    final hash = client.name.hashCode;
    final colors = [
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
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

    return InkWell(
      onTap: () => context.pushNamed('client-detail', extra: client),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F1F33).withOpacity(0.6),
              const Color(0xFF1A1A28).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: clientColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        clientColor,
                        clientColor.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: clientColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: -1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(client.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    client.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (client.isCorporate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: clientColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: clientColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.business,
                                    size: 12,
                                    color: Color(0xFF6F4BFF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Corporate',
                                    style: TextStyle(
                                      color: clientColor,
                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                  ),
                ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Phone
                      if (phoneLabel != '-')
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                phoneLabel,
                  style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Tags and Stats
            if (client.tags.isNotEmpty || orderCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Tags
                  if (client.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: client.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // Order Count
                  if (orderCount > 0) ...[
                    if (client.tags.isNotEmpty) const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5AD8A4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF5AD8A4).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: Color(0xFF5AD8A4),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$orderCount ${orderCount == 1 ? 'order' : 'orders'}',
                            style: const TextStyle(
                              color: Color(0xFF5AD8A4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
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
          _FilterChip(
            label: 'All',
            icon: Icons.people,
            isSelected: selectedFilter == _ClientFilterType.all,
            onTap: () => onFilterChanged(_ClientFilterType.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Corporate',
            icon: Icons.business,
            isSelected: selectedFilter == _ClientFilterType.corporate,
            onTap: () => onFilterChanged(_ClientFilterType.corporate),
          ),
          const SizedBox(width: 8),
          _FilterChip(
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF).withOpacity(0.2)
              : const Color(0xFF1B1B2C).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF6F4BFF)
                  : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState({required this.onAddClient});

  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1B2C).withOpacity(0.6),
            const Color(0xFF161622).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6F4BFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 32,
              color: Color(0xFF6F4BFF),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No clients yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first client to the system',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Client'),
            onPressed: onAddClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6F4BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No clients match "$query"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.pageCount,
    required this.currentIndex,
    required this.onPageTap,
  });

  final int pageCount;
  final double currentIndex;
  final ValueChanged<int> onPageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return GestureDetector(
            onTap: () => onPageTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6F4BFF) : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }
}

