import 'dart:ui';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/utils/analytics_trend_utils.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:dash_web/presentation/blocs/analytics_dashboard/analytics_dashboard_cubit.dart';
import 'package:dash_web/presentation/blocs/analytics_dashboard/analytics_dashboard_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/transaction_analytics_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// Period for analytics: monthly (by month, FY) or daily (past 30 days).
enum AnalyticsPeriod { monthly, daily }

/// Unified analytics dashboard: tabs for Transactions, Clients, Employees, Vendors,
/// Deliveries, Productions, and Trip Wages. Loads all types from ANALYTICS collection.
class AnalyticsDashboardView extends StatefulWidget {
  const AnalyticsDashboardView({super.key});

  @override
  State<AnalyticsDashboardView> createState() => _AnalyticsDashboardViewState();
}

class _AnalyticsDashboardViewState extends State<AnalyticsDashboardView> {
  int _selectedTabIndex = 0;
  AnalyticsPeriod _period = AnalyticsPeriod.monthly;

  String _getFinancialYear() {
    final orgState = context.read<OrganizationContextCubit>().state;
    final fy = orgState.financialYear;
    if (fy != null && fy.isNotEmpty) {
      return fy;
    }
    return FinancialYearUtils.getCurrentFinancialYear();
  }

  void _load() {
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id ?? '';
    if (orgId.isNotEmpty) {
      context.read<AnalyticsDashboardCubit>().loadInitial(
            orgId: orgId,
            financialYear: _getFinancialYear(),
          );
    }
  }

  void _onTabSelected(int index) {
    setState(() => _selectedTabIndex = index);
    final orgState = context.read<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id ?? '';
    if (orgId.isNotEmpty) {
      context.read<AnalyticsDashboardCubit>().loadTabData(
            orgId: orgId,
            financialYear: _getFinancialYear(),
            tabIndex: index,
          );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
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

    return BlocBuilder<AnalyticsDashboardCubit, AnalyticsDashboardState>(
      builder: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null && !state.hasAny) {
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
                  onPressed: _load,
                ),
              ],
            ),
          );
        }

        final showNoAnalytics = state.status == ViewStatus.success &&
            state.loadingTabs.isEmpty &&
            !state.hasAny;
        if (showNoAnalytics) {
          return const Center(
            child: EmptyState(
              icon: Icons.analytics_outlined,
              title: 'No analytics for this period',
              message: 'Analytics documents are not available for the selected organization and financial year.',
            ),
          );
        }

        return _AnalyticsTabContent(
                period: _period,
                onPeriodChanged: (p) => setState(() => _period = p),
                selectedTabIndex: _selectedTabIndex,
                onTabChanged: _onTabSelected,
              );
      },
    );
  }
}

class _AnalyticsTabContent extends StatelessWidget {
  const _AnalyticsTabContent({
    required this.period,
    required this.onPeriodChanged,
    required this.selectedTabIndex,
    required this.onTabChanged,
  });

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;

