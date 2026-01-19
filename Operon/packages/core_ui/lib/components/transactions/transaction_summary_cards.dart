import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Reusable summary cards showing financial metrics
/// Displays: Income, Payments, Purchases, Net Balance
class TransactionSummaryCards extends StatelessWidget {
  const TransactionSummaryCards({
    super.key,
    required this.income,
    required this.payments,
    required this.purchases,
    required this.netBalance,
    this.formatCurrency,
  });

  final double income;
  final double payments;
  final double purchases;
  final double netBalance;
  final String Function(double)? formatCurrency;

  String _formatCurrency(double amount) {
    if (formatCurrency != null) {
      return formatCurrency!(amount);
    }
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.trending_up,
                  label: 'Income',
                  value: _formatCurrency(income),
                  color: AuthColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.trending_down,
                  label: 'Payments',
                  value: _formatCurrency(payments),
                  color: AuthColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.shopping_cart,
                  label: 'Purchases',
                  value: _formatCurrency(purchases),
                  color: AuthColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Net Balance',
                  value: _formatCurrency(netBalance),
                  color: netBalance >= 0 ? AuthColors.success : AuthColors.error,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.trending_up,
                      label: 'Income',
                      value: _formatCurrency(income),
                      color: AuthColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.trending_down,
                      label: 'Payments',
                      value: _formatCurrency(payments),
                      color: AuthColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.shopping_cart,
                      label: 'Purchases',
                      value: _formatCurrency(purchases),
                      color: AuthColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.account_balance_wallet,
                      label: 'Net Balance',
                      value: _formatCurrency(netBalance),
                      color: netBalance >= 0 ? AuthColors.success : AuthColors.error,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
