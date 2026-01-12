import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/domain/entities/organization_membership.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/domain/entities/organization_user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'section_workspace_layout.dart' show computeHomeSections;

class PageWorkspaceLayout extends StatefulWidget {
  const PageWorkspaceLayout({
    super.key,
    required this.title,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
    this.onBack,
    this.hideTitle = false,
    this.allowedSections,
  });

  final String title;
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback? onBack;
  final bool hideTitle;
  final List<int>? allowedSections;

  @override
  State<PageWorkspaceLayout> createState() => _PageWorkspaceLayoutState();
}

class _PageWorkspaceLayoutState extends State<PageWorkspaceLayout> {
  bool _isProfileOpen = false;
  bool _isSettingsOpen = false;

  Widget _buildHeader(BuildContext context) {
    if (widget.hideTitle) {
      return Row(
        children: [
          IconButton(
            onPressed: widget.onBack ??
                () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        IconButton(
          onPressed: widget.onBack ??
              () {
                if (context.canPop()) {
                  context.pop();
                }
              },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white70,
          ),
        ),
        Expanded(
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 48), // Balance for icon button
      ],
    );
  }

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
    const headerHeight = 72.0;
    const topOffset = 100.0; // Space for top nav bar
    final bottomOffset = bottomSafe + 24;

    final appAccessRole = orgState.appAccessRole;
    final visibleSections = widget.allowedSections?.toList() ??
        computeHomeSections(appAccessRole);
    final isAdminRole = appAccessRole?.isAdmin ?? fallbackAdmin;
    final canManageUsers = appAccessRole?.canCreate('users') ?? isAdminRole;

    // Brighter scaffold in debug for visibility
    const scaffoldColor =
        kDebugMode ? Color(0xFF121226) : Color(0xFF010104);

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Panel
            Positioned(
              top: topOffset + headerHeight,
              left: 20,
              right: 20,
              bottom: bottomOffset,
              child: Container(
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: widget.child,
                  ),
                ),
              ),
            ),
            // Header with title and back button
            Positioned(
              top: topOffset,
              left: 20,
              right: 20,
              height: headerHeight,
              child: _buildHeader(context),
            ),
            // Top Navigation Bar with Profile and Settings (single horizontal row)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _FloatingSquareIcon(
                    icon: Icons.person_outline,
                    onTap: () => setState(() {
                      _isProfileOpen = true;
                      _isSettingsOpen = false;
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: DecoratedBox(
                        decoration: kDebugMode
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orangeAccent,
                                  width: 1.25,
                                ),
                                color: const Color(0xFF11111B).withValues(
                                  alpha: 0.95,
                                ),
                              )
                            : const BoxDecoration(),
                        child: _TopNavBar(
                          currentIndex: widget.currentIndex,
                          onTap: widget.onNavTap,
                          visibleSections: visibleSections,
                        ),
                      ),
                    ),
                  ),
                  _FloatingSquareIcon(
                    icon: Icons.settings_outlined,
                    onTap: () => setState(() {
                      _isSettingsOpen = true;
                      _isProfileOpen = false;
                    }),
                  ),
                ],
              ),
            ),
            // Overlay when side sheets are open
            AnimatedOpacity(
              opacity: (_isProfileOpen || _isSettingsOpen) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: (_isProfileOpen || _isSettingsOpen)
                  ? Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isProfileOpen = false;
                          _isSettingsOpen = false;
                        }),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.54),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Profile Side Sheet (slides from left)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: _isProfileOpen ? 0 : -media.size.width,
              child: _ProfileSideSheet(
                user: authState.userProfile,
                organization: organization,
                usersRepository: context.read<UsersRepository>(),
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
            // Settings Side Sheet (slides from right)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isSettingsOpen ? 0 : -media.size.width,
              child: _SettingsSideSheet(
                canManageRoles: isAdminRole,
                canManageProducts:
                    appAccessRole?.canCreate('products') ?? isAdminRole,
                onClose: () => setState(() => _isSettingsOpen = false),
                onOpenRoles: () => context.go('/roles'),
                onOpenProducts: () => context.go('/products'),
                onOpenPaymentAccounts:
                    isAdminRole ? () => context.go('/payment-accounts') : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.visibleSections,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> visibleSections;

  static const _items = [
    Icons.home_outlined,
    Icons.pending_actions_outlined,
    Icons.schedule_outlined,
    Icons.map_outlined,
    Icons.dashboard_outlined,
  ];

  static const _labels = [
    'Overview',
    'Pending',
    'Schedule',
    'Map',
    'Analytics',
  ];

  bool _isAccessControlOpen(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return location == '/access-control';
  }

  @override
  Widget build(BuildContext context) {
    final allowed = <int>{0};
    if (visibleSections.isNotEmpty) {
      allowed.addAll(visibleSections
          .where((index) => index >= 0 && index < _items.length));
    } else {
      allowed.addAll(List.generate(_items.length, (index) => index));
    }
    final displayed = allowed.toList()..sort();

    // Build navigation items
    final navItems = displayed.map((index) {
      final isActive = index == currentIndex && !_isAccessControlOpen(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => onTap(index),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: isActive ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.95 + (value * 0.05), // Subtle scale effect
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18 + (value * 2), // Slight padding increase when active
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Colors.transparent,
                      const Color(0xFF6F4BFF),
                      value,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value > 0.5
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6F4BFF).withValues(alpha: value * 0.3),
                              blurRadius: 12 * value,
                              offset: Offset(0, 4 * value),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          _items[index],
                          color: Color.lerp(
                            Colors.white54,
                            Colors.white,
                            value,
                          ),
                          size: 22 + (value * 1), // Slight size increase when active
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: Color.lerp(
                            Colors.white54,
                            Colors.white,
                            value,
                          )!,
                          fontSize: 15,
                          fontWeight: value > 0.5
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        child: Text(_labels[index]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();

    // If Access Control page is open via route, add it as a 6th section
    if (_isAccessControlOpen(context)) {
      navItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _AnimatedNavItem(
            key: const ValueKey('access-control'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Access Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: navItems,
      ),
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  const _AnimatedNavItem({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _FloatingSquareIcon extends StatelessWidget {
  const _FloatingSquareIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Match nav bar height: container padding (10*2) + item padding (12*2) + icon (22) = 66
    const buttonSize = 66.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF161626).withValues(alpha: 0.9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// Reuse the side sheets from section_workspace_layout
class _ProfileSideSheet extends StatelessWidget {
  const _ProfileSideSheet({
    required this.user,
    required this.organization,
    required this.usersRepository,
    required this.onClose,
    required this.onChangeOrg,
    this.showUsers = false,
    this.onOpenUsers,
    required this.onLogout,
  });

  final UserProfile? user;
  final OrganizationMembership? organization;
  final UsersRepository usersRepository;
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
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<OrganizationUser?>(
                          future: (user?.id != null && organization?.id != null)
                              ? usersRepository.fetchCurrentUser(
                                  orgId: organization!.id,
                                  userId: user!.id,
                                  phoneNumber: user!.phoneNumber,
                                )
                              : Future.value(null),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              );
                            }
                            final userName = snapshot.data?.name ?? 
                                            user?.displayName ?? 
                                            'User';
                            return Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
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
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
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
              const _ProfileAction(
                icon: Icons.security,
                label: 'Permissions',
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
    required this.onClose,
    required this.onOpenRoles,
    required this.onOpenProducts,
    this.onOpenPaymentAccounts,
  });

  final bool canManageRoles;
  final bool canManageProducts;
  final VoidCallback onClose;
  final VoidCallback onOpenRoles;
  final VoidCallback onOpenProducts;
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
              child: Icon(icon, color: Colors.white70, size: 20),
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
  final masked =
      phone.substring(0, phone.length - 4).replaceAll(RegExp(r'.'), '•');
  return '$masked$visible';
}