  static const _tabs = [
    (icon: Icons.receipt_long, label: 'Transactions'),
    (icon: Icons.people_outline, label: 'Clients'),
    (icon: Icons.badge_outlined, label: 'Employees'),
    (icon: Icons.storefront_outlined, label: 'Vendors'),
    (icon: Icons.local_shipping_outlined, label: 'Deliveries'),
    (icon: Icons.factory_outlined, label: 'Productions'),
    (icon: Icons.paid_outlined, label: 'Trip Wages'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AnalyticsDashboardCubit>().state;
    final isDaily = period == AnalyticsPeriod.daily;
    final showDailyEmptyState = isDaily && selectedTabIndex != 0;

    if (kDebugMode) {
      debugPrint('[AnalyticsDashboard UI] period=${period.name} selectedTabIndex=$selectedTabIndex '
          'hasTransactions=${state.transactions != null} hasClients=${state.clients != null} '
          'hasEmployees=${state.employees != null} hasVendors=${state.vendors != null} '
          'hasDeliveries=${state.deliveries != null} hasProductions=${state.productions != null} '
          'hasTripWages=${state.tripWages != null} showDailyEmptyState=$showDailyEmptyState');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Center(
            child: _AnalyticsSingleRowNavBar(
              period: period,
              onPeriodChanged: onPeriodChanged,
              selectedTabIndex: selectedTabIndex,
              onTabChanged: onTabChanged,
              tabs: _tabs,
            ),
          ),
        ),
        Expanded(
          child: showDailyEmptyState
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _EmptySection(
                    message: 'Daily breakdown is available for Transactions only. Switch to Monthly to see this category.',
                    icon: Icons.today,
                  ),
                )
              : IndexedStack(
                  index: selectedTabIndex,
                  children: [
                    _TabContent(
                      isLoading: state.isLoadingTab(0),
                      hasData: state.transactions != null,
                      emptyMessage: 'No transaction analytics for this period.',
                      emptyIcon: Icons.receipt_long,
                      child: state.transactions != null
                          ? TransactionAnalyticsContent(
                              analytics: state.transactions!,
                              isDailyView: period == AnalyticsPeriod.daily,
                            )
                          : null,
                    ),
              _TabContent(
                isLoading: state.isLoadingTab(1),
                hasData: state.clients != null,
                emptyMessage: 'No client analytics for this period.',
                emptyIcon: Icons.people_outline,
                child: state.clients != null ? _ClientsSection(analytics: state.clients!) : null,
              ),
              _TabContent(
                isLoading: state.isLoadingTab(2),
                hasData: state.employees != null,
                emptyMessage: 'No employee analytics for this period.',
                emptyIcon: Icons.badge_outlined,
                child: state.employees != null ? _EmployeesSection(analytics: state.employees!) : null,
              ),
              _TabContent(
                isLoading: state.isLoadingTab(3),
                hasData: state.vendors != null,
                emptyMessage: 'No vendor analytics for this period.',
                emptyIcon: Icons.storefront_outlined,
                child: state.vendors != null ? _VendorsSection(analytics: state.vendors!) : null,
              ),
              _TabContent(
                isLoading: state.isLoadingTab(4),
                hasData: state.deliveries != null,
                emptyMessage: 'No delivery analytics for this period.',
                emptyIcon: Icons.local_shipping_outlined,
                child: state.deliveries != null ? _DeliveriesSection(analytics: state.deliveries!) : null,
              ),
              _TabContent(
                isLoading: state.isLoadingTab(5),
                hasData: state.productions != null,
                emptyMessage: 'No production analytics for this period.',
                emptyIcon: Icons.factory_outlined,
                child: state.productions != null
                    ? _ProductionsSection(
                        analytics: state.productions!,
                        deliveries: state.deliveries,
                      )
                    : null,
              ),
              _TabContent(
                isLoading: state.isLoadingTab(6),
                hasData: state.tripWages != null,
                emptyMessage: 'No trip wages analytics for this period.',
                emptyIcon: Icons.paid_outlined,
                child: state.tripWages != null ? _TripWagesSection(analytics: state.tripWages!) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.isLoading,
    required this.hasData,
    required this.emptyMessage,
    required this.emptyIcon,
    this.child,
  });

  final bool isLoading;
  final bool hasData;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _AnalyticsTabShimmer(),
      );
    }
    if (hasData && child != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: child!,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _EmptySection(message: emptyMessage, icon: emptyIcon),
    );
  }
}

class _AnalyticsTabShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkeletonLoader(width: 140, height: 24, borderRadius: BorderRadius.circular(6)),
            const SizedBox(width: 16),
            SkeletonLoader(width: 100, height: 20, borderRadius: BorderRadius.circular(4)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: List.generate(
            4,
            (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SkeletonLoader(
                  height: 120,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SkeletonLoader(
          width: double.infinity,
          height: 280,
          borderRadius: BorderRadius.circular(16),
        ),
        const SizedBox(height: 24),
        SkeletonLoader(
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.circular(16),
        ),
      ],
    );
  }
}

