import 'package:flutter/material.dart';

class OrdersMapView extends StatelessWidget {
  const OrdersMapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orders Map',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1F33), Color(0xFF13131F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final dots = [
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.65, size.height * 0.2),
      Offset(size.width * 0.45, size.height * 0.75),
    ];
    for (final dot in dots) {
      canvas.drawCircle(
        dot,
        5,
        Paint()
          ..color = const Color(0xFF6F4BFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

