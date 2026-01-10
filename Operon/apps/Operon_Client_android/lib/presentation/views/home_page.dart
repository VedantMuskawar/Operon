import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/home_overview_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/pending_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/schedule_orders_view.dart';
import 'package:dash_mobile/presentation/views/home_sections/orders_map_view.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/permissions_section.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

List<int> computeHomeSections(OrganizationRole? role) {
  final visible = <int>[0];
  if (role == null) return visible;
  if (role.canAccessSection('pendingOrders')) visible.add(1);
  if (role.canAccessSection('scheduleOrders')) visible.add(2);
  if (role.canAccessSection('ordersMap')) visible.add(3);
  if (role.canAccessSection('analyticsDashboard')) visible.add(4);
  return visible;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentIndex = widget.initialIndex;
  List<int> _allowedSections = const [0];

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
      _ensureIndexAllowed();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = context.watch<OrganizationContextCubit>().state.role;
    final allowed = computeHomeSections(role);
    if (!listEquals(allowed, _allowedSections)) {
      setState(() {
        _allowedSections = allowed;
      });
    }
    _ensureIndexAllowed();
  }

  static const _sections = [
    HomeOverviewView(),
    PendingOrdersView(),
    ScheduleOrdersView(),
    OrdersMapView(),
    _AnalyticsPlaceholder(),
  ];

  static const _sectionTitles = [
    '',
    '',
    '',
    'Orders Map',
    '',
  ];

  void _ensureIndexAllowed() {
    if (!_allowedSections.contains(_currentIndex)) {
      setState(() {
        _currentIndex = _allowedSections.first;
      });
    }
  }

  void _handleNavTap(int index) {
    if (!_allowedSections.contains(index)) return;
    setState(() => _currentIndex = index);
  }

  Widget _buildProfileDrawer(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final role = orgState.role;
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';
    final isAdminRole = role?.isAdmin ?? fallbackAdmin;
    final canManageUsers = role?.canCreate('users') ?? isAdminRole;

    return _ProfileDrawer(
      user: authState.userProfile,
      organization: organization,
      showUsers: canManageUsers,
      onOpenUsers: canManageUsers ? () {
        Scaffold.of(context).closeDrawer();
        Future.microtask(() => context.go('/users'));
      } : null,
      onChangeOrg: () {
        Scaffold.of(context).closeDrawer();
        Future.microtask(() => context.go('/org-selection'));
      },
      onLogout: () {
        Scaffold.of(context).closeDrawer();
        context.read<AuthBloc>().add(const AuthReset());
        Future.microtask(() => context.go('/login'));
      },
    );
  }

  Widget _buildSettingsDrawer(BuildContext context) {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final role = orgState.role;
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';
    final isAdminRole = role?.isAdmin ?? fallbackAdmin;

    return _SettingsDrawer(
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
      onOpenPaymentAccounts: isAdminRole ? () {
        Scaffold.of(context).closeEndDrawer();
        Future.microtask(() => context.go('/payment-accounts'));
      } : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSections = _allowedSections;
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;
    final bottomOffset = 80 + bottomPadding + 20;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _sectionTitles[_currentIndex].isNotEmpty
            ? Text(
                _sectionTitles[_currentIndex],
                style: AppTypography.h2,
              )
            : null,
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0A0A0A),
        child: Builder(
          builder: (context) => _buildProfileDrawer(context),
        ),
      ),
      endDrawer: Drawer(
        backgroundColor: const Color(0xFF0A0A0A),
        child: Builder(
          builder: (context) => _buildSettingsDrawer(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.pagePaddingAll,
                    child: _sections[_currentIndex],
                  ),
                ),
                QuickNavBar(
                  currentIndex: _currentIndex,
                  onTap: _handleNavTap,
                  visibleSections: visibleSections,
                ),
              ],
            ),
            // Quick Action Menu - visible on Home and Pending Orders pages
            if (_currentIndex == 0 || _currentIndex == 1)
              QuickActionMenu(
                actions: [
                  QuickActionItem(
                    icon: Icons.receipt,
                    label: 'Add Expense',
                    onTap: () {
                      context.go('/record-expense');
                    },
                  ),
                  QuickActionItem(
                    icon: Icons.payment,
                    label: 'Payments',
                    onTap: () {
                      context.go('/record-payment');
                    },
                  ),
                  QuickActionItem(
                    icon: Icons.shopping_cart,
                    label: 'Record Purchase',
                    onTap: () {
                      context.go('/record-purchase');
                    },
                  ),
                  QuickActionItem(
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
      ),
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Analytics coming soon',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _ProfileDrawer extends StatelessWidget {
  const _ProfileDrawer({
    required this.user,
    required this.organization,
    required this.onChangeOrg,
    this.showUsers = false,
    this.onOpenUsers,
    required this.onLogout,
  });

  final UserProfile? user;
  final OrganizationMembership? organization;
  final VoidCallback onChangeOrg;
  final bool showUsers;
  final VoidCallback? onOpenUsers;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final maskedPhone = _maskPhone(user?.phoneNumber ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1F1F2C),
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: AppTypography.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        maskedPhone.isNotEmpty ? maskedPhone : '—',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      ),
                      if (organization != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${organization!.name} • ${organization!.role}',
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Quick Actions',
              style: AppTypography.h4.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _ProfileAction(
              icon: Icons.swap_horiz,
              label: 'Change Organization',
              onTap: () {
                Scaffold.of(context).closeDrawer();
                Future.microtask(() => onChangeOrg());
              },
            ),
            if (showUsers)
              _ProfileAction(
                icon: Icons.group_add_outlined,
                label: 'Users',
                onTap: () {
                  Scaffold.of(context).closeDrawer();
                  Future.microtask(() => onOpenUsers?.call());
                },
              ),
            const _ProfileAction(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
            ),
            _ProfileAction(
              icon: Icons.security,
              label: 'Permissions',
              onTap: () {
                Scaffold.of(context).closeDrawer();
                Future.microtask(() {
                  showDialog(
                    context: context,
                    builder: (context) => const PermissionsDialog(),
                  );
                });
              },
            ),
            const _ProfileAction(
              icon: Icons.lock_outline,
              label: 'Security',
            ),
            const _ProfileAction(
              icon: Icons.support_agent,
              label: 'Support',
            ),
            const SizedBox(height: 24),
            DashButton(
              label: 'Logout',
              onPressed: () {
                Scaffold.of(context).closeDrawer();
                Future.microtask(() => onLogout());
              },
            ),
          ],
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
              style: AppTypography.h1,
            ),
            const SizedBox(height: 16),
            Text(
              'Pages',
              style: AppTypography.body.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
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
                style: TextStyle(color: Colors.white38),
              ),
            const SizedBox(height: 12),
            _SettingsTile(
              label: 'Products',
              subtitle: canManageProducts ? null : 'Read only',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => onOpenProducts());
              },
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              label: 'Raw Materials',
              subtitle: canManageRawMaterials ? null : 'Read only',
              onTap: () {
                Scaffold.of(context).closeEndDrawer();
                Future.microtask(() => onOpenRawMaterials());
              },
            ),
            const SizedBox(height: 12),
            if (canAccessVehicles)
              _SettingsTile(
                label: 'Vehicles',
                onTap: () {
                  Scaffold.of(context).closeEndDrawer();
                  Future.microtask(() => onOpenVehicles());
                },
              ),
            const SizedBox(height: 12),
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
                style: TextStyle(color: Colors.white38),
              ),
            const SizedBox(height: 12),
            _SettingsTile(
              label: 'Expense Sub-Categories',
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
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textDisabled),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.borderDefault,
              ),
              child: Icon(icon, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

String _maskPhone(String phone) {
  if (phone.isEmpty) return '';
  if (phone.length <= 4) return phone;
  final visible = phone.substring(phone.length - 4);
  final masked = phone.substring(0, phone.length - 4).replaceAll(RegExp(r'.'), '•');
  return '$masked$visible';
}

