import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/create_order_page.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SelectCustomerPage extends StatefulWidget {
  const SelectCustomerPage({super.key});

  @override
  State<SelectCustomerPage> createState() => _SelectCustomerPageState();
}

class _SelectCustomerPageState extends State<SelectCustomerPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    // Load recent clients on init
    context.read<ClientsCubit>().subscribeToRecent();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<ClientsCubit>().search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<ClientsCubit>().search('');
  }

  void _onClientSelected(ClientRecord client) {
    // Navigate to create order page with selected client
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CreateOrderPage(client: client),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWorkspaceLayout(
      title: 'Select Customer',
      currentIndex: 1,
      onBack: () => Navigator.of(context).pop(),
      onNavTap: (value) => context.go('/home', extra: value),
      child: BlocBuilder<ClientsCubit, ClientsState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchBar(state),
                const SizedBox(height: 20),
                if (state.searchQuery.isNotEmpty)
                  _SearchResultsSection(
                    state: state,
                    onClear: _clearSearch,
                    onClientSelected: _onClientSelected,
                  )
                else
                  _RecentClientsSection(
                    state: state,
                    onClientSelected: _onClientSelected,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(ClientsState state) {
    return TextField(
      controller: _searchController,
      autofocus: true,
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

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.state,
    required this.onClear,
    required this.onClientSelected,
  });

  final ClientsState state;
  final VoidCallback onClear;
  final ValueChanged<ClientRecord> onClientSelected;

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
                return _ClientTile(
                  client: client,
                  onTap: () => onClientSelected(client),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RecentClientsSection extends StatelessWidget {
  const _RecentClientsSection({
    required this.state,
    required this.onClientSelected,
  });

  final ClientsState state;
  final ValueChanged<ClientRecord> onClientSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Clients',
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
            'No clients found. Create a new client to get started.',
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
              return _ClientTile(
                client: client,
                onTap: () => onClientSelected(client),
              );
            },
          ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.client,
    required this.onTap,
  });

  final ClientRecord client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty ? client.phones.first['number'] as String : '-');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF6F4BFF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phoneLabel,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

