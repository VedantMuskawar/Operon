import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/data/repositories/organization_repository.dart';
import 'package:dash_superadmin/domain/entities/organization_summary.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/blocs/organization_list/organization_list_bloc.dart';
import 'package:dash_superadmin/presentation/widgets/create_organization_dialog.dart';
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

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  Future<void> _openDialog(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => const CreateOrganizationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: BlocListener<OrganizationListBloc, OrganizationListState>(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  displayName: authState.userProfile?.displayName ?? 'SuperAdmin',
                ),
                const SizedBox(height: 24),
                const _MetricHighlights(),
                const SizedBox(height: 24),
                _AddOrgTile(onTap: () => _openDialog(context)),
                const SizedBox(height: 24),
                const Expanded(
                  child: _OrganizationList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricHighlights extends StatelessWidget {
  const _MetricHighlights();

  @override
  Widget build(BuildContext context) {
    const cards = [
      _HighlightCardData(
        title: 'Active Orgs',
        value: '312',
        trendLabel: '+18 new this week',
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9686FF)],
        ),
        icon: Icons.apartment_rounded,
      ),
      _HighlightCardData(
        title: 'Pending Approvals',
        value: '48',
        trendLabel: '6 awaiting review',
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA6), Color(0xFF1E88E5)],
        ),
        icon: Icons.verified_user_rounded,
      ),
      _HighlightCardData(
        title: 'Avg. Onboarding',
        value: '14m',
        trendLabel: '2m faster vs last week',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
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
  }
}

class _HighlightCardData {
  const _HighlightCardData({
    required this.title,
    required this.value,
    required this.trendLabel,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String value;
  final String trendLabel;
  final Gradient gradient;
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
        gradient: data.gradient,
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.2),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: AuthColors.textMain),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color.fromRGBO(255, 255, 255, 0.2),
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
                ?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.85)),
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
                ?.copyWith(color: const Color.fromRGBO(255, 255, 255, 0.9)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            AuthColors.surface,
            AuthColors.background,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
        ),
      ),
          child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AuthColors.legacyAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Dash SuperAdmin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AuthColors.textSub,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Control Center',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 40,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Signed in as $displayName',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: DashButton(
              label: 'Sign out',
              icon: Icons.logout_sharp,
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthReset()),
            ),
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
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.05)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              blurRadius: 30,
              offset: Offset(0, 18),
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
                gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3DD598)],
                ),
              ),
              child: const Icon(Icons.add_business, color: AuthColors.textMain, size: 30),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromRGBO(255, 255, 255, 0.1),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: AuthColors.textMain),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationList extends StatefulWidget {
  const _OrganizationList();

  @override
  State<_OrganizationList> createState() => _OrganizationListState();
}

enum _OrgSortMode { newest, alpha }

class _OrganizationListState extends State<_OrganizationList> {
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
    final industryController = TextEditingController(text: organization.industry);
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
                'Example: Logistics, Healthcare, SaaS',
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
                    decoration: const InputDecoration(
                      hintText: 'Search organization or industry',
                      prefixIcon: Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Color.fromRGBO(255, 255, 255, 0.04),
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
                  fillColor: const Color.fromRGBO(255, 255, 255, 0.1),
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
                        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                      }
                      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bTime.compareTo(aTime);
                    });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No organizations match your filters.',
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AuthColors.textSub,
                                ),
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
                          bottom: index == state.organizations.length - 1 ? 0 : 16,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color.fromRGBO(255, 255, 255, 0.03),
                          border: Border.all(
                            color: const Color.fromRGBO(255, 255, 255, 0.05),
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
                                  colors: [AuthColors.legacyAccent, AuthColors.successVariant],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                org.name.characters.take(2).toString().toUpperCase(),
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
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: const Color.fromRGBO(255, 255, 255, 0.08),
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
                                          ?.copyWith(color: AuthColors.textDisabled),
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
                                  onPressed: () => _showEditDialog(context, org),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Delete organization',
                                  onPressed: () => _confirmDelete(context, org),
                                  icon: const Icon(Icons.delete_outline_rounded),
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
