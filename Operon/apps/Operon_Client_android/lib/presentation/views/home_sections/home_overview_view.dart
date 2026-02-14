import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const Color _peopleColor = Color(0xFFB96A2C); // Muted rust
  static const Color _financialColor = Color(0xFF3E8E6F); // Industrial green
  static const Color _operationsColor = Color(0xFF3E6E8C); // Steel blue

  // Memoized tile list - only rebuilds when role changes
  List<_TileData>? _cachedTiles;
  dynamic _cachedRoleId; // Cache role identity to detect changes
  String? _cachedOrgId;

  static String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  Widget _buildFuelBalanceTile(BuildContext context, String? orgId) {
    if (orgId == null || orgId.isEmpty) {
      return const HomeTile(
        title: '—',
        subtitle: 'Fuel Balance',
        icon: Icons.local_gas_station_outlined,
        accentColor: _financialColor,
        onTap: _noOp,
        isCompact: true,
        showIcon: false,
      );
    }

    final vendorsQuery = FirebaseFirestore.instance
        .collection('VENDORS')
        .where('organizationId', isEqualTo: orgId)
        .where('vendorType', isEqualTo: 'fuel');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: vendorsQuery.snapshots(),
      builder: (context, snapshot) {
        double totalBalance = 0.0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final balance = (data['currentBalance'] as num?)?.toDouble() ?? 0.0;
            totalBalance += balance;
          }
        }

        final title = snapshot.connectionState == ConnectionState.waiting
            ? 'Loading…'
            : _formatCurrency(totalBalance);

        return HomeTile(
          title: title,
          subtitle: 'Fuel Balance',
          icon: Icons.local_gas_station_outlined,
          accentColor: _financialColor,
              titleFontSize: 18,
          onTap: _noOp,
          isCompact: true,
          showIcon: false,
        );
      },
    );
  }

  List<_TileData> _buildTiles(dynamic role, String? orgId) {
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

    if (role?.canAccessPage('vendors') == true) {
      peopleTiles.add(const _TileData(
        icon: Icons.store_outlined,
        title: 'Vendors',
        route: '/vendors',
        color: _peopleColor,
      ));
    }

    final operationsTiles = <_TileData>[];
    if (role?.canAccessSection('pendingOrders') == true ||
        role?.canAccessSection('scheduleOrders') == true) {
      operationsTiles.add(const _TileData(
        icon: Icons.description_outlined,
        title: 'DM',
        route: '/delivery-memos',
        color: _operationsColor,
      ));
    }

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

    if (role?.canAccessPage('employees') == true) {
      operationsTiles.add(const _TileData(
        icon: Icons.event_available_outlined,
        title: 'Attendance',
        route: '/attendance',
        color: _operationsColor,
      ));
    }

    final documentsTiles = <_TileData>[];

    final financialTiles = <_TileData>[
      if (role?.canAccessSection('analyticsDashboard') == true ||
          role?.canAccessPage('financialTransactions') == true ||
          role?.isAdmin == true)
        _TileData.custom(
          builder: (context) => _buildFuelBalanceTile(context, orgId),
        ),
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

  List<_TileData> _getTiles(dynamic role, String? orgId) {
    // Use identity check to detect role changes
    if (_cachedTiles == null ||
        _cachedRoleId != role ||
        _cachedOrgId != orgId) {
      _cachedRoleId = role;
      _cachedOrgId = orgId;
      _cachedTiles = _buildTiles(role, orgId);
    }
    return _cachedTiles!;
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final role = orgState.appAccessRole;
    final orgId = orgState.organization?.id;
    final allTiles = _getTiles(role, orgId);

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
              (context, index) {
                final tile = allTiles[index];
                if (tile.builder != null) {
                  return tile.builder!(context);
                }
                return HomeTile(
                  title: tile.title,
                  icon: tile.icon,
                  accentColor: tile.color,
                  onTap: () => context.go(tile.route),
                  isCompact: true,
                );
              },
              childCount: allTiles.length,
            ),
          ),
        ),
      ],
    );
  }
}

void _noOp() {}

/// Simple data class for tile configuration
class _TileData {
  const _TileData({
    required this.icon,
    required this.title,
    required this.route,
    required this.color,
  })  : readOnly = false,
        builder = null;

  const _TileData.custom({
    required this.builder,
  })  : icon = Icons.local_gas_station_outlined,
        title = 'Fuel Balance',
        route = '',
        color = AuthColors.success,
        readOnly = true;

  final IconData icon;
  final String title;
  final String route;
  final Color color;
  final bool readOnly;
  final Widget Function(BuildContext context)? builder;
}
