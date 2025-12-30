import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/pending_orders_view.dart';
import 'package:dash_web/presentation/views/schedule_orders_view.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

class _HomeOverviewView extends StatelessWidget {
  const _HomeOverviewView();

  @override
  Widget build(BuildContext context) {
    final appAccessRole = context.watch<OrganizationContextCubit>().state.appAccessRole;
    final organization = context.watch<OrganizationContextCubit>().state.organization;
    final isAdmin = appAccessRole?.isAdmin ?? false;
    final tiles = <Widget>[];
    
    if (isAdmin || appAccessRole?.canCreate('employees') == true) {
      tiles.add(_OverviewTile(
        icon: Icons.badge_outlined,
        label: 'Employees',
        description: 'Manage team members',
        color: const Color(0xFF6F4BFF),
        onTap: () => context.go('/employees'),
      ));
    }
    if (isAdmin || appAccessRole?.canCreate('vendors') == true || appAccessRole?.canAccessPage('vendors') == true) {
      tiles.add(_OverviewTile(
        icon: Icons.store_outlined,
        label: 'Vendors',
        description: 'Manage vendors',
        color: const Color(0xFF9C27B0),
        onTap: () => context.go('/vendors'),
      ));
    }
    if (isAdmin ||
        appAccessRole?.canAccessPage('zonesCity') == true ||
        appAccessRole?.canAccessPage('zonesRegion') == true ||
        appAccessRole?.canAccessPage('zonesPrice') == true) {
      tiles.add(_OverviewTile(
        icon: Icons.location_city_outlined,
        label: 'Zones',
        description: 'Delivery zones & prices',
        color: const Color(0xFF5AD8A4),
        onTap: () => context.go('/zones'),
      ));
    }
    if (isAdmin || appAccessRole?.canAccessPage('clients') == true) {
      tiles.add(_OverviewTile(
        icon: Icons.people_outline,
        label: 'Clients',
        description: 'Client management',
        color: const Color(0xFFFF9800),
        onTap: () => context.go('/clients'),
      ));
    }
    // Delivery Memos - accessible to users who can view orders
    if (isAdmin ||
        appAccessRole?.canAccessSection('pendingOrders') == true ||
        appAccessRole?.canAccessSection('scheduleOrders') == true) {
      tiles.add(_OverviewTile(
        icon: Icons.description_outlined,
        label: 'Delivery Memos',
        description: 'Track delivery memos',
        color: const Color(0xFF2196F3),
        onTap: () => context.go('/delivery-memos'),
      ));
    }
    // Transactions - accessible to all authenticated users
    tiles.add(_OverviewTile(
      icon: Icons.receipt_long_outlined,
      label: 'Transactions',
      description: 'View transactions',
      color: const Color(0xFF4CAF50),
      onTap: () => context.go('/transactions'),
    ));
    // Purchases - accessible to all authenticated users
    tiles.add(_OverviewTile(
      icon: Icons.shopping_cart,
      label: 'Purchases',
      description: 'View purchases',
      color: const Color(0xFFFF9800),
      onTap: () => context.go('/purchases'),
    ));
    // Fuel Ledger - accessible to all authenticated users
    tiles.add(_OverviewTile(
      icon: Icons.local_gas_station,
      label: 'Fuel Ledger',
      description: 'Track fuel purchases',
      color: const Color(0xFFFF5722),
      onTap: () => context.go('/fuel-ledger'),
    ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                ),
              ),
              if (organization != null) ...[
                const SizedBox(height: 8),
                Text(
                  organization.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFB0B0B0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Quick Access Tiles
        if (tiles.isEmpty)
          Container(
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
        else
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: tiles,
          ),
      ],
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
                    color: widget.color.withValues(
                      alpha: _isHovered ? 0.5 : 0.2,
                    ),
                    width: _isHovered ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _glowAnimation.value * 0.3,
                      ),
                      blurRadius: 20 * _glowAnimation.value,
                      spreadRadius: -5,
                      offset: Offset(0, 10 * _glowAnimation.value),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
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
            );
          },
        ),
      ),
    );
  }
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

