import 'package:flutter/material.dart';

/// A custom painter that draws a uniform grid of dots
class _DotGridPainter extends CustomPainter {
  final double spacing;
  final double dotRadius;
  final Color dotColor;

  _DotGridPainter({
    required this.spacing,
    required this.dotRadius,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Calculate the number of dots needed to cover the entire area
    final horizontalDots = (size.width / spacing).ceil() + 1;
    final verticalDots = (size.height / spacing).ceil() + 1;

    // Draw dots in a grid pattern
    for (int i = 0; i < horizontalDots; i++) {
      for (int j = 0; j < verticalDots; j++) {
        final x = i * spacing;
        final y = j * spacing;

        // Only draw if within bounds
        if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
          canvas.drawCircle(Offset(x, y), dotRadius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotColor != dotColor;
  }
}

/// A background widget that displays a uniform grid of dots with fading edges
/// 
/// The dots are arranged in a grid pattern with configurable spacing and fade
/// out towards the edges using a radial gradient mask.
class DotGridPattern extends StatelessWidget {
  /// Spacing between dots in pixels (default: 20px)
  final double spacing;

  /// Radius of each dot in pixels (default: 1px)
  final double dotRadius;

  /// Color of the dots (default: white with 5% opacity)
  final Color dotColor;

  /// Whether to apply radial gradient fade at edges (default: true)
  final bool fadeEdges;

  const DotGridPattern({
    Key? key,
    this.spacing = 20.0,
    this.dotRadius = 1.0,
    this.dotColor = const Color.fromRGBO(255, 255, 255, 0.05),
    this.fadeEdges = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final painter = _DotGridPainter(
          spacing: spacing,
          dotRadius: dotRadius,
          dotColor: dotColor,
        );

        Widget gridWidget = SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: painter,
            size: size,
          ),
        );

        // Apply radial gradient mask for fading edges
        if (fadeEdges) {
          gridWidget = ShaderMask(
            shaderCallback: (Rect bounds) {
              return RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.white, // Fully visible in center
                  Colors.white, // Stay visible for most of the area
                  Colors.white.withOpacity(0.5), // Start fading
                  Colors.transparent, // Completely transparent at edges
                ],
                stops: const [0.0, 0.6, 0.85, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: gridWidget,
          );
        }

        return gridWidget;
      },
    );
  }
}
