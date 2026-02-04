import 'dart:ui';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/transaction_analytics/transaction_analytics_cubit.dart';
import 'package:dash_web/presentation/blocs/transaction_analytics/transaction_analytics_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Transaction analytics dashboard: stat cards, monthly line chart, receivable aging donut.
/// Responsive layout (Wrap/GridView for wide screens).
class TransactionAnalyticsView extends StatefulWidget {
  const TransactionAnalyticsView({super.key});

  @override
  State<TransactionAnalyticsView> createState() => _TransactionAnalyticsViewState();
}

class _TransactionAnalyticsViewState extends State<TransactionAnalyticsView> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id ?? '';
    final fy = orgState.financialYear;
    if (orgId.isNotEmpty) {
      context.read<TransactionAnalyticsCubit>().load(
            orgId: orgId,
            financialYear: fy,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    if (!orgState.hasSelection) {
      return const Center(
        child: EmptyState(
          icon: Icons.business_outlined,
          title: 'Select an organization',
          message: 'Choose an organization to view analytics',
        ),
      );
    }

    return BlocBuilder<TransactionAnalyticsCubit, TransactionAnalyticsState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
            ),
          );
        }

        if (state.status == ViewStatus.failure && state.message != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.message!,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                DashButton(
                  label: 'Retry',
                  onPressed: () {
                    final orgId = orgState.organization!.id;
                    final fy = orgState.financialYear;
                    context.read<TransactionAnalyticsCubit>().load(
                          orgId: orgId,
                          financialYear: fy,
                        );
                  },
                ),
              ],
            ),
          );
        }

        final analytics = state.analytics;
        if (analytics == null) {
          return const Center(
            child: EmptyState(
              icon: Icons.analytics_outlined,
              title: 'No analytics for this period',
              message: 'Transaction analytics are not available for the selected organization and financial year.',
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: TransactionAnalyticsContent(analytics: analytics),
        );
      },
    );
  }
}

/// Content only: stat cards + line chart + donut. Used by [AnalyticsDashboardView].
/// When [isDailyView] is true, shows only daily chart (last 30 days); otherwise monthly chart only.
class TransactionAnalyticsContent extends StatefulWidget {
  const TransactionAnalyticsContent({
    super.key,
    required this.analytics,
    this.isDailyView = false,
  });

  final TransactionAnalytics analytics;
  final bool isDailyView;

  @override
  State<TransactionAnalyticsContent> createState() => _TransactionAnalyticsContentState();
}

class _TransactionAnalyticsContentState extends State<TransactionAnalyticsContent> {
  final ValueNotifier<String?> _touchedDateOrMonth = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _touchedDateOrMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = widget.analytics;
    final isDaily = widget.isDailyView;

    if (kDebugMode) {
      debugPrint('[TransactionAnalyticsContent UI] isDailyView=$isDaily '
          'totalIncome=${analytics.totalIncome} totalReceivables=${analytics.totalReceivables} '
          'incomeMonthlyKeys=${analytics.incomeMonthly.keys.length} incomeDailyKeys=${analytics.incomeDaily.keys.length} '
          'receivablesMonthlyKeys=${analytics.receivablesMonthly.keys.length} receivablesDailyKeys=${analytics.receivablesDaily.keys.length}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        _StatCards(analytics: analytics),
        const SizedBox(height: 24),
        if (isDaily)
          (analytics.incomeDaily.isNotEmpty || analytics.receivablesDaily.isNotEmpty)
              ? _DailyTrendsChart(
                  analytics: analytics,
                  touchedDateOrMonth: _touchedDateOrMonth,
                )
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No daily data for the past 30 days.',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                    ),
                  ),
                )
        else
          _MonthlyLineChart(
            analytics: analytics,
            touchedDateOrMonth: _touchedDateOrMonth,
          ),
        const SizedBox(height: 24),
        _ReceivableAgingDonut(analytics: analytics),
      ],
    );
  }
}

