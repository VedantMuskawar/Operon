import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Status enum for vehicle markers.
enum VehicleStatus {
  active,
  offline,
  warning,
  available,   // Vehicle ready for assignment - Green (#2ECC71)
  onTrip,      // Vehicle currently on a trip - Blue (#2980B9)
  alert,       // Vehicle needs attention/issue - Red (#E74C3C)
}

/// Marker tier based on zoom level for Level of Detail (LOD) system.
enum MarkerTier {
  nano,      // Zoom < 11: Simple 12px circle
  standard,  // Zoom 11-15: Halo Pin with last 4 digits
  detailed,  // Zoom > 15: Rich capsule with full vehicle number
}

/// Utility for generating custom map markers with donut ring design.
/// 
/// Creates premium markers with:
/// - Colored ring indicating status (green/orange/yellow)
/// - White center with vehicle ID or icon
/// - Bearing indicator (triangle) showing direction of travel
class MarkerGenerator {
  MarkerGenerator._();

  /// Create a donut ring marker with status color and bearing indicator.
  /// 
  /// [vehicleId] - Short identifier to display in center (max 4 chars recommended)
  /// [status] - Vehicle status determining ring color
  /// [bearing] - Direction of travel in degrees (0-360)
  /// [size] - Logical size of marker (default: 48x48)
  /// [devicePixelRatio] - Device pixel ratio for crisp rendering (default: 3.0)
  /// [showIcon] - If true, shows car icon instead of text (default: false)
  static Future<BitmapDescriptor> createDonutMarker({
    required String vehicleId,
    required VehicleStatus status,
    required double bearing,
    double size = 48.0,
    double devicePixelRatio = 3.0,
    bool showIcon = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Scale for high-DPI rendering
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);
    final outerRadius = size / 2;
    final ringWidth = 6.0;
    final innerRadius = outerRadius - ringWidth;
    final centerRadius = innerRadius - 4.0; // Center circle radius

    // Determine ring color based on status
    final ringColor = _getStatusColor(status);

    // Draw outer ring (status indicator)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = ringColor;
    canvas.drawCircle(center, outerRadius - ringWidth / 2, ringPaint);

    // Draw white center circle
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, centerRadius, centerPaint);

    // Draw center content (icon or text)
    if (showIcon) {
      _drawCarIcon(canvas, center, centerRadius * 0.6);
    } else {
      _drawVehicleId(canvas, center, centerRadius, vehicleId);
    }

    // Draw bearing indicator (triangle on ring)
    _drawBearingIndicator(canvas, center, outerRadius, bearing, ringColor);

