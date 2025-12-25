import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/org_selector/org_selector_cubit.dart';
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
    // Always load organizations when page is shown
    // This ensures organizations are loaded even after refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadOrganizations();
      }
    });
  }

  void _loadOrganizations() {
    final authState = context.read<AuthBloc>().state;
    final userId = authState.userProfile?.id;
    final phoneNumber = authState.userProfile?.phoneNumber;
    final orgState = context.read<OrgSelectorCubit>().state;
    
    // Always reload organizations to ensure fresh data
    // This handles refresh scenarios where state might be reset
    if (userId != null) {
      // Only load if not already loading or if list is empty
      if (orgState.status != ViewStatus.loading && 
          (orgState.organizations.isEmpty || orgState.status == ViewStatus.initial)) {
        context.read<OrgSelectorCubit>().loadOrganizations(
              userId,
              phoneNumber: phoneNumber,
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF020205),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: MultiBlocListener(
              listeners: [
                BlocListener<OrgSelectorCubit, OrgSelectorState>(
                  listener: (context, state) {
                    if (state.status == ViewStatus.failure && state.errorMessage != null) {
                      DashSnackbar.show(
                        context,
                        message: state.errorMessage!,
                        isError: true,
                      );
                    }
                  },
                ),
                BlocListener<AuthBloc, AuthState>(
                  listener: (context, authState) {
                    // Reload organizations when auth state changes (e.g., after refresh)
                    if (authState.userProfile != null) {
                      final orgState = context.read<OrgSelectorCubit>().state;
                      // Only reload if list is empty or initial state
                      if (orgState.organizations.isEmpty || orgState.status == ViewStatus.initial) {
                        _loadOrganizations();
                      }
                    }
                  },
                ),
              ],
              child: BlocBuilder<OrgSelectorCubit, OrgSelectorState>(
                builder: (context, state) {
                  if (state.status == ViewStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.organizations.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: _EmptyOrganizations(
                        onRefresh: _loadOrganizations,
                      ),
                    );
                  }
                  return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(theme: theme),
                      const SizedBox(height: 40),
                      ...state.organizations.map((org) {
                        final isSelected =
                            state.selectedOrganization?.id == org.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OrganizationTile(
                            organization: org,
                            isSelected: isSelected,
                            onTap: () =>
                                context.read<OrgSelectorCubit>().selectOrganization(org),
                          ),
                        );
                      }),
                      const SizedBox(height: 40),
                      _FinancialYearSelector(
                        state: state,
                        financialYears: _financialYears,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        height: 56,
                        width: double.infinity,
                        child: DashButton(
                          label: 'Continue to Dashboard',
                          onPressed: state.selectedOrganization != null &&
                                  (state.financialYear ?? '').isNotEmpty
                              ? () async {
                              final org = state.selectedOrganization;
                              if (org == null) return;
                              final appAccessRolesRepository =
                                  context.read<AppAccessRolesRepository>();
                              late final AppAccessRole appAccessRole;
                              try {
                                // Use appAccessRoleId if available, otherwise fallback to role
                                final roleId = org.appAccessRoleId ?? org.role;
                                final appRoles =
                                    await appAccessRolesRepository.fetchAppAccessRoles(org.id);
                                
                                // First try to find by appAccessRoleId
                                appAccessRole = appRoles.firstWhere(
                                  (role) => role.id == roleId,
                                  orElse: () {
                                    // Fallback: try by name (case-insensitive)
                                    return appRoles.firstWhere(
                                      (role) => role.name.toUpperCase() == roleId.toUpperCase(),
                                      orElse: () {
                                        // Fallback: try admin role or first role
                                        return appRoles.firstWhere(
                                          (role) => role.isAdmin,
                                          orElse: () => appRoles.isNotEmpty
                                              ? appRoles.first
                                              : AppAccessRole(
                                                  id: '${org.id}-${roleId}',
                                                  name: roleId,
                                                  description: 'Default role',
                                                  colorHex: '#6F4BFF',
                                                  isAdmin: roleId.toUpperCase() == 'ADMIN',
                                                ),
                                        );
                                      },
                                    );
                                  },
                                );
                              } catch (_) {
                                // Fallback if fetch fails
                                final roleId = org.appAccessRoleId ?? org.role;
                                appAccessRole = AppAccessRole(
                                  id: '${org.id}-${roleId}',
                                  name: roleId,
                                  description: 'Default role',
                                  colorHex: '#6F4BFF',
                                  isAdmin: roleId.toUpperCase() == 'ADMIN',
                                );
                              }

                              final authState = context.read<AuthBloc>().state;
                              final userId = authState.userProfile?.id ?? '';
                              await context.read<OrganizationContextCubit>().setContext(
                                    userId: userId,
                                    organization: org,
                                    financialYear:
                                        state.financialYear ?? _financialYears.first,
                                    appAccessRole: appAccessRole,
                                  );
                              if (context.mounted) {
                                context.go('/home');
                              }
                            }
                            : null,
                        ),
                      ),
                    ],
                  ),
                );
                },
              ),
            ),
          ),
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
                "Pick an organization and we'll tailor everything to it.",
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Financial Year',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: state.financialYear,
          dropdownColor: const Color(0xFF11111D),
          iconEnabledColor:
              state.isFinancialYearLocked ? Colors.white24 : Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 1.5),
            ),
            helperText: state.isFinancialYearLocked
                ? 'Locked to current year for your role.'
                : null,
            helperStyle: const TextStyle(color: Colors.white54, fontSize: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.35),
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
                    : Colors.white.withValues(alpha: 0.08),
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
