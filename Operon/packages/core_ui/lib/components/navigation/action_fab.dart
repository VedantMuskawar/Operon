import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/auth_colors.dart';

/// Action item configuration for ActionFab
class ActionItem {
  const ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A creative floating action button menu with staggered spring animations
/// 
/// **Features:**
/// - Main button rotates 45° to 'X' when expanded
/// - Action buttons pop out with bouncy spring effect in vertical stack
/// - Dynamic action list support with smooth transitions
/// - Glassmorphic action buttons with labels
/// - Optimized backdrop blur that doesn't redraw the whole screen
class ActionFab extends StatefulWidget {
  const ActionFab({
    super.key,
    required this.actions,
    this.right,
    this.bottom,
    this.onStateChanged,
  });

  /// List of action items
  final List<ActionItem> actions;

  /// Right position offset (defaults to platform-specific)
  final double? right;

  /// Bottom position offset (defaults to platform-specific)
  final double? bottom;

  /// Callback when menu state changes (expanded/collapsed)
  final ValueChanged<bool>? onStateChanged;

  /// Standard FAB position - right edge with safe padding
  static const double standardRightWeb = 40.0;
  static const double standardRightMobile = 24.0;

  /// Standard FAB position - above nav bar with safe padding
  static double standardBottomWeb(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;
    return 120.0 + bottomPadding;
  }

  static double standardBottomMobile(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;
    // Nav bar height (~80px) + safe area bottom + spacing (16px)
    return 80.0 + bottomPadding + 16.0;
  }

  @override
  State<ActionFab> createState() => _ActionFabState();
}

class _ActionFabState extends State<ActionFab>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _mainController;
  late AnimationController _backdropController;
  List<AnimationController> _actionControllers = [];
  late List<Animation<double>> _actionScaleAnimations;
  late List<Animation<Offset>> _actionOffsetAnimations;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _backdropOpacity;


  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Main button controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Backdrop controller (separate for optimization)
    _backdropController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Rotation animation (0° to 45°)
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Scale animation for main button press effect
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Backdrop opacity
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backdropController,
        curve: Curves.easeOut,
      ),
    );

    // Initialize action controllers
    _setupActionAnimations();
  }

  void _setupActionAnimations() {
    // Dispose old controllers
    for (final controller in _actionControllers) {
      controller.dispose();
    }

    // Create new controllers for each action
    _actionControllers = List.generate(
      widget.actions.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      ),
    );

    // Create staggered spring animations
    _actionScaleAnimations = _actionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final reversedIndex = widget.actions.length - 1 - index;
      final delay = (reversedIndex * 0.1).clamp(0.0, 0.4);

      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: entry.value,
          curve: Interval(
            delay,
            delay + 0.6,
            curve: Curves.elasticOut, // Bouncy spring effect
          ),
        ),
      );
    }).toList();

    // Create offset animations (vertical stack)
    _actionOffsetAnimations = _actionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final reversedIndex = widget.actions.length - 1 - index;
      final delay = (reversedIndex * 0.1).clamp(0.0, 0.4);

      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: entry.value,
          curve: Interval(
            delay,
            delay + 0.6,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(ActionFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle dynamic action list changes
    if (widget.actions.length != oldWidget.actions.length ||
        !_listsEqual(widget.actions, oldWidget.actions)) {
      if (_isExpanded) {
        // Animate out old actions
        _animateOutActions(() {
          setState(() {
            _setupActionAnimations();
            if (_isExpanded) {
              _animateInActions();
            }
          });
        });
      } else {
        setState(() {
          _setupActionAnimations();
        });
      }
    }
  }

  bool _listsEqual(List<ActionItem> a, List<ActionItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].icon != b[i].icon || a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }

  void _animateOutActions(VoidCallback onComplete) {
    final futures = _actionControllers.map((controller) {
      return controller.reverse();
    }).toList();
    
    Future.wait(futures).then((_) => onComplete());
  }

  void _animateInActions() {
    for (final controller in _actionControllers) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _backdropController.dispose();
    for (final controller in _actionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleMenu() {
    if (!mounted) return;
    
    setState(() {
      _isExpanded = !_isExpanded;
      
      if (_isExpanded) {
        // Haptic feedback on mobile
        if (!kIsWeb) {
          HapticFeedback.mediumImpact();
        }
        _mainController.forward();
        _backdropController.forward();
        _animateInActions();
      } else {
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
        _mainController.reverse();
        _backdropController.reverse();
        for (final controller in _actionControllers) {
          controller.reverse();
        }
      }
      
      widget.onStateChanged?.call(_isExpanded);
    });
  }

  void _handleActionTap(ActionItem action) {
    // Close menu immediately
    if (_isExpanded) {
      _toggleMenu();
    }
    // Execute action after a brief delay to allow menu to close
    Future.delayed(const Duration(milliseconds: 150), () {
      action.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final rightPosition = widget.right ??
        (isWeb ? ActionFab.standardRightWeb : ActionFab.standardRightMobile);
    final bottomPosition = widget.bottom ??
        (isWeb
            ? ActionFab.standardBottomWeb(context)
            : ActionFab.standardBottomMobile(context));

    return RepaintBoundary(
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Optimized backdrop - only repaints when opacity changes
            if (_isExpanded)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleMenu,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _backdropOpacity,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _backdropOpacity.value,
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Action buttons - vertical stack with spring animation
            ...widget.actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              final reversedIndex = widget.actions.length - 1 - index;
              final offset = (reversedIndex + 1) * 72.0; // 56px button + 16px spacing

              return Positioned(
                right: rightPosition,
                bottom: bottomPosition + offset,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _actionScaleAnimations[index],
                    _actionOffsetAnimations[index],
                  ]),
                  builder: (context, child) {
                    final scale = _actionScaleAnimations[index].value;
                    final offsetValue = _actionOffsetAnimations[index].value;
                    final opacity = scale.clamp(0.0, 1.0);

                    return IgnorePointer(
                      ignoring: !_isExpanded || opacity == 0.0,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, offsetValue.dy * 80),
                          child: Transform.scale(
                            scale: scale,
                            child: _GlassActionButton(
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
              right: rightPosition,
              bottom: bottomPosition,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleMenu,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _rotationAnimation,
                      _scaleAnimation,
                    ]),
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
                                        AuthColors.primaryVariant,
                                        AuthColors.primary,
                                      ]
                                    : [
                                        AuthColors.primary,
                                        AuthColors.primaryVariant,
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AuthColors.primaryWithOpacity(
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
      ),
    );
  }
}

/// Glassmorphic action button with label
class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AuthColors.primary,
                  AuthColors.primaryVariant,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.primaryWithOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AuthColors.textMain,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: kIsWeb
              ? container // On web, skip BackdropFilter for better performance
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: container,
                ),
        ),
      ),
    );
  }
}
