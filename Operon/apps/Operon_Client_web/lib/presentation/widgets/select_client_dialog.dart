import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/create_order_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectClientDialog extends StatefulWidget {
  const SelectClientDialog({super.key});

  @override
  State<SelectClientDialog> createState() => _SelectClientDialogState();
}

class _SelectClientDialogState extends State<SelectClientDialog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
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

  void _onClientSelected(Client client) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => CreateOrderDialog(client: client),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'Please select an organization first',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final clientsRepository = context.read<ClientsRepository>();

    return BlocProvider(
      create: (_) => ClientsCubit(
        repository: clientsRepository,
        orgId: organization.id,
      )..loadRecentClients(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Customer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSearchBar(),
              const SizedBox(height: 20),
              Expanded(
                child: BlocBuilder<ClientsCubit, ClientsState>(
                  builder: (context, state) {
                    if (state.searchQuery.isNotEmpty) {
                      return _SearchResultsSection(
                        state: state,
                        onClear: _clearSearch,
                        onClientSelected: _onClientSelected,
                      );
                    } else {
                      return _RecentClientsSection(
                        state: state,
                        onClientSelected: _onClientSelected,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
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
      },
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
  final ValueChanged<Client> onClientSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No clients found for "${state.searchQuery}".',
                style: const TextStyle(color: Colors.white60),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
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
  final ValueChanged<Client> onClientSelected;

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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No clients found. Please create a client first.',
              style: TextStyle(color: Colors.white60),
            ),
          )
          else
          Expanded(
            child: ListView.separated(
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

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty
            ? (client.phones.first['number'] as String? ?? '-')
            : '-');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
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
      ),
    );
  }
}
