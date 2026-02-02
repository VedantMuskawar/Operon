import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/data/repositories/profile_stats_repository_adapter.dart';
import 'package:dash_web/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/fleet_map_screen.dart';
import 'package:dash_web/presentation/views/pending_orders_view.dart';
import 'package:dash_web/presentation/views/schedule_orders_view.dart';
import 'package:dash_web/presentation/views/home_sections/attendance_view.dart';
import 'package:dash_web/presentation/views/analytics_dashboard_view.dart';
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
  static final _sections = [
    const _HomeOverviewView(),
    const PendingOrdersView(),
    const ScheduleOrdersView(),
    const FleetMapScreen(),
    const AnalyticsDashboardView(),
    const AttendanceView(),
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
    final orgState = context.watch<OrganizationContextCubit>().state;
    final pendingOrdersRepository = context.read<PendingOrdersRepository>();
    final profileStatsRepository = ProfileStatsRepositoryAdapter(
      pendingOrdersRepository: pendingOrdersRepository,
    );

    // Guard rail: if org context is missing, guide user back to selector.
    if (!orgState.hasSelection) {
      return Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No organization selected.',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontFamily: 'SF Pro Display',
                ),
              ),
              const SizedBox(height: 12),
              DashButton(
                label: 'Choose organization',
                onPressed: () => context.go('/org-selection'),
              ),
            ],
          ),
        ),
      );
    }

    // If we have org selection but app access role is still loading/restoring, show a lightweight loader.
    if (orgState.appAccessRole == null) {
      return const Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
          ),
        ),
      );
    }

    // Use HomeCubit for state management
    // Get organization ID for key to prevent recreation when org doesn't change
    final orgId = orgState.organization?.id ?? 'no-org';
    
    return BlocProvider(
      key: ValueKey('home_cubit_$orgId'), // Prevent recreation when org doesn't change
      create: (context) {
        final cubit = HomeCubit(
          profileStatsRepository: profileStatsRepository,
        );
        
        // Initialize with current role
        cubit.updateAppAccessRole(orgState.appAccessRole);
        
        // Defer loadProfileStats until after first frame to prevent blocking initial render
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final currentOrgState = context.read<OrganizationContextCubit>().state;
            if (currentOrgState.organization != null) {
              cubit.loadProfileStats(currentOrgState.organization!.id);
            }
          }
        });
        
        return cubit;
      },
      child: BlocListener<OrganizationContextCubit, OrganizationContextState>(
        listener: (context, newOrgState) {
          final homeCubit = context.read<HomeCubit>();
          homeCubit.updateAppAccessRole(newOrgState.appAccessRole);
          if (newOrgState.organization != null) {
            homeCubit.loadProfileStats(newOrgState.organization!.id);
          } else {
            homeCubit.loadProfileStats('');
          }
        },
        child: BlocBuilder<HomeCubit, HomeState>(
          buildWhen: (previous, current) => 
              previous.currentIndex != current.currentIndex ||
              previous.allowedSections != current.allowedSections,
          builder: (context, homeState) {
          return SectionWorkspaceLayout(
            panelTitle: _sectionTitles[homeState.currentIndex],
            currentIndex: homeState.currentIndex,
            onNavTap: (index) {
              // Cash Ledger is the 6th nav item (index 5) and opens its own page
              if (index == 5) {
                context.go('/cash-ledger');
                return;
              }
              context.read<HomeCubit>().switchToSection(index);
            },
            allowedSections: homeState.allowedSections,
            child: _sections[homeState.currentIndex],
          );
        },
        ),
      ),
    );
  }
}

