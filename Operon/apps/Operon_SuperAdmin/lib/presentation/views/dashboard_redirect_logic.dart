import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/data/repositories/organization_repository.dart';
import 'package:dash_superadmin/domain/entities/organization_summary.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/blocs/organization_list/organization_list_bloc.dart';
import 'package:dash_superadmin/presentation/widgets/create_organization_dialog.dart';
import 'package:dash_superadmin/presentation/widgets/superadmin_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DashboardRedirectPage extends StatelessWidget {
  const DashboardRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.userProfile == null) {
          Future.microtask(() => context.go('/'));
          return const Scaffold(body: SizedBox.shrink());
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => OrganizationListBloc(
                repository: context.read<OrganizationRepository>(),
              )..add(const OrganizationListWatchRequested()),
            ),
          ],
          child: const _DashboardView(),
        );
      },
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  int _currentIndex = 0;

  Future<void> _openDialog(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => const CreateOrganizationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationListBloc, OrganizationListState>(
      listenWhen: (previous, current) =>
          previous.commandStatus != current.commandStatus &&
          current.message != null,
      listener: (context, state) {
        if (state.message == null) return;
        DashSnackbar.show(
          context,
          message: state.message!,
          isError: state.commandStatus == ViewStatus.failure,
        );
      },
      child: SuperAdminWorkspaceLayout(
        currentIndex: _currentIndex,
        onNavTap: (index) => setState(() => _currentIndex = index),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _OverviewSection(onCreateOrg: () => _openDialog(context)),
            const _OrganizationsSection(),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.onCreateOrg});

  final VoidCallback onCreateOrg;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MetricHighlights(),
          const SizedBox(height: 24),
          _AddOrgTile(onTap: onCreateOrg),
        ],
      ),
    );
  }
}

class _MetricHighlights extends StatelessWidget {
  const _MetricHighlights();

  static int _countCreatedSince(
    List<OrganizationSummary> organizations,
    DateTime since,
  ) {
    return organizations
        .where((o) => o.createdAt != null && !o.createdAt!.isBefore(since))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrganizationListBloc, OrganizationListState>(
      builder: (context, state) {
        final isLoading = state.status == ViewStatus.loading;
        final orgs = state.organizations;
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final monthAgo = now.subtract(const Duration(days: 30));
        final total = orgs.length;
        final newThisWeek = _countCreatedSince(orgs, weekAgo);
        final newThisMonth = _countCreatedSince(orgs, monthAgo);

        final cards = [
          _HighlightCardData(
            title: 'Organizations',
            value: isLoading && total == 0 ? '—' : '$total',
            trendLabel: isLoading && total == 0
                ? 'Loading…'
                : (newThisWeek > 0 ? '+$newThisWeek new this week' : 'All organizations'),
            accentColor: AuthColors.primary,
            icon: Icons.apartment_rounded,
          ),
          _HighlightCardData(
            title: 'New this week',
            value: isLoading && total == 0 ? '—' : '$newThisWeek',
            trendLabel: 'Created in last 7 days',
            accentColor: AuthColors.info,
            icon: Icons.verified_user_rounded,
          ),
          _HighlightCardData(
            title: 'New this month',
            value: isLoading && total == 0 ? '—' : '$newThisMonth',
            trendLabel: 'Created in last 30 days',
            accentColor: AuthColors.warning,
            icon: Icons.timer_rounded,
          ),
        ];

        return Row(
          children: [
            for (final data in cards) ...[
              Expanded(child: _HighlightCard(data: data)),
              if (data != cards.last) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _HighlightCardData {
  const _HighlightCardData({
    required this.title,
    required this.value,
    required this.trendLabel,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final String value;
  final String trendLabel;
  final Color accentColor;
  final IconData icon;
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.data});

  final _HighlightCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AuthColors.surface,
        border: Border(
          left: BorderSide(color: data.accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.accentColor),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AuthColors.textMainWithOpacity(0.2),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AuthColors.textMainWithOpacity(0.9)),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AuthColors.textMain,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            data.trendLabel,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AuthColors.textMainWithOpacity(0.95)),
          ),
        ],
      ),
    );
  }
}

class _AddOrgTile extends StatelessWidget {
  const _AddOrgTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [AuthColors.surface, AuthColors.background],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: AuthColors.background.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AuthColors.primary, AuthColors.successVariant],
                ),
              ),
              child: const Icon(
                  Icons.add_business, color: AuthColors.textMain, size: 30),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Launch Organization Builder',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spin up a workspace, assign a primary admin and preview access policies in one streamlined dialog.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AuthColors.textSub,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuthColors.textMainWithOpacity(0.1),
              ),
              child: const Icon(
                  Icons.arrow_forward_rounded, color: AuthColors.textMain),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationsSection extends StatefulWidget {
  const _OrganizationsSection();

  @override
  State<_OrganizationsSection> createState() => _OrganizationsSectionState();
}

