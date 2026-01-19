import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/auth_colors.dart';

/// Navigation item configuration for FloatingNavBar
class NavBarItem {
  const NavBarItem({
    required this.icon,
    required this.label,
    this.heroTag,
  });

  final IconData icon;
  final String label;
  final String? heroTag;
}

/// A modern floating navigation bar with glassmorphic design
/// 
/// **Web Behavior:**
/// - Position: Floating at the TOP center
/// - Content: Icon + Text Label (Row layout)
/// - Animation: Animated highlight behind selected item
/// 
/// **Android Behavior:**
/// - Position: Floating at the BOTTOM center (Safe Area respected)
/// - Content: ICON ONLY (No labels)
/// - Style: Minimalist glass pill
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemTapped,
    this.visibleIndices,
  });

  /// List of navigation items
  final List<NavBarItem> items;

  /// Currently selected index
  final int currentIndex;

  /// Callback when an item is tapped
  final ValueChanged<int> onItemTapped;

  /// Optional list of visible indices (for role-based visibility)
  /// If null, all items are visible
  final List<int>? visibleIndices;

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final visibleItems = _getVisibleItems();

    return RepaintBoundary(
      child: SafeArea(
        top: isWeb,
        bottom: !isWeb,
        child: isWeb
            ? _buildWebNavBar(visibleItems)
            : _buildMobileNavBar(visibleItems),
      ),
    );
  }

  Widget _buildWebNavBar(List<NavBarItem> visibleItems) {
    // Match QuickNavBar styling but with burgundy color palette
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.95), // Match mobile background
        borderRadius: BorderRadius.circular(16), // Match mobile border radius
        border: Border.all(
          color: Colors.white.withOpacity(0.1), // Match mobile border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
          // Add burgundy glow instead of purple
          BoxShadow(
            color: AuthColors.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _NavBarContent(
        items: visibleItems,
        originalItems: items,
        currentIndex: currentIndex,
        onItemTapped: onItemTapped,
        isWeb: true,
      ),
    );
  }

  Widget _buildMobileNavBar(List<NavBarItem> visibleItems) {
    // Match exact QuickNavBar styling
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.95), // AppColors.cardBackground
        borderRadius: BorderRadius.circular(16), // AppSpacing.cardRadius
        border: Border.all(
          color: Colors.white.withOpacity(0.1), // AppColors.borderDefault
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _NavBarContent(
        items: visibleItems,
        originalItems: items,
        currentIndex: currentIndex,
        onItemTapped: onItemTapped,
        isWeb: false,
      ),
    );
  }

  List<NavBarItem> _getVisibleItems() {
    if (visibleIndices == null) {
      return items;
    }
    return visibleIndices!
        .where((index) => index >= 0 && index < items.length)
        .map((index) => items[index])
        .toList();
  }
}

/// Navigation bar content
class _NavBarContent extends StatefulWidget {
  const _NavBarContent({
    required this.items,
    required this.originalItems,
    required this.currentIndex,
    required this.onItemTapped,
    required this.isWeb,
  });

  final List<NavBarItem> items; // Filtered visible items
  final List<NavBarItem> originalItems; // All items for index mapping
  final int currentIndex;
  final ValueChanged<int> onItemTapped;
  final bool isWeb;

  @override
  State<_NavBarContent> createState() => _NavBarContentState();
}

class _NavBarContentState extends State<_NavBarContent> {
  // Cache index mapping to avoid O(n) lookups on every build
  late List<int> _indexMapping;

  @override
  void initState() {
    super.initState();
    _updateIndexMapping();
  }

  @override
  void didUpdateWidget(_NavBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild cache if items changed
    if (oldWidget.items != widget.items || oldWidget.originalItems != widget.originalItems) {
      _updateIndexMapping();
    }
  }

  void _updateIndexMapping() {
    _indexMapping = widget.items.map((visibleItem) {
      return widget.originalItems.indexOf(visibleItem);
    }).toList();
  }

  int _getOriginalIndex(int visibleIndex) {
    // Use cached mapping for O(1) lookup
    if (visibleIndex >= 0 && visibleIndex < _indexMapping.length) {
      return _indexMapping[visibleIndex];
    }
    // Fallback to original O(n) lookup if cache is invalid
    final visibleItem = widget.items[visibleIndex];
    return widget.originalItems.indexOf(visibleItem);
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.items.length;
    if (itemCount == 0) return const SizedBox.shrink();

    // Navigation items - each item has its own background when selected
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(itemCount, (index) {
        final originalIndex = _getOriginalIndex(index);
        final isSelected = originalIndex == widget.currentIndex;
        final item = widget.items[index];

        return Expanded(
          child: RepaintBoundary(
            child: _NavBarItem(
              item: item,
              isSelected: isSelected,
              isWeb: widget.isWeb,
              onTap: () {
                // Haptic feedback on Android
                if (!widget.isWeb) {
                  HapticFeedback.selectionClick();
                }
                widget.onItemTapped(originalIndex);
              },
            ),
          ),
        );
      }),
    );
  }
}


/// Individual navigation bar item
class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.isWeb,
    required this.onTap,
  });

  final NavBarItem item;
  final bool isSelected;
  final bool isWeb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isWeb) {
      // Web: Use stateful widget with QuickNavBar-style animations
      return _WebNavItem(
        item: item,
        isSelected: isSelected,
        onTap: onTap,
      );
    } else {
      // Mobile: Use the stateful widget that matches QuickNavBar
      return _MobileNavItem(
        item: item,
        isSelected: isSelected,
        onTap: onTap,
      );
    }
  }
}

/// Web navigation item with icon + label - matches QuickNavBar animations
class _WebNavItem extends StatefulWidget {
  const _WebNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_WebNavItem> createState() => _WebNavItemState();
}

class _WebNavItemState extends State<_WebNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _iconColorAnimation;
  late Animation<Color?> _textColorAnimation;

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

    _iconColorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.7), // Light color to match dark nav bar background
      end: Colors.white, // White when active
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _textColorAnimation = ColorTween(
      begin: Colors.white.withOpacity(0.7), // Light color to match dark nav bar background
      end: Colors.white, // White when active
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_WebNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
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
            width: double.infinity, // Fill available width
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AuthColors.primary // Full burgundy background
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12), // Match mobile
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max, // Fill container width
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: widget.item.heroTag ?? 'nav_${widget.item.icon.codePoint}',
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Icon(
                      widget.item.icon,
                      size: 20,
                      color: _iconColorAnimation.value,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _textColorAnimation.value,
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.2,
                    fontFamily: 'SF Pro Display',
                  ),
                  child: Text(widget.item.label),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Mobile navigation item (icon only) - matches QuickNavBar styling
class _MobileNavItem extends StatefulWidget {
  const _MobileNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_MobileNavItem> createState() => _MobileNavItemState();
}

class _MobileNavItemState extends State<_MobileNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
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

    _colorAnimation = ColorTween(
      begin: AuthColors.textSub, // Inactive color
      end: Colors.white, // White when active
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_MobileNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
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
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AuthColors.primary // Full burgundy background
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12), // AppSpacing.radiusMD
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: widget.item.heroTag ?? 'nav_${widget.item.icon.codePoint}',
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Icon(
                      widget.item.icon,
                      color: _colorAnimation.value,
                      size: 24, // AppSpacing.iconLG
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
