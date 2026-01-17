import 'package:core_bloc/core_bloc.dart';
import 'package:core_bloc/home/home_state.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/profile_stats_repository_adapter.dart';
import 'package:dash_mobile/data/repositories/users_repository.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/home_overview_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/pending_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/schedule_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_map_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/attendance_view.dart';
import 'package:dash_mobile/presentation/widgets/permissions_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Navigation arguments for HomePage to support pre-fetched data
class HomeNavigationArgs {
  final int initialIndex;
  final Future<int>? preFetchedPendingOrdersCount;
  
  const HomeNavigationArgs({
    this.initialIndex = 0,
    this.preFetchedPendingOrdersCount,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key, 
    this.initialIndex = 0,
    this.preFetchedPendingOrdersCount,
  });

  final int initialIndex;
  final Future<int>? preFetchedPendingOrdersCount;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _sections = [
    HomeOverviewView(),
    PendingOrdersView(),
    ScheduleOrdersView(),
    OrdersMapView(),
    _AnalyticsPlaceholder(),
    AttendanceView(),
  ];

  static const _sectionTitles = [
    '',
    '',
    '',
    'Orders Map',
    '',
    'Attendance',
  ];

  @override
  Widget build(BuildContext context) {
    final pendingOrdersRepository = context.read<PendingOrdersRepository>();
    final profileStatsRepository = ProfileStatsRepositoryAdapter(
      pendingOrdersRepository: pendingOrdersRepository,
    );
    
    // Get organization ID for key to prevent recreation when org doesn't change
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id ?? 'no-org';

    return BlocProvider(
      key: ValueKey('home_cubit_$orgId'), // Prevent recreation when org doesn't change
      create: (context) {
        final cubit = HomeCubit(
          profileStatsRepository: profileStatsRepository,
        );
        
        // Initialize with current role
        final orgState = context.read<OrganizationContextCubit>().state;
        cubit.updateAppAccessRole(orgState.appAccessRole);
        
        // Use pre-fetched data if available
        if (widget.preFetchedPendingOrdersCount != null) {
          widget.preFetchedPendingOrdersCount!.then((count) {
            if (context.mounted) {
              cubit.setProfileStats(ProfileStats(pendingOrdersCount: count));
            }
          }).catchError((error) {
            // Fallback to normal fetch on error
            if (context.mounted && orgState.organization != null) {
              cubit.loadProfileStats(orgState.organization!.id);
            }
          });
        } else {
          // Fallback: normal flow for direct navigation (e.g., page refresh)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              final currentOrgState = context.read<OrganizationContextCubit>().state;
              if (currentOrgState.organization != null) {
                cubit.loadProfileStats(currentOrgState.organization!.id);
              }
            }
          });
        }
        
        return cubit;
      },
      child: BlocListener<OrganizationContextCubit, OrganizationContextState>(
        listener: (context, orgState) {
          final homeCubit = context.read<HomeCubit>();
          homeCubit.updateAppAccessRole(orgState.appAccessRole);
          if (orgState.organization != null) {
            homeCubit.loadProfileStats(orgState.organization!.id);
          } else {
            homeCubit.loadProfileStats('');
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          buildWhen: (previous, current) => 
              previous.currentIndex != current.currentIndex ||
              previous.allowedSections != current.allowedSections,
          builder: (context, homeState) {
            return Scaffold(
              backgroundColor: AuthColors.background,
              appBar: _HomeAppBar(
                title: _sectionTitles[homeState.currentIndex],
              ),
              drawer: const _HomeProfileDrawer(),
              endDrawer: const _HomeSettingsDrawer(),
            body: Stack(
              children: [
                // DotGridPattern background (matching login page)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: const DotGridPattern(),
                  ),
                ),
                // Main content
                Column(
                  children: [
                    Expanded(
                      child: SafeArea(
                        bottom: false,
                        child: HomeSectionTransition(
                          child: IndexedStack(
                            index: homeState.currentIndex,
                            children: _sections,
                          ),
                        ),
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
                          icon: Icons.dashboard_rounded,
                          label: 'Analytics',
                          heroTag: 'nav_analytics',
                        ),
                      ],
                      currentIndex: homeState.currentIndex,
                      onItemTapped: (index) {
                        context.read<HomeCubit>().switchToSection(index);
                      },
                      visibleIndices: homeState.allowedSections,
                    ),
                  ],
                ),
                // Smart Action FAB - visible on Home and Pending Orders pages
                if (homeState.currentIndex == 0 || homeState.currentIndex == 1)
                  ActionFab(
                    actions: [
                      ActionItem(
                        icon: Icons.receipt,
                        label: 'Add Expense',
                        onTap: () {
                          context.go('/record-expense');
                        },
                      ),
                      ActionItem(
                        icon: Icons.payment,
                        label: 'Payments',
                        onTap: () {
                          context.go('/record-payment');
                        },
                      ),
                      ActionItem(
                        icon: Icons.shopping_cart,
                        label: 'Record Purchase',
                        onTap: () {
                          context.go('/record-purchase');
                        },
                      ),
                      ActionItem(
                        icon: Icons.add_shopping_cart_outlined,
                        label: 'Create Order',
                        onTap: () {
                          PendingOrdersView.showCustomerTypeDialog(context);
                        },
                      ),
                    ],
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

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Analytics coming soon',
        style: TextStyle(
          color: AuthColors.textSub,
          fontSize: 16,
          fontFamily: 'SF Pro Display',
        ),
      ),
    );
  }
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.canManageRoles,
    required this.canManageProducts,
    required this.canManageRawMaterials,
    required this.canAccessVehicles,
    required this.onOpenRoles,
    required this.onOpenProducts,
    required this.onOpenRawMaterials,
    required this.onOpenVehicles,
    this.onOpenPaymentAccounts,
    this.onOpenDmSettings,
    this.onOpenExpenseSubCategories,
  });

  final bool canManageRoles;
  final bool canManageProducts;
  final bool canManageRawMaterials;
  final bool canAccessVehicles;
  final VoidCallback onOpenRoles;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenRawMaterials;
  final VoidCallback onOpenVehicles;
  final VoidCallback? onOpenPaymentAccounts;
  final VoidCallback? onOpenDmSettings;
  final VoidCallback? onOpenExpenseSubCategories;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pages',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: 12),
            // 1. Roles
            if (canManageRoles)
            _SettingsTile(
              label: 'Roles',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => onOpenRoles());
              },
            )
            else
              Text(
                'Role management available for admins only.',
                style: TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 14,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            const SizedBox(height: 12),
            // 2. Products
            _SettingsTile(
              label: 'Products',
              subtitle: canManageProducts ? null : 'Read only',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => onOpenProducts());
              },
            ),
            const SizedBox(height: 12),
            // 3. Vehicles
            if (canAccessVehicles)
              _SettingsTile(
                label: 'Vehicles',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenVehicles());
                },
              ),
            if (canAccessVehicles) const SizedBox(height: 12),
            // 4. Payment Accounts
            if (onOpenPaymentAccounts != null)
              _SettingsTile(
                label: 'Payment Accounts',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenPaymentAccounts!());
                },
              )
            else
              Text(
                'Payment accounts available for admins only.',
                style: TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 14,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            if (onOpenPaymentAccounts != null) const SizedBox(height: 12),
            // 5. DM Settings
            if (onOpenDmSettings != null)
              _SettingsTile(
                label: 'DM Settings',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenDmSettings!());
                },
              ),
            if (onOpenDmSettings != null) const SizedBox(height: 12),
            // 6. Expense Sub Categories
            _SettingsTile(
              label: 'Expense Sub Categories',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => context.go('/expense-sub-categories'));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 13,
                  fontFamily: 'SF Pro Display',
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: AuthColors.textSub,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Extracted AppBar widget to prevent unnecessary rebuilds
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.person_outline,
            color: AuthColors.textMain,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: title.isNotEmpty
          ? Text(
              title,
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            )
          : null,
      centerTitle: true,
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AuthColors.textMain,
            ),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }
}