enum _OrgSortMode { newest, alpha }

class _OrganizationsSectionState extends State<_OrganizationsSection> {
  final _searchController = TextEditingController();
  String _query = '';
  _OrgSortMode _sortMode = _OrgSortMode.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _onSortChanged(_OrgSortMode mode) {
    setState(() => _sortMode = mode);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OrganizationSummary organization,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete organization'),
        content: Text(
          'Are you sure you want to delete ${organization.name}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AuthColors.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      context.read<OrganizationListBloc>().add(
            OrganizationListDeleteRequested(
              organizationId: organization.id,
            ),
          );
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    OrganizationSummary organization,
  ) async {
    final nameController = TextEditingController(text: organization.name);
    final industryController =
        TextEditingController(text: organization.industry);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Edit organization'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update the organization details to keep records current.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AuthColors.textSub),
              ),
              const SizedBox(height: 16),
              DashFormField(
                controller: nameController,
                label: 'Organization Name',
              ),
              const SizedBox(height: 4),
              Text(
                'Use the registered legal name.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AuthColors.textSub),
              ),
              const SizedBox(height: 12),
              DashFormField(
                controller: industryController,
                label: 'Industry',
              ),
              const SizedBox(height: 4),
              Text(
                'e.g. Logistics, Healthcare, SaaS',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AuthColors.textSub),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      context.read<OrganizationListBloc>().add(
            OrganizationListUpdateRequested(
              organizationId: organization.id,
              name: nameController.text.trim(),
              industry: industryController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organizations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search organization or industry',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AuthColors.textMainWithOpacity(0.04),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: _OrgSortMode.values
                      .map((mode) => mode == _sortMode)
                      .toList(),
                  onPressed: (index) =>
                      _onSortChanged(_OrgSortMode.values[index]),
                  borderRadius: BorderRadius.circular(16),
                  selectedColor: AuthColors.textMain,
                  color: AuthColors.textSub,
                  fillColor: AuthColors.textMainWithOpacity(0.1),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Newest'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('A-Z'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BlocBuilder<OrganizationListBloc, OrganizationListState>(
                builder: (context, state) {
                  if (state.status == ViewStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ViewStatus.failure) {
                    return Center(
                      child: Text(
                        state.message ?? 'Failed to load organizations.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AuthColors.error),
                      ),
                    );
                  }
                  final filtered = state.organizations.where((org) {
                    if (_query.isEmpty) return true;
                    final haystack =
                        '${org.name} ${org.industry} ${org.orgCode}'.toLowerCase();
                    return haystack.contains(_query);
                  }).toList()
                    ..sort((a, b) {
                      if (_sortMode == _OrgSortMode.alpha) {
                        return a.name
                            .toLowerCase()
                            .compareTo(b.name.toLowerCase());
                      }
                      final aTime = a.createdAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime = b.createdAt ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No organizations match your filters.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AuthColors.textSub),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final org = filtered[index];
                      final createdLabel = org.createdAt != null
                          ? MaterialLocalizations.of(context)
                              .formatMediumDate(org.createdAt!)
                          : null;

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: index == filtered.length - 1 ? 0 : 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AuthColors.textMainWithOpacity(0.03),
                          border: Border.all(
                            color: AuthColors.textMainWithOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    AuthColors.legacyAccent,
                                    AuthColors.successVariant,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                org.name
                                    .characters
                                    .take(2)
                                    .toString()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          org.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: AuthColors.textMainWithOpacity(0.08),
                                        ),
                                        child: Text(
                                          org.orgCode,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(letterSpacing: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    org.industry,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AuthColors.textSub),
                                  ),
                                  if (createdLabel != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Created $createdLabel',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AuthColors.textDisabled),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit organization',
                                  onPressed: () =>
                                      _showEditDialog(context, org),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Delete organization',
                                  onPressed: () =>
                                      _confirmDelete(context, org),
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
