import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerUtils {
  MapMarkerUtils._();

  static final BitmapDescriptor fallbackDepotMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

  static final Map<String, BitmapDescriptor> _depotMarkerCache = {};

  static Future<BitmapDescriptor> depotMarkerForLabel(String? rawLabel) async {
    final label = (rawLabel ?? 'Depot').trim();
    if (_depotMarkerCache.containsKey(label)) {
      return _depotMarkerCache[label]!;
    }

    const double width = 160;
    const double bodyHeight = 80;
    const double pointerHeight = 28;
    const double height = bodyHeight + pointerHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, bodyHeight),
      const Radius.circular(28),
    );

    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(0, bodyHeight),
      const [
        Color(0xFF2563EB),
        Color(0xFF4F46E5),
      ],
    );
    final bodyPaint = Paint()..shader = gradient;
    canvas.drawRRect(bodyRect, bodyPaint);

    final pointerPath = Path()
      ..moveTo(width / 2 - 16, bodyHeight)
      ..lineTo(width / 2, height)
      ..lineTo(width / 2 + 16, bodyHeight)
      ..close();
    canvas.drawPath(pointerPath, bodyPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.2);
    canvas.drawRRect(bodyRect, borderPaint);
    canvas.drawPath(pointerPath, borderPaint);

    final displayLabel = label.isEmpty ? 'Depot' : label;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: width - 32);

    final textOffset = Offset(
      (width - textPainter.width) / 2,
      (bodyHeight - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    final image = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return fallbackDepotMarker;
    }

    final marker = BitmapDescriptor.fromBytes(
      byteData.buffer.asUint8List(),
    );
    _depotMarkerCache[label] = marker;
    return marker;
  }
}

