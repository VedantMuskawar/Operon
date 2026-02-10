import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:core_ui/core_ui.dart';

/// Home overview view with categorized tiles using unified HomeTile component
class HomeOverviewView extends StatefulWidget {
  const HomeOverviewView({super.key});

  @override
  State<HomeOverviewView> createState() => _HomeOverviewViewState();
}

class _HomeOverviewViewState extends State<HomeOverviewView> {
  // Category color mapping
  static const Color _peopleColor = AuthColors.warning; // Orange
  static const Color _financialColor = AuthColors.success; // Green
  static const Color _operationsColor = AuthColors.info; // Blue
  static const Color _documentsColor = AuthColors.secondary; // Purple

  // Memoized tile list - only rebuilds when role changes
  List<_TileData>? _cachedTiles;
  dynamic _cachedRoleId; // Cache role identity to detect changes

  List<_TileData> _buildTiles(dynamic role) {
    // Build tiles by category
    final peopleTiles = <_TileData>[
      const _TileData(
        icon: Icons.people_outline,
        title: 'Clients',
        route: '/clients',
        color: _peopleColor,
      ),
      const _TileData(
        icon: Icons.group_outlined,
        title: 'Employees',
        route: '/employees',
        color: _peopleColor,
      ),
    ];

    // Add attendance tile if user can access employees page
    if (role?.canAccessPage('employees') == true) {
      peopleTiles.add(const _TileData(
        icon: Icons.event_available_outlined,
        title: 'Attendance',
        route: '/attendance',
        color: _peopleColor,
      ));
    }

    if (role?.canAccessPage('vendors') == true) {
      peopleTiles.add(const _TileData(
        icon: Icons.store_outlined,
        title: 'Vendors',
        route: '/vendors',
        color: _peopleColor,
      ));
    }

    final operationsTiles = <_TileData>[];
    if (role?.canAccessPage('zonesCity') == true ||
        role?.canAccessPage('zonesRegion') == true ||
        role?.canAccessPage('zonesPrice') == true) {
      operationsTiles.add(const _TileData(
        icon: Icons.location_city_outlined,
        title: 'Zones',
        route: '/zones',
        color: _operationsColor,
      ));
    }

    final documentsTiles = <_TileData>[];
    if (role?.canAccessSection('pendingOrders') == true ||
        role?.canAccessSection('scheduleOrders') == true) {
      documentsTiles.add(const _TileData(
        icon: Icons.description_outlined,
        title: 'DM',
        route: '/delivery-memos',
        color: _documentsColor,
      ));
    }

    final financialTiles = <_TileData>[
      const _TileData(
        icon: Icons.payment_outlined,
        title: '*Transactions',
        route: '/financial-transactions',
        color: _financialColor,
      ),
      const _TileData(
        icon: Icons.payments_outlined,
        title: 'Employee Wages',
        route: '/employee-wages',
        color: _financialColor,
      ),
    ];
    if (role?.canAccessPage('accountsLedger') == true ||
        role?.isAdmin == true) {
      financialTiles.add(const _TileData(
        icon: Icons.account_balance_outlined,
        title: 'Accounts',
        route: '/accounts',
        color: _financialColor,
      ));
    }

    // Combine all tiles into a single list
    return <_TileData>[
      ...peopleTiles,
      ...operationsTiles,
      ...documentsTiles,
      ...financialTiles,
    ];
  }

  List<_TileData> _getTiles(dynamic role) {
    // Use identity check to detect role changes
    if (_cachedTiles == null || _cachedRoleId != role) {
      _cachedRoleId = role;
      _cachedTiles = _buildTiles(role);
    }
    return _cachedTiles!;
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OrganizationContextCubit>().state.appAccessRole;
    final allTiles = _getTiles(role);

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => HomeTile(
                title: allTiles[index].title,
                icon: allTiles[index].icon,
                accentColor: allTiles[index].color,
                onTap: () => context.go(allTiles[index].route),
                isCompact: true,
              ),
              childCount: allTiles.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple data class for tile configuration
class _TileData {
  const _TileData({
    required this.icon,
    required this.title,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String route;
  final Color color;
}
