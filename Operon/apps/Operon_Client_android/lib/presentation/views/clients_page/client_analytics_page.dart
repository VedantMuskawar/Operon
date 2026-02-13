import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/analytics_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/foundation.dart';
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
  bool _analyticsLoaded = false;
  String? _cachedActiveClientsValue;
  String? _cachedOnboardingValue;
  Map<String, double>? _cachedChartData;
  String? _lastOrgId;
  String? _lastFy;

  @override
  void initState() {
    super.initState();
    // Defer analytics loading - load only when page is visible
    _scheduleAnalyticsLoad();
  }

  void _scheduleAnalyticsLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_analyticsLoaded) {
        _loadAnalytics();
      }
    });
  }

  @override
  void didUpdateWidget(ClientAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload analytics only if org or FY changed
    _checkAndReloadIfNeeded();
  }

  void _checkAndReloadIfNeeded() {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final newOrgId = orgContext.organization?.id;
    final newFy = _canonicalFy(orgContext.financialYear);
    
    if (_lastOrgId != newOrgId || _lastFy != newFy) {
      _lastOrgId = newOrgId;
      _lastFy = newFy;
      _analyticsLoaded = false;
      _scheduleAnalyticsLoad();
    }
  }

  void _updateCachedValues() {
    if (_analytics == null) return;
    _cachedActiveClientsValue = _analytics!.totalActiveClients.toString();
    _cachedOnboardingValue = _calculateCurrentValue(_analytics!.onboardingMonthly);
    // Prepare chart data
    final sortedKeys = _analytics!.onboardingMonthly.keys.toList()..sort();
    _cachedChartData = Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, _analytics!.onboardingMonthly[key] ?? 0.0)),
    );
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
      final organizationId = orgContext.organization?.id;
      
      if (kDebugMode) {
        print('[ClientAnalyticsPage] Loading analytics for org: $organizationId, FY: $canonicalFy');
      }
      
      final analytics = await repository.fetchClientsAnalytics(
        financialYear: canonicalFy.isNotEmpty ? canonicalFy : null,
        organizationId: organizationId,
      );
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
          _analyticsLoaded = true;
        });
        _updateCachedValues();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _analyticsLoaded = true; // Mark as attempted even if failed
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_analytics == null || _analytics!.onboardingMonthly.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: AuthColors.textSub.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              const Text(
                'No analytics data available',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.paddingSM),
              Text(
                'Analytics will appear once clients are added.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuthColors.textSub.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Statistics Header
        BlocBuilder<ClientsCubit, ClientsState>(
          buildWhen: (previous, current) {
            // Only rebuild when recentClients list changes
            return previous.recentClients != current.recentClients;
          },
          builder: (context, state) {
            return _ClientsStatsHeader(clients: state.recentClients);
          },
        ),
        const SizedBox(height: AppSpacing.paddingXXL),
        // Info Tiles
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'Active Clients',
                value: _cachedActiveClientsValue ?? _analytics!.totalActiveClients.toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _InfoTile(
                title: 'Onboarding',
                value: _cachedOnboardingValue ?? _calculateCurrentValue(_analytics!.onboardingMonthly),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingXXL),
        // Graph
        if (_analytics != null)
          _OnboardingChart(
            data: _cachedChartData ?? _analytics!.onboardingMonthly,
          ),
        const SizedBox(height: AppSpacing.paddingXXL),
        // Summary Stats
        _SummaryStats(data: _analytics!.onboardingMonthly),
      ],
      ),
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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.primary.withValues(alpha: 0.2),
            AuthColors.success.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textSub.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
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

  Map<String, double> _prepareChartData() {
    if (data.isEmpty) return {};
    final sortedKeys = data.keys.toList()..sort();
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, data[key] ?? 0.0)),
    );
  }

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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textSub.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onboarding Trend',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    // Only repaint if data actually changed
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.minValue != minValue;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 40.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding - 30;
    final dataPoints = data.values.toList();
    final dataKeys = data.keys.toList();
    
    // Guard against invalid sizes
    if (chartWidth <= 0 || chartHeight <= 0) return;
    
    // Guard against empty data
    if (dataPoints.isEmpty) return;
    
    // Handle case where all values are the same (flat line)
    final valueRange = maxValue - minValue;
    final normalizedValueRange = valueRange > 0 ? valueRange : 1.0; // Use 1.0 to avoid division by zero

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AuthColors.textSub.withValues(alpha: 0.2)
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
    const textStyle = TextStyle(
              color: AuthColors.textSub,
      fontSize: 11,
    );
    for (int i = 0; i <= 4; i++) {
      final value = valueRange > 0 
          ? maxValue - valueRange * (i / 4)
          : maxValue; // Handle case where maxValue == minValue
      final yPos = padding + (chartHeight / 4) * i;
      
      // Guard against NaN
      if (yPos.isNaN || !yPos.isFinite) continue;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Guard against invalid textPainter dimensions
      if (textPainter.height.isNaN || !textPainter.height.isFinite) continue;
      
      final offsetY = yPos - textPainter.height / 2;
      if (offsetY.isNaN || !offsetY.isFinite) continue;
      
      textPainter.paint(
        canvas,
        Offset(0, offsetY),
      );
    }

    // Draw line and points
    final divisor = (dataPoints.length - 1);
    final chartDivisor = divisor > 0 ? divisor : 1.0; // Avoid division by zero for single point
    
    if (dataPoints.length > 1) {
      final path = Path();
      final pointPaint = Paint()
        ..color = AuthColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / chartDivisor) * i;
        final normalizedValue = (dataPoints[i] - minValue) / normalizedValueRange;
        final y = padding + chartHeight - (normalizedValue * chartHeight);
        
        // Guard against NaN values
        if (x.isNaN || y.isNaN || !x.isFinite || !y.isFinite) continue;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, pointPaint);

      // Draw points
      final pointPaint2 = Paint()
        ..color = AuthColors.primary
        ..style = PaintingStyle.fill;

      for (int i = 0; i < dataPoints.length; i++) {
        final x = padding + (chartWidth / chartDivisor) * i;
        final normalizedValue = (dataPoints[i] - minValue) / normalizedValueRange;
        final y = padding + chartHeight - (normalizedValue * chartHeight);
        
        // Guard against NaN values
        if (x.isNaN || y.isNaN || !x.isFinite || !y.isFinite) continue;

        canvas.drawCircle(Offset(x, y), 4, pointPaint2);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
      }

      // Draw value labels
      for (int i = 0; i < dataPoints.length; i++) {
        if (i % ((dataPoints.length / 6).ceil()) == 0 || i == dataPoints.length - 1) {
          final x = padding + (chartWidth / chartDivisor) * i;
          final normalizedValue = (dataPoints[i] - minValue) / normalizedValueRange;
          final y = padding + chartHeight - (normalizedValue * chartHeight);
          
          // Guard against NaN values
          if (x.isNaN || y.isNaN || !x.isFinite || !y.isFinite) continue;

          final valueText = TextPainter(
            text: TextSpan(
              text: dataPoints[i].toInt().toString(),
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          valueText.layout();
          final offsetX = x - valueText.width / 2;
          final offsetY = y - 20;
          
          // Final guard before painting
          if (offsetX.isNaN || offsetY.isNaN || !offsetX.isFinite || !offsetY.isFinite) continue;
          
          valueText.paint(
            canvas,
            Offset(offsetX, offsetY),
          );
        }
      }
    } else if (dataPoints.length == 1) {
      // Handle single data point - just draw a point
      final pointPaint2 = Paint()
        ..color = AuthColors.primary
        ..style = PaintingStyle.fill;
      
      final x = padding + chartWidth / 2;
      final normalizedValue = (dataPoints[0] - minValue) / normalizedValueRange;
      final y = padding + chartHeight - (normalizedValue * chartHeight);
      
      if (!x.isNaN && !y.isNaN && x.isFinite && y.isFinite) {
        canvas.drawCircle(Offset(x, y), 4, pointPaint2);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = AuthColors.textMain);
      }
    }

    // Draw X-axis labels
    if (dataKeys.length > 1) {
    final xAxisLabelCount = (dataKeys.length / 4).ceil();
      final xAxisDivisor = dataKeys.length - 1;
      
    for (int i = 0; i < dataKeys.length; i++) {
      if (i % xAxisLabelCount == 0 || i == dataKeys.length - 1) {
          final x = padding + (chartWidth / xAxisDivisor) * i;
          
          // Guard against NaN values
          if (x.isNaN || !x.isFinite) continue;
          
        final label = _formatXAxisLabel(dataKeys[i]);
        final labelText = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        labelText.layout();
          final offsetX = x - labelText.width / 2;
          final offsetY = size.height - 25;
          
          // Final guard before painting
          if (offsetX.isNaN || offsetY.isNaN || !offsetX.isFinite || !offsetY.isFinite) continue;
          
          labelText.paint(
            canvas,
            Offset(offsetX, offsetY),
          );
        }
      }
    } else if (dataKeys.length == 1) {
      // Handle single data point case
      final label = _formatXAxisLabel(dataKeys[0]);
      final labelText = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              color: AuthColors.textSub,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelText.layout();
      final offsetX = padding + chartWidth / 2 - labelText.width / 2;
      final offsetY = size.height - 25;
      
      if (!offsetX.isNaN && !offsetY.isNaN && offsetX.isFinite && offsetY.isFinite) {
        labelText.paint(
          canvas,
          Offset(offsetX, offsetY),
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
            color: AuthColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
        Expanded(
          child: _StatChip(
            label: 'Max',
            value: maxValue.toInt().toString(),
            subtitle: _formatMonth(maxKey),
            color: AuthColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
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
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXS),
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
                const SizedBox(width: AppSpacing.paddingXS),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AuthColors.textSub,
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

class _ClientsStatsHeader extends StatelessWidget {
  const _ClientsStatsHeader({required this.clients});

  final List<ClientRecord> clients;

  @override
  Widget build(BuildContext context) {
    final totalClients = clients.length;
    final corporateCount = clients.where((c) => c.isCorporate).length;
    final individualCount = totalClients - corporateCount;
    final totalOrders = clients.fold<int>(
      0,
      (sum, client) => sum + ((client.stats['orders'] as num?)?.toInt() ?? 0),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_outline,
                label: 'Total',
                value: totalClients.toString(),
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.business_outlined,
                label: 'Corporate',
                value: corporateCount.toString(),
                color: AuthColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.person_outline,
                label: 'Individual',
                value: individualCount.toString(),
                color: AuthColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.shopping_bag_outlined,
                label: 'Orders',
                value: totalOrders.toString(),
                color: AuthColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
          color: AuthColors.textSub.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
