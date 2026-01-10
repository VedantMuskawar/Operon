import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

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
      crossAxisSpacing: AppSpacing.paddingLG,
      mainAxisSpacing: AppSpacing.paddingLG,
      childAspectRatio: 1.2,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingXS),
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

  // Palette of vibrant colors that work well on dark backgrounds
  static final List<Color> _colorPalette = [
    AppColors.primary,        // Purple
    AppColors.info,            // Blue
    AppColors.success,         // Green
    AppColors.warning,         // Orange
    AppColors.error,           // Pink/Red
    const Color(0xFF9C27B0),  // Deep Purple
    const Color(0xFF00BCD4),  // Cyan
    const Color(0xFF4CAF50),  // Green
    const Color(0xFFFFC107),  // Amber
    const Color(0xFFFF5722),  // Deep Orange
    const Color(0xFFE91E63),   // Pink
    const Color(0xFF3F51B5),   // Indigo
    const Color(0xFF009688),   // Teal
    const Color(0xFF795548),   // Brown
    const Color(0xFF607D8B),   // Blue Grey
  ];

  Color _getRandomColor() {
    // Use label hash to get consistent random color per tile
    final hash = widget.label.hashCode;
    final index = hash.abs() % _colorPalette.length;
    return _colorPalette[index];
  }

  Color _getMixedBackgroundColor() {
    final randomColor = _getRandomColor();
    // Mix the random color with card background (75% card, 25% random color)
    // This creates subtle, varied backgrounds
    return Color.lerp(
      AppColors.cardBackground,
      randomColor.withOpacity(0.4),
      0.25,
    ) ?? AppColors.cardBackground;
  }

  @override
  Widget build(BuildContext context) {
    final randomColor = _getRandomColor();
    final backgroundColor = _getMixedBackgroundColor();

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
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingLG,
            vertical: AppSpacing.paddingXL,
          ),
          decoration: BoxDecoration(
            color: backgroundColor, // Solid mixed color instead of gradient
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: _isPressed
                  ? randomColor.withOpacity(0.6)
                  : randomColor.withOpacity(0.2),
              width: _isPressed ? 2 : 1.5,
            ),
            boxShadow: _isPressed 
                ? [
                    BoxShadow(
                      color: randomColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: randomColor.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
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
                    width: AppSpacing.avatarMD,
                    height: AppSpacing.avatarMD,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          randomColor.withOpacity(0.25),
                          randomColor.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: randomColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: AppSpacing.iconLG,
                      color: randomColor,
                    ),
                  ),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.cardBackground,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppSpacing.paddingSM),
              Text(
                widget.label,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
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

