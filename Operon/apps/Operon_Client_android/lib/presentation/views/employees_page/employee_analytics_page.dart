import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/analytics_repository.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmployeeAnalyticsPage extends StatefulWidget {
  const EmployeeAnalyticsPage({super.key});

  @override
  State<EmployeeAnalyticsPage> createState() => _EmployeeAnalyticsPageState();
}

class _EmployeeAnalyticsPageState extends State<EmployeeAnalyticsPage> {
  EmployeesAnalytics? _analytics;
  bool _isLoading = true;
  String? _cachedActiveEmployeesValue;
  String? _cachedWagesValue;
  Map<String, double>? _cachedChartData;
  Map<String, double>? _lastAnalyticsData;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didUpdateWidget(EmployeeAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_analytics != null && _lastAnalyticsData != _analytics!.wagesCreditMonthly) {
      _updateCachedValues();
    }
  }

  void _updateCachedValues() {
    if (_analytics == null) return;
    _cachedActiveEmployeesValue = _analytics!.totalActiveEmployees.toString();
    _cachedWagesValue = _calculateCurrentValue(_analytics!.wagesCreditMonthly);
    // Prepare chart data
    final sortedKeys = _analytics!.wagesCreditMonthly.keys.toList()..sort();
    _cachedChartData = Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, _analytics!.wagesCreditMonthly[key] ?? 0.0)),
    );
    _lastAnalyticsData = _analytics!.wagesCreditMonthly;
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
        print('[EmployeeAnalyticsPage] Loading analytics for org: $organizationId, FY: $canonicalFy');
      }
      
      final analytics = await repository.fetchEmployeesAnalytics(
        financialYear: canonicalFy.isNotEmpty ? canonicalFy : null,
        organizationId: organizationId,
      );
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
        _updateCachedValues();
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
          padding: EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_analytics == null || _analytics!.wagesCreditMonthly.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              Text(
                'No analytics data available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.paddingSM),
              Text(
                'Analytics will appear once employees are added and wages are credited.',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Statistics Header
          BlocBuilder<EmployeesCubit, EmployeesState>(
            buildWhen: (previous, current) {
              // Only rebuild when employees list changes
              return previous.employees != current.employees;
            },
            builder: (context, state) {
              return _EmployeesStatsHeader(employees: state.employees);
            },
          ),
          const SizedBox(height: AppSpacing.paddingXXL),
          // Info Tiles
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  title: 'Active Employees',
                  value: _cachedActiveEmployeesValue ?? _analytics!.totalActiveEmployees.toString(),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: _InfoTile(
                  title: 'Wages This Month',
                  value: _cachedWagesValue ?? _calculateCurrentValue(_analytics!.wagesCreditMonthly),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingXXL),
          // Graph
          if (_analytics != null)
            _WagesChart(
              data: _cachedChartData ?? _analytics!.wagesCreditMonthly,
            ),
          const SizedBox(height: AppSpacing.paddingXXL),
          // Summary Stats
          _SummaryStats(data: _analytics!.wagesCreditMonthly),
        ],
      ),
    );
  }

  String _calculateCurrentValue(Map<String, double> data) {
    if (data.isEmpty) return '₹0';
    final sortedKeys = data.keys.toList()..sort();
    final latestKey = sortedKeys.last;
    final value = data[latestKey] ?? 0.0;
    return '₹${value.toInt()}';
  }
}

class _EmployeesStatsHeader extends StatelessWidget {
  const _EmployeesStatsHeader({required this.employees});

  final List employees;

  @override
  Widget build(BuildContext context) {
    final totalEmployees = employees.length;
    final totalOpeningBalance = employees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.openingBalance,
    );
    final totalCurrentBalance = employees.fold<double>(
      0.0,
      (sum, emp) => sum + emp.currentBalance,
    );
    final avgBalance = totalEmployees > 0
        ? totalCurrentBalance / totalEmployees
        : 0.0;
    final balanceDifference = totalCurrentBalance - totalOpeningBalance;
    final balanceChangePercent = totalOpeningBalance != 0
        ? (balanceDifference / totalOpeningBalance * 100)
        : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_outline,
                label: 'Total',
                value: totalEmployees.toString(),
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Opening Balance',
                value: '₹${totalOpeningBalance.toStringAsFixed(2)}',
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
                icon: Icons.trending_up,
                label: 'Current Balance',
                value: '₹${totalCurrentBalance.toStringAsFixed(2)}',
                subtitle: balanceDifference != 0
                    ? '${balanceDifference >= 0 ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)} (${balanceChangePercent >= 0 ? '+' : ''}${balanceChangePercent.abs().toStringAsFixed(1)}%)'
                    : null,
                subtitleColor: balanceDifference >= 0 ? AuthColors.success : AuthColors.error,
                color: AuthColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.analytics_outlined,
                label: 'Average Balance',
                value: '₹${avgBalance.toStringAsFixed(2)}',
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
    this.subtitle,
    this.subtitleColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

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
          color: AuthColors.textSub.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withOpacity(0.3),
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
                  color: color.withOpacity(0.2),
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
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.paddingXS),
            Text(
              subtitle!,
              style: TextStyle(
                    color: subtitleColor ?? AuthColors.textSub,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
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
            const Color(0xFF6F4BFF).withOpacity(0.2),
            const Color(0xFF4CE0B3).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
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
          const SizedBox(height: AppSpacing.paddingSM),
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

class _WagesChart extends StatelessWidget {
  const _WagesChart({
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
        border: Border.all(color: AuthColors.textSub.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wages Credit Trend',
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
              painter: _WagesLineChartPainter(
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

class _WagesLineChartPainter extends CustomPainter {
  _WagesLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
  });

  final Map<String, double> data;
  final double maxValue;
  final double minValue;

  @override
  bool shouldRepaint(covariant _WagesLineChartPainter oldDelegate) {
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
    
    if (chartWidth <= 0 || chartHeight <= 0) return;
    if (dataPoints.isEmpty) return;
    
    final valueRange = maxValue - minValue;
    final normalizedValueRange = valueRange > 0 ? valueRange : 1.0;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = AuthColors.textSub.withOpacity(0.2)
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
          : maxValue;
      final yPos = padding + (chartHeight / 4) * i;
      
      if (yPos.isNaN || !yPos.isFinite) continue;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '₹${value.toInt()}',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
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
    final chartDivisor = divisor > 0 ? divisor : 1.0;
    
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
          
          if (x.isNaN || y.isNaN || !x.isFinite || !y.isFinite) continue;

          final valueText = TextPainter(
            text: TextSpan(
              text: '₹${dataPoints[i].toInt()}',
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
          
          if (offsetX.isNaN || offsetY.isNaN || !offsetX.isFinite || !offsetY.isFinite) continue;
          
          valueText.paint(
            canvas,
            Offset(offsetX, offsetY),
          );
        }
      }
    } else if (dataPoints.length == 1) {
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
          
          if (offsetX.isNaN || offsetY.isNaN || !offsetX.isFinite || !offsetY.isFinite) continue;
          
          labelText.paint(
            canvas,
            Offset(offsetX, offsetY),
          );
        }
      }
    } else if (dataKeys.length == 1) {
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
            value: '₹${currentValue.toInt()}',
            color: AuthColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
        Expanded(
          child: _StatChip(
            label: 'Max',
            value: '₹${maxValue.toInt()}',
            subtitle: _formatMonth(maxKey),
            color: AuthColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.paddingMD),
        Expanded(
          child: _StatChip(
            label: 'Min',
            value: '₹${minValue.toInt()}',
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: color.withOpacity(0.3)),
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

