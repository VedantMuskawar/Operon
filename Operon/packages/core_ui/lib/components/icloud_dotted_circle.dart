import 'dart:math' as math;
import 'package:flutter/material.dart';

class ICloudDottedCircle extends StatefulWidget {
  const ICloudDottedCircle({
    super.key,
    required this.size,
    this.centerWidget,
  });

  final double size;
  final Widget? centerWidget;

  @override
  State<ICloudDottedCircle> createState() => _ICloudDottedCircleState();
}

class _ICloudDottedCircleState extends State<ICloudDottedCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _shimmerAnimation;
  
  // Pre-generate random offsets for each dot to create organic shimmer
  late List<double> _dotShimmerOffsets;

  @override
  void initState() {
    super.initState();
    
    // Generate random shimmer offsets for organic animation
    final random = math.Random();
    _dotShimmerOffsets = List.generate(500, (index) => random.nextDouble() * 2 * math.pi);
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 45), // Slow rotation (45 seconds per rotation)
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
    
    _shimmerAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DottedCirclePainter(
                  size: widget.size,
                  rotationValue: _rotationAnimation.value,
                  shimmerValue: _shimmerAnimation.value,
                  shimmerOffsets: _dotShimmerOffsets,
                ),
              );
            },
          ),
          if (widget.centerWidget != null) widget.centerWidget!,
        ],
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  _DottedCirclePainter({
    required this.size,
    required this.rotationValue,
    required this.shimmerValue,
    required this.shimmerOffsets,
  });

  final double size;
  final double rotationValue;
  final double shimmerValue;
  final List<double> shimmerOffsets;

  // iCloud privacy icon color palette
  static const List<Color> _colors = [
    Color(0xFFFF3B30), // Red
    Color(0xFFAF52DE), // Purple
    Color(0xFF5856D6), // Indigo
    Color(0xFF007AFF), // Blue
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final centerHoleRadius = maxRadius * 0.3; // 30% of total width for center hole
    
    // Define 10 concentric rings with varying properties
    // [radiusRatio, dotCount, baseDotSizeRatio, blurRadius]
    final rings = [
      [0.35, 12, 0.008, 2.0],   // Ring 1 (just outside center hole)
      [0.42, 16, 0.009, 2.5],   // Ring 2
      [0.50, 20, 0.010, 3.0],   // Ring 3
      [0.58, 24, 0.011, 3.5],   // Ring 4
      [0.65, 28, 0.012, 4.0],   // Ring 5
      [0.72, 32, 0.013, 4.5],   // Ring 6
      [0.78, 36, 0.014, 5.0],   // Ring 7
      [0.84, 40, 0.015, 5.5],   // Ring 8
      [0.89, 44, 0.016, 6.0],   // Ring 9
      [0.94, 48, 0.017, 6.5],   // Ring 10 (outermost - largest)
    ];

    int dotIndex = 0;
    
    for (final ringData in rings) {
      final radiusRatio = ringData[0] as double;
      final dotCount = ringData[1] as int;
      final baseDotSizeRatio = ringData[2] as double;
      final blurRadius = ringData[3] as double;
      
      final radius = maxRadius * radiusRatio;
      final baseDotSize = size.width * baseDotSizeRatio;
      
      // Draw dots in this ring
      for (int i = 0; i < dotCount; i++) {
        // Base angle with rotation
        final baseAngle = (i * 2 * math.pi) / dotCount + rotationValue;
        
        // Add organic shimmer offset
        final shimmerOffset = shimmerOffsets[dotIndex % shimmerOffsets.length];
        final shimmerPhase = (shimmerValue + shimmerOffset) % (2 * math.pi);
        final shimmerAmount = math.sin(shimmerPhase) * 0.03; // Small random offset
        final angle = baseAngle + shimmerAmount;
        
        // Calculate position
        final x = center.dx + radius * math.cos(angle);
        final y = center.dy + radius * math.sin(angle);
        
        // Calculate distance from center for color gradient
        final distanceFromCenter = math.sqrt(
          math.pow(x - center.dx, 2) + math.pow(y - center.dy, 2)
        );
        final normalizedDistance = (distanceFromCenter - centerHoleRadius) / (maxRadius - centerHoleRadius);
        
        // Calculate angle for color gradient (atan2 gives angle from center)
        final angleFromCenter = math.atan2(y - center.dy, x - center.dx);
        final normalizedAngle = (angleFromCenter + math.pi) / (2 * math.pi); // Normalize to 0-1
        
        // Interpolate colors based on angle and distance
        final colorT = (normalizedAngle + normalizedDistance * 0.3) % 1.0;
        final colorIndex = (colorT * (_colors.length - 1)).floor();
        final nextColorIndex = (colorIndex + 1) % _colors.length;
        final colorLerp = (colorT * (_colors.length - 1)) % 1.0;
        
        final baseColor = Color.lerp(_colors[colorIndex], _colors[nextColorIndex], colorLerp)!;
        
        // Add shimmer opacity variation
        final shimmerOpacity = 0.7 + (math.sin(shimmerPhase) * 0.3);
        final dotColor = baseColor.withOpacity(shimmerOpacity.clamp(0.4, 1.0));
        
        // Size variation with shimmer
        final sizeVariation = 1.0 + (math.sin(shimmerPhase * 0.5) * 0.15);
        final dotSize = baseDotSize * sizeVariation;
        
        // Create paint with soft glow using MaskFilter
        final paint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
        
        // Draw the glowing dot
        canvas.drawCircle(
          Offset(x, y),
          dotSize / 2,
          paint,
        );
        
        dotIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.rotationValue != rotationValue ||
           oldDelegate.shimmerValue != shimmerValue ||
           oldDelegate.size != size;
  }
}
