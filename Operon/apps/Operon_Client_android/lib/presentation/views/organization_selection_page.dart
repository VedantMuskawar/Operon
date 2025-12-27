import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';
import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_selector/org_selector_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OrganizationSelectionPage extends StatefulWidget {
  const OrganizationSelectionPage({super.key});

  @override
  State<OrganizationSelectionPage> createState() =>
      _OrganizationSelectionPageState();
}

class _OrganizationSelectionPageState
    extends State<OrganizationSelectionPage> {
  static const _financialYears = [
    'FY 2022-2023',
    'FY 2023-2024',
    'FY 2024-2025',
    'FY 2025-2026',
  ];

  @override
  void initState() {
    super.initState();
    // Organizations should already be loaded by AppInitializationCubit
    // Just ensure they're loaded if not already
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userProfile?.id;
    final phoneNumber = authState.userProfile?.phoneNumber;
    final orgState = context.read<OrgSelectorCubit>().state;
    
    if (userId != null && orgState.organizations.isEmpty) {
      context.read<OrgSelectorCubit>().loadOrganizations(
            userId,
            phoneNumber: phoneNumber,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF020205),
      body: SafeArea(
        child: BlocConsumer<OrgSelectorCubit, OrgSelectorState>(
          listener: (context, state) {
            if (state.status == ViewStatus.failure && state.errorMessage != null) {
              DashSnackbar.show(
                context,
                message: state.errorMessage!,
                isError: true,
              );
            }
            // Context restoration is handled by AppInitializationCubit
            // No need to restore here as it's already done during app initialization
          },
          builder: (context, state) {
            if (state.status == ViewStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.organizations.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: _EmptyOrganizations(
                  onRefresh: () {
                    final authState = context.read<AuthBloc>().state;
                    final userId = authState.userProfile?.id;
                    final phoneNumber = authState.userProfile?.phoneNumber;
                    if (userId != null) {
                      context.read<OrgSelectorCubit>().loadOrganizations(
                            userId,
                            phoneNumber: phoneNumber,
                          );
                    }
                  },
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _Header(theme: theme),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: state.organizations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final org = state.organizations[index];
                        final isSelected =
                            state.selectedOrganization?.id == org.id;
                        return _OrganizationTile(
                          organization: org,
                          isSelected: isSelected,
                          onTap: () =>
                              context.read<OrgSelectorCubit>().selectOrganization(org),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FinancialYearSelector(
                    state: state,
                    financialYears: _financialYears,
                  ),
                  const SizedBox(height: 18),
                  DashButton(
                    label: 'Continue to Dashboard',
                    onPressed: state.selectedOrganization != null &&
                            (state.financialYear ?? '').isNotEmpty
                        ? () async {
                            final org = state.selectedOrganization;
                            if (org == null) return;
                            final rolesRepository =
                                context.read<RolesRepository>();
                            late final OrganizationRole roleDetails;
                            try {
                              final roles =
                                  await rolesRepository.fetchRoles(org.id);
                              roleDetails = roles.firstWhere(
                                (role) =>
                                    role.title.toUpperCase() ==
                                    org.role.toUpperCase(),
                                orElse: () => OrganizationRole(
                                  id: '${org.id}-${org.role}',
                                  title: org.role,
                                  salaryType: SalaryType.salaryMonthly,
                                  colorHex: '#6F4BFF',
                                ),
                              );
                            } catch (_) {
                              roleDetails = OrganizationRole(
                                id: '${org.id}-${org.role}',
                                title: org.role,
                                salaryType: SalaryType.salaryMonthly,
                                colorHex: '#6F4BFF',
                              );
                            }

                            final authState = context.read<AuthBloc>().state;
                            final userId = authState.userProfile?.id ?? '';
                            context.read<OrganizationContextCubit>().setContext(
                                  userId: userId,
                                  organization: org,
                                  financialYear:
                                      state.financialYear ?? _financialYears.first,
                                  role: roleDetails,
                                );
                            context.go('/home');
                          }
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose workspace',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick an organization and we’ll tailor everything to it.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            // Clear organization context before logout
            await context.read<OrganizationContextCubit>().clear();
            context.read<AuthBloc>().add(const AuthReset());
            if (context.mounted) {
              context.go('/login');
            }
          },
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class _FinancialYearSelector extends StatelessWidget {
  const _FinancialYearSelector({
    required this.state,
    required this.financialYears,
  });

  final OrgSelectorState state;
  final List<String> financialYears;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Year',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: state.financialYear,
          dropdownColor: const Color(0xFF11111D),
          iconEnabledColor:
              state.isFinancialYearLocked ? Colors.white24 : Colors.white,
          style: const TextStyle(color: Colors.white),
          items: financialYears
              .map(
                (year) => DropdownMenuItem<String>(
                  value: year,
                  child: Text(year),
                ),
              )
              .toList(),
          onChanged: state.isFinancialYearLocked
              ? null
              : (value) {
                  if (value != null) {
                    context.read<OrgSelectorCubit>().selectFinancialYear(value);
                  }
                },
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF11111D),
            border: const OutlineInputBorder(),
            helperText: state.isFinancialYearLocked
                ? 'Locked to current year for your role.'
                : null,
            helperStyle: const TextStyle(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class _OrganizationTile extends StatelessWidget {
  const _OrganizationTile({
    required this.organization,
    required this.isSelected,
    required this.onTap,
  });

  final OrganizationMembership organization;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1F1C2C), Color(0xFF3A1C71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFF101019),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF7A5CFF) : const Color(0xFF1F1F2B),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6F4BFF).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF816BFF)
                    : const Color(0xFF1D1D2C),
              ),
              child: const Icon(
                Icons.apartment,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${organization.role}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF9D7BFF)
                    : Colors.white.withOpacity(0.08),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.chevron_right,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrganizations extends StatelessWidget {
  const _EmptyOrganizations({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.apartment,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No organizations found for this user.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask your admin to link this phone number to an org\n'
            'or tap refresh after they do.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 20),
          DashButton(
            label: 'Refresh',
            onPressed: onRefresh,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () async {
              // Clear organization context before logout
              await context.read<OrganizationContextCubit>().clear();
              context.read<AuthBloc>().add(const AuthReset());
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