/// Single-row nav bar: Monthly | Daily | Transactions | Clients | ... (production-style dark pill bar, scrollable).
class _AnalyticsSingleRowNavBar extends StatelessWidget {
  const _AnalyticsSingleRowNavBar({
    required this.period,
    required this.onPeriodChanged,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.tabs,
  });

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;
  final List<({IconData icon, String label})> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AuthColors.primary.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnalyticsNavPill(
              icon: Icons.calendar_month,
              label: 'Monthly',
              isSelected: period == AnalyticsPeriod.monthly,
              onTap: () => onPeriodChanged(AnalyticsPeriod.monthly),
            ),
            const SizedBox(width: 4),
            _AnalyticsNavPill(
              icon: Icons.today,
              label: 'Daily',
              isSelected: period == AnalyticsPeriod.daily,
              onTap: () => onPeriodChanged(AnalyticsPeriod.daily),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            ...List.generate(tabs.length, (int index) {
              final tab = tabs[index];
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _AnalyticsNavPill(
                  icon: tab.icon,
                  label: tab.label,
                  isSelected: selectedTabIndex == index,
                  onTap: () => onTabChanged(index),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsNavPill extends StatelessWidget {
  const _AnalyticsNavPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AuthColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.analytics_outlined,
              size: 56,
              color: AuthColors.textMainWithOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Analytics are rebuilt automatically every 24 hours.',
              style: TextStyle(
                color: AuthColors.textSub.withOpacity(0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Clients section: stat cards + line chart (onboarding monthly) + summary stats ---
class _ClientsSection extends StatelessWidget {
  const _ClientsSection({required this.analytics});

  final ClientsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        _ClientsStatCards(analytics: analytics),
        const SizedBox(height: 24),
        _ClientsOnboardingChart(analytics: analytics),
        if (analytics.onboardingMonthly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ClientsSummaryStats(analytics: analytics),
        ],
      ],
    );
  }
}

class _ClientsStatCards extends StatelessWidget {
  const _ClientsStatCards({required this.analytics});

  final ClientsAnalytics analytics;

  static String _fmt(int? n) => n?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final data = analytics.onboardingMonthly;
    final sorted = data.keys.toList()..sort();
    final latest = sorted.isNotEmpty ? (data[sorted.last] ?? 0.0) : 0.0;
    final previous = sorted.length >= 2 ? (data[sorted[sorted.length - 2]] ?? 0.0) : 0.0;
    final onboardingTrend = sorted.length >= 2 ? calculateTrend(latest, previous) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        const maxCrossAxisExtent = 200.0;
        final count = (constraints.maxWidth / maxCrossAxisExtent).ceil().clamp(1, 4);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _AnalyticsStatCard(
              title: 'Active clients',
              value: analytics.totalActiveClients.toString(),
              icon: Icons.people,
              color: AuthColors.success,
              trend: onboardingTrend,
            ),
            _AnalyticsStatCard(
              title: 'Total orders',
              value: _fmt(analytics.totalOrders),
              icon: Icons.shopping_cart,
              color: AuthColors.info,
            ),
            _AnalyticsStatCard(
              title: 'Corporate',
              value: _fmt(analytics.corporateCount),
              icon: Icons.business,
              color: AuthColors.primary,
            ),
            _AnalyticsStatCard(
              title: 'Individual',
              value: _fmt(analytics.individualCount),
              icon: Icons.person,
              color: AuthColors.secondary,
            ),
          ],
        );
      },
    );
  }
}

class _ClientsOnboardingChart extends StatelessWidget {
  const _ClientsOnboardingChart({required this.analytics});

