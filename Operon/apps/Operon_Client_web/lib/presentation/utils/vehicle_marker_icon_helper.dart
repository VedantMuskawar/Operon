import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VehicleMarkerIconHelper {
  VehicleMarkerIconHelper._();

  /// Creates a simple rounded-corner marker badge with [vehicleNumber] text inside.
  ///
  /// Uses a darker grey theme when [isOffline] is true.
  static Future<BitmapDescriptor> buildVehicleNumberBadge({
    required String vehicleNumber,
    required bool isOffline,
    double devicePixelRatio = 3.0,
  }) async {
    final cleaned = vehicleNumber.trim();
    final label = cleaned.isEmpty ? '—' : cleaned;

    // Adaptive font sizing for longer vehicle numbers.
    var fontSize = 18.0;
    TextPainter painterFor(double size) {
      final p = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      )..layout(maxWidth: 220);
      return p;
    }

    var tp = painterFor(fontSize);
    while (tp.width > 180 && fontSize > 12) {
      fontSize -= 1;
      tp = painterFor(fontSize);
    }

    const paddingX = 14.0;
    const paddingY = 10.0;
    const minW = 76.0;
    const minH = 42.0;

    final w = math.max(minW, tp.width + paddingX * 2);
    final h = math.max(minH, tp.height + paddingY * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw at logical pixels but render at higher pixel ratio for sharpness.
    canvas.scale(devicePixelRatio);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final shadowPath = Path()..addRRect(rrect);
    canvas.drawShadow(
      shadowPath,
      Colors.black.withValues(alpha: 0.45),
      6,
      false,
    );

    final bgColors = isOffline
        ? const [Color(0xFF3A3A3A), Color(0xFF1F1F1F)]
        : const [Color(0xFF6F4BFF), Color(0xFF5A3FE0)];

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(w, h),
        bgColors,
      );
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: isOffline ? 0.18 : 0.25);
    canvas.drawRRect(rrect, borderPaint);

    // Center the text.
    final textOffset = Offset(
      (w - tp.width) / 2,
      (h - tp.height) / 2,
    );
    tp.paint(canvas, textOffset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (w * devicePixelRatio).round(),
      (h * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }
}

