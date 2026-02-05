import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmployeeWagesAnalyticsPage extends StatelessWidget {
  const EmployeeWagesAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeWagesCubit, EmployeeWagesState>(
      builder: (context, state) {
        final transactions = state.transactions;
        
        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.paddingXXL),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: AuthColors.textSub.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.paddingLG),
                  Text(
                    'No analytics data available',
                    style: const TextStyle(color: AuthColors.textSub, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.paddingSM),
                  const Text(
                    'Analytics will appear once wages transactions are recorded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final totalAmount = transactions.fold<double>(0.0, (acc, tx) => acc + tx.amount);
        final salaryCount = transactions.where((tx) => tx.category == TransactionCategory.salaryCredit).length;
        final bonusCount = transactions.where((tx) => tx.category == TransactionCategory.bonus).length;
        final avgAmount = transactions.isNotEmpty ? totalAmount / transactions.length : 0.0;

        final monthlyTotals = <String, double>{};
        for (final tx in transactions) {
          final date = tx.createdAt ?? DateTime.now();
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + tx.amount;
        }
        final avgMonthly = monthlyTotals.isNotEmpty
            ? monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length
            : 0.0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _WagesStatsHeader(
                totalAmount: totalAmount,
                salaryCount: salaryCount,
                bonusCount: bonusCount,
                avgAmount: avgAmount,
                avgMonthly: avgMonthly,
              ),
              const SizedBox(height: AppSpacing.paddingXXL),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      title: 'Average Amount',
                      value: '₹${avgAmount.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingXXL),
              Container(
                padding: const EdgeInsets.all(AppSpacing.paddingXXXL * 1.25),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_outlined, size: 48, color: AuthColors.textSub.withValues(alpha: 0.5)),
                    const SizedBox(height: AppSpacing.paddingLG),
                    const Text(
                      'Charts coming soon',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    const Text(
                      'Wages analytics charts will be available here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
          ),
        );
      },
    );
  }
}

class _WagesStatsHeader extends StatelessWidget {
  const _WagesStatsHeader({
    required this.totalAmount,
    required this.salaryCount,
    required this.bonusCount,
    required this.avgAmount,
    required this.avgMonthly,
  });

  final double totalAmount;
  final int salaryCount;
  final int bonusCount;
  final double avgAmount;
  final double avgMonthly;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Amount',
                value: _formatCurrency(totalAmount),
                color: AuthColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.payments,
                label: 'Salary Credits',
                value: salaryCount.toString(),
                color: AuthColors.successVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.card_giftcard,
                label: 'Bonuses',
                value: bonusCount.toString(),
                color: AuthColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                label: 'Average Amount',
                value: _formatCurrency(avgAmount),
                color: AuthColors.accentPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_month,
                label: 'Avg Monthly',
                value: _formatCurrency(avgMonthly),
                color: AuthColors.secondary,
              ),
            ),
            const Spacer(),
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
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
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
            style: const TextStyle(color: AuthColors.textMain, fontSize: 16, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AuthColors.textSub, fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AuthColors.textSub, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            value,
            style: const TextStyle(color: AuthColors.textMain, fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

