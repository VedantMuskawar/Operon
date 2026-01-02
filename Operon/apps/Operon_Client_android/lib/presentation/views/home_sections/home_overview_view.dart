import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';

class HomeOverviewView extends StatelessWidget {
  const HomeOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<OrganizationContextCubit>().state.role;
    final tiles = <Widget>[
      const _OverviewTile(
        icon: Icons.people_outline,
        label: 'Clients',
        route: '/clients',
        category: _ModuleCategory.people,
      ),
      const _OverviewTile(
        icon: Icons.group_outlined,
        label: 'Employees',
        route: '/employees',
        category: _ModuleCategory.people,
      ),
    ];
    if (role?.canAccessPage('vendors') == true) {
      tiles.add(const _OverviewTile(
        icon: Icons.store_outlined,
        label: 'Vendors',
        route: '/vendors',
        category: _ModuleCategory.people,
      ));
    }
    if (role?.canAccessPage('zonesCity') == true ||
        role?.canAccessPage('zonesRegion') == true ||
        role?.canAccessPage('zonesPrice') == true) {
      tiles.add(const _OverviewTile(
        icon: Icons.location_city_outlined,
        label: 'Zones',
        route: '/zones',
        category: _ModuleCategory.operations,
      ));
    }
    // Delivery Memos - accessible to users who can view orders
    if (role?.canAccessSection('pendingOrders') == true ||
        role?.canAccessSection('scheduleOrders') == true) {
      tiles.add(const _OverviewTile(
        icon: Icons.description_outlined,
        label: 'DM',
        route: '/delivery-memos',
        category: _ModuleCategory.documents,
      ));
    }
    // Transactions - accessible to all users
    tiles.add(const _OverviewTile(
      icon: Icons.payment_outlined,
      label: 'Transactions',
      route: '/transactions',
      category: _ModuleCategory.financial,
    ));
    // Fuel Ledger - accessible to all users
    tiles.add(const _OverviewTile(
      icon: Icons.local_gas_station,
      label: 'Fuel Ledger',
      route: '/fuel-ledger',
      category: _ModuleCategory.financial,
    ));
    // Employee Wages - accessible to all users
    tiles.add(const _OverviewTile(
      icon: Icons.payments_outlined,
      label: 'Employee Wages',
      route: '/employee-wages',
      category: _ModuleCategory.financial,
    ));
    // Purchases - accessible to all users
    tiles.add(const _OverviewTile(
      icon: Icons.shopping_cart_outlined,
      label: 'Purchases',
      route: '/purchases',
      category: _ModuleCategory.financial,
    ));
    // Expenses - accessible to all users
    tiles.add(const _OverviewTile(
      icon: Icons.receipt_long_outlined,
      label: 'Expenses',
      route: '/expenses',
      category: _ModuleCategory.financial,
    ));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: tiles,
    );
  }
}

enum _ModuleCategory {
  people,
  operations,
  financial,
  documents,
}

class _OverviewTile extends StatefulWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.category,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final String route;
  final _ModuleCategory category;
  final int? badgeCount;

  @override
  State<_OverviewTile> createState() => _OverviewTileState();
}

class _OverviewTileState extends State<_OverviewTile> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case _ModuleCategory.people:
        return const Color(0xFF4A90E2); // Blue
      case _ModuleCategory.operations:
        return const Color(0xFF4CAF50); // Green
      case _ModuleCategory.financial:
        return const Color(0xFFFF9800); // Orange
      case _ModuleCategory.documents:
        return const Color(0xFF6F4BFF); // Purple
    }
  }

  List<Color> _getGradientColors() {
    final baseColor = _getCategoryColor();
    return [
      baseColor.withOpacity(0.15),
      baseColor.withOpacity(0.05),
      const Color(0xFF13131E),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();
    final gradientColors = _getGradientColors();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () => context.go(widget.route),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isPressed
                  ? categoryColor.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: _isPressed ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? categoryColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.3),
                blurRadius: _isPressed ? 20 : 12,
                offset: Offset(0, _isPressed ? 8 : 4),
                spreadRadius: _isPressed ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          categoryColor.withOpacity(0.25),
                          categoryColor.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: categoryColor,
                    ),
                  ),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF13131E),
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

