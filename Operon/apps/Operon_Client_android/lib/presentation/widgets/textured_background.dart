import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

/// A widget that provides a textured background (grain or dotted pattern)
/// for the entire app
class TexturedBackground extends StatelessWidget {
  const TexturedBackground({
    super.key,
    required this.child,
    this.pattern = BackgroundPattern.grain,
    this.opacity = 0.03,
    this.debugMode = false,
  });

  final Widget child;
  final BackgroundPattern pattern;
  final double opacity;
  final bool debugMode;

  @override
  Widget build(BuildContext context) {
    // Debug logging
    if (kDebugMode) {
      debugPrint(
          '[TexturedBackground] Building with Pattern: $pattern, Opacity: $opacity');
    }

    return Container(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // TEST: Simple colored container to verify Stack is working
          // Make it very visible
          Container(
            color: kDebugMode && debugMode
                ? AuthColors.info
                    .withOpacity(0.5) // Blue tint to verify rendering
                : AuthColors.transparent,
          ),
          // Textured overlay - using LayoutBuilder to get actual size
          IgnorePointer(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 1000,
                    constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : 2000,
                  );
                  if (kDebugMode && debugMode) {
                    debugPrint(
                        '[TexturedBackground] LayoutBuilder constraints: ${constraints.maxWidth}x${constraints.maxHeight}');
                    debugPrint(
                        '[TexturedBackground] Using size: ${size.width}x${size.height}');
                  }
                  return SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CustomPaint(
                      painter: _TexturedPainter(
                        pattern: pattern,
                        opacity: opacity,
                        debugMode: debugMode,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Debug indicator (top-right corner)
          if (debugMode && kDebugMode)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.paddingSM),
                decoration: BoxDecoration(
                  color: AuthColors.error.withOpacity(0.9),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                  border: Border.all(color: AuthColors.textMain, width: 1),
                ),
                child: Text(
                  'BG: ${pattern.name}\nOpacity: ${opacity.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Content
          child,
        ],
      ),
    );
  }
}

enum BackgroundPattern {
  grain,
  dotted,
  diagonal,
}

class _TexturedPainter extends CustomPainter {
  _TexturedPainter({
    required this.pattern,
    required this.opacity,
    this.debugMode = false,
  });

  final BackgroundPattern pattern;
  final double opacity;
  final bool debugMode;

  @override
  void paint(Canvas canvas, Size size) {
    // Validate size first
    if (size.width <= 0 || size.height <= 0 || !size.isFinite) {
      if (kDebugMode && debugMode) {
        debugPrint(
            '[TexturedPainter] Invalid or infinite size: ${size.width}x${size.height}, skipping');
      }
      return;
    }

    // Use white with opacity for better visibility on black background
    // Increase opacity for better visibility
    final effectiveOpacity = opacity * 1.5; // Boost visibility
    final paint = Paint()
      ..color =
          AuthColors.textMain.withOpacity(effectiveOpacity.clamp(0.0, 1.0))
      ..strokeWidth = 0.5
      ..style = PaintingStyle.fill;

    // Debug: Log paint call
    if (kDebugMode && debugMode) {
      debugPrint(
          '[TexturedPainter] Painting ${pattern.name} pattern on ${size.width}x${size.height} canvas with opacity ${effectiveOpacity.toStringAsFixed(2)}');
    }

    // Test: Draw a border to verify painting works
    if (kDebugMode && debugMode) {
      final testPaint = Paint()
        ..color = AuthColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), testPaint);
    }

    switch (pattern) {
      case BackgroundPattern.grain:
        _paintGrain(canvas, size, paint);
        break;
      case BackgroundPattern.dotted:
        _paintDotted(canvas, size, paint);
        break;
      case BackgroundPattern.diagonal:
        _paintDiagonal(canvas, size, paint);
        break;
    }
  }

  void _paintGrain(Canvas canvas, Size size, Paint paint) {
    // Create a random grain pattern using noise
    // More visible grain texture
    final random = _SeededRandom(42);
    const density = 0.12; // Increased density for better visibility
    final totalPixels = (size.width * size.height * density / 100).round();

    if (kDebugMode && debugMode) {
      debugPrint('[TexturedPainter] Drawing $totalPixels grain dots');
    }

    for (int i = 0; i < totalPixels; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5; // Larger dots

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }

  void _paintDotted(Canvas canvas, Size size, Paint paint) {
    // Create a regular dotted pattern - more visible
    const spacing = 4.0; // Closer spacing
    const dotSize = 2.0; // Larger dots

    // Validate size
    if (size.width <= 0 || size.height <= 0) {
      if (kDebugMode && debugMode) {
        debugPrint(
            '[TexturedPainter] Invalid size: ${size.width}x${size.height}, skipping paint');
      }
      return;
    }

    int dotCount = 0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Offset every other row for a more natural look
        final offsetX = ((y / spacing).floor() % 2 == 0) ? x : x + spacing / 2;
        if (offsetX < size.width) {
          canvas.drawCircle(
            Offset(offsetX, y),
            dotSize,
            paint,
          );
          dotCount++;
        }
      }
    }

    if (kDebugMode && debugMode) {
      debugPrint(
          '[TexturedPainter] Drew $dotCount dotted pattern dots on ${size.width}x${size.height}');
    }
  }

  void _paintDiagonal(Canvas canvas, Size size, Paint paint) {
    // Create diagonal lines pattern
    const spacing = 8.0;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.3;

    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple seeded random number generator for consistent grain pattern
class _SeededRandom {
  _SeededRandom(this.seed);

  int seed;

  double nextDouble() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }
}