class _DataTimestamp extends StatelessWidget {
  const _DataTimestamp({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.update, size: 14, color: AuthColors.textSub),
          const SizedBox(width: 8),
          Text(
            'Last updated: $formatted',
            style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendsChart extends StatelessWidget {
  const _DailyTrendsChart({
    required this.analytics,
    this.touchedDateOrMonth,
  });

  final TransactionAnalytics analytics;
  final ValueNotifier<String?>? touchedDateOrMonth;

  @override
  Widget build(BuildContext context) {
    final incomeDaily = analytics.incomeDaily;
    final receivablesDaily = analytics.receivablesDaily;
    final allDays = <String>{...incomeDaily.keys, ...receivablesDaily.keys}.toList()..sort();
    
    // Show last 30 days or all if less
    final recentDays = allDays.length > 30 ? allDays.sublist(allDays.length - 30) : allDays;
    
    if (recentDays.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = [
      ...incomeDaily.values,
      ...receivablesDaily.values,
    ].fold<double>(0.0, (a, b) => a > b ? a : b);
    const minY = 0.0;
    final range = (maxY - minY).clamp(1.0, double.infinity);

    final incomeSpots = <FlSpot>[];
    final receivablesSpots = <FlSpot>[];
    for (var i = 0; i < recentDays.length; i++) {
      final day = recentDays[i];
      incomeSpots.add(FlSpot(i.toDouble(), (incomeDaily[day] ?? 0.0)));
      receivablesSpots.add(FlSpot(i.toDouble(), (receivablesDaily[day] ?? 0.0)));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AuthColors.info,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Daily Income vs Receivables (Last 30 Days)',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: ValueListenableBuilder<String?>(
              valueListenable: touchedDateOrMonth ?? ValueNotifier<String?>(null),
              builder: (context, touched, _) {
                double? syncLineX;
                if (touched != null) {
                  if (touched.length > 7) {
                    final monthKey = touched.substring(0, 7);
                    for (var i = 0; i < recentDays.length; i++) {
                      if (recentDays[i].startsWith(monthKey)) {
                        syncLineX = i.toDouble();
                        break;
                      }
                    }
                  } else {
                    final idx = recentDays.indexOf(touched);
                    if (idx >= 0) syncLineX = idx.toDouble();
                  }
                }
                final chartData = LineChartData(
                    minX: 0,
                    maxX: (recentDays.length - 1).clamp(0, double.infinity).toDouble(),
                    minY: minY - range * 0.05,
                    maxY: maxY + range * 0.05,
                    extraLinesData: syncLineX != null
                        ? ExtraLinesData(
                            verticalLines: [
                              VerticalLine(
                                x: syncLineX,
                                color: AuthColors.primary.withOpacity(0.5),
                                strokeWidth: 2,
                                dashArray: [4, 4],
                              ),
                            ],
                          )
                        : null,
                    gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AuthColors.textMainWithOpacity(0.08),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        value >= 0 ? '₹${(value / 1000).toStringAsFixed(0)}k' : '',
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: recentDays.length > 10 ? (recentDays.length / 10).ceil().toDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i >= 0 && i < recentDays.length && i % ((recentDays.length / 10).ceil().clamp(1, recentDays.length)) == 0) {
                          final d = recentDays[i];
                          try {
                            final parts = d.split('-');
                            if (parts.length >= 3) {
                              final day = int.tryParse(parts[2]);
                              if (day != null) {
                                return Text(
                                  day.toString(),
                                  style: const TextStyle(color: AuthColors.textSub, fontSize: 9),
                                );
                              }
                            }
                            return Text(d.substring(5), style: const TextStyle(color: AuthColors.textSub, fontSize: 9));
                          } catch (_) {
                            return Text(d, style: const TextStyle(color: AuthColors.textSub, fontSize: 8));
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                    left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AuthColors.success,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AuthColors.success.withOpacity(0.1),
                          AuthColors.success.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: receivablesSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AuthColors.info,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AuthColors.info.withOpacity(0.1),
                          AuthColors.info.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    if (touchedDateOrMonth != null) {
                      if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                        final spot = response.lineBarSpots!.first;
                        final i = spot.x.round();
                        if (i >= 0 && i < recentDays.length) {
                          touchedDateOrMonth!.value = recentDays[i];
                        }
                      } else {
                        touchedDateOrMonth!.value = null;
                      }
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AuthColors.surface,
                    tooltipBorder: BorderSide(color: AuthColors.textMainWithOpacity(0.2)),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final label = s.barIndex == 0 ? 'Income' : 'Receivables';
                      return LineTooltipItem(
                        '$label: ₹${s.y.toStringAsFixed(0)}',
                        const TextStyle(color: AuthColors.textMain, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
              );
                return LineChart(
                  chartData,
                  duration: const Duration(milliseconds: 250),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AuthColors.success),
              SizedBox(width: 8),
              Text('Income', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
              SizedBox(width: 20),
              _LegendDot(color: AuthColors.info),
              SizedBox(width: 8),
              Text(
                'Receivables',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCards extends StatelessWidget {
  const _StatCards({required this.analytics});

  final TransactionAnalytics analytics;

  static String _formatCurrency(double amount) {
    final formatted = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount.abs());
    return amount < 0 ? '($formatted)' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final netReceivables = analytics.netReceivables ??
        (analytics.totalIncome - analytics.totalReceivables).clamp(0.0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        final cards = [
          _StatCard(
            icon: Icons.trending_up,
            label: 'Total Income',
            value: _formatCurrency(analytics.totalIncome),
            color: AuthColors.success,
          ),
          _StatCard(
            icon: Icons.receipt_long,
            label: 'Total Receivables',
            value: _formatCurrency(analytics.totalReceivables),
            color: AuthColors.info,
          ),
          _StatCard(
            icon: Icons.account_balance_wallet,
            label: 'Net Receivables',
            value: _formatCurrency(netReceivables),
            color: AuthColors.secondary,
          ),
        ];
        if (isWide) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards,
        );
      },
    );
  }
}

/// Summary stat card matching Fuel Ledger design: DashCard with icon, label, value.
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
    return DashCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  const _MonthlyLineChart({
    required this.analytics,
    this.touchedDateOrMonth,
  });

  final TransactionAnalytics analytics;
  final ValueNotifier<String?>? touchedDateOrMonth;

  @override
  Widget build(BuildContext context) {
    final incomeMonthly = analytics.incomeMonthly;
    final receivablesMonthly = analytics.receivablesMonthly;
    final allMonths = <String>{...incomeMonthly.keys, ...receivablesMonthly.keys}.toList()..sort();
    if (allMonths.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No monthly data',
            style: TextStyle(color: AuthColors.textSub, fontSize: 14),
          ),
        ),
      );
    }

    final maxY = [
      ...incomeMonthly.values,
      ...receivablesMonthly.values,
    ].fold<double>(0.0, (a, b) => a > b ? a : b);
    const minY = 0.0;
    final range = (maxY - minY).clamp(1.0, double.infinity);

    final incomeSpots = <FlSpot>[];
    final receivablesSpots = <FlSpot>[];
    for (var i = 0; i < allMonths.length; i++) {
      final month = allMonths[i];
      incomeSpots.add(FlSpot(i.toDouble(), (incomeMonthly[month] ?? 0.0)));
      receivablesSpots.add(FlSpot(i.toDouble(), (receivablesMonthly[month] ?? 0.0)));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AuthColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Monthly Income vs Receivables',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: ValueListenableBuilder<String?>(
              valueListenable: touchedDateOrMonth ?? ValueNotifier<String?>(null),
              builder: (context, touched, _) {
                double? syncLineX;
                if (touched != null && touched.length > 7) {
                  final monthKey = touched.substring(0, 7);
                  final idx = allMonths.indexOf(monthKey);
                  if (idx >= 0) syncLineX = idx.toDouble();
                } else if (touched != null && touched.length <= 7) {
                  final idx = allMonths.indexOf(touched);
                  if (idx >= 0) syncLineX = idx.toDouble();
                }
                final chartData = LineChartData(
                    minX: 0,
                    maxX: (allMonths.length - 1).clamp(0, double.infinity).toDouble(),
                    minY: minY - range * 0.05,
                    maxY: maxY + range * 0.05,
                    extraLinesData: syncLineX != null
                        ? ExtraLinesData(
                            verticalLines: [
                              VerticalLine(
                                x: syncLineX,
                                color: AuthColors.primary.withOpacity(0.5),
                                strokeWidth: 2,
                                dashArray: [4, 4],
                              ),
                            ],
                          )
                        : null,
                    gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AuthColors.textMainWithOpacity(0.08),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        value >= 0 ? '₹${(value / 1000).toStringAsFixed(0)}k' : '',
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i >= 0 && i < allMonths.length) {
                          final m = allMonths[i];
                          final parts = m.split('-');
                          if (parts.length >= 2) {
                            final monthNum = int.tryParse(parts[1]);
                            if (monthNum != null) {
                              const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                              return Text(
                                months[monthNum - 1],
                                style: const TextStyle(color: AuthColors.textSub, fontSize: 10),
                              );
                            }
                          }
                          return Text(m, style: const TextStyle(color: AuthColors.textSub, fontSize: 9));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                    left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AuthColors.success,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: AuthColors.success,
                        strokeWidth: 2,
                        strokeColor: AuthColors.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AuthColors.success.withOpacity(0.15),
                          AuthColors.success.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: receivablesSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AuthColors.info,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: AuthColors.info,
                        strokeWidth: 2,
                        strokeColor: AuthColors.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AuthColors.info.withOpacity(0.15),
                          AuthColors.info.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    if (touchedDateOrMonth != null) {
                      if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                        final spot = response.lineBarSpots!.first;
                        final i = spot.x.round();
                        if (i >= 0 && i < allMonths.length) {
                          touchedDateOrMonth!.value = allMonths[i];
                        }
                      } else {
                        touchedDateOrMonth!.value = null;
                      }
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AuthColors.surface,
                    tooltipBorder: BorderSide(color: AuthColors.textMainWithOpacity(0.2)),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      final label = s.barIndex == 0 ? 'Income' : 'Receivables';
                      return LineTooltipItem(
                        '$label: ₹${s.y.toStringAsFixed(0)}',
                        const TextStyle(color: AuthColors.textMain, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
              );
                return LineChart(
                  chartData,
                  duration: const Duration(milliseconds: 250),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AuthColors.success),
              SizedBox(width: 8),
              Text('Income', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
              SizedBox(width: 20),
              _LegendDot(color: AuthColors.info),
              SizedBox(width: 8),
              Text(
                'Receivables',
                style: TextStyle(color: AuthColors.textSub, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ReceivableAgingDonut extends StatelessWidget {
  const _ReceivableAgingDonut({required this.analytics});

  final TransactionAnalytics analytics;

  static const _agingLabels = {
    'current': 'Current',
    'days31to60': '31–60 days',
    'days61to90': '61–90 days',
    'daysOver90': '90+ days',
  };

  static const _agingColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = analytics.receivableAging.nonZeroEntries;
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No receivable aging data',
            style: TextStyle(color: AuthColors.textSub, fontSize: 14),
          ),
        ),
      );
    }

    final total = analytics.receivableAging.total;
    final entryList = entries.entries.toList();
    final sections = entryList.asMap().entries.map((e) {
      final i = e.key;
      final value = e.value.value;
      final pct = total > 0 ? (value / total * 100) : 0.0;
      return PieChartSectionData(
        value: value,
        title: '${pct.toStringAsFixed(0)}%',
        color: _agingColors[i % _agingColors.length],
        radius: 48,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWide = constraints.maxWidth > 600;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AuthColors.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Receivable Aging',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: useWide ? 320 : double.infinity,
                    height: 260,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 56,
                      ),
                    ),
                  ),
                  if (useWide) const SizedBox(width: 24),
                  if (useWide)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entryList.asMap().entries.map((e) {
                          final i = e.key;
                          final bucketKey = e.value.key;
                          final value = e.value.value;
                          final label = _agingLabels[bucketKey] ?? bucketKey;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _agingColors[i % _agingColors.length],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: AuthColors.textSub,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${value.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: _agingColors[i % _agingColors.length],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              if (!useWide) ...[
                const SizedBox(height: 16),
                ...entryList.asMap().entries.map((e) {
                  final i = e.key;
                  final bucketKey = e.value.key;
                  final value = e.value.value;
                  final label = _agingLabels[bucketKey] ?? bucketKey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _agingColors[i % _agingColors.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
                          ),
                        ),
                        Text(
                          '₹${value.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _agingColors[i % _agingColors.length],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}
