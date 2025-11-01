import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashboardTile extends StatefulWidget {
  final String emoji;
  final String title;
  final VoidCallback? onTap;
  final bool isEnabled;
  final String? tooltip;

  const DashboardTile({
    super.key,
    required this.emoji,
    required this.title,
    this.onTap,
    this.isEnabled = true,
    this.tooltip,
  });

  @override
  State<DashboardTile> createState() => _DashboardTileState();
}

class _DashboardTileState extends State<DashboardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // PaveBoard exact duration
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // PaveBoard exact scale: scale(1.02)
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Cubic(0.4, 0, 0.2, 1), // PaveBoard exact curve
    ));

    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Cubic(0.4, 0, 0.2, 1),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.isEnabled && widget.onTap != null,
      label: widget.tooltip ?? widget.title,
      child: Tooltip(
        message: widget.tooltip ?? widget.title,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                elevation: _elevationAnimation.value,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isEnabled ? _handleTap : null,
                  onTapDown: widget.isEnabled ? _handleTapDown : null,
                  onTapUp: widget.isEnabled ? _handleTapUp : null,
                  onTapCancel: widget.isEnabled ? _handleTapCancel : null,
                  onHover: (isHovering) {
                    if (isHovering) {
                      _handleHoverEnter();
                    } else {
                      _handleHoverExit();
                    }
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 128, // h-32 (128px) like PaveBoard
                      minWidth: 112,
                      maxHeight: 128, // h-32 (128px) like PaveBoard
                    ),
                    padding: const EdgeInsets.all(16), // p-4 (16px) - PaveBoard mobile sizing
                    decoration: BoxDecoration(
                      color: widget.isEnabled 
                          ? AppTheme.surfaceColor
                          : AppTheme.surfaceColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: widget.isEnabled 
                            ? AppTheme.borderColor
                            : AppTheme.borderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Emoji/Icon with drop shadow like PaveBoard - tile-icon text-4xl mb-6 filter drop-shadow-lg
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                          child: Center(
                            child: Text(
                              widget.emoji,
                              style: const TextStyle(
                                fontSize: 36, // text-4xl
                                height: 1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), // mb-4 (16px)
                        // Title - PaveBoard exact: text-sm font-bold text-gray-100 leading-tight tracking-wide
                        Flexible(
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFF3F4F6), // text-gray-100
                              fontWeight: FontWeight.bold,
                              fontSize: 14, // text-sm
                              height: 1.25, // leading-tight
                              letterSpacing: 0.025, // tracking-wide
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
  }

  void _handleHoverEnter() {
    if (widget.isEnabled) {
      _animationController.forward();
    }
  }

  void _handleHoverExit() {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }
}

