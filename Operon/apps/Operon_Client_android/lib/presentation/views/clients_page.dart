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

class _ClientsPageState extends State<ClientsPage> {
  late final TextEditingController _searchController;
  late final PageController _pageController;
  double _currentPage = 0;

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
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSearchBar(state),
                                  const SizedBox(height: 20),
                                  if (state.searchQuery.isNotEmpty)
                                    _SearchResultsCard(
                                      state: state,
                                      onClear: _clearSearch,
                                    ),
                                  const SizedBox(height: 12),
                                  _RecentClientsList(state: state),
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
          Positioned(
            right: 40,
            bottom: 120, // Fixed position: 80px (nav bar) + 20px (spacing)
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
            Text(
              'No clients found for "${state.searchQuery}".',
              style: const TextStyle(color: Colors.white60),
            )
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
  const _RecentClientsList({required this.state});

  final ClientsState state;

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
        if (state.recentClients.isEmpty && !state.isRecentLoading)
          const Text(
            'You haven\'t added any clients yet. Tap the + button to get started.',
            style: TextStyle(color: Colors.white60),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.recentClients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final client = state.recentClients[index];
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

  @override
  Widget build(BuildContext context) {
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty ? client.phones.first['number'] as String : '-');
    final createdAtLabel = client.createdAt != null
        ? _formatDate(client.createdAt!)
        : 'Recently added';

    return InkWell(
      onTap: () => context.pushNamed('client-detail', extra: client),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  createdAtLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              phoneLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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

