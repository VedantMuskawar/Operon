import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';

/// Base modal dialog component for detail views
/// Provides consistent styling, animations, and behavior
class DetailModalBase extends StatefulWidget {
  const DetailModalBase({
    super.key,
    required this.child,
    this.onClose,
    this.barrierDismissible = true,
  });

  final Widget child;
  final VoidCallback? onClose;
  final bool barrierDismissible;

  @override
  State<DetailModalBase> createState() => _DetailModalBaseState();
}

class _DetailModalBaseState extends State<DetailModalBase>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final modalWidth = isMobile ? screenWidth * 0.95 : 800.0;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Backdrop
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: widget.barrierDismissible ? _handleClose : null,
                        child: Container(
                          color: AuthColors.background.withOpacity(0.7),
                        ),
                      ),
                    ),
                    // Modal content
                    Center(
                      child: Container(
                        width: modalWidth,
                        constraints: const BoxConstraints(
                          maxWidth: 800,
                        ),
                        height: 900,
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 0,
                          vertical: isMobile ? 8 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: AuthColors.background,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AuthColors.background.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: -10,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: widget.child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper function to show a detail modal
Future<T?> showDetailModal<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    builder: (context) => DetailModalBase(
      onClose: () => Navigator.of(context).pop(),
      barrierDismissible: barrierDismissible,
      child: child,
    ),
  );
}

