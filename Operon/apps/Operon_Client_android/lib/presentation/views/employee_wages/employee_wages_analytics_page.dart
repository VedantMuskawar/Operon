import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_state.dart';
import 'package:core_models/core_models.dart';
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
                    'Analytics will appear once wages transactions are recorded.',
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

        // Calculate statistics
        final totalTransactions = transactions.length;
        final totalAmount = transactions.fold<double>(
          0.0,
          (sum, tx) => sum + tx.amount,
        );
        final salaryCount = transactions.where((tx) => tx.category == TransactionCategory.salaryCredit).length;
        final bonusCount = transactions.where((tx) => tx.category == TransactionCategory.bonus).length;
        final avgAmount = totalTransactions > 0 ? totalAmount / totalTransactions : 0.0;
        
        // Calculate monthly totals
        final monthlyTotals = <String, double>{};
        for (final tx in transactions) {
          final date = tx.createdAt ?? DateTime.now();
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + tx.amount;
        }
        final avgMonthly = monthlyTotals.isNotEmpty
            ? monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Statistics Header
            _WagesStatsHeader(
              totalTransactions: totalTransactions,
              totalAmount: totalAmount,
              salaryCount: salaryCount,
              bonusCount: bonusCount,
              avgAmount: avgAmount,
              avgMonthly: avgMonthly,
            ),
            const SizedBox(height: 24),
            // Info Tiles
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    title: 'Total Transactions',
                    value: totalTransactions.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    title: 'Average Amount',
                    value: '₹${avgAmount.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Placeholder for future charts
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF131324),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Charts coming soon',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wages analytics charts will be available here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WagesStatsHeader extends StatelessWidget {
  const _WagesStatsHeader({
    required this.totalTransactions,
    required this.totalAmount,
    required this.salaryCount,
    required this.bonusCount,
    required this.avgAmount,
    required this.avgMonthly,
  });

  final int totalTransactions;
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
                icon: Icons.receipt_long,
                label: 'Total Transactions',
                value: totalTransactions.toString(),
                color: const Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Amount',
                value: _formatCurrency(totalAmount),
                color: const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.payments,
                label: 'Salary Credits',
                value: salaryCount.toString(),
                color: const Color(0xFF5AD8A4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.card_giftcard,
                label: 'Bonuses',
                value: bonusCount.toString(),
                color: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                label: 'Average Amount',
                value: _formatCurrency(avgAmount),
                color: const Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_month,
                label: 'Avg Monthly',
                value: _formatCurrency(avgMonthly),
                color: const Color(0xFFE91E63),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
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

