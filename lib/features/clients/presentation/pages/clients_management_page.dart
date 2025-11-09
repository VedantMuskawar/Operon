import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../contexts/organization_context.dart';
import '../../../../core/models/client.dart';
import '../../../../core/navigation/organization_navigation_scope.dart';
import '../../../../core/repositories/client_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/realtime_list_cache_mixin.dart';
import '../../bloc/clients_bloc.dart';
import '../../bloc/clients_event.dart';
import '../../bloc/clients_state.dart';

class ClientsManagementPage extends StatelessWidget {
  const ClientsManagementPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        final organizationName = orgContext.organizationName ?? 'Organization';

        if (organizationId == null) {
          return const Center(
            child: Text(
              'Organization not found',
              style: TextStyle(color: AppTheme.textPrimaryColor),
            ),
          );
        }

        final navigation = OrganizationNavigationScope.of(context);

        return BlocProvider(
          create: (context) =>
              ClientsBloc(clientRepository: ClientRepository())
                ..add(ClientsRequested(organizationId: organizationId)),
          child: ClientsManagementView(
            organizationId: organizationId,
            organizationName: organizationName,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack ?? navigation?.goHome,
          ),
        );
      },
    );
  }
}

class ClientsManagementView extends StatefulWidget {
  const ClientsManagementView({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.userRole,
    this.onBack,
  });

  final String organizationId;
  final String organizationName;
  final int userRole;
  final VoidCallback? onBack;

  @override
  State<ClientsManagementView> createState() => _ClientsManagementViewState();
}