  final ClientsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics.onboardingMonthly;
    final months = data.keys.toList()..sort();
    if (months.isEmpty) {
      return _chartCard(
        title: 'Client onboarding (monthly)',
        child: const Center(child: Text('No monthly data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final maxY = data.values.fold<double>(0.0, (a, b) => a > b ? a : b);
    final spots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), data[e.value] ?? 0.0)).toList();
    return _chartCard(
      title: 'Client onboarding (monthly)',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).clamp(0, double.infinity).toDouble(),
            minY: 0,
            maxY: maxY * 1.1 + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AuthColors.textMainWithOpacity(0.08),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: _monthTitles(months),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AuthColors.success,
                barWidth: 3,
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
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

class _ClientsSummaryStats extends StatelessWidget {
  const _ClientsSummaryStats({required this.analytics});

  final ClientsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics.onboardingMonthly;
    if (data.isEmpty) return const SizedBox.shrink();
    final sorted = data.keys.toList()..sort();
    final latest = sorted.isNotEmpty ? data[sorted.last] ?? 0.0 : 0.0;
    final previous = sorted.length >= 2 ? data[sorted[sorted.length - 2]] ?? 0.0 : 0.0;
    final growth = previous != 0 ? ((latest - previous) / previous * 100) : 0.0;
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final avg = data.length > 0 ? total / data.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.success.withOpacity(0.08),
            AuthColors.success.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.success.withOpacity(0.2)),
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
              Icon(Icons.insights, color: AuthColors.success, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Onboarding Summary',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 32,
            runSpacing: 20,
            children: [
              _SummaryItem(label: 'Latest month', value: latest.toInt().toString()),
              _SummaryItem(label: 'Total (FY)', value: total.toInt().toString()),
              _SummaryItem(label: 'Monthly avg', value: avg.toStringAsFixed(1)),
              _SummaryItem(
                label: 'Growth',
                value: '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                valueColor: growth >= 0 ? AuthColors.success : AuthColors.error,
                icon: growth >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: valueColor ?? AuthColors.textSub),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AuthColors.textMain,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// --- Employees section: stat cards + line chart (wages credit monthly) + summary ---
class _EmployeesSection extends StatelessWidget {
  const _EmployeesSection({required this.analytics});

  final EmployeesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final wages = analytics.wagesCreditMonthly;
            final sorted = wages.keys.toList()..sort();
            final latest = sorted.isNotEmpty ? (wages[sorted.last] ?? 0.0) : 0.0;
            final previous = sorted.length >= 2 ? (wages[sorted[sorted.length - 2]] ?? 0.0) : 0.0;
            final trend = sorted.length >= 2 ? calculateTrend(latest, previous) : null;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: (constraints.maxWidth / 240).ceil().clamp(1, 3),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _AnalyticsStatCard(
                  title: 'Active employees',
                  value: analytics.totalActiveEmployees.toString(),
                  icon: Icons.badge,
                  color: AuthColors.secondary,
                  trend: trend,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _EmployeesWagesChart(analytics: analytics),
        if (analytics.wagesCreditMonthly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _EmployeesWagesSummary(analytics: analytics),
        ],
      ],
    );
  }
}

class _EmployeesWagesChart extends StatelessWidget {
  const _EmployeesWagesChart({required this.analytics});

  final EmployeesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics.wagesCreditMonthly;
    final months = data.keys.toList()..sort();
    if (months.isEmpty) {
      return _chartCard(
        title: 'Wages credited (monthly)',
        child: const Center(child: Text('No monthly data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final maxY = data.values.fold<double>(0.0, (a, b) => a > b ? a : b);
    final spots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), data[e.value] ?? 0.0)).toList();
    return _chartCard(
      title: 'Wages credited (monthly)',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).clamp(0, double.infinity).toDouble(),
            minY: 0,
            maxY: maxY * 1.1 + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AuthColors.textMainWithOpacity(0.08),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: _monthTitles(months),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AuthColors.secondary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: AuthColors.secondary,
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
                      AuthColors.secondary.withOpacity(0.15),
                      AuthColors.secondary.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

class _EmployeesWagesSummary extends StatelessWidget {
  const _EmployeesWagesSummary({required this.analytics});

  final EmployeesAnalytics analytics;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final data = analytics.wagesCreditMonthly;
    if (data.isEmpty) return const SizedBox.shrink();
    final sorted = data.keys.toList()..sort();
    final latest = sorted.isNotEmpty ? data[sorted.last] ?? 0.0 : 0.0;
    final previous = sorted.length >= 2 ? data[sorted[sorted.length - 2]] ?? 0.0 : 0.0;
    final growth = previous != 0 ? ((latest - previous) / previous * 100) : 0.0;
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final avg = data.length > 0 ? total / data.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.secondary.withOpacity(0.08),
            AuthColors.secondary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.secondary.withOpacity(0.2)),
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
              Icon(Icons.insights, color: AuthColors.secondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Wages Summary',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 32,
            runSpacing: 20,
            children: [
              _SummaryItem(label: 'Latest month', value: _fmt(latest)),
              _SummaryItem(label: 'Total (FY)', value: _fmt(total)),
              _SummaryItem(label: 'Monthly avg', value: _fmt(avg)),
              _SummaryItem(
                label: 'Growth',
                value: '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
                valueColor: growth >= 0 ? AuthColors.success : AuthColors.error,
                icon: growth >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Vendors section: stat cards (total payable + per type) + chart (purchases by vendor type) ---
class _VendorsSection extends StatelessWidget {
  const _VendorsSection({required this.analytics});

  final VendorsAnalytics analytics;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final byType = analytics.purchasesByVendorType;
    final typeTotals = <String, double>{};
    for (final entry in byType.entries) {
      typeTotals[entry.key] = entry.value.values.fold<double>(0.0, (a, b) => a + b);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final monthlyTotal = <String, double>{};
            for (final typeData in byType.values) {
              for (final e in typeData.entries) {
                monthlyTotal[e.key] = (monthlyTotal[e.key] ?? 0) + e.value;
              }
            }
            final sortedMonths = monthlyTotal.keys.toList()..sort();
            final latestPurchases = sortedMonths.isNotEmpty ? (monthlyTotal[sortedMonths.last] ?? 0.0) : 0.0;
            final previousPurchases = sortedMonths.length >= 2 ? (monthlyTotal[sortedMonths[sortedMonths.length - 2]] ?? 0.0) : 0.0;
            final payableTrend = sortedMonths.length >= 2 ? calculateTrend(latestPurchases, previousPurchases) : null;

            final cards = <Widget>[
              _AnalyticsStatCard(
                title: 'Total payable',
                value: _fmt(analytics.totalPayable),
                icon: Icons.payments,
                color: AuthColors.warning,
                trend: payableTrend,
              ),
            ];
            const typeColors = [AuthColors.success, AuthColors.info, AuthColors.primary];
            for (var i = 0; i < typeTotals.entries.take(3).length; i++) {
              final entry = typeTotals.entries.elementAt(i);
              cards.add(_AnalyticsStatCard(
                title: entry.key,
                value: _fmt(entry.value),
                icon: Icons.storefront,
                color: typeColors[i % typeColors.length],
              ));
            }
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: (constraints.maxWidth / 240).ceil().clamp(1, 4),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: cards,
            );
          },
        ),
        const SizedBox(height: 24),
        _VendorsPurchasesChart(analytics: analytics),
        if (typeTotals.isNotEmpty) ...[
          const SizedBox(height: 24),
          _VendorsTypeBreakdown(typeTotals: typeTotals),
        ],
      ],
    );
  }
}

class _VendorsPurchasesChart extends StatelessWidget {
  const _VendorsPurchasesChart({required this.analytics});

  final VendorsAnalytics analytics;

  static const _colors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
  ];

  @override
  Widget build(BuildContext context) {
    final byType = analytics.purchasesByVendorType;
    if (byType.isEmpty) {
      return _chartCard(
        title: 'Purchases by vendor type (monthly)',
        child: const Center(child: Text('No data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final allMonths = <String>{};
    for (final m in byType.values) {
      allMonths.addAll(m.keys);
    }
    final months = allMonths.toList()..sort();
    final types = byType.keys.toList();
    double maxVal = 0;
    for (final m in byType.values) {
      for (final v in m.values) {
        if (v > maxVal) maxVal = v;
      }
    }
    final lineBars = types.asMap().entries.map((typeEntry) {
      final i = typeEntry.key;
      final type = typeEntry.value;
      final monthly = byType[type]!;
      final spots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), monthly[e.value] ?? 0.0)).toList();
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: _colors[i % _colors.length],
        barWidth: 2,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return _chartCard(
      title: 'Purchases by vendor type (monthly)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (months.length - 1).clamp(0, double.infinity).toDouble(),
                minY: 0,
                maxY: maxVal * 1.1 + 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AuthColors.textMainWithOpacity(0.08),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: _monthTitles(months),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                    left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                  ),
                ),
                lineBarsData: lineBars.asMap().entries.map((entry) {
                  final i = entry.key;
                  final bar = entry.value;
                  final color = _colors[i % _colors.length];
                  return LineChartBarData(
                    spots: bar.spots,
                    isCurved: bar.isCurved,
                    curveSmoothness: bar.curveSmoothness,
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: AuthColors.surface,
                      ),
                    ),
                    belowBarData: bar.belowBarData,
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: types.asMap().entries.map((e) {
              final i = e.key;
              final type = e.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(type, style: const TextStyle(color: AuthColors.textSub, fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// --- Shared helpers ---
Widget _chartCard({required String title, required Widget child}) {
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
            Text(
              title,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

FlTitlesData _monthTitles(List<String> months) {
  return FlTitlesData(
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) => Text(
          value >= 0 ? value.toStringAsFixed(0) : '',
          style: const TextStyle(color: AuthColors.textSub, fontSize: 10),
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
          if (i >= 0 && i < months.length) {
            final m = months[i];
            final parts = m.split('-');
            if (parts.length >= 2) {
              final monthNum = int.tryParse(parts[1]);
              if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
                const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return Text(names[monthNum - 1], style: const TextStyle(color: AuthColors.textSub, fontSize: 10));
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
  );
}

class _VendorsTypeBreakdown extends StatelessWidget {
  const _VendorsTypeBreakdown({required this.typeTotals});

  final Map<String, double> typeTotals;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);
  static const _typeColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = typeTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = typeTotals.values.fold<double>(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.warning.withOpacity(0.08),
            AuthColors.warning.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.warning.withOpacity(0.2)),
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
              Icon(Icons.pie_chart_outline, color: AuthColors.warning, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Purchases by Vendor Type (Total)',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final pct = total > 0 ? (e.value / total * 100) : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AuthColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _typeColors[i % _typeColors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pct.toStringAsFixed(1)}% of total',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmt(e.value),
                    style: TextStyle(
                      color: _typeColors[i % _typeColors.length],
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuthColors.primary.withOpacity(0.1),
            AuthColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuthColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AuthColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.update, size: 12, color: AuthColors.primary),
          ),
          const SizedBox(width: 10),
          Text(
            'Last updated: $formatted',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary stat card matching TransactionSummaryCards style used on other pages.
class _AnalyticsStatCard extends StatelessWidget {
  const _AnalyticsStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final TrendResult? trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend!.badgeText,
              style: TextStyle(
                color: trend!.direction == TrendDirection.up
                    ? AuthColors.success
                    : trend!.direction == TrendDirection.down
                        ? AuthColors.error
                        : AuthColors.textSub,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Deliveries section ---
class _DeliveriesSection extends StatelessWidget {
  const _DeliveriesSection({required this.analytics});

  final DeliveriesAnalytics analytics;

  static String _fmt(int n) => NumberFormat.decimalPattern().format(n);

  @override
  Widget build(BuildContext context) {
    final regionCount = analytics.quantityByRegion.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const maxCrossAxisExtent = 200.0;
            final count = (constraints.maxWidth / maxCrossAxisExtent).ceil().clamp(1, 4);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: count,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _AnalyticsStatCard(
                  title: 'Quantity delivered (FY)',
                  value: _fmt(analytics.totalQuantityDeliveredYearly),
                  icon: Icons.local_shipping,
                  color: AuthColors.primary,
                ),
                _AnalyticsStatCard(
                  title: 'Regions / cities',
                  value: regionCount.toString(),
                  icon: Icons.location_on_outlined,
                  color: AuthColors.info,
                ),
                _AnalyticsStatCard(
                  title: 'Top clients (FY)',
                  value: analytics.top20ClientsByOrderValueYearly.length.toString(),
                  icon: Icons.star_outline,
                  color: AuthColors.success,
                ),
              ],
            );
          },
        ),
        if (analytics.totalQuantityDeliveredMonthly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _DeliveriesQuantityChart(analytics: analytics),
        ],
        if (analytics.quantityByRegion.isNotEmpty) ...[
          const SizedBox(height: 24),
          _RegionBreakdownCard(quantityByRegion: analytics.quantityByRegion),
        ],
        if (analytics.top20ClientsByOrderValueYearly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _TopClientsTable(entries: analytics.top20ClientsByOrderValueYearly),
        ],
      ],
    );
  }
}

class _DeliveriesQuantityChart extends StatelessWidget {
  const _DeliveriesQuantityChart({required this.analytics});

  final DeliveriesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics.totalQuantityDeliveredMonthly;
    final months = data.keys.toList()..sort();
    if (months.isEmpty) {
      return _chartCard(
        title: 'Quantity delivered (monthly)',
        child: const Center(child: Text('No monthly data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final maxY = data.values.fold<double>(0.0, (a, b) => a > b ? a : b);
    final spots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (data[e.value] ?? 0).toDouble())).toList();
    return _chartCard(
      title: 'Quantity delivered (monthly)',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).clamp(0, double.infinity).toDouble(),
            minY: 0,
            maxY: maxY * 1.1 + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AuthColors.textMainWithOpacity(0.08), strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: _monthTitles(months),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AuthColors.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: AuthColors.primary,
                    strokeWidth: 2,
                    strokeColor: AuthColors.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AuthColors.primary.withOpacity(0.15), AuthColors.primary.withOpacity(0.0)],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

class _RegionBreakdownCard extends StatelessWidget {
  const _RegionBreakdownCard({required this.quantityByRegion});

  final Map<String, Map<String, double>> quantityByRegion;

  static String _fmt(num n) => NumberFormat.decimalPattern().format(n);

  @override
  Widget build(BuildContext context) {
    final regionTotals = quantityByRegion.map((region, monthly) {
      final total = monthly.values.fold<double>(0.0, (a, b) => a + b);
      return MapEntry(region, total);
    });
    final sorted = regionTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _chartCard(
      title: 'Quantity by region / city',
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: sorted.take(12).map((e) => Chip(
          avatar: CircleAvatar(
            backgroundColor: AuthColors.primary.withOpacity(0.15),
            child: Icon(Icons.place, size: 16, color: AuthColors.primary),
          ),
          label: Text('${e.key}: ${_fmt(e.value)}'),
        )).toList(),
      ),
    );
  }
}

class _TopClientsTable extends StatelessWidget {
  const _TopClientsTable({required this.entries});

  final List<TopClientEntry> entries;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    return _chartCard(
      title: 'Top 20 clients by order value (FY)',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AuthColors.textMainWithOpacity(0.06)),
          columns: const [
            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            DataColumn(label: Text('Total amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), numeric: true),
            DataColumn(label: Text('Orders', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), numeric: true),
          ],
          rows: entries.asMap().entries.map((e) => DataRow(
            cells: [
              DataCell(Text('${e.key + 1}')),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(e.value.clientName, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Text(_fmt(e.value.totalAmount))),
              DataCell(Text('${e.value.orderCount}')),
            ],
          )).toList(),
        ),
      ),
    );
  }
}

// --- Productions section ---
class _ProductionsSection extends StatelessWidget {
  const _ProductionsSection({
    required this.analytics,
    this.deliveries,
  });

  final ProductionsAnalytics analytics;
  final DeliveriesAnalytics? deliveries;

  static String _fmt(int n) => NumberFormat.decimalPattern().format(n);

  @override
  Widget build(BuildContext context) {
    final hasRawMaterials = analytics.totalRawMaterialsMonthly.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const maxCrossAxisExtent = 200.0;
            final count = (constraints.maxWidth / maxCrossAxisExtent).ceil().clamp(1, 4);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: count,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _AnalyticsStatCard(
                  title: 'Total production (FY)',
                  value: _fmt(analytics.totalProductionYearly),
                  icon: Icons.factory,
                  color: AuthColors.info,
                ),
                if (hasRawMaterials)
                  _AnalyticsStatCard(
                    title: 'Raw materials (FY)',
                    value: _fmt(analytics.totalRawMaterialsMonthly.values.fold<double>(0.0, (a, b) => a + b).toInt()),
                    icon: Icons.inventory_2_outlined,
                    color: AuthColors.warning,
                  ),
              ],
            );
          },
        ),
        if (analytics.totalProductionMonthly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ProductionsChart(analytics: analytics, deliveries: deliveries),
        ],
      ],
    );
  }
}

class _ProductionsChart extends StatelessWidget {
  const _ProductionsChart({
    required this.analytics,
    this.deliveries,
  });

  final ProductionsAnalytics analytics;
  final DeliveriesAnalytics? deliveries;

  @override
  Widget build(BuildContext context) {
    final data = analytics.totalProductionMonthly;
    final months = data.keys.toList()..sort();
    if (months.isEmpty) {
      return _chartCard(
        title: 'Production (monthly)',
        child: const Center(child: Text('No monthly data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final deliveryData = deliveries?.totalQuantityDeliveredMonthly ?? <String, double>{};
    final allMonths = <String>{...months, ...deliveryData.keys};
    final sortedMonths = allMonths.toList()..sort();
    final maxY = [
      ...data.values,
      ...deliveryData.values,
    ].fold<double>(0.0, (a, b) => a > b ? a : b);

    final productionSpots = sortedMonths.asMap().entries.map((e) => FlSpot(e.key.toDouble(), data[e.value] ?? 0.0)).toList();
    final deliverySpots = sortedMonths.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (deliveryData[e.value] ?? 0).toDouble())).toList();

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: productionSpots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: AuthColors.info,
        barWidth: 3,
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
            colors: [AuthColors.info.withOpacity(0.15), AuthColors.info.withOpacity(0.0)],
          ),
        ),
      ),
    ];
    if (deliveryData.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: deliverySpots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: AuthColors.primary,
          barWidth: 2.5,
          dashArray: [8, 4],
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 3,
              color: AuthColors.primary,
              strokeWidth: 2,
              strokeColor: AuthColors.surface,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return _chartCard(
      title: 'Production (monthly)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sortedMonths.length - 1).clamp(0, double.infinity).toDouble(),
                minY: 0,
                maxY: maxY * 1.1 + 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AuthColors.textMainWithOpacity(0.08), strokeWidth: 1, dashArray: [4, 4]),
                ),
                titlesData: _monthTitles(sortedMonths),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                    left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                  ),
                ),
                lineBarsData: lineBars,
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
          if (deliveryData.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: AuthColors.info, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Production', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
                const SizedBox(width: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 4, height: 2, color: AuthColors.primary),
                    const SizedBox(width: 2),
                    Container(width: 4, height: 2, color: AuthColors.primary),
                    const SizedBox(width: 2),
                    Container(width: 4, height: 2, color: AuthColors.primary),
                  ],
                ),
                const SizedBox(width: 6),
                const Text('Delivery', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --- Trip Wages section ---
class _TripWagesSection extends StatelessWidget {
  const _TripWagesSection({required this.analytics});

  final TripWagesAnalytics analytics;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final totalYearly = analytics.totalTripWagesMonthly.values.fold<double>(0.0, (a, b) => a + b);
    final quantityBuckets = analytics.wagesPaidByFixedQuantityYearly.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analytics.generatedAt != null) ...[
          _DataTimestamp(timestamp: analytics.generatedAt!),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const maxCrossAxisExtent = 200.0;
            final count = (constraints.maxWidth / maxCrossAxisExtent).ceil().clamp(1, 4);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: count,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _AnalyticsStatCard(
                  title: 'Total trip wages (FY)',
                  value: _fmt(totalYearly),
                  icon: Icons.paid_outlined,
                  color: AuthColors.success,
                ),
                _AnalyticsStatCard(
                  title: 'Quantity tiers',
                  value: quantityBuckets.toString(),
                  icon: Icons.stacked_bar_chart,
                  color: AuthColors.secondary,
                ),
              ],
            );
          },
        ),
        if (analytics.totalTripWagesMonthly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _TripWagesChart(analytics: analytics),
        ],
        if (analytics.wagesPaidByFixedQuantityYearly.isNotEmpty) ...[
          const SizedBox(height: 24),
          _TripWagesByQuantityCard(analytics: analytics),
        ],
      ],
    );
  }
}

