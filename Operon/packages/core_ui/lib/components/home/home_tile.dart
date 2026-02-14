import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/auth_colors.dart';

/// High-performance, unified home tile component for Android and Web
/// 
/// Features:
/// - CustomPainter for optimized background rendering
/// - RepaintBoundary to prevent unnecessary redraws
/// - Burgundy (#5D1C19) interaction states
/// - Compact (Android) and Large (Web) modes
class HomeTile extends StatefulWidget {
  const HomeTile({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    this.badgeCount = 0,
    this.subtitle,
    required this.onTap,
    this.isCompact = true,
    this.showIcon = true,
    this.titleFontSize,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final int badgeCount;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isCompact;
  final bool showIcon;
  final double? titleFontSize;

  @override
  State<HomeTile> createState() => _HomeTileState();
}

class _HomeTileState extends State<HomeTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  static const Color _background = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.isCompact ? 0.95 : 1.05,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.isCompact ? Curves.easeInOut : Curves.easeOut,
      ),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = true);
    if (widget.isCompact) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleHoverEnter() {
    if (!mounted || widget.isCompact) return;
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _handleHoverExit() {
    if (!mounted || widget.isCompact) return;
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) => _handleHoverExit(),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  constraints: widget.isCompact
                      ? const BoxConstraints(
                          minHeight: 120,
                          minWidth: double.infinity,
                        )
                      : const BoxConstraints(
                          minWidth: 220,
                          maxWidth: 220,
                          minHeight: 160,
                          maxHeight: 160,
                        ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.isCompact ? 16 : 20,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _HomeTilePainter(
                      isActive: _isHovered || _isPressed,
                      glowProgress: _glowAnimation.value,
                      accentColor: widget.accentColor,
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: _buildContent(), // Extract child to prevent rebuilds
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.all(widget.isCompact ? 20 : 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            _buildIconSection(),
            SizedBox(height: widget.isCompact ? 12 : 16),
          ],
          _buildTextSection(),
        ],
      ),
    );
  }

  Widget _buildIconSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.isCompact ? 40 : 48,
          height: widget.isCompact ? 40 : 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentColor.withOpacity(0.15),
                widget.accentColor.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            size: widget.isCompact ? 20 : 24,
            color: widget.accentColor,
          ),
        ),
        if (widget.badgeCount > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AuthColors.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _background,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextSection() {
    final subtitle = widget.subtitle;
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.titleFontSize ?? (widget.isCompact ? 16 : 18),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: widget.isCompact ? 12 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for optimized tile background rendering
/// Uses a single paint operation instead of multiple Container layers
class _HomeTilePainter extends CustomPainter {
  _HomeTilePainter({
    required this.isActive,
    required this.glowProgress,
    required this.accentColor,
  });

  final bool isActive;
  final double glowProgress;
  final Color accentColor;

  static const Color _background = Color(0xFF1A1A1A);
  static const Color _borderDefault = Color(0x1AFFFFFF); // white10
  static const Color _brandColor = Color(0xFF5D1C19);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = BorderRadius.circular(20).resolve(TextDirection.ltr);

    // Draw background
    final backgroundPaint = Paint()
      ..color = _background
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius.topLeft),
      backgroundPaint,
    );

    // Draw center accent glow (always visible in steady state, using accent color)
    final centerGlowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0, // Covers the tile area
        colors: [
          accentColor.withOpacity(0.08), // Center glow - reduced intensity
          accentColor.withOpacity(0.04), // Mid glow - reduced intensity
          accentColor.withOpacity(0.0), // Fades to transparent at edges
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius.topLeft),
      centerGlowPaint,
    );

    // Draw enhanced center glow effect when active (intensifies the accent glow)
    if (isActive && glowProgress > 0) {
      final activeGlowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2, // Extends beyond tile bounds for glow effect
          colors: [
            accentColor.withOpacity(0.2 * glowProgress), // Reduced intensity
            accentColor.withOpacity(0.1 * glowProgress), // Reduced intensity
            accentColor.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius.topLeft),
        activeGlowPaint,
      );
    }

    // Draw border
    final borderColor = isActive
        ? Color.lerp(_borderDefault, _brandColor, glowProgress)!
        : _borderDefault;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = isActive ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius.topLeft),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_HomeTilePainter oldDelegate) {
    return oldDelegate.isActive != isActive ||
        oldDelegate.glowProgress != glowProgress ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Skeleton loader for home tiles
/// Matches the structure and size of HomeTile for seamless loading states
class HomeTileSkeleton extends StatelessWidget {
  const HomeTileSkeleton({
    super.key,
    this.isCompact = true,
  });

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: isCompact
          ? const BoxConstraints(
              minHeight: 120,
              minWidth: double.infinity,
            )
          : const BoxConstraints(
              minWidth: 220,
              maxWidth: 220,
              minHeight: 160,
              maxHeight: 160,
            ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(
          color: const Color(0x1AFFFFFF), // white10
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 20 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon skeleton
            Container(
              width: isCompact ? 40 : 48,
              height: isCompact ? 40 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
                color: AuthColors.textMainWithOpacity(0.1),
              ),
            ),
            SizedBox(height: isCompact ? 12 : 16),
            // Text skeleton
            Container(
              width: isCompact ? 80 : 100,
              height: isCompact ? 14 : 16,
              decoration: BoxDecoration(
                color: AuthColors.textMainWithOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
