import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/domain/entities/app_access_role.dart';
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

  // Cache for pre-fetched app access roles
  final Map<String, List<AppAccessRole>> _cachedRoles = {};
  final Map<String, Map<String, AppAccessRole>> _roleLookupMaps = {};
  bool _isLoadingRole = false;
  String? _loadingOrgId;

  @override
  void initState() {
    super.initState();
    // Organizations should already be loaded by AppInitializationCubit
    // But on app restart, they might be empty - load them as a fallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final orgState = context.read<OrgSelectorCubit>().state;
        final authState = context.read<AuthBloc>().state;
        // If organizations are empty but user is authenticated, try to load them
        if (orgState.organizations.isEmpty && authState.userProfile != null) {
          context.read<OrgSelectorCubit>().loadOrganizations(
            authState.userProfile!.id,
            phoneNumber: authState.userProfile!.phoneNumber,
          );
        }
      }
    });
  }

  /// Pre-fetch app access roles when organization is selected
  Future<void> _prefetchAppAccessRoles(String orgId) async {
    if (_cachedRoles.containsKey(orgId)) {
      return; // Already cached
    }

    if (_isLoadingRole && _loadingOrgId == orgId) {
      return; // Already loading
    }

    setState(() {
      _isLoadingRole = true;
      _loadingOrgId = orgId;
    });

    try {
      final appAccessRolesRepository =
          context.read<AppAccessRolesRepository>();
      final appRoles =
          await appAccessRolesRepository.fetchAppAccessRoles(orgId);

      // Create lookup map for O(1) access
      final lookupMap = <String, AppAccessRole>{};
      for (final role in appRoles) {
        lookupMap[role.id.toLowerCase()] = role;
        lookupMap[role.name.toLowerCase()] = role;
      }

      if (mounted) {
        setState(() {
          _cachedRoles[orgId] = appRoles;
          _roleLookupMaps[orgId] = lookupMap;
          _isLoadingRole = false;
          _loadingOrgId = null;
        });
      }

      // Pre-fetch profile stats in background (non-blocking)
      _prefetchProfileStats(orgId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
          _loadingOrgId = null;
        });
      }
    }
  }

  /// Pre-fetch profile stats to warm up cache for faster home page load
  void _prefetchProfileStats(String orgId) {
    // Fire and forget - this warms up the cache
    try {
      final pendingOrdersRepository = context.read<PendingOrdersRepository>();
      pendingOrdersRepository.getPendingOrdersCount(orgId).catchError((_) {
        // Silently fail - this is just a cache warm-up
        return 0; // Return default value on error
      });
    } catch (_) {
      // Silently fail if repository not available
    }
  }

  /// Find app access role using optimized lookup
  AppAccessRole _findAppAccessRole(
    String orgId,
    String roleId,
    List<AppAccessRole> appRoles,
  ) {
    final lookupMap = _roleLookupMaps[orgId];
    if (lookupMap != null) {
      // Try by ID first
      final roleById = lookupMap[roleId.toLowerCase()];
      if (roleById != null) return roleById;
    }

    // Fallback: try by name (case-insensitive)
    try {
      return appRoles.firstWhere(
        (role) => role.name.toUpperCase() == roleId.toUpperCase(),
      );
    } catch (_) {
      // Fallback: try admin role
      try {
        return appRoles.firstWhere((role) => role.isAdmin);
      } catch (_) {
        // Last resort: first role or default
        return appRoles.isNotEmpty
            ? appRoles.first
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
      backgroundColor: AuthColors.backgroundAlt,
      body: Stack(
        children: [
          // Dot grid pattern background - fills entire viewport
          const Positioned.fill(
            child: RepaintBoundary(
              child: DotGridPattern(),
            ),
          ),
          // Main content
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
                // Organizations are loaded by AppInitializationCubit
                // No need for duplicate loading here
              ],
              child: BlocBuilder<OrgSelectorCubit, OrgSelectorState>(
                buildWhen: (previous, current) {
                  // Only rebuild when these specific properties change
                  return previous.status != current.status ||
                         previous.organizations.length != current.organizations.length ||
                         previous.selectedOrganization?.id != current.selectedOrganization?.id ||
                         previous.financialYear != current.financialYear ||
                         previous.isFinancialYearLocked != current.isFinancialYearLocked;
                },
                builder: (context, state) {
                  if (state.status == ViewStatus.loading) {
                        // Show skeleton loaders instead of full-screen spinner
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                          child: Transform.translate(
                            offset: const Offset(0, -20),
                            child: _buildSkeletonContent(context),
                          ),
                        );
                  }
                  
                  if (state.organizations.isEmpty) {
                      return Padding(
                      padding: const EdgeInsets.all(32),
                          child: EmptyOrganizationsState(
                        onRefresh: () {
                          // Organizations should be loaded by AppInitializationCubit
                          // If empty, user needs to contact admin
                        },
                            onBackToLogin: () async {
                              await context.read<OrganizationContextCubit>().clear();
                              context.read<AuthBloc>().add(const AuthReset());
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                      ),
                    );
                  }
                  
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: _buildContent(context, state),
                    ),
                  );
                },
              ),
                ),
              ),
            ),
            // Logout button in top right corner
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DashButton(
                  label: 'Logout',
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await context.read<OrganizationContextCubit>().clear();
                    context.read<AuthBloc>().add(const AuthReset());
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  variant: DashButtonVariant.outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AuthColors.primaryVariant.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizationSelectionHeader(),
          const SizedBox(height: 40),
          const OrganizationSelectionSkeleton(count: 3),
          const SizedBox(height: 40),
          // Financial year selector skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Continue button skeleton
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: AuthColors.primaryWithOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrgSelectorState state) {
    return Container(
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AuthColors.primaryVariant.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrganizationSelectionHeader(),
          const SizedBox(height: 40),
          RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: state.organizations.map((org) {
                final isSelected = state.selectedOrganization?.id == org.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OrganizationTile(
                    organizationName: org.name,
                    organizationRole: org.role,
                    isSelected: isSelected,
                    onTap: () {
                        context.read<OrgSelectorCubit>().selectOrganization(org);
                        // Pre-fetch app access roles when org is selected
                        _prefetchAppAccessRoles(org.id);
                      },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 40),
          FinancialYearSelector(
            financialYear: state.financialYear,
            financialYears: _financialYears,
            isLocked: state.isFinancialYearLocked,
            onChanged: (value) {
              if (value != null) {
                context.read<OrgSelectorCubit>().selectFinancialYear(value);
              }
            },
          ),
          const SizedBox(height: 40),
          OrganizationSelectionContinueButton(
            isEnabled: state.selectedOrganization != null &&
                (state.financialYear ?? '').isNotEmpty,
            isLoading: _isLoadingRole && _loadingOrgId == state.selectedOrganization?.id,
            onPressed: () async {
                      final org = state.selectedOrganization;
                      if (org == null) return;

                      // Wait for pre-fetched roles if still loading
                      if (_isLoadingRole && _loadingOrgId == org.id) {
                        // Wait for pre-fetch to complete (max 3 seconds)
                        int attempts = 0;
                        while (_isLoadingRole && attempts < 30 && mounted) {
                          await Future.delayed(const Duration(milliseconds: 100));
                          attempts++;
                        }
                      }

                      final appAccessRolesRepository =
                          context.read<AppAccessRolesRepository>();
                      late final AppAccessRole appAccessRole;

                      // Use cached roles if available, otherwise fetch
                      final appRoles = _cachedRoles[org.id];
                      if (appRoles != null && appRoles.isNotEmpty) {
                        // Use cached roles with optimized lookup
                        final roleId = org.appAccessRoleId ?? org.role;
                        appAccessRole = _findAppAccessRole(org.id, roleId, appRoles);
                      } else {
                        // Fallback: fetch if not cached (shouldn't happen if pre-fetch worked)
                        try {
                          final roleId = org.appAccessRoleId ?? org.role;
                          final fetchedRoles =
                              await appAccessRolesRepository.fetchAppAccessRoles(org.id);
                          appAccessRole = _findAppAccessRole(org.id, roleId, fetchedRoles);
                        } catch (_) {
                          // Final fallback if fetch fails
                          final roleId = org.appAccessRoleId ?? org.role;
                          appAccessRole = AppAccessRole(
                            id: '${org.id}-$roleId',
                            name: roleId,
                            description: 'Default role',
                            colorHex: '#6F4BFF',
                            isAdmin: roleId.toUpperCase() == 'ADMIN',
                          );
                        }
                      }

                      final authState = context.read<AuthBloc>().state;
                      final userId = authState.userProfile?.id ?? '';
                      
                      // Optimistic navigation: set context and navigate immediately
                      context.read<OrganizationContextCubit>().setContext(
                            userId: userId,
                            organization: org,
                            financialYear:
                                state.financialYear ?? _financialYears.first,
                            appAccessRole: appAccessRole,
                          );
                      
                      if (context.mounted) {
                        context.go('/home');
                      }
            },
          ),
        ],
      ),
    );
  }
}
