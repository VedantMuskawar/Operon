import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/create_order_dialog.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectClientDialog extends StatefulWidget {
  const SelectClientDialog({super.key});

  @override
  State<SelectClientDialog> createState() => _SelectClientDialogState();
}

class _SelectClientDialogState extends State<SelectClientDialog> {
  late final TextEditingController _searchController;
  BuildContext? _providerContext;
  VoidCallback? _searchListener;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    if (_searchListener != null) {
      _searchController.removeListener(_searchListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _setupListener(BuildContext providerContext) {
    if (_providerContext == null) {
      _providerContext = providerContext;
      _searchListener = () {
        try {
          providerContext.read<ClientsCubit>().search(_searchController.text);
        } catch (e) {
          // Provider not available, ignore
        }
      };
      _searchController.addListener(_searchListener!);
    }
  }

  void _clearSearch(BuildContext context) {
    _searchController.clear();
    try {
      context.read<ClientsCubit>().search('');
    } catch (e) {
      // Provider not available yet, ignore
    }
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
              colors: [AuthColors.surface, AuthColors.background],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'Please select an organization first',
            style: TextStyle(color: AuthColors.textSub),
          ),
        ),
      );
    }

    final clientsRepository = context.read<ClientsRepository>();

    return BlocProvider(
      create: (_) => ClientsCubit(
        repository: clientsRepository,
        orgId: organization.id,
        analyticsRepository: context.read<AnalyticsRepository>(),
      )..loadRecentClients(),
      child: Builder(
        builder: (providerContext) {
          // Set up listener once we're inside the BlocProvider context
          _setupListener(providerContext);
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AuthColors.surface, AuthColors.background],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
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
                            color: AuthColors.textMain,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: AuthColors.textSub),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSearchBar(providerContext),
                  const SizedBox(height: 20),
                  Expanded(
                    child: BlocBuilder<ClientsCubit, ClientsState>(
                      builder: (context, state) {
                        if (state.searchQuery.isNotEmpty) {
                          return _SearchResultsSection(
                            state: state,
                            onClear: () => _clearSearch(providerContext),
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
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext providerContext) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
        return TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AuthColors.textMain),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: () => _clearSearch(providerContext),
                  )
                : null,
            hintText: 'Search clients by name or phone',
            hintStyle: const TextStyle(color: AuthColors.textDisabled),
            filled: true,
            fillColor: AuthColors.surface,
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
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
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
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DashButton(
                label: 'Clear',
                onPressed: onClear,
                variant: DashButtonVariant.text,
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
                style: const TextStyle(color: AuthColors.textSub),
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
        const SizedBox(height: 12),
        if (state.recentClients.isEmpty && !state.isRecentLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No clients found. Please create a client first.',
              style: TextStyle(color: AuthColors.textSub),
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
            color: AuthColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AuthColors.primaryWithOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: AuthColors.primary,
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
                        color: AuthColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phoneLabel,
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AuthColors.textSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
