import 'package:dash_mobile/data/repositories/analytics_repository.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ClientAnalyticsPage extends StatefulWidget {
  const ClientAnalyticsPage({super.key});

  @override
  State<ClientAnalyticsPage> createState() => _ClientAnalyticsPageState();
}

class _ClientAnalyticsPageState extends State<ClientAnalyticsPage> {
  ClientsAnalytics? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  String _canonicalFy(String? prettyFy) {
    if (prettyFy == null || prettyFy.isEmpty) return '';
    final digits = RegExp(r'\d{4}').allMatches(prettyFy).map((m) => m.group(0)!);
    if (digits.length >= 2) {
      final first = digits.first.substring(2);
      final second = digits.elementAt(1).substring(2);
      return 'FY$first$second';
    }
    return prettyFy.replaceAll(' ', '');
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final orgContext = context.read<OrganizationContextCubit>().state;
      final repository = AnalyticsRepository();
      final canonicalFy = _canonicalFy(orgContext.financialYear);
      final analytics = await repository.fetchClientsAnalytics(
        financialYear: canonicalFy.isNotEmpty ? canonicalFy : null,
      );
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_analytics == null || _analytics!.onboardingMonthly.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No analytics data available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analytics will appear once clients are added.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info Tiles
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'Active Clients',
                value: _calculateCurrentValue(_analytics!.activeClientsMonthly),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                title: 'Onboarding',
                value: _calculateCurrentValue(_analytics!.onboardingMonthly),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Graph
        _OnboardingChart(
          data: _analytics!.onboardingMonthly,
        ),
        const SizedBox(height: 24),
        // Summary Stats
        _SummaryStats(data: _analytics!.onboardingMonthly),
      ],
    );
  }

  String _calculateCurrentValue(Map<String, double> data) {
    if (data.isEmpty) return '0';
    final sortedKeys = data.keys.toList()..sort();
    final latestKey = sortedKeys.last;
    return data[latestKey]?.toInt().toString() ?? '0';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6F4BFF).withOpacity(0.2),
            const Color(0xFF4CE0B3).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingChart extends StatelessWidget {
  const _OnboardingChart({
    required this.data,
  });

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final chartData = _prepareChartData();
    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = chartData.values.reduce((a, b) => a > b ? a : b);
    final minValue = chartData.values.reduce((a, b) => a < b ? a : b);
    const chartHeight = 240.0;

    return Container(
      height: chartHeight + 60,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onboarding Trend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                data: chartData,
                maxValue: maxValue,
                minValue: minValue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _prepareChartData() {
    if (data.isEmpty) return {};
    final sortedKeys = data.keys.toList()..sort();
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, data[key] ?? 0.0)),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
  });

  final Map<String, double> data;
  final double maxValue;
  final double minValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding - 30;
    final dataPoints = data.values.toList();
    final dataKeys = data.keys.toList();

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padding + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw Y-axis labels
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontSize: 11,
    );
    for (int i = 0; i <= 4; i++) {
      final value = maxValue - (maxValue - minValue) * (i / 4);
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(0, padding + (chartHeight / 4) * i - textPainter.height / 2),
      );
    }

    // Draw line
    if (dataPoints.length > 1) {
      final path = Path();
      final pointPaint = Paint()
        ..color = const Color(0xFF6F4BFF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / (dataPoints.length - 1)) * i;
        final normalizedValue = (dataPoints[i] - minValue) / (maxValue - minValue);
        final y = padding + chartHeight - (normalizedValue * chartHeight);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, pointPaint);

      // Draw points
      final pointPaint2 = Paint()
        ..color = const Color(0xFF6F4BFF)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / (dataPoints.length - 1)) * i;
        final normalizedValue = (dataPoints[i] - minValue) / (maxValue - minValue);
        final y = padding + chartHeight - (normalizedValue * chartHeight);

        canvas.drawCircle(Offset(x, y), 4, pointPaint2);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
      }

      // Draw value labels
      for (int i = 0; i < dataPoints.length; i++) {
        if (i % ((dataPoints.length / 6).ceil()) == 0 || i == dataPoints.length - 1) {
          final x = padding + (chartWidth / (dataPoints.length - 1)) * i;
          final normalizedValue = (dataPoints[i] - minValue) / (maxValue - minValue);
          final y = padding + chartHeight - (normalizedValue * chartHeight);

          final valueText = TextPainter(
            text: TextSpan(
              text: dataPoints[i].toInt().toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          valueText.layout();
          valueText.paint(
            canvas,
            Offset(x - valueText.width / 2, y - 20),
          );
        }
      }
    }

    // Draw X-axis labels
    final xAxisLabelCount = (dataKeys.length / 4).ceil();
    for (int i = 0; i < dataKeys.length; i++) {
      if (i % xAxisLabelCount == 0 || i == dataKeys.length - 1) {
        final x = padding + (chartWidth / (dataKeys.length - 1)) * i;
        final label = _formatXAxisLabel(dataKeys[i]);
        final labelText = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelText.layout();
        labelText.paint(
          canvas,
          Offset(x - labelText.width / 2, size.height - 25),
        );
      }
    }
  }

  String _formatXAxisLabel(String key) {
    try {
      final parts = key.split('-');
      if (parts.length == 2) {
        final month = int.parse(parts[1]);
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        if (month >= 1 && month <= 12) {
          return monthNames[month - 1];
        }
      }
      return key;
    } catch (_) {
      return key;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.data});

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.values.toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxKey = data.entries.firstWhere((e) => e.value == maxValue).key;
    final minKey = data.entries.firstWhere((e) => e.value == minValue).key;
    final currentValue = values.last;

    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Current',
            value: currentValue.toInt().toString(),
            color: const Color(0xFF6F4BFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            label: 'Max',
            value: maxValue.toInt().toString(),
            subtitle: _formatMonth(maxKey),
            color: const Color(0xFF4CE0B3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            label: 'Min',
            value: minValue.toInt().toString(),
            subtitle: _formatMonth(minKey),
            color: Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  String _formatMonth(String key) {
    try {
      final parts = key.split('-');
      if (parts.length == 2) {
        final month = int.parse(parts[1]);
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        if (month >= 1 && month <= 12) {
          return monthNames[month - 1];
        }
      }
      return key;
    } catch (_) {
      return key;
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
