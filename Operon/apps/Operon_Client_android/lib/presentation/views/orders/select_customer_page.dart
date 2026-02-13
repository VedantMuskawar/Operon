import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/views/orders/create_order_page.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernPageHeader(
        title: 'Select Customer',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<ClientsCubit, ClientsState>(
                builder: (context, state) {
                  return SingleChildScrollView(
                    padding: AppSpacing.pagePaddingAll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBar(state),
                        const SizedBox(height: AppSpacing.sectionSpacing),
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
      ),
    );
  }

  Widget _buildSearchBar(ClientsState state) {
    return StandardSearchBar(
      controller: _searchController,
      hintText: 'Search clients by name or phone',
      onChanged: (value) {
        // The search is handled by the controller listener
      },
      onClear: _clearSearch,
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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
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
                  style: AppTypography.h4,
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
            Text(
              'No clients found for "${state.searchQuery}".',
              style: AppTypography.body.copyWith(color: AppColors.textTertiary),
            )
          else
            Column(
              children: [
                for (int i = 0; i < state.searchResults.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.paddingMD),
                  _ClientTile(
                    client: state.searchResults[i],
                    onTap: () => onClientSelected(state.searchResults[i]),
                  ),
                ],
              ],
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
                style: AppTypography.h4,
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
        const SizedBox(height: AppSpacing.paddingMD),
        if (state.recentClients.isEmpty && !state.isRecentLoading)
          Text(
            'No clients found. Create a new client to get started.',
            style: AppTypography.body.copyWith(color: AppColors.textTertiary),
          )
        else
          Column(
            children: [
              for (int i = 0; i < state.recentClients.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.paddingMD),
                _ClientTile(
                  client: state.recentClients[i],
                  onTap: () => onClientSelected(state.recentClients[i]),
                ),
              ],
            ],
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.avatarMD,
              height: AppSpacing.avatarMD,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: AppSpacing.iconLG,
              ),
            ),
            const SizedBox(width: AppSpacing.itemSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: AppTypography.h4,
                  ),
                  const SizedBox(height: AppSpacing.paddingXS),
                  Text(
                    phoneLabel,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