class _TripWagesChart extends StatelessWidget {
  const _TripWagesChart({required this.analytics});

  final TripWagesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics.totalTripWagesMonthly;
    final months = data.keys.toList()..sort();
    if (months.isEmpty) {
      return _chartCard(
        title: 'Trip wages (monthly)',
        child: const Center(child: Text('No monthly data', style: TextStyle(color: AuthColors.textSub, fontSize: 14))),
      );
    }
    final maxY = data.values.fold<double>(0.0, (a, b) => a > b ? a : b);
    final spots = months.asMap().entries.map((e) => FlSpot(e.key.toDouble(), data[e.value] ?? 0.0)).toList();
    return _chartCard(
      title: 'Trip wages (monthly)',
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).clamp(0, double.infinity).toDouble(),
            minY: 0,
            maxY: maxY * 1.1 + 1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AuthColors.textMainWithOpacity(0.08), strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: _monthTitles(months),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
                left: BorderSide(color: AuthColors.textMainWithOpacity(0.1), width: 1),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AuthColors.success,
                barWidth: 3,
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
                    colors: [AuthColors.success.withOpacity(0.15), AuthColors.success.withOpacity(0.0)],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

class _TripWagesByQuantityCard extends StatelessWidget {
  const _TripWagesByQuantityCard({required this.analytics});

  final TripWagesAnalytics analytics;

  static String _fmt(double n) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final sorted = analytics.wagesPaidByFixedQuantityYearly.entries.toList()
      ..sort((a, b) => ((int.tryParse(a.key) ?? 0) - (int.tryParse(b.key) ?? 0)));
    return _chartCard(
      title: 'Wages by quantity per trip',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: sorted.take(15).map((e) => Chip(
          avatar: CircleAvatar(
            backgroundColor: AuthColors.success.withOpacity(0.15),
            child: Icon(Icons.numbers, size: 16, color: AuthColors.success),
          ),
          label: Text('Qty ${e.key}: ${_fmt(e.value)}'),
        )).toList(),
      ),
    );
  }
}