class _ClientsManagementViewState
    extends RealtimeListCacheState<ClientsManagementView, Client> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  String _statusFilter = _statusAll;

  static const String _statusAll = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    final bloc = context.read<ClientsBloc>();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      bloc.add(const ClientsClearSearch());
    } else {
      bloc.add(ClientsSearchQueryChanged(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientsBloc, ClientsState>(
      listener: (context, state) {
        if (state.status == ClientsStatus.success) {
          applyRealtimeItems(
            state.visibleClients,
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == ClientsStatus.empty) {
          applyRealtimeEmpty(
            searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
          );
        } else if (state.status == ClientsStatus.initial) {
          resetRealtimeSnapshot();
        }

        if (state.status == ClientsStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        final sourceClients =
            hasRealtimeData ? realtimeItems : state.visibleClients;
        final clients = _applyStatusFilter(sourceClients);
        final effectiveSearch =
            state.searchQuery.isNotEmpty ? state.searchQuery : realtimeSearchQuery ?? '';

        return PageContainer(
          fullHeight: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Clients',
                role: _roleLabel(widget.userRole),
                onBack: widget.onBack,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Manage client relationships for ${widget.organizationName}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              _buildSummary(
                state.metrics,
                state.status == ClientsStatus.loading,
              ),
              const SizedBox(height: AppTheme.spacingLg),
              _buildToolbar(context, state),
              const SizedBox(height: AppTheme.spacingLg),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildContent(
                      state,
                      clients,
                      searchQuery: effectiveSearch,
                      tableWidth: constraints.maxWidth,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(ClientsMetrics metrics, bool isLoading) {
    return ClientsSummaryStrip(metrics: metrics, isLoading: isLoading);
  }

  Widget _buildToolbar(BuildContext context, ClientsState state) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181C1F),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              controller: _searchController,
              hintText: 'Search clients by name, phone, email, or tags...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? const Icon(Icons.close, size: 18)
                  : null,
              onSuffixIconTap: state.searchQuery.isNotEmpty
                  ? () {
                      _searchController.clear();
                      context.read<ClientsBloc>().add(
                        const ClientsClearSearch(),
                      );
                    }
                  : null,
              variant: CustomTextFieldVariant.search,
            ),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          SizedBox(width: 220, child: _buildStatusDropdown()),
          const SizedBox(width: AppTheme.spacingLg),
          CustomButton(
            text: 'Refresh',
            variant: CustomButtonVariant.secondary,
            isLoading: state.isRefreshing,
            isDisabled: state.status == ClientsStatus.loading,
            onPressed: () {
              context.read<ClientsBloc>().add(const ClientsRefreshed());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return CustomDropdown<String>(
      value: _statusFilter,
      labelText: 'Status',
      items: const [
        DropdownMenuItem(value: _statusAll, child: Text('All Statuses')),
        DropdownMenuItem(value: ClientStatus.active, child: Text('Active')),
        DropdownMenuItem(value: ClientStatus.inactive, child: Text('Inactive')),
        DropdownMenuItem(value: ClientStatus.archived, child: Text('Archived')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildContent(
    ClientsState state,
    List<Client> clients, {
    required String searchQuery,
    required double tableWidth,
  }) {
    final bool waitingForFirstLoad = !hasRealtimeData &&
        (state.status == ClientsStatus.initial ||
            state.status == ClientsStatus.loading);

    if (waitingForFirstLoad) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (state.status == ClientsStatus.failure) {
      return _buildError(state.errorMessage ?? 'Something went wrong');
    }

    final bool shouldShowEmpty =
        state.status == ClientsStatus.empty || (hasRealtimeData && clients.isEmpty);

    if (shouldShowEmpty) {
      final hasSearch = searchQuery.isNotEmpty;
      return _buildEmpty(hasSearch);
    }

    final table = ClientsTable(
      clients: clients,
      scrollController: _verticalScrollController,
      horizontalController: _horizontalScrollController,
      hasMore: state.hasMore,
      isLoadingMore: state.isFetchingMore,
      onLoadMore: () =>
          context.read<ClientsBloc>().add(const ClientsLoadMore()),
      availableWidth: tableWidth,
    );

    final bool showOverlay = hasRealtimeData &&
        (state.status == ClientsStatus.loading || state.isRefreshing);

    return withRealtimeBusyOverlay(
      child: table,
      showOverlay: showOverlay,
      overlayColor: Colors.black.withValues(alpha: 0.18),
      progressIndicator: const CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildEmpty(bool isSearch) {
    final icon = isSearch ? Icons.search_off : Icons.people_outline;
    final title = isSearch ? 'No Matching Clients' : 'No Clients Yet';
    final subtitle = isSearch
        ? 'Try a different search query or clear filters'
        : 'Add clients from the Android app to see them here';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondaryColor),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Text(
              'Unable to load clients',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            CustomButton(
              text: 'Retry',
              variant: CustomButtonVariant.primary,
              onPressed: () => context.read<ClientsBloc>().add(
                ClientsRequested(
                  organizationId: widget.organizationId,
                  forceRefresh: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Client> _applyStatusFilter(List<Client> clients) {
    if (_statusFilter == _statusAll) {
      return clients;
    }
    return clients
        .where((client) => client.status.toLowerCase() == _statusFilter)
        .toList(growable: false);
  }

  String _roleLabel(int role) {
    switch (role) {
      case 0:
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }
}

class ClientsSummaryStrip extends StatelessWidget {
  const ClientsSummaryStrip({
    super.key,
    required this.metrics,
    required this.isLoading,
  });

  final ClientsMetrics metrics;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final summaries = [
      _SummaryCardData(
        title: 'Total Clients',
        value: metrics.total,
        icon: Icons.people_alt_outlined,
        color: AppTheme.primaryColor,
      ),
      _SummaryCardData(
        title: 'Active Clients',
        value: metrics.active,
        icon: Icons.verified_user_outlined,
        color: AppTheme.successColor,
      ),
      _SummaryCardData(
        title: 'Inactive',
        value: metrics.inactive,
        icon: Icons.pause_circle_outline,
        color: AppTheme.warningColor,
      ),
      _SummaryCardData(
        title: 'New (30 days)',
        value: metrics.recent,
        icon: Icons.new_releases_outlined,
        color: AppTheme.accentColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final spacing = AppTheme.spacingLg;

        final children = summaries
            .map((data) => _SummaryCard(data: data, isLoading: isLoading))
            .toList();

        if (isCompact) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: children
                .map(
                  (child) => SizedBox(
                    width: constraints.maxWidth / 2 - spacing,
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1)
                const SizedBox(width: AppTheme.spacingLg),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.isLoading});

  final _SummaryCardData data;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        color: const Color(0xFF141618).withValues(alpha: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? Container(
                        height: 20,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Text(
                        data.value.toString(),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
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

class ClientsTable extends StatelessWidget {
  const ClientsTable({
    super.key,
    required this.clients,
    required this.scrollController,
    required this.horizontalController,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.availableWidth,
  });

  final List<Client> clients;
  final ScrollController scrollController;
  final ScrollController horizontalController;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final double availableWidth;

  static const double _minTableWidth = 1100;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141618).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: clients.length > 12,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(_minTableWidth, availableWidth),
                    child: DataTable(
                      headingRowHeight: 56,
                      dataRowMinHeight: 72,
                      dataRowMaxHeight: 88,
                      horizontalMargin: 0,
                      columnSpacing: 24,
                      dividerThickness: 1,
                      headingRowColor: MaterialStateProperty.all(
                        const Color(0xFF1F2937).withValues(alpha: 0.88),
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(MaterialState.hovered)) {
                          return AppTheme.borderColor.withValues(alpha: 0.24);
                        }
                        return Colors.transparent;
                      }),
                      columns: const [
                        DataColumn(label: _TableHeader('CLIENT')),
                        DataColumn(label: _TableHeader('CONTACT')),
                        DataColumn(label: _TableHeader('EMAIL')),
                        DataColumn(label: _TableHeader('STATUS')),
                        DataColumn(label: _TableHeader('TAGS')),
                        DataColumn(label: _TableHeader('JOINED')),
                      ],
                      rows: clients.map(_buildRow).toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasMore || isLoadingMore) _buildLoadMore(),
        ],
      ),
    );
  }

  DataRow _buildRow(Client client) {
    return DataRow(
      cells: [
        DataCell(_ClientCell(client: client)),
        DataCell(_ContactCell(client: client)),
        DataCell(_EmailCell(email: client.email)),
        DataCell(_StatusChip(status: client.status)),
        DataCell(_TagsCell(tags: client.tags)),
        DataCell(_DateCell(date: client.createdAt)),
      ],
    );
  }

  Widget _buildLoadMore() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      alignment: Alignment.center,
      child: CustomButton(
        text: 'Load More',
        variant: CustomButtonVariant.secondary,
        isLoading: isLoadingMore,
        isDisabled: isLoadingMore,
        onPressed: onLoadMore,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ClientCell extends StatelessWidget {
  const _ClientCell({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: Text(
              client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  client.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  client.clientId,
                  style: const TextStyle(
                    color: AppTheme.textTertiaryColor,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final phones = <String>{
      client.phoneNumber,
      ...client.phoneList,
    }.where((phone) => phone.trim().isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: phones
            .map(
              (phone) => Text(
                phone,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 13,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _EmailCell extends StatelessWidget {
  const _EmailCell({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(
        email ?? '—',
        style: TextStyle(
          color: email != null
              ? AppTheme.textSecondaryColor
              : AppTheme.textTertiaryColor,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case ClientStatus.active:
        color = AppTheme.successColor;
        break;
      case ClientStatus.archived:
        color = AppTheme.textTertiaryColor;
        break;
      default:
        color = AppTheme.warningColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagsCell extends StatelessWidget {
  const _TagsCell({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(color: AppTheme.textTertiaryColor, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 11,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Text(
        _formatDate(date),
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
