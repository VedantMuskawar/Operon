import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

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
                color: AuthColors.textMain,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
            gradient: const LinearGradient(
              colors: [AuthColors.surface, AuthColors.background],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
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
      ..color = AuthColors.textMainWithOpacity(0.13)
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
          ..color = AuthColors.legacyAccent
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

