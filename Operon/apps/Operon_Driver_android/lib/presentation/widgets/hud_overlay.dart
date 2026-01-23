import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Heads-Up Display overlay for Driver Map.
/// 
/// Displays real-time trip information (speed, ETA, distance) in a compact,
/// high-contrast format optimized for driver visibility.
class HudOverlay extends StatelessWidget {
  const HudOverlay({
    super.key,
    this.speed,
    this.eta,
    this.distance,
  });

  /// Current speed in km/h. Null if not available.
  final double? speed;

  /// Estimated time to arrival as Duration. Null if not available.
  final Duration? eta;

  /// Remaining distance in kilometers. Null if not available.
  final double? distance;

  String _formatSpeed(double? speed) {
    if (speed == null) return '--';
    return '${speed.toStringAsFixed(1)}';
  }

  String _formatEta(Duration? eta) {
    if (eta == null) return '--:--';
    final hours = eta.inHours;
    final minutes = eta.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatDistance(double? distance) {
    if (distance == null) return '--';
    if (distance < 1.0) {
      return '${(distance * 1000).toStringAsFixed(0)}m';
    }
    return '${distance.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    // Use Roboto Mono for monospaced numbers to prevent jitter
    final monospaceStyle = GoogleFonts.robotoMono(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: LogisticsColors.neonGreen,
      letterSpacing: 0.5,
    );

    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.grey[400],
      letterSpacing: 0.3,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: LogisticsColors.hudBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HudStatItem(
                label: 'SPEED',
                value: _formatSpeed(speed),
                unit: 'km/h',
                valueStyle: monospaceStyle,
                labelStyle: labelStyle,
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.1),
              ),
              _HudStatItem(
                label: 'ETA',
                value: _formatEta(eta),
                unit: '',
                valueStyle: monospaceStyle,
                labelStyle: labelStyle,
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.1),
              ),
              _HudStatItem(
                label: 'DISTANCE',
                value: _formatDistance(distance),
                unit: 'km',
                valueStyle: monospaceStyle,
                labelStyle: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudStatItem extends StatelessWidget {
  const _HudStatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueStyle,
    required this.labelStyle,
  });

  final String label;
  final String value;
  final String unit;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: labelStyle,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: valueStyle,
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: labelStyle.copyWith(fontSize: 10),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
