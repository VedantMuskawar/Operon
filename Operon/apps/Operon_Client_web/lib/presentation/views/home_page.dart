import 'dart:math' as math;

import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/dm_settings_page.dart';
import 'package:dash_web/presentation/views/pending_orders_view.dart';
import 'package:dash_web/presentation/views/schedule_orders_view.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final appAccessRole = context.watch<OrganizationContextCubit>().state.appAccessRole;
    final allowed = computeHomeSections(appAccessRole);
    if (!listEquals(allowed, _allowedSections)) {
      setState(() {
        _allowedSections = allowed;
      });
    }
    _ensureIndexAllowed();
  }

  static final _sections = [
    const _HomeOverviewView(),
    const PendingOrdersView(),
    const ScheduleOrdersView(),
    const _OrdersMapView(),
    const _AnalyticsPlaceholder(),
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

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;

    // Guard rail: if org context is missing, guide user back to selector.
    if (!orgState.hasSelection) {
      return Scaffold(
        backgroundColor: const Color(0xFF010104),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No organization selected.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/org-selection'),
                child: const Text('Choose organization'),
              ),
            ],
          ),
        ),
      );
    }

    // If we have org selection but app access role is still loading/restoring, show a lightweight loader.
    if (orgState.appAccessRole == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF010104),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Use SectionWorkspaceLayout with proper content
    return SectionWorkspaceLayout(
      panelTitle: _sectionTitles[_currentIndex],
      currentIndex: _currentIndex,
      onNavTap: _handleNavTap,
      allowedSections: _allowedSections,
      child: _sections[_currentIndex],
    );
  }
}

