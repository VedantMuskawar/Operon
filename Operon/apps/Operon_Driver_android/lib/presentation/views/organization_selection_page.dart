import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';

class OrganizationSelectionPage extends StatefulWidget {
  const OrganizationSelectionPage({super.key});

  @override
  State<OrganizationSelectionPage> createState() =>
      _OrganizationSelectionPageState();
}

class _OrganizationSelectionPageState extends State<OrganizationSelectionPage> {
  static const _financialYears = [
    'FY 2022-2023',
    'FY 2023-2024',
    'FY 2024-2025',
    'FY 2025-2026',
  ];

  final Map<String, List<AppAccessRole>> _cachedRoles = {};
  final Map<String, Map<String, AppAccessRole>> _roleLookupMaps = {};
  bool _isLoadingRole = false;
  String? _loadingOrgId;

  Future<void> _prefetchAppAccessRoles(String orgId) async {
    if (_cachedRoles.containsKey(orgId)) return;
    if (_isLoadingRole && _loadingOrgId == orgId) return;

    setState(() {
      _isLoadingRole = true;
      _loadingOrgId = orgId;
    });

    try {
      final repo = context.read<AppAccessRolesRepository>();
      final roles = await repo.fetchAppAccessRoles(orgId);

      final lookupMap = <String, AppAccessRole>{};
      for (final role in roles) {
        lookupMap[role.id.toLowerCase()] = role;
        lookupMap[role.name.toLowerCase()] = role;
      }

      if (!mounted) return;
      setState(() {
        _cachedRoles[orgId] = roles;
        _roleLookupMaps[orgId] = lookupMap;
        _isLoadingRole = false;
        _loadingOrgId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRole = false;
        _loadingOrgId = null;
      });
    }
  }

  AppAccessRole _findAppAccessRole(
    String orgId,
    String roleId,
    List<AppAccessRole> roles,
  ) {
    final lookupMap = _roleLookupMaps[orgId];
    if (lookupMap != null) {
      final byId = lookupMap[roleId.toLowerCase()];
      if (byId != null) return byId;
    }

    try {
      return roles.firstWhere(
        (role) => role.name.toUpperCase() == roleId.toUpperCase(),
      );
    } catch (_) {
      try {
        return roles.firstWhere((role) => role.isAdmin);
      } catch (_) {
        return roles.isNotEmpty
            ? roles.first
            : AppAccessRole(
                id: '$orgId-$roleId',
                name: roleId,
                description: 'Default role',
                colorHex: '#6F4BFF',
                isAdmin: roleId.toUpperCase() == 'ADMIN',
              );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: DotGridPattern(),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                BlocConsumer<OrgSelectorCubit, OrgSelectorState>(
                  listener: (context, state) {
                    if (state.status == ViewStatus.failure &&
                        state.errorMessage != null) {
                      DashSnackbar.show(
                        context,
                        message: state.errorMessage!,
                        isError: true,
                      );
                    }
                  },
                  builder: (context, state) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    final horizontalPadding = screenWidth < 400 ? 16.0 : 24.0;
                    final verticalPadding = screenHeight < 600 ? 24.0 : 40.0;

                    if (state.status == ViewStatus.loading) {
                      return Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: screenWidth < 600 ? double.infinity : 450,
                              minWidth: 280,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 40,
                              ),
                              decoration: BoxDecoration(
                                color: AuthColors.surface,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AuthColors.secondaryWithOpacity(0.3),
                                    blurRadius: 40,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OrganizationSelectionHeader(),
                                  SizedBox(height: 32),
                                  OrganizationSelectionSkeleton(count: 3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (state.organizations.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: EmptyOrganizationsState(
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
                            onBackToLogin: () async {
                              await context.read<OrganizationContextCubit>().clear();
                              context.read<AuthBloc>().add(const AuthReset());
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: screenWidth < 600 ? double.infinity : 450,
                            minWidth: 280,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 40,
                            ),
                            decoration: BoxDecoration(
                              color: AuthColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AuthColors.secondaryWithOpacity(0.3),
                                  blurRadius: 40,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const OrganizationSelectionHeader(),
                                const SizedBox(height: 32),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: state.organizations.map((org) {
                                    final isSelected =
                                        state.selectedOrganization?.id == org.id;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: OrganizationTile(
                                        organizationName: org.name,
                                        organizationRole: org.role,
                                        isSelected: isSelected,
                                        onTap: () {
                                          context
                                              .read<OrgSelectorCubit>()
                                              .selectOrganization(org);
                                          _prefetchAppAccessRoles(org.id);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 24),
                                FinancialYearSelector(
                                  financialYear: state.financialYear,
                                  financialYears: _financialYears,
                                  isLocked: state.isFinancialYearLocked,
                                  onChanged: (value) {
                                    if (value != null) {
                                      context
                                          .read<OrgSelectorCubit>()
                                          .selectFinancialYear(value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                OrganizationSelectionContinueButton(
                                  isEnabled: state.selectedOrganization != null &&
                                      (state.financialYear ?? '').isNotEmpty,
                                  isLoading: _isLoadingRole &&
                                      _loadingOrgId ==
                                          state.selectedOrganization?.id,
                                  onPressed: () async {
                                    final org = state.selectedOrganization;
                                    if (org == null) return;

                                    // Wait briefly if role prefetch is in-flight.
                                    if (_isLoadingRole && _loadingOrgId == org.id) {
                                      int attempts = 0;
                                      while (_isLoadingRole &&
                                          attempts < 30 &&
                                          mounted) {
                                        await Future.delayed(
                                            const Duration(milliseconds: 100));
                                        attempts++;
                                      }
                                    }

                                    final rolesRepo =
                                        context.read<AppAccessRolesRepository>();

                                    final roleId =
                                        org.appAccessRoleId ?? org.role;

                                    final cached = _cachedRoles[org.id];
                                    final roles = cached ??
                                        await rolesRepo.fetchAppAccessRoles(org.id);

                                    final appAccessRole =
                                        _findAppAccessRole(org.id, roleId, roles);

                                    final userId = context
                                            .read<AuthBloc>()
                                            .state
                                            .userProfile
                                            ?.id ??
                                        '';

                                    await context
                                        .read<OrganizationContextCubit>()
                                        .setContext(
                                          userId: userId,
                                          organization: org,
                                          financialYear: state.financialYear ??
                                              _financialYears.first,
                                          appAccessRole: appAccessRole,
                                        );

                                    if (context.mounted) {
                                      context.go('/home');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.read<OrganizationContextCubit>().clear();
                        context.read<AuthBloc>().add(const AuthReset());
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        side: BorderSide(
                          color: AuthColors.textMainWithOpacity(0.3),
                          width: 1.5,
                        ),
                        backgroundColor: AuthColors.textMainWithOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AuthColors.textMain,
                        size: 18,
                      ),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ),
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

