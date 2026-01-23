import 'package:core_ui/core_ui.dart';
import 'package:dash_web/features/fleet_map/logic/history_player_controller.dart';
import 'package:dash_web/features/fleet_map/models/timeline_segment.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// DVR-style playback control sheet for vehicle history.
/// 
/// Provides timeline scrubbing, play/pause controls, speed adjustment,
/// and visual timeline segments showing moving vs stopped periods.
class HistoryPlaybackSheet extends StatefulWidget {
  const HistoryPlaybackSheet({
    super.key,
    required this.controller,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onClose,
  });

  final HistoryPlayerController controller;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClose;

  @override
  State<HistoryPlaybackSheet> createState() => _HistoryPlaybackSheetState();
}

class _HistoryPlaybackSheetState extends State<HistoryPlaybackSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Select date',
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.selectedDate),
      );

      if (time != null && mounted) {
        final selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (selectedDateTime.isAfter(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot select future time')),
            );
          }
          return;
        }

        widget.onDateSelected(selectedDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final startTime = controller.startTime;
    final endTime = controller.endTime;
    final currentTime = controller.currentTime;

    if (startTime == null || endTime == null) {
      return const SizedBox.shrink();
    }

    final totalDuration = endTime.difference(startTime);
    final currentPosition = currentTime.difference(startTime);
    final progress = totalDuration.inMilliseconds > 0
        ? currentPosition.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    return GlassPanel(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Header (Date picker + Close button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date picker button
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: LogisticsColors.navyBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, yyyy').format(widget.selectedDate),
                        style: TextStyle(
                          color: LogisticsColors.navyBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Close button
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: LogisticsColors.navyBlue,
                ),
                onPressed: widget.onClose,
                tooltip: 'Exit history mode',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2: Timeline slider with segments
          _TimelineSlider(
            progress: progress.clamp(0.0, 1.0),
            segments: controller.getSegments(),
            startTime: startTime,
            endTime: endTime,
            onChanged: (value) {
              final newTime = startTime.add(
                Duration(
                  milliseconds: (totalDuration.inMilliseconds * value).round(),
                ),
              );
              controller.seekTo(newTime);
            },
          ),
          const SizedBox(height: 16),
          // Row 3: Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamp display (left)
              Text(
                DateFormat('HH:mm:ss').format(currentTime),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LogisticsColors.navyBlue,
                ),
              ),
              // Playback controls (center)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => controller.seekBackward(
                      const Duration(seconds: 10),
                    ),
                    tooltip: 'Backward 10s',
                    color: LogisticsColors.navyBlue,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 48,
                    ),
                    onPressed: controller.togglePlayPause,
                    tooltip: controller.isPlaying ? 'Pause' : 'Play',
                    color: LogisticsColors.navyBlue,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => controller.seekForward(
                      const Duration(seconds: 10),
                    ),
                    tooltip: 'Forward 10s',
                    color: LogisticsColors.navyBlue,
                  ),
                ],
              ),
              // Speed toggle (right)
              TextButton(
                onPressed: controller.cycleSpeed,
                child: Text(
                  '${controller.playbackSpeed.toInt()}x',
                  style: TextStyle(
                    color: LogisticsColors.navyBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom timeline slider with colored segments showing movement patterns.
class _TimelineSlider extends StatelessWidget {
  const _TimelineSlider({
    required this.progress,
    required this.segments,
    required this.startTime,
    required this.endTime,
    required this.onChanged,
  });

  final double progress;
  final List<TimelineSegment> segments;
  final DateTime startTime;
  final DateTime endTime;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final localX = details.localPosition.dx;
            final newProgress = (localX / constraints.maxWidth).clamp(0.0, 1.0);
            onChanged(newProgress);
          },
          onPanUpdate: (details) {
            final localX = details.localPosition.dx;
            final newProgress = (localX / constraints.maxWidth).clamp(0.0, 1.0);
            onChanged(newProgress);
          },
          child: Stack(
            children: [
              // Background segments
              CustomPaint(
                size: Size(constraints.maxWidth, 40),
                painter: _TimelinePainter(
                  segments: segments,
                  startTime: startTime,
                  endTime: endTime,
                ),
              ),
              // Slider track
              Positioned.fill(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    activeTrackColor: LogisticsColors.navyBlue.withOpacity(0.3),
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: LogisticsColors.navyBlue,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for timeline segments (green = moving, red = stopped).
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.segments,
    required this.startTime,
    required this.endTime,
  });

  final List<TimelineSegment> segments;
  final DateTime startTime;
  final DateTime endTime;

  @override
  void paint(Canvas canvas, Size size) {
    final totalDuration = endTime.difference(startTime).inMilliseconds;
    if (totalDuration <= 0) return;

    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4),
      const Radius.circular(2),
    );

    // Draw background (grey)
    final bgPaint = Paint()
      ..color = Colors.grey[300]!.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRect, bgPaint);

    // Draw segments
    for (final segment in segments) {
      final segmentStart = segment.start.difference(startTime).inMilliseconds;
      final segmentEnd = segment.end.difference(startTime).inMilliseconds;

      if (segmentEnd < 0 || segmentStart > totalDuration) continue;

      final startX = (segmentStart / totalDuration * size.width).clamp(0.0, size.width);
      final endX = (segmentEnd / totalDuration * size.width).clamp(0.0, size.width);
      final width = endX - startX;

      if (width <= 0) continue;

      final segmentPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = segment.status == TimelineStatus.moving
            ? LogisticsColors.neonGreen.withOpacity(0.6)
            : LogisticsColors.burntOrange.withOpacity(0.6);

      final segmentRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, size.height / 2 - 2, width, 4),
        const Radius.circular(2),
      );
      canvas.drawRRect(segmentRect, segmentPaint);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return segments != oldDelegate.segments ||
        startTime != oldDelegate.startTime ||
        endTime != oldDelegate.endTime;
  }
}