class _OverviewTileData {
  const _OverviewTileData({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
}

class _HomeOverviewView extends StatefulWidget {
  const _HomeOverviewView();

  @override
  State<_HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends State<_HomeOverviewView>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appAccessRole = context.watch<OrganizationContextCubit>().state.appAccessRole;
    final organization = context.watch<OrganizationContextCubit>().state.organization;
    final isAdmin = appAccessRole?.isAdmin ?? false;
    
    // Organize tiles by categories
    final peopleTiles = <_OverviewTileData>[];
    final financialTiles = <_OverviewTileData>[];
    final operationsTiles = <_OverviewTileData>[];
    
    // People & Contacts
    if (isAdmin || appAccessRole?.canCreate('employees') == true) {
      peopleTiles.add(_OverviewTileData(
        icon: Icons.badge_outlined,
        label: 'Employees',
        description: 'Manage team members',
        color: const Color(0xFF6F4BFF),
        onTap: () => context.go('/employees'),
      ));
    }
    if (isAdmin || appAccessRole?.canAccessPage('clients') == true) {
      peopleTiles.add(_OverviewTileData(
        icon: Icons.people_outline,
        label: 'Clients',
        description: 'Client management',
        color: const Color(0xFFFF9800),
        onTap: () => context.go('/clients'),
      ));
    }
    if (isAdmin || appAccessRole?.canCreate('vendors') == true || appAccessRole?.canAccessPage('vendors') == true) {
      peopleTiles.add(_OverviewTileData(
        icon: Icons.store_outlined,
        label: 'Vendors',
        description: 'Manage vendors',
        color: const Color(0xFF9C27B0),
        onTap: () => context.go('/vendors'),
      ));
    }
    
    // Financial
    financialTiles.add(_OverviewTileData(
      icon: Icons.receipt_long_outlined,
      label: 'Transactions',
      description: 'View transactions',
      color: const Color(0xFF4CAF50),
      onTap: () => context.go('/transactions'),
    ));
    financialTiles.add(_OverviewTileData(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Expenses',
      description: 'Manage expenses',
      color: const Color(0xFF6F4BFF),
      onTap: () => context.go('/expenses'),
    ));
    financialTiles.add(_OverviewTileData(
      icon: Icons.shopping_cart,
      label: 'Purchases',
      description: 'View purchases',
      color: const Color(0xFFFF9800),
      onTap: () => context.go('/purchases'),
    ));
    if (isAdmin || appAccessRole?.canAccessPage('employees') == true) {
      financialTiles.add(_OverviewTileData(
        icon: Icons.payments_outlined,
        label: 'Employee Wages',
        description: 'Manage salaries',
        color: const Color(0xFF9C27B0),
        onTap: () => context.go('/employee-wages'),
      ));
    }
    financialTiles.add(_OverviewTileData(
      icon: Icons.local_gas_station,
      label: 'Fuel Ledger',
      description: 'Track fuel purchases',
      color: const Color(0xFFFF5722),
      onTap: () => context.go('/fuel-ledger'),
    ));
    financialTiles.add(_OverviewTileData(
      icon: Icons.construction_outlined,
      label: 'Production Wages',
      description: 'Batch wages',
      color: const Color(0xFF00BCD4),
      onTap: () => context.go('/production-batches'),
    ));
    financialTiles.add(_OverviewTileData(
      icon: Icons.local_shipping_outlined,
      label: 'Trip Wages',
      description: 'Loading/unloading',
      color: const Color(0xFF3F51B5),
      onTap: () => context.go('/trip-wages'),
    ));
    
    // Operations
    if (isAdmin ||
        appAccessRole?.canAccessSection('pendingOrders') == true ||
        appAccessRole?.canAccessSection('scheduleOrders') == true) {
      operationsTiles.add(_OverviewTileData(
        icon: Icons.description_outlined,
        label: 'Delivery Memos',
        description: 'Track delivery memos',
        color: const Color(0xFF2196F3),
        onTap: () => context.go('/delivery-memos'),
      ));
    }
    if (isAdmin ||
        appAccessRole?.canAccessPage('zonesCity') == true ||
        appAccessRole?.canAccessPage('zonesRegion') == true ||
        appAccessRole?.canAccessPage('zonesPrice') == true) {
      operationsTiles.add(_OverviewTileData(
        icon: Icons.location_city_outlined,
        label: 'Zones',
        description: 'Delivery zones & prices',
        color: const Color(0xFF5AD8A4),
        onTap: () => context.go('/zones'),
      ));
    }
    // DM Settings - accessible to admins
    if (isAdmin) {
      operationsTiles.add(_OverviewTileData(
        icon: Icons.settings_outlined,
        label: 'DM Settings',
        description: 'Configure delivery memo settings',
        color: const Color(0xFF9C27B0),
        onTap: () => showDmSettingsDialog(context),
      ));
    }

    final allTiles = peopleTiles.length + financialTiles.length + operationsTiles.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: 2/3 width - Section Groups
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: allTiles == 0
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.dashboard_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Overview content coming soon',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (peopleTiles.isNotEmpty)
                        _SectionGroup(
                          title: 'People & Contacts',
                          icon: Icons.people_outline,
                          tiles: peopleTiles,
                          animationController: _entranceController,
                          delay: 0.3,
                        ),
                      if (financialTiles.isNotEmpty) ...[
                        if (peopleTiles.isNotEmpty) const SizedBox(height: 40),
                        _SectionGroup(
                          title: 'Financial',
                          icon: Icons.account_balance_outlined,
                          tiles: financialTiles,
                          animationController: _entranceController,
                          delay: 0.5,
                        ),
                      ],
                      if (operationsTiles.isNotEmpty) ...[
                        if (peopleTiles.isNotEmpty || financialTiles.isNotEmpty)
                          const SizedBox(height: 40),
                        _SectionGroup(
                          title: 'Operations',
                          icon: Icons.work_outline,
                          tiles: operationsTiles,
                          animationController: _entranceController,
                          delay: 0.7,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        // Right side: 1/3 width - Organization Name + Notifications
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Organization Name with Animated Ornament
              if (organization != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _AnimatedOrnament(animation: _entranceController),
                      _OrgName(
                        name: organization.name,
                      ),
                    ],
                  ),
                ),
              // Notification Tab
              const _NotificationTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrgName extends StatelessWidget {
  const _OrgName({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6F4BFF).withValues(alpha: 0.25),
            blurRadius: 40,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Base glass layer
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F1F33).withValues(alpha: 0.9),
                  const Color(0xFF1A1A28).withValues(alpha: 0.95),
                  const Color(0xFF151520).withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
          ),
          // Accent border glow
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          // Top-left accent corner
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomRight: Radius.circular(30),
                ),
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  colors: [
                    const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                    const Color(0xFF6F4BFF).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Bottom-right accent corner
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(24),
                  topLeft: Radius.circular(25),
                ),
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF9C27B0).withValues(alpha: 0.25),
                    const Color(0xFF9C27B0).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Decorative corner elements
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Subtle pattern overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _OrgNamePatternPainter(),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 20,
            ),
            child: Text(
              name.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.varelaRound(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 34,
                letterSpacing: 2.0,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTab extends StatelessWidget {
  const _NotificationTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF6F4BFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: Color(0xFF6F4BFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedOrnament extends StatefulWidget {
  const _AnimatedOrnament({required this.animation});

  final AnimationController animation;

  @override
  State<_AnimatedOrnament> createState() => _AnimatedOrnamentState();
}

class _AnimatedOrnamentState extends State<_AnimatedOrnament> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Floating particles
            ...List.generate(8, (index) {
              final angle = (index / 8) * 2 * math.pi;
              final radius = 80.0 + (widget.animation.value * 20);
              final x = radius * (1 + 0.3 * widget.animation.value) * 
                  (1 + 0.2 * math.sin(widget.animation.value * 2 * math.pi + angle));
              final y = radius * (1 + 0.3 * widget.animation.value) * 
                  (1 + 0.2 * math.cos(widget.animation.value * 2 * math.pi + angle));
              final opacity = 0.2 + (0.3 * widget.animation.value);
              
              return Transform.translate(
                offset: Offset(
                  x * math.cos(angle),
                  y * math.sin(angle),
                ),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            // Rotating geometric shapes
            Transform.rotate(
              angle: widget.animation.value * 2 * math.pi,
              child: Opacity(
                opacity: 0.15 * widget.animation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9C27B0),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({
    required this.title,
    required this.icon,
    required this.tiles,
    required this.animationController,
    required this.delay,
  });

  final String title;
  final IconData icon;
  final List<_OverviewTileData> tiles;
  final AnimationController animationController;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final sectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Interval(
          delay,
          delay + 0.3,
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: sectionAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: sectionAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - sectionAnimation.value)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: title,
                  icon: icon,
                  animation: sectionAnimation,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: tiles.asMap().entries.map((entry) {
                    final tileIndex = entry.key;
                    final tileData = entry.value;
                    final tileDelay = delay + 0.3 + (tileIndex * 0.1);
                    final tileAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animationController,
                        curve: Interval(
                          tileDelay.clamp(0.0, 1.0),
                          (tileDelay + 0.2).clamp(0.0, 1.0),
                          curve: Curves.elasticOut,
                        ),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: tileAnimation,
                      builder: (context, child) {
                        final clampedOpacity = tileAnimation.value.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: clampedOpacity,
                          child: Transform.scale(
                            scale: 0.7 + (tileAnimation.value * 0.3),
                            child: child,
                          ),
                        );
                      },
                      child: _OverviewTile(
                        icon: tileData.icon,
                        label: tileData.label,
                        description: tileData.description,
                        color: tileData.color,
                        onTap: tileData.onTap,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.animation,
  });

  final String title;
  final IconData icon;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-20 * (1 - animation.value), 0),
          child: Opacity(
            opacity: animation.value,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF6F4BFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTile extends StatefulWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_OverviewTile> createState() => _OverviewTileState();
}

class _OverviewTileState extends State<_OverviewTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 220,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _glowAnimation.value * 0.3,
                      ),
                      blurRadius: 25 * _glowAnimation.value,
                      spreadRadius: -3,
                      offset: Offset(0, 12 * _glowAnimation.value),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Base glass layer
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A28).withValues(
                          alpha: _isHovered ? 0.95 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: _isHovered ? 0.12 : 0.06,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Animated border glow
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.color.withValues(
                            alpha: _glowAnimation.value * 0.6,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Color accent overlay (top-left corner)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            bottomRight: Radius.circular(40),
                          ),
                          gradient: RadialGradient(
                            center: Alignment.topLeft,
                            colors: [
                              widget.color.withValues(
                                alpha: _isHovered ? 0.25 : 0.15,
                              ),
                              widget.color.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Subtle pattern overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CustomPaint(
                          painter: _TilePatternPainter(
                            color: widget.color.withValues(
                              alpha: _isHovered ? 0.08 : 0.04,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.color.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 28,
                              color: widget.color,
                            ),
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TilePatternPainter extends CustomPainter {
  const _TilePatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw subtle diagonal lines pattern
    const spacing = 20.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrgNamePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw subtle grid pattern
    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }

    // Draw subtle diagonal accent
    final accentPaint = Paint()
      ..color = const Color(0xFF6F4BFF).withValues(alpha: 0.08)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, size.height),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrdersMapView extends StatelessWidget {
  const _OrdersMapView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Orders Map',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF5AD8A4).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFF5AD8A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const _EmptyStateCard(
          icon: Icons.map_outlined,
          title: 'Orders Map',
          description: 'Visualize order locations and delivery routes',
          color: Color(0xFF5AD8A4),
        ),
      ],
    );
  }
}

class _AnalyticsPlaceholder extends StatelessWidget {
  const _AnalyticsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _EmptyStateCard(
        icon: Icons.dashboard_outlined,
        title: 'Analytics Dashboard',
        description: 'View insights and performance metrics',
        color: Color(0xFF6F4BFF),
        isCentered: true,
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.isCentered = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B1B2C).withValues(alpha: 0.6),
            const Color(0xFF161622).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (isCentered) {
      return Center(child: content);
    }
    return content;
  }
}

