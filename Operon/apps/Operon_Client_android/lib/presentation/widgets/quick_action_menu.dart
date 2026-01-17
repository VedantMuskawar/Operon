import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class QuickActionMenu extends StatefulWidget {
  const QuickActionMenu({
    super.key,
    required this.actions,
    this.right,
    this.bottom,
  });

  final List<QuickActionItem> actions;
  final double? right;
  final double? bottom;

  /// Standard FAB position - right edge with safe padding
  static const double standardRight = 24.0;
  
  /// Standard FAB position - above nav bar with safe padding
  static double standardBottom(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;
    // Nav bar height (~80px) + safe area bottom + spacing (16px)
    return 80.0 + bottomPadding + 16.0;
  }

  @override
  State<QuickActionMenu> createState() => _QuickActionMenuState();
}

class _QuickActionMenuState extends State<QuickActionMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late List<Animation<Offset>> _slideAnimations;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Scale animation for main button
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Rotation animation for main button
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Fade animation for backdrop
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Slide animations for each action button
    _slideAnimations = widget.actions.asMap().entries.map((entry) {
      final index = entry.key;
      final reversedIndex = widget.actions.length - 1 - index;
      final delay = (reversedIndex * 0.05).clamp(0.0, 0.3);
      
      return Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay,
            delay + 0.4,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (!mounted) return;
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleActionTap(QuickActionItem action) {
    // Close menu immediately
    if (_isExpanded) {
      _toggleMenu();
    }
    // Execute action after a brief delay to allow menu to close
    Future.delayed(const Duration(milliseconds: 100), () {
      action.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Backdrop - only visible when expanded
          if (_isExpanded)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleMenu,
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                      ),
                    );
                  },
                ),
              ),
            ),
        
        // Action buttons - slide up from bottom
        ...widget.actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          final reversedIndex = widget.actions.length - 1 - index;
          final offset = (reversedIndex + 1) * 72.0; // 56px button + 16px spacing

          return Positioned(
            right: widget.right ?? QuickActionMenu.standardRight,
            bottom: (widget.bottom ?? QuickActionMenu.standardBottom(context)) + offset,
            child: AnimatedBuilder(
              animation: _slideAnimations[index],
              builder: (context, child) {
                final slideValue = _slideAnimations[index].value;
                final opacity = slideValue.dy == 0 ? 1.0 : 0.0;
                
                return IgnorePointer(
                  ignoring: !_isExpanded || opacity == 0.0,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, slideValue.dy * 80),
                      child: Transform.scale(
                        scale: 1.0 - (slideValue.dy * 0.2),
                        child: _ActionButton(
                          icon: action.icon,
                          label: action.label,
                          onTap: () => _handleActionTap(action),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
        
        // Main FAB button - always visible
        Positioned(
          right: widget.right ?? QuickActionMenu.standardRight,
          bottom: widget.bottom ?? QuickActionMenu.standardBottom(context),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleMenu,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 2 * 3.14159,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isExpanded
                                ? [
                                    AuthColors.legacyAccent,
                                    AuthColors.legacyAccent.withOpacity(0.8),
                                  ]
                                : [
                                    AuthColors.legacyAccent,
                                    AuthColors.legacyAccent.withOpacity(0.9),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AuthColors.legacyAccent.withOpacity(
                                _isExpanded ? 0.5 : 0.4,
                              ),
                              blurRadius: _isExpanded ? 20 : 12,
                              offset: Offset(0, _isExpanded ? 8 : 4),
                              spreadRadius: _isExpanded ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isExpanded ? Icons.close : Icons.add,
                          color: AuthColors.textMain,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AuthColors.legacyAccent,
                      AuthColors.legacyAccent.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.legacyAccent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