    // Add shadow
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.3),
      4,
      false,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * devicePixelRatio).round(),
      (size * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  /// Get color for vehicle status.
  static Color _getStatusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.active:
        return LogisticsColors.neonGreen;
      case VehicleStatus.offline:
        return LogisticsColors.burntOrange;
      case VehicleStatus.warning:
        return LogisticsColors.warningYellow;
      case VehicleStatus.available:
        return LogisticsColors.vehicleAvailable;
      case VehicleStatus.onTrip:
        return LogisticsColors.vehicleOnTrip;
      case VehicleStatus.alert:
        return LogisticsColors.vehicleAlert;
    }
  }

  /// Draw vehicle ID text in center.
  static void _drawVehicleId(
    Canvas canvas,
    Offset center,
    double radius,
    String vehicleId,
  ) {
    // Shorten vehicle ID if too long
    final displayText = vehicleId.length > 4
        ? vehicleId.substring(0, 4)
        : vehicleId;

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: LogisticsColors.hudBlack,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  /// Draw car icon in center.
  static void _drawCarIcon(Canvas canvas, Offset center, double size) {
    // Simple car icon using path
    final carPath = Path()
      ..moveTo(center.dx - size * 0.4, center.dy)
      ..lineTo(center.dx - size * 0.3, center.dy - size * 0.3)
      ..lineTo(center.dx + size * 0.3, center.dy - size * 0.3)
      ..lineTo(center.dx + size * 0.4, center.dy)
      ..lineTo(center.dx + size * 0.35, center.dy + size * 0.2)
      ..lineTo(center.dx - size * 0.35, center.dy + size * 0.2)
      ..close();

    final iconPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = LogisticsColors.hudBlack;
    canvas.drawPath(carPath, iconPaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = LogisticsColors.hudBlack;
    canvas.drawCircle(
      Offset(center.dx - size * 0.25, center.dy + size * 0.15),
      size * 0.08,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size * 0.25, center.dy + size * 0.15),
      size * 0.08,
      wheelPaint,
    );
  }

  /// Draw bearing indicator (triangle) on ring edge.
  static void _drawBearingIndicator(
    Canvas canvas,
    Offset center,
    double radius,
    double bearing,
    Color color,
  ) {
    // Convert bearing to radians (bearing is 0-360, where 0 is North)
    // Map to standard math coordinates (0 is right, counter-clockwise)
    final angleRad = (bearing - 90) * math.pi / 180;

    // Calculate triangle position on ring edge
    final triangleCenter = Offset(
      center.dx + radius * math.cos(angleRad),
      center.dy + radius * math.sin(angleRad),
    );

    // Triangle size
    final triangleSize = 6.0;

    // Create triangle path pointing outward
    final trianglePath = Path()
      ..moveTo(
        triangleCenter.dx + triangleSize * math.cos(angleRad),
        triangleCenter.dy + triangleSize * math.sin(angleRad),
      )
      ..lineTo(
        triangleCenter.dx +
            triangleSize * 0.5 * math.cos(angleRad + 2.5),
        triangleCenter.dy +
            triangleSize * 0.5 * math.sin(angleRad + 2.5),
      )
      ..lineTo(
        triangleCenter.dx +
            triangleSize * 0.5 * math.cos(angleRad - 2.5),
        triangleCenter.dy +
            triangleSize * 0.5 * math.sin(angleRad - 2.5),
      )
      ..close();

    final trianglePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(trianglePath, trianglePaint);
  }

  /// Extract last 4 digits from vehicle number.
  static String _extractLastFourDigits(String vehicleNumber) {
    if (vehicleNumber.length <= 4) return vehicleNumber;
    return vehicleNumber.substring(vehicleNumber.length - 4);
  }

  /// Get color for pin marker status.
  static Color _getPinStatusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return LogisticsColors.vehicleAvailable; // #2ECC71
      case VehicleStatus.onTrip:
        return LogisticsColors.vehicleOnTrip;    // #2980B9
      case VehicleStatus.offline:
        return LogisticsColors.vehicleOffline;  // #95A5A6
      case VehicleStatus.alert:
        return LogisticsColors.vehicleAlert;    // #E74C3C
      // Legacy statuses map to closest match
      case VehicleStatus.active:
        return LogisticsColors.vehicleAvailable;
      case VehicleStatus.warning:
        return LogisticsColors.vehicleAlert;
    }
  }

  /// Draw pin shape (circle + triangle pointer).
  static void _drawPinShape(
    Canvas canvas,
    Offset center,
    double pinHeadRadius,
    double pointerHeight,
    double pointerWidth,
    Color fillColor,
  ) {
    // Draw pin head (circle)
    final pinHeadPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawCircle(center, pinHeadRadius, pinHeadPaint);

    // Draw pointer/beak (triangle pointing down)
    final pointerPath = Path()
      ..moveTo(center.dx, center.dy + pinHeadRadius) // Top of pointer
      ..lineTo(center.dx - pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight) // Bottom left
      ..lineTo(center.dx + pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight) // Bottom right
      ..close();
    
    canvas.drawPath(pointerPath, pinHeadPaint);
  }

  /// Draw white border ring around pin head.
  static void _drawPinBorder(
    Canvas canvas,
    Offset center,
    double pinHeadRadius,
    double borderWidth,
  ) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = Colors.white;
    canvas.drawCircle(center, pinHeadRadius, borderPaint);
  }

  /// Draw text (last 4 digits) in pin head.
  static void _drawPinText(
    Canvas canvas,
    Offset center,
    double pinHeadRadius,
    String text,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: pinHeadRadius * 0.6,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  /// Create a pin-style marker with status color and vehicle number.
  /// 
  /// Creates a modern pin marker with:
  /// - Circular pin head with triangular pointer/beak at bottom
  /// - Status-based color coding (Available/On Trip/Offline/Alert)
  /// - White border ring for visibility
  /// - Last 4 digits of vehicle number displayed in white text
  /// - Subtle drop shadow for depth
  /// 
  /// [vehicleNumber] - Full vehicle number (e.g., "MH12JM9999")
  /// [status] - Vehicle status determining pin color
  /// [size] - Logical size of marker (default: 64x64)
  /// [devicePixelRatio] - Device pixel ratio for crisp rendering (default: 3.0)
  static Future<BitmapDescriptor> createPinMarker({
    required String vehicleNumber,
    required VehicleStatus status,
    double size = 64.0,
    double devicePixelRatio = 3.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Scale for high-DPI rendering
    canvas.scale(devicePixelRatio);

    // Pin structure calculations
    final pointerHeight = size * 0.2;
    final pointerWidth = size * 0.3;
    final pinHeadRadius = size * 0.4;
    final borderWidth = 2.5;
    
    // Center point (pin head center, not including pointer)
    final center = Offset(size / 2, size / 2 - pointerHeight / 2);
    
    // Get status color
    final statusColor = _getPinStatusColor(status);
    
    // Extract last 4 digits
    final displayText = _extractLastFourDigits(vehicleNumber);

    // Draw pin shape (circle + triangle)
    _drawPinShape(
      canvas,
      center,
      pinHeadRadius,
      pointerHeight,
      pointerWidth,
      statusColor,
    );

    // Draw white border ring
    _drawPinBorder(
      canvas,
      center,
      pinHeadRadius,
      borderWidth,
    );

    // Draw text (last 4 digits)
    _drawPinText(
      canvas,
      center,
      pinHeadRadius,
      displayText,
    );

    // Add shadow for depth
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: pinHeadRadius))
      ..addPath(
        Path()
          ..moveTo(center.dx, center.dy + pinHeadRadius)
          ..lineTo(center.dx - pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight)
          ..lineTo(center.dx + pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight)
          ..close(),
        Offset.zero,
      );
    
    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.3),
      4,
      false,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * devicePixelRatio).round(),
      (size * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  // ============================================================================
  // Dynamic LOD Marker System - "The Halo Pin"
  // ============================================================================

  /// Get halo color based on vehicle status (high-contrast palette).
  static Color _getHaloColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return const Color(0xFF00E676); // Neon Green
      case VehicleStatus.onTrip:
        return const Color(0xFF29B6F6); // Bright Blue
      case VehicleStatus.offline:
        return const Color(0xFFB0BEC5); // Medium Grey
      case VehicleStatus.alert:
        return const Color(0xFFFF3D00); // Red Orange
      // Legacy statuses map to closest match
      case VehicleStatus.active:
        return const Color(0xFF00E676); // Neon Green
      case VehicleStatus.warning:
        return const Color(0xFFFF3D00); // Red Orange
    }
  }

  /// Get core color based on vehicle status.
  static Color _getCoreColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.offline:
        return Colors.white; // White for offline
      default:
        return const Color(0xFF263238); // Dark Slate for all others
    }
  }

  /// Get text color based on vehicle status.
  static Color _getTextColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.offline:
        return const Color(0xFF263238); // Dark Grey for offline
      default:
        return Colors.white; // White for all others
    }
  }

  /// Create a marker with dynamic Level of Detail (LOD) based on tier.
  /// 
  /// [text] - Vehicle number or identifier to display
  /// [status] - Vehicle status determining colors
  /// [tier] - Marker tier (nano/standard/detailed) based on zoom level
  /// [devicePixelRatio] - Device pixel ratio for crisp rendering (default: 3.0)
  static Future<BitmapDescriptor> createMarker({
    required String text,
    required VehicleStatus status,
    required MarkerTier tier,
    double devicePixelRatio = 3.0,
  }) async {
    switch (tier) {
      case MarkerTier.nano:
        return _createNanoMarker(status, devicePixelRatio);
      case MarkerTier.standard:
        return _createStandardMarker(text, status, devicePixelRatio);
      case MarkerTier.detailed:
        return _createDetailedMarker(text, status, devicePixelRatio);
    }
  }

  /// Create nano tier marker (zoom < 11): Simple 12px circle.
  static Future<BitmapDescriptor> _createNanoMarker(
    VehicleStatus status,
    double devicePixelRatio,
  ) async {
    const size = 12.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    final haloColor = _getHaloColor(status);

    // Draw solid circle with status color
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = haloColor;
    canvas.drawCircle(center, radius, paint);

    // Add subtle shadow
    final shadowPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.3), 2, false);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * devicePixelRatio).round(),
      (size * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  /// Create standard tier marker (zoom 11-15): "Halo Pin" design.
  static Future<BitmapDescriptor> _createStandardMarker(
    String text,
    VehicleStatus status,
    double devicePixelRatio,
  ) async {
    const size = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    // Pin structure calculations
    final pointerHeight = size * 0.2;
    final pointerWidth = size * 0.3;
    final pinHeadRadius = size * 0.4;
    final haloWidth = 3.0;
    
    // Center point (pin head center, not including pointer)
    final center = Offset(size / 2, size / 2 - pointerHeight / 2);
    
    final haloColor = _getHaloColor(status);
    final coreColor = _getCoreColor(status);
    final textColor = _getTextColor(status);
    
    // Extract last 4 digits
    final displayText = _extractLastFourDigits(text);

    // Draw core circle
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = coreColor;
    canvas.drawCircle(center, pinHeadRadius, corePaint);

    // Draw halo (colored stroke ring)
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = haloWidth
      ..color = haloColor;
    canvas.drawCircle(center, pinHeadRadius, haloPaint);

    // Draw pointer/beak (triangle pointing down)
    final pointerPath = Path()
      ..moveTo(center.dx, center.dy + pinHeadRadius) // Top of pointer
      ..lineTo(center.dx - pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight) // Bottom left
      ..lineTo(center.dx + pointerWidth / 2, center.dy + pinHeadRadius + pointerHeight) // Bottom right
      ..close();
    
    final pointerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = coreColor;
    canvas.drawPath(pointerPath, pointerPaint);

    // Draw halo on pointer too
    final pointerHaloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = haloWidth
      ..color = haloColor;
    canvas.drawPath(pointerPath, pointerHaloPaint);

    // Draw text (last 4 digits)
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: textColor,
          fontSize: pinHeadRadius * 0.6,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);

    // Add shadow for depth
    final shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: pinHeadRadius))
      ..addPath(pointerPath, Offset.zero);
    
    canvas.drawShadow(
      shadowPath,
      Colors.black.withOpacity(0.3),
      4,
      false,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * devicePixelRatio).round(),
      (size * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  /// Create detailed tier marker (zoom > 15): Rich capsule with icon and full text.
  static Future<BitmapDescriptor> _createDetailedMarker(
    String text,
    VehicleStatus status,
    double devicePixelRatio,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    const minHeight = 64.0;
    const iconSize = 32.0;
    const paddingX = 16.0;
    const iconPadding = 12.0;
    const cornerRadius = 16.0;

    final haloColor = _getHaloColor(status);
    final coreColor = _getCoreColor(status);
    final textColor = _getTextColor(status);

    // Measure text to determine capsule width
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 16.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final capsuleWidth = iconSize + iconPadding + textWidth + paddingX * 2;
    final capsuleHeight = minHeight;

    // Create rounded rectangle path
    final capsuleRect = Rect.fromLTWH(0, 0, capsuleWidth, capsuleHeight);
    final capsulePath = Path()
      ..addRRect(RRect.fromRectAndRadius(capsuleRect, Radius.circular(cornerRadius)));

    // Draw core background
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = coreColor;
    canvas.drawPath(capsulePath, corePaint);

    // Draw halo border
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = haloColor;
    canvas.drawPath(capsulePath, haloPaint);

    // Draw vehicle icon on left
    final iconCenter = Offset(iconSize / 2 + paddingX, capsuleHeight / 2);
    _drawVehicleIcon(canvas, iconCenter, iconSize * 0.7, textColor);

    // Draw text on right
    final textOffset = Offset(
      iconSize + iconPadding + paddingX,
      (capsuleHeight - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    // Add shadow
    canvas.drawShadow(
      capsulePath,
      Colors.black.withOpacity(0.3),
      6,
      false,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (capsuleWidth * devicePixelRatio).round(),
      (capsuleHeight * devicePixelRatio).round(),
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    return BitmapDescriptor.bytes(bytes);
  }

  /// Draw vehicle icon (truck/car) for detailed tier marker.
  static void _drawVehicleIcon(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
    // Draw truck icon using path
    final truckPath = Path()
      // Main body
      ..moveTo(center.dx - size * 0.4, center.dy + size * 0.15)
      ..lineTo(center.dx - size * 0.4, center.dy - size * 0.2)
      ..lineTo(center.dx - size * 0.15, center.dy - size * 0.2)
      ..lineTo(center.dx - size * 0.1, center.dy - size * 0.35)
      ..lineTo(center.dx + size * 0.3, center.dy - size * 0.35)
      ..lineTo(center.dx + size * 0.3, center.dy + size * 0.15)
      ..close()
      // Cab window
      ..moveTo(center.dx - size * 0.3, center.dy - size * 0.15)
      ..lineTo(center.dx - size * 0.15, center.dy - size * 0.15)
      ..lineTo(center.dx - size * 0.15, center.dy - size * 0.05)
      ..lineTo(center.dx - size * 0.3, center.dy - size * 0.05)
      ..close();

    final iconPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(truckPath, iconPaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(
      Offset(center.dx - size * 0.15, center.dy + size * 0.15),
      size * 0.1,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size * 0.15, center.dy + size * 0.15),
      size * 0.1,
      wheelPaint,
    );
  }
}
