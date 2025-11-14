import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/dashboard_metadata.dart';
import '../../../../core/repositories/dashboard_metadata_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/financial_year_utils.dart';
import '../../../../core/widgets/gradient_card.dart';

class ClientsMetadataPanel extends StatefulWidget {
  ClientsMetadataPanel({
    super.key,
    DashboardMetadataRepository? repository,
  }) : repository = repository ?? DashboardMetadataRepository();

  final DashboardMetadataRepository repository;

  @override
  State<ClientsMetadataPanel> createState() => _ClientsMetadataPanelState();
}

class _ClientsMetadataPanelState extends State<ClientsMetadataPanel> {
  DashboardClientsSummary? _summary;
  List<DashboardClientsYearlyMetadata> _years = const [];
  DashboardClientsYearlyMetadata? _selectedYear;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.repository.fetchClientsSummary(),
        widget.repository.fetchClientFinancialYears(),
      ]);

      final summary = results[0] as DashboardClientsSummary;
      var years = results[1] as List<DashboardClientsYearlyMetadata>;

      if (years.isEmpty) {
        years = [
          DashboardClientsYearlyMetadata.empty(
            FinancialYearUtils.financialYearId(),
          ),
        ];
      }

      setState(() {
        _summary = summary;
        _years = years;
        _selectedYear = years.first;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Unable to load dashboard metadata';
        _isLoading = false;
      });
    }
  }

  Future<void> _onSelectYear(String? financialYearId) async {
    if (financialYearId == null ||
        financialYearId == _selectedYear?.financialYearId) {
      return;
    }

    final existing = _years.where(
      (year) => year.financialYearId == financialYearId,
    );

    if (existing.isNotEmpty) {
      setState(() {
        _selectedYear = existing.first;
      });
      return;
    }

    try {
      final metadata =
          await widget.repository.fetchClientFinancialYear(financialYearId);
      setState(() {
        _years = [..._years, metadata];
        _selectedYear = metadata;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load $financialYearId insights'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _ClientsMetadataLoading();
    }

    if (_error != null) {
      return _ClientsMetadataError(
        message: _error!,
        onRetry: _loadMetadata,
      );
    }

    final summary = _summary ?? DashboardClientsSummary.empty();
    final selectedYear = _selectedYear;

    if (selectedYear == null) {
      return _ClientsMetadataError(
        message: 'No financial year data found.',
        onRetry: _loadMetadata,
      );
    }

    final monthlySeries = _buildMonthlySeries(selectedYear);
    final topMonths = [...monthlySeries]..sort(
        (a, b) => b.value.compareTo(a.value),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Client Onboarding Insights',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            DropdownButton<String>(
              value: selectedYear.financialYearId,
              dropdownColor: const Color(0xFF1F2937),
              style: const TextStyle(color: Colors.white),
              items: _years
                  .map(
                    (year) => DropdownMenuItem(
                      value: year.financialYearId,
                      child: Text(year.financialYearId),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _onSelectYear,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Tracks onboarding velocity and active clients for each financial year (Apr–Mar).',
          style: TextStyle(
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            final children = [
              Expanded(
                child: _SummaryStatTile(
                  title: 'Active Clients',
                  value: summary.totalActiveClients.toString(),
                  subtitle: 'Across all organizations',
                  icon: Icons.people_alt,
                  gradient: AppTheme.successGradient,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryStatTile(
                  title: 'Onboarded (FY)',
                  value: selectedYear.totalOnboarded.toString(),
                  subtitle: selectedYear.financialYearId,
                  icon: Icons.trending_up,
                  gradient: AppTheme.accentGradient,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryStatTile(
                  title: 'Avg / Month',
                  value: _formatAverage(selectedYear.totalOnboarded),
                  subtitle: 'Financial year average',
                  icon: Icons.calendar_month,
                  gradient: AppTheme.heroGradient,
                ),
              ),
            ];

            if (isCompact) {
              return Column(
                children: [
                  Row(children: children.sublist(0, 2)),
                  const SizedBox(height: 16),
                  Row(children: [children[2]]),
                ],
              );
            }

            return Row(children: children);
          },
        ),
        const SizedBox(height: 24),
        GradientCard(
          gradient: AppTheme.cardGradient,
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              final chart = _ClientsBarChart(series: monthlySeries);
              final breakdown = _MonthlyBreakdown(months: topMonths);

              if (isCompact) {
                return Column(
                  children: [
                    SizedBox(height: 240, child: chart),
                    const SizedBox(height: 24),
                    breakdown,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(height: 280, child: chart),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: breakdown),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<_MonthlyPoint> _buildMonthlySeries(
    DashboardClientsYearlyMetadata metadata,
  ) {
    final parts = metadata.financialYearId.split('-');
    final startYear = int.tryParse(parts.first) ?? DateTime.now().year;
    final start = DateTime(startYear, DateTime.april);
    final months = <_MonthlyPoint>[];

    for (var i = 0; i < 12; i++) {
      final date = DateTime(start.year, start.month + i);
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
      final value = metadata.monthlyOnboarding[key] ?? 0;
      months.add(
        _MonthlyPoint(
          label: _financialMonthLabels[i],
          value: value,
        ),
      );
    }

    return months;
  }

  String _formatAverage(int totalOnboarded) {
    final average = totalOnboarded / 12;
    if (average >= 1) {
      return average.toStringAsFixed(1);
    }
    return average.toStringAsFixed(2);
  }
}

class _ClientsMetadataLoading extends StatelessWidget {
  const _ClientsMetadataLoading();

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: AppTheme.cardGradient,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 220,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsMetadataError extends StatelessWidget {
  const _ClientsMetadataError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: AppTheme.cardGradient,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client metadata unavailable',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStatTile extends StatelessWidget {
  const _SummaryStatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return GradientCardWithGlow(
      gradient: gradient,
      padding: const EdgeInsets.all(20),
      glowColor: gradient.colors.first,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientsBarChart extends StatelessWidget {
  const _ClientsBarChart({required this.series});

  final List<_MonthlyPoint> series;

  @override
  Widget build(BuildContext context) {
    final highest = series.fold<int>(
      0,
      (previousValue, element) => math.max(previousValue, element.value),
    );

    if (highest == 0) {
      return Center(
        child: Text(
          'No onboarding activity captured for this financial year yet.',
          style: TextStyle(color: AppTheme.textSecondaryColor),
          textAlign: TextAlign.center,
        ),
      );
    }

    final maxY = (highest + 2).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) => FlLine(
            strokeWidth: 1,
            color: AppTheme.borderColor.withValues(alpha: 0.4),
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= series.length) {
                  return const SizedBox.shrink();
                }
                final label = series[index].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: series
            .asMap()
            .entries
            .map(
              (entry) => BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value.toDouble(),
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                    gradient: AppTheme.primaryGradient,
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _MonthlyBreakdown extends StatelessWidget {
  const _MonthlyBreakdown({required this.months});

  final List<_MonthlyPoint> months;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly breakdown',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...months.map(
          (month) => Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Text(
                  month.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  month.value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyPoint {
  const _MonthlyPoint({required this.label, required this.value});

  final String label;
  final int value;
}

const List<String> _financialMonthLabels = [
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
  'Jan',
  'Feb',
  'Mar',
];

