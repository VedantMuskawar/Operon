import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/profile_stats_repository_adapter.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/home_overview_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/pending_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/schedule_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_map_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/attendance_view.dart';
import 'package:dash_mobile/presentation/views/cash_ledger/cash_ledger_section.dart';
import 'package:dash_mobile/shared/utils/responsive_layout.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
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
    CashLedgerSection(),
    AttendanceView(),
  ];

  static const _sectionTitles = [
    '',
    '',
    '',
    'Orders Map',
    'Cash Ledger',
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
                onProfileTap: () => context.go('/profile'),
              ),
              endDrawer: const _HomeSettingsDrawer(),
              body: ResponsiveWrapper(
                mobile: (context) => _buildHomeBody(context, homeState),
                tablet: (context) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _buildHomeBody(context, homeState),
                ),
                desktop: (context) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildHomeBody(context, homeState),
                  ),
                ),
              ),
          );
        },
        ),
      ),
    );
  }

  static Widget _buildHomeBody(BuildContext context, HomeState homeState) {
    return Stack(
      children: [
        // DotGridPattern background (matching login page)
        const Positioned.fill(
          child: RepaintBoundary(
            child: DotGridPattern(),
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
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Cash Ledger',
                  heroTag: 'nav_cash_ledger',
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
        padding: const EdgeInsets.all(AppSpacing.paddingXXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            const Text(
              'Pages',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
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
              const Text(
                'Role management available for admins only.',
                style: TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 14,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            const SizedBox(height: AppSpacing.paddingMD),
            // 2. Products
            _SettingsTile(
              label: 'Products',
              subtitle: canManageProducts ? null : 'Read only',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => onOpenProducts());
              },
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            // 3. Vehicles
            if (canAccessVehicles)
              _SettingsTile(
                label: 'Vehicles',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenVehicles());
                },
              ),
            if (canAccessVehicles) const SizedBox(height: AppSpacing.paddingMD),
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
              const Text(
                'Payment accounts available for admins only.',
                style: TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 14,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            if (onOpenPaymentAccounts != null) const SizedBox(height: AppSpacing.paddingMD),
            // 5. DM Settings
            if (onOpenDmSettings != null)
              _SettingsTile(
                label: 'DM Settings',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenDmSettings!());
                },
              ),
            if (onOpenDmSettings != null) const SizedBox(height: AppSpacing.paddingMD),
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: AuthColors.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(
                  color: AuthColors.textDisabled,
                  fontSize: 13,
                  fontFamily: 'SF Pro Display',
                ),
              )
            : null,
        trailing: const Icon(
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
  const _HomeAppBar({
    required this.title,
    required this.onProfileTap,
  });

  final String title;
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.person_outline,
          color: AuthColors.textMain,
        ),
        onPressed: onProfileTap,
      ),
      title: title.isNotEmpty
          ? Text(
              title,
              style: const TextStyle(
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
        onOpenDmSettings: () {
          Scaffold.of(context).closeEndDrawer();
          Future.microtask(() => context.go('/dm-settings'));
        },
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