/// Extracted profile drawer widget to prevent unnecessary rebuilds
class _HomeProfileDrawer extends StatelessWidget {
  const _HomeProfileDrawer();

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final role = orgState.appAccessRole;
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';
    final isAdminRole = role?.isAdmin ?? fallbackAdmin;
    final canManageUsers = role?.canCreate('users') ?? isAdminRole;

    return Drawer(
      backgroundColor: AuthColors.surface,
      child: ProfileView(
        user: authState.userProfile,
        organization: organization,
        fetchUserName: (authState.userProfile?.id != null && organization?.id != null)
            ? () async {
                try {
                  final orgUser = await context.read<UsersRepository>().fetchCurrentUser(
                    orgId: organization!.id,
                    userId: authState.userProfile!.id,
                    phoneNumber: authState.userProfile!.phoneNumber,
                  );
                  return orgUser?.name;
                } catch (_) {
                  return null;
                }
              }
            : null,
        onChangeOrg: () {
          Scaffold.of(context).closeDrawer();
          Future.microtask(() => context.go('/org-selection'));
        },
        onLogout: () {
          Scaffold.of(context).closeDrawer();
          context.read<AuthBloc>().add(const AuthReset());
          Future.microtask(() => context.go('/login'));
        },
        onOpenUsers: canManageUsers
            ? () {
                Scaffold.of(context).closeDrawer();
                Future.microtask(() => context.go('/users'));
              }
            : null,
        onOpenPermissions: () {
          Scaffold.of(context).closeDrawer();
          Future.microtask(() {
            showDialog(
              context: context,
              builder: (context) => const PermissionsDialog(),
            );
          });
        },
      ),
    );
  }
}

/// Extracted settings drawer widget to prevent unnecessary rebuilds
class _HomeSettingsDrawer extends StatelessWidget {
  const _HomeSettingsDrawer();

  @override
  Widget build(BuildContext context) {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final role = orgState.appAccessRole;
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';
    final isAdminRole = role?.isAdmin ?? fallbackAdmin;

    return Drawer(
      backgroundColor: AuthColors.surface,
      child: _SettingsDrawer(
        canManageRoles: isAdminRole,
        canManageProducts: role?.canCreate('products') ?? isAdminRole,
        canManageRawMaterials: role?.canCreate('rawMaterials') ?? isAdminRole,
        canAccessVehicles: role?.canAccessPage('vehicles') ?? false,
        onOpenRoles: () {
          Scaffold.of(context).closeEndDrawer();
          Future.microtask(() => context.go('/roles'));
        },
        onOpenProducts: () {
          Scaffold.of(context).closeEndDrawer();
          Future.microtask(() => context.go('/products'));
        },
        onOpenRawMaterials: () {
          Scaffold.of(context).closeEndDrawer();
          Future.microtask(() => context.go('/raw-materials'));
        },
        onOpenVehicles: () {
          Scaffold.of(context).closeEndDrawer();
          Future.microtask(() => context.go('/vehicles'));
        },
        onOpenPaymentAccounts: isAdminRole
            ? () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => context.go('/payment-accounts'));
              }
            : null,
        onOpenDmSettings: isAdminRole
            ? () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => context.go('/dm-settings'));
              }
            : null,
        onOpenExpenseSubCategories: isAdminRole
            ? () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => context.go('/expense-sub-categories'));
              }
            : null,
      ),
    );
  }
}
