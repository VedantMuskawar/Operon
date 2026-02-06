import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Movement state for vehicle markers (TIER 1: Visual Hierarchy).
enum MovementState {
  /// Online, speed > 5 km/h - Neon-green arrow with pulse
  moving,

  /// Online, speed ≤ 5 km/h, engine ON (or inferred) - Neon orange/yellow hexagon
  idling,

  /// Online, engine OFF - Solid blue rounded square
  stopped,

  /// Stale location (>10 min) - Ghost icon + optional Last Seen badge
  offline,
}

/// Vehicle type for marker icons (TIER 2).
enum VehicleType {
  truck,
  van,
  bike,
  unknown,
}

/// Legacy status enum - kept for backward compatibility during migration.
/// Prefer [MovementState] for new code.
enum VehicleStatus {
  active,
  offline,
  warning,
  available,
  idling,
  onTrip,
  alert,
}

/// Marker tier based on zoom level for Level of Detail (LOD) system.
enum MarkerTier {
  nano, // Zoom < 11: Simple colored dot
  standard, // Zoom 11-15: Shape + vehicle type icon
  detailed, // Zoom > 15: Shape + icon + vehicle ID + speed label
}

/// Utility for generating custom map markers.
class MarkerGenerator {
  MarkerGenerator._();

  /// Tier-based canvas sizes.
  static double _sizeForTier(MarkerTier tier) {
    switch (tier) {
      case MarkerTier.nano:
        return 24.0;
      case MarkerTier.standard:
        return 48.0;
      case MarkerTier.detailed:
        return 72.0;
    }
  }

  static IconData _iconForVehicleType(VehicleType type) {
    switch (type) {
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.van:
        return Icons.directions_car;
      case VehicleType.bike:
        return Icons.two_wheeler;
      case VehicleType.unknown:
        return Icons.directions_car;
    }
  }

  /// Create a marker based on movement state and vehicle type.
  ///
  /// [text] - Vehicle number or identifier
  /// [movementState] - Movement state (moving/idling/stopped/offline)
  /// [vehicleType] - Vehicle type for icon
  /// [tier] - Marker tier (nano/standard/detailed)
  /// [subtitle] - Optional subtitle (e.g. "5m ago" for offline)
  /// [speedLabel] - Speed string for Detailed tier when moving (e.g. "60 km/h")
  static Future<BitmapDescriptor> createMarker({
    required String text,
    required MovementState movementState,
    required MarkerTier tier,
    VehicleType vehicleType = VehicleType.van,
    double devicePixelRatio = 3.0,
    String? subtitle,
    String? speedLabel,
  }) async {
    final cacheKey =
        '$tier|${movementState.name}|${vehicleType.name}|$text|$subtitle|$speedLabel';
    final cached = _markerCache[cacheKey];
    if (cached != null) return cached;

    final descriptor = await _createMarkerInternal(
      text: text,
      movementState: movementState,
      vehicleType: vehicleType,
      tier: tier,
      devicePixelRatio: devicePixelRatio,
      subtitle: subtitle,
      speedLabel: speedLabel,
    );
    _markerCache[cacheKey] = descriptor;
    return descriptor;
  }

  /// Legacy API - maps [VehicleStatus] to [MovementState] and calls [createMarker].
  static Future<BitmapDescriptor> createMarkerLegacy({
    required String text,
    required VehicleStatus status,
    required MarkerTier tier,
    VehicleType vehicleType = VehicleType.van,
    double devicePixelRatio = 3.0,
    String? subtitle,
    String? speedLabel,
  }) async {
    final movementState = _statusToMovementState(status);
    return createMarker(
      text: text,
      movementState: movementState,
      vehicleType: vehicleType,
      tier: tier,
      devicePixelRatio: devicePixelRatio,
      subtitle: subtitle,
      speedLabel: speedLabel,
    );
  }

