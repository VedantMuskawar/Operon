import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

class QuickNavBar extends StatelessWidget {
  const QuickNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.visibleSections,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int>? visibleSections;

  static const _items = [
    Icons.home_rounded,
    Icons.pending_actions_rounded,
    Icons.schedule_rounded,
    Icons.map_rounded,
    Icons.dashboard_rounded,
    Icons.event_available_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final allowed = <int>{0};
    if (visibleSections != null) {
      allowed.addAll(visibleSections!
          .where((index) => index >= 0 && index < _items.length));
    } else {
      allowed.addAll(List.generate(_items.length, (index) => index));
    }
    final displayed = allowed.toList()..sort();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingMD),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM, vertical: AppSpacing.paddingSM),
        decoration: BoxDecoration(
          color: AuthColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: displayed.map((index) {
            final isActive = currentIndex >= 0 && index == currentIndex;
            return Expanded(
              child: _NavBarItem(
                icon: _items[index],
                isActive: isActive,
                onTap: () => onTap(index),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _colorAnimation = ColorTween(
      begin: AuthColors.textDisabled,
      end: AuthColors.primary,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AuthColors.primary.withOpacity(0.2 * _fadeAnimation.value)
                  : AuthColors.background.withOpacity(0),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Icon(
                    widget.icon,
                    color: _colorAnimation.value,
                    size: AppSpacing.iconLG,
                  ),
                ),
                if (widget.isActive && _fadeAnimation.value > 0) ...[
                  const SizedBox(height: AppSpacing.paddingXS),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AuthColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
