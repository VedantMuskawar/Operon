import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/organization_membership.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/pending_orders_view.dart';
import 'package:dash_mobile/presentation/widgets/quick_action_menu.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/permissions_section.dart';
import 'package:flutter/material.dart';
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

class HomeWorkspaceLayout extends StatefulWidget {
  const HomeWorkspaceLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
    this.allowedSections,
    this.panelTitle,
  });

  final Widget child;
  final String? panelTitle;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final List<int>? allowedSections;

  @override
  State<HomeWorkspaceLayout> createState() => _HomeWorkspaceLayoutState();
}

class _HomeWorkspaceLayoutState extends State<HomeWorkspaceLayout> {
  bool _isProfileOpen = false;
  bool _isSettingsOpen = false;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final fallbackAdmin = (organization?.role.toUpperCase() ?? '') == 'ADMIN';

    final media = MediaQuery.of(context);
    final statusBar = media.padding.top;
    final bottomSafe = media.padding.bottom;
    final totalHeight = media.size.height;
    const topOffset = 80.0;
    final bottomOffset = bottomSafe + 80;
    final rawHeight = totalHeight - statusBar - topOffset - bottomOffset;
    final panelHeight = rawHeight.clamp(300, totalHeight).toDouble();

    final role = orgState.role;
    final visibleSections = widget.allowedSections?.toList() ??
        computeHomeSections(role);
    final isAdminRole = role?.isAdmin ?? fallbackAdmin;
    final canManageUsers = role?.canCreate('users') ?? isAdminRole;