  static MovementState _statusToMovementState(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.offline:
        return MovementState.offline;
      case VehicleStatus.idling:
        return MovementState.idling;
      case VehicleStatus.available:
      case VehicleStatus.active:
      case VehicleStatus.onTrip:
        return MovementState.moving;
      case VehicleStatus.alert:
      case VehicleStatus.warning:
        return MovementState.idling; // Fallback
    }
  }

  static Future<BitmapDescriptor> _createMarkerInternal({
    required String text,
    required MovementState movementState,
    required VehicleType vehicleType,
    required MarkerTier tier,
    required double devicePixelRatio,
    String? subtitle,
    String? speedLabel,
  }) async {
    switch (movementState) {
      case MovementState.offline:
        return _createOfflineGhostMarker(
          text: text,
          vehicleType: vehicleType,
          tier: tier,
          devicePixelRatio: devicePixelRatio,
          subtitle: subtitle,
        );
      case MovementState.moving:
        return _createMovingMarker(
          text: text,
          vehicleType: vehicleType,
          tier: tier,
          devicePixelRatio: devicePixelRatio,
          speedLabel: speedLabel,
        );
      case MovementState.idling:
        return _createIdlingMarker(
          text: text,
          vehicleType: vehicleType,
          tier: tier,
          devicePixelRatio: devicePixelRatio,
        );
      case MovementState.stopped:
        return _createStoppedMarker(
          text: text,
          vehicleType: vehicleType,
          tier: tier,
          devicePixelRatio: devicePixelRatio,
        );
    }
  }

  /// Moving: Neon-green arrow with trailing pulse/glow; show direction.
  static Future<BitmapDescriptor> _createMovingMarker({
    required String text,
    required VehicleType vehicleType,
    required MarkerTier tier,
    required double devicePixelRatio,
    String? speedLabel,
  }) async {
    final size = _sizeForTier(tier);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);

    // Nano: just colored dot
    if (tier == MarkerTier.nano) {
      _drawNanoDot(canvas, center, LogisticsColors.neonGreen, size);
    } else {
      // Arrow geometry (pointing Up)
      final scale = size / 64.0;
      final path = Path()
        ..moveTo(center.dx, center.dy - 20 * scale)
        ..lineTo(center.dx + 14 * scale, center.dy + 16 * scale)
        ..lineTo(center.dx, center.dy + 8 * scale)
        ..lineTo(center.dx - 14 * scale, center.dy + 16 * scale)
        ..close();

      // Trailing pulse / glow
      final glowPaint = Paint()
        ..color = LogisticsColors.neonGreen.withOpacity(0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scale);
      canvas.drawPath(path, glowPaint);

      // Main arrow
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx, center.dy - 20 * scale),
          Offset(center.dx, center.dy + 16 * scale),
          [Colors.white, LogisticsColors.neonGreen],
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);

      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(path, borderPaint);

      // Standard/Detailed: add icon in center
      if (tier == MarkerTier.standard || tier == MarkerTier.detailed) {
        _paintVehicleIcon(
          canvas,
          Offset(center.dx, center.dy - 2 * scale),
          vehicleType,
          size * 0.35,
          Colors.white,
        );
      }

      // Detailed: vehicle ID + speed label below
      if (tier == MarkerTier.detailed) {
        var y = center.dy + 14 * scale;
        final idText = _extractLastFourDigits(text);
        _paintText(canvas, center.dx, y, idText, 10, Colors.white);
        if (speedLabel != null && speedLabel.isNotEmpty) {
          y += 12;
          _paintText(canvas, center.dx, y, speedLabel, 9, Colors.white70);
        }
      }
    }

    return _finishCanvas(recorder, size, size, devicePixelRatio);
  }

  /// Idling: Neon orange/yellow hexagon + pause symbol or vehicle ID.
  static Future<BitmapDescriptor> _createIdlingMarker({
    required String text,
    required VehicleType vehicleType,
    required MarkerTier tier,
    required double devicePixelRatio,
  }) async {
    final size = _sizeForTier(tier);
    const idlingColor = Color(0xFFFFB300); // Neon orange/yellow
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);

    if (tier == MarkerTier.nano) {
      _drawNanoDot(canvas, center, idlingColor, size);
    } else {
      final hexPath = _createHexagonPath(center, size * 0.35);
      final paint = Paint()
        ..color = idlingColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(hexPath, paint);
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(hexPath, borderPaint);

      if (tier == MarkerTier.standard || tier == MarkerTier.detailed) {
        _paintVehicleIcon(
            canvas, center, vehicleType, size * 0.3, Colors.white);
      }

      if (tier == MarkerTier.detailed) {
        _paintText(
          canvas,
          center.dx,
          center.dy + size * 0.28,
          _extractLastFourDigits(text),
          10,
          Colors.white,
        );
      }
    }

    return _finishCanvas(recorder, size, size, devicePixelRatio);
  }

  /// Stopped: Solid blue rounded square.
  static Future<BitmapDescriptor> _createStoppedMarker({
    required String text,
    required VehicleType vehicleType,
    required MarkerTier tier,
    required double devicePixelRatio,
  }) async {
    final size = _sizeForTier(tier);
    const stoppedColor = Color(0xFF2980B9); // Solid blue
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);

    if (tier == MarkerTier.nano) {
      _drawNanoDot(canvas, center, stoppedColor, size);
    } else {
      final half = size * 0.35;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: half * 2,
          height: half * 2,
        ),
        const Radius.circular(6),
      );
      final paint = Paint()
        ..color = stoppedColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rect, borderPaint);

      if (tier == MarkerTier.standard || tier == MarkerTier.detailed) {
        _paintVehicleIcon(
            canvas, center, vehicleType, size * 0.28, Colors.white);
      }

      if (tier == MarkerTier.detailed) {
        _paintText(
          canvas,
          center.dx,
          center.dy + size * 0.28,
          _extractLastFourDigits(text),
          10,
          Colors.white,
        );
      }
    }

    return _finishCanvas(recorder, size, size, devicePixelRatio);
  }

  /// Offline: Ghost version of vehicle icon + optional Last Seen badge (Detailed tier only).
  static Future<BitmapDescriptor> _createOfflineGhostMarker({
    required String text,
    required VehicleType vehicleType,
    required MarkerTier tier,
    required double devicePixelRatio,
    String? subtitle,
  }) async {
    final size = _sizeForTier(tier);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);
    const ghostColor = Color(0xFF546E7A); // vehicleOfflineSlate
    final ghostFill = ghostColor.withOpacity(0.5);
    final ghostIcon = Colors.white.withOpacity(0.6);

    if (tier == MarkerTier.nano) {
      _drawNanoDot(canvas, center, ghostFill, size);
    } else {
      // Rounded square as ghost shape
      final half = size * 0.32;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: half * 2,
          height: half * 2,
        ),
        const Radius.circular(6),
      );
      final paint = Paint()
        ..color = ghostFill
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(rect, borderPaint);

      _paintVehicleIcon(canvas, center, vehicleType, size * 0.26, ghostIcon);

      if (tier == MarkerTier.detailed &&
          subtitle != null &&
          subtitle.isNotEmpty) {
        _paintText(
          canvas,
          center.dx,
          center.dy + size * 0.38,
          subtitle,
          9,
          const Color(0xFFAAAAAA),
        );
      }
    }

    return _finishCanvas(recorder, size, size, devicePixelRatio);
  }

  static void _drawNanoDot(
      Canvas canvas, Offset center, Color color, double size) {
    final r = size * 0.2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, paint);
  }

  static Path _createHexagonPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angleRad = (i * 60 - 90) * (math.pi / 180);
      final x = center.dx + radius * math.cos(angleRad);
      final y = center.dy + radius * math.sin(angleRad);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static void _paintVehicleIcon(
    Canvas canvas,
    Offset center,
    VehicleType vehicleType,
    double size,
    Color color,
  ) {
    final iconData = _iconForVehicleType(vehicleType);
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily ?? 'MaterialIcons',
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  static void _paintText(
    Canvas canvas,
    double centerX,
    double y,
    String text,
    double fontSize,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, y));
  }

  static String _extractLastFourDigits(String text) {
    if (text.length <= 4) return text;
    if (text.startsWith('VH-')) return text.substring(3);
    return text.substring(text.length - 4);
  }

  static Future<BitmapDescriptor> _finishCanvas(
    ui.PictureRecorder recorder,
    double width,
    double height,
    double devicePixelRatio,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * devicePixelRatio).round(),
      (height * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.bytes(bytes);
  }

  /// Clears the marker cache. Call when tier changes or to free memory.
  static void clearMarkerCache() {
    _markerCache.clear();
  }

  static final Map<String, BitmapDescriptor> _markerCache = {};

  // ============================================================================
  // Cluster icons
  // ============================================================================

  static final Map<String, BitmapDescriptor> _clusterIconCache = {};

  static Future<BitmapDescriptor> createClusterIcon(
    int count, {
    bool hasAlert = false,
  }) async {
    final cacheKey = '$count|$hasAlert';
    final cached = _clusterIconCache[cacheKey];
    if (cached != null) return cached;

    const size = 48.0;
    const devicePixelRatio = 3.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 4;

    // Status ring: red when cluster has alert vehicle
    final ringColor =
        hasAlert ? LogisticsColors.vehicleAlert : LogisticsColors.neonGreen;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ringColor.withOpacity(0.9);
    canvas.drawCircle(center, radius + 2, ringPaint);

    // Glassmorphism: semi-transparent fill + soft border
    final fillColor = LogisticsColors.neonGreen.withOpacity(0.85);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawCircle(center, radius - 1, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(center, radius - 1, borderPaint);

    // Count text
    final text = count > 99 ? '99+' : count.toString();
    final textColor = const Color(0xFF263238);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final descriptor =
        await _finishCanvas(recorder, size, size, devicePixelRatio);
    _clusterIconCache[cacheKey] = descriptor;
    return descriptor;
  }
}