class _TileData {
  const _TileData({
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
    final isAdmin = appAccessRole?.isAdmin ?? false;
    
    // Organize tiles by categories
    final peopleTiles = <_TileData>[];
    final financialTiles = <_TileData>[];
    final operationsTiles = <_TileData>[];
    
    // People & Contacts
    if (isAdmin || appAccessRole?.canCreate('employees') == true) {
      peopleTiles.add(_TileData(
        icon: Icons.badge_outlined,
        label: 'Employees',
        description: 'Manage team members',
        color: AuthColors.warning, // Orange
        onTap: () => context.go('/employees'),
      ));
    }
    if (isAdmin || appAccessRole?.canAccessPage('employees') == true) {
      peopleTiles.add(_TileData(
        icon: Icons.event_available_outlined,
        label: 'Attendance',
        description: 'Track employee attendance',
        color: AuthColors.warning, // Orange
        onTap: () => context.go('/attendance'),
      ));
    }
    if (isAdmin || appAccessRole?.canAccessPage('clients') == true) {
      peopleTiles.add(_TileData(
        icon: Icons.people_outline,
        label: 'Clients',
        description: 'Client management',
        color: AuthColors.warning, // Orange
        onTap: () => context.go('/clients'),
      ));
    }
    if (isAdmin || appAccessRole?.canCreate('vendors') == true || appAccessRole?.canAccessPage('vendors') == true) {
      peopleTiles.add(_TileData(
        icon: Icons.store_outlined,
        label: 'Vendors',
        description: 'Manage vendors',
        color: AuthColors.warning, // Orange
        onTap: () => context.go('/vendors'),
      ));
    }
    
    // Financial
    financialTiles.add(_TileData(
      icon: Icons.receipt_long_outlined,
      label: '*Transactions',
      description: 'View transactions',
      color: AuthColors.success, // Green
      onTap: () => context.go('/financial-transactions'),
    ));
    if (isAdmin || appAccessRole?.canAccessPage('employees') == true) {
      financialTiles.add(_TileData(
        icon: Icons.payments_outlined,
        label: 'Employee Wages',
        description: 'Manage salaries',
        color: AuthColors.success, // Green
        onTap: () => context.go('/employee-wages'),
      ));
    }
    if (isAdmin) {
      financialTiles.add(_TileData(
        icon: Icons.calendar_month_outlined,
        label: 'Monthly Salary & Bonus',
        description: 'Bulk salary and bonus',
        color: AuthColors.success, // Green
        onTap: () => context.go('/monthly-salary-bonus'),
      ));
    }
    financialTiles.add(_TileData(
      icon: Icons.local_gas_station,
      label: 'Fuel Ledger',
      description: 'Track fuel purchases',
      color: AuthColors.success, // Green
      onTap: () => context.go('/fuel-ledger'),
    ));
    financialTiles.add(_TileData(
      icon: Icons.construction_outlined,
      label: 'Production Wages',
      description: 'Batch wages',
      color: AuthColors.success, // Green
      onTap: () => context.go('/production-batches'),
    ));
    financialTiles.add(_TileData(
      icon: Icons.local_shipping_outlined,
      label: 'Trip Wages',
      description: 'Loading/unloading',
      color: AuthColors.success, // Green
      onTap: () => context.go('/trip-wages'),
    ));
    
    // Operations
    if (isAdmin ||
        appAccessRole?.canAccessSection('pendingOrders') == true ||
        appAccessRole?.canAccessSection('scheduleOrders') == true) {
      operationsTiles.add(_TileData(
        icon: Icons.description_outlined,
        label: 'Delivery Memos',
        description: 'Track delivery memos',
        color: AuthColors.info, // Blue
        onTap: () => context.go('/delivery-memos'),
      ));
    }
    if (isAdmin ||
        appAccessRole?.canAccessPage('zonesCity') == true ||
        appAccessRole?.canAccessPage('zonesRegion') == true ||
        appAccessRole?.canAccessPage('zonesPrice') == true) {
      operationsTiles.add(_TileData(
        icon: Icons.location_city_outlined,
        label: 'Zones',
        description: 'Delivery zones & prices',
        color: AuthColors.info, // Blue
        onTap: () => context.go('/zones'),
      ));
    }

    // Combine all tiles into a single list
    final allTiles = <_TileData>[
      ...peopleTiles,
      ...financialTiles,
      ...operationsTiles,
    ];

    return allTiles.isEmpty
        ? Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AuthColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.dashboard_outlined,
                  size: 64,
                  color: AuthColors.textMainWithOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Overview content coming soon',
                  style: TextStyle(
                    color: AuthColors.textMainWithOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiles section - 2/3 width
              Expanded(
                flex: 2,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: allTiles.length,
                  itemBuilder: (context, index) {
                    final tileData = allTiles[index];
                    final tileDelay = 0.1 + (index * 0.05);
                    final tileAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _entranceController,
                        curve: Interval(
                          tileDelay.clamp(0.0, 1.0),
                          (tileDelay + 0.2).clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      ),
                    );
                    return AnimatedBuilder(
                      animation: tileAnimation,
                      builder: (context, child) {
                        final clampedOpacity = tileAnimation.value.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: clampedOpacity,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - clampedOpacity)),
                            child: child,
                          ),
                        );
                      },
                      child: HomeTile(
                        title: tileData.label,
                        icon: tileData.icon,
                        accentColor: tileData.color,
                        onTap: tileData.onTap,
                        isCompact: false,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // Notification section - 1/3 width
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Additional container above notification - DISABLED
                    // Container(
                    //   padding: const EdgeInsets.all(20),
                    //   decoration: BoxDecoration(
                    //     color: const Color(0xFF1A1A1A), // Same as HomeTile background
                    //     borderRadius: BorderRadius.circular(20),
                    //     border: Border.all(
                    //       color: Colors.white.withOpacity(0.1),
                    //       width: 1,
                    //     ),
                    //   ),
                    //   child: _DeliveryProgressWidget(),
                    // ),
                    // const SizedBox(height: 20),
                    _NotificationSection(
                      animationController: _entranceController,
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}

/// Notification section widget with HomeTile background
class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.animationController,
  });

  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    final notificationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(
          0.3,
          0.5,
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: notificationAnimation,
      builder: (context, child) {
        final clampedOpacity = notificationAnimation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedOpacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - clampedOpacity)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AuthColors.surface, // Same as HomeTile background
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: AuthColors.textMain,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Notifications',
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200, // Fixed height for notification content area
                    child: Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(
                          color: AuthColors.textMainWithOpacity(0.5),
                          fontSize: 14,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}



/// Widget showing delivery progress for today's scheduled trips
class _DeliveryProgressWidget extends StatelessWidget {
  const _DeliveryProgressWidget();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    
    // Return empty if no organization selected
    if (!orgState.hasSelection || orgState.organization == null) {
      return const SizedBox.shrink();
    }

    final organizationId = orgState.organization!.id;
    final currentDate = DateTime.now();
    
    final repository = context.read<ScheduledTripsRepository>();
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repository.watchScheduledTripsForDate(
        organizationId: organizationId,
        scheduledDate: currentDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading trips',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          );
        }

        final trips = snapshot.data ?? [];
        final totalTrips = trips.length;
        
        // Handle empty state - no scheduled trips
        if (totalTrips == 0) {
          return Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 0.0,
                    strokeWidth: 14,
                    backgroundColor: AuthColors.textMainWithOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AuthColors.successVariant),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '0%',
                        style: TextStyle(
                          color: AuthColors.textMainWithOpacity(0.5),
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No trips',
                        style: TextStyle(
                          color: AuthColors.textMainWithOpacity(0.4),
                          fontSize: 12,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final deliveredTrips = trips.where((trip) {
          final status = (trip['tripStatus'] as String? ?? '').toLowerCase();
          return status == 'delivered';
        }).length;

        final progress = deliveredTrips / totalTrips;
        final percentage = (progress * 100).round();

        return Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 14,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5AD8A4)),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SF Pro Display',
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