    return Scaffold(
      backgroundColor: const Color(0xFF010104),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _SectionPanel(
                    height: panelHeight,
                    title: widget.panelTitle,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: QuickNavBar(
                currentIndex: widget.currentIndex,
                onTap: widget.onNavTap,
                visibleSections: visibleSections,
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: _FloatingCircleIcon(
                icon: Icons.person_outline,
                onTap: () => setState(() {
                  _isProfileOpen = true;
                  _isSettingsOpen = false;
                }),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _FloatingCircleIcon(
                icon: Icons.settings_outlined,
                onTap: () => setState(() {
                  _isSettingsOpen = true;
                  _isProfileOpen = false;
                }),
              ),
            ),
            // Organization name display (only on home page)
            if (widget.currentIndex == 0 && organization != null)
              Positioned(
                top: 16,
                left: 72, // Leave space for profile icon (48px + 16px margin + 8px gap)
                right: 72, // Leave space for settings icon (48px + 16px margin + 8px gap)
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11111B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      organization.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            if (_isProfileOpen || _isSettingsOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isProfileOpen = false;
                    _isSettingsOpen = false;
                  }),
                  child: Container(color: Colors.black54),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: _isProfileOpen ? 0 : -media.size.width,
              child: _ProfileSideSheet(
                user: authState.userProfile,
                organization: organization,
                onClose: () => setState(() => _isProfileOpen = false),
                onChangeOrg: () {
                  setState(() => _isProfileOpen = false);
                  context.go('/org-selection');
                },
                showUsers: canManageUsers,
                onOpenUsers: canManageUsers ? () => context.go('/users') : null,
                onLogout: () {
                  context.read<AuthBloc>().add(const AuthReset());
                  context.go('/login');
                },
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isSettingsOpen ? 0 : -media.size.width,
              child: _SettingsSideSheet(
                context: context,
                canManageRoles: isAdminRole,
                canManageProducts:
                    role?.canCreate('products') ?? isAdminRole,
                canManageRawMaterials:
                    role?.canCreate('rawMaterials') ?? isAdminRole,
                canAccessVehicles: role?.canAccessPage('vehicles') ?? false,
                onClose: () => setState(() => _isSettingsOpen = false),
                onOpenRoles: () => context.go('/roles'),
                onOpenProducts: () => context.go('/products'),
                onOpenRawMaterials: () => context.go('/raw-materials'),
                onOpenVehicles: () => context.go('/vehicles'),
                onOpenPaymentAccounts: isAdminRole ? () => context.go('/payment-accounts') : null,
              ),
            ),
            // Quick Action Menu - visible on Home and Pending Orders pages
            if (widget.currentIndex == 0 || widget.currentIndex == 1)
              Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  final bottomPadding = media.padding.bottom;
                  // Nav bar height (~80px) + safe area bottom + spacing (20px)
                  final bottomOffset = 80 + bottomPadding + 20;
                  return QuickActionMenu(
                    right: 40,
                    bottom: bottomOffset,
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
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.height,
    required this.child,
    this.title,
  });

  final double height;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F33), Color(0xFF0F0F16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 45,
            offset: Offset(0, 25),
          ),
        ],
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCircleIcon extends StatelessWidget {
  const _FloatingCircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF161626).withOpacity(0.9),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProfileSideSheet extends StatelessWidget {
  const _ProfileSideSheet({
    required this.user,
    required this.organization,
    required this.onClose,
    required this.onChangeOrg,
    this.showUsers = false,
    this.onOpenUsers,
    required this.onLogout,
  });

  final UserProfile? user;
  final OrganizationMembership? organization;
  final VoidCallback onClose;
  final VoidCallback onChangeOrg;
  final bool showUsers;
  final VoidCallback? onOpenUsers;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.78).clamp(280.0, 420.0);
    final maskedPhone = _maskPhone(user?.phoneNumber ?? '');

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF11111B),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          maskedPhone.isNotEmpty ? maskedPhone : '—',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        if (organization != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${organization!.name} • ${organization!.role}',
                            style:
                                const TextStyle(color: Colors.white38, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _ProfileAction(
                icon: Icons.swap_horiz,
                label: 'Change Organization',
                onTap: () {
                  onClose();
                  onChangeOrg();
                },
              ),
            if (showUsers)
              _ProfileAction(
                icon: Icons.group_add_outlined,
                label: 'Users',
                onTap: () {
                  onClose();
                  onOpenUsers?.call();
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
                  onClose();
                  showDialog(
                    context: context,
                    builder: (context) => const PermissionsDialog(),
                  );
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
              const Spacer(),
              DashButton(
                label: 'Logout',
                onPressed: () {
                  onClose();
                  onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSideSheet extends StatelessWidget {
  const _SettingsSideSheet({
    required this.canManageRoles,
    required this.canManageProducts,
    required this.canManageRawMaterials,
    required this.canAccessVehicles,
    required this.onClose,
    required this.onOpenRoles,
    required this.onOpenProducts,
    required this.onOpenRawMaterials,
    required this.onOpenVehicles,
    this.onOpenPaymentAccounts,
    required this.context,
  });

  final BuildContext context;

  final bool canManageRoles;
  final bool canManageProducts;
  final bool canManageRawMaterials;
  final bool canAccessVehicles;
  final VoidCallback onClose;
  final VoidCallback onOpenRoles;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenRawMaterials;
  final VoidCallback onOpenVehicles;
  final VoidCallback? onOpenPaymentAccounts;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.78).clamp(280.0, 420.0);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF11111B),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Pages',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              if (canManageRoles)
                _SettingsTile(
                  label: 'Roles',
                  onTap: () {
                    onClose();
                    onOpenRoles();
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
                  onClose();
                  onOpenProducts();
                },
              ),
              const SizedBox(height: 12),
              _SettingsTile(
                label: 'Raw Materials',
                subtitle: canManageRawMaterials ? null : 'Read only',
                onTap: () {
                  onClose();
                  onOpenRawMaterials();
                },
              ),
              const SizedBox(height: 12),
              if (canAccessVehicles)
                _SettingsTile(
                  label: 'Vehicles',
                  onTap: () {
                    onClose();
                    onOpenVehicles();
                  },
                ),
              const SizedBox(height: 12),
              if (onOpenPaymentAccounts != null)
                _SettingsTile(
                  label: 'Payment Accounts',
                  onTap: () {
                    onClose();
                    onOpenPaymentAccounts!();
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
                  onClose();
                  context.go('/expense-sub-categories');
                },
              ),
            ],
          ),
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
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(color: Colors.white38),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.white30),
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.white),
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

