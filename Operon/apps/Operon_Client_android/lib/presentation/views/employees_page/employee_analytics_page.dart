import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmployeeAnalyticsPage extends StatelessWidget {
  const EmployeeAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesCubit, EmployeesState>(
      builder: (context, state) {
        final employees = state.employees;
        
        if (employees.isEmpty) {
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
                    'Analytics will appear once employees are added.',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Statistics Header
            _EmployeesStatsHeader(
              totalEmployees: totalEmployees,
              totalOpeningBalance: totalOpeningBalance,
              totalCurrentBalance: totalCurrentBalance,
              avgBalance: avgBalance,
              balanceDifference: balanceDifference,
              balanceChangePercent: balanceChangePercent,
            ),
            const SizedBox(height: 24),
            // Info Tiles
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    title: 'Total Employees',
                    value: totalEmployees.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    title: 'Average Balance',
                    value: '₹${avgBalance.toStringAsFixed(2)}',
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
                    'Employee analytics charts will be available here.',
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

class _EmployeesStatsHeader extends StatelessWidget {
  const _EmployeesStatsHeader({
    required this.totalEmployees,
    required this.totalOpeningBalance,
    required this.totalCurrentBalance,
    required this.avgBalance,
    required this.balanceDifference,
    required this.balanceChangePercent,
  });

  final int totalEmployees;
  final double totalOpeningBalance;
  final double totalCurrentBalance;
  final double avgBalance;
  final double balanceDifference;
  final double balanceChangePercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_outline,
                label: 'Total',
                value: totalEmployees.toString(),
                color: const Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Opening Balance',
                value: '₹${totalOpeningBalance.toStringAsFixed(2)}',
                color: const Color(0xFF5AD8A4),
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
                label: 'Current Balance',
                value: '₹${totalCurrentBalance.toStringAsFixed(2)}',
                subtitle: balanceDifference != 0
                    ? '${balanceDifference >= 0 ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)} (${balanceChangePercent >= 0 ? '+' : ''}${balanceChangePercent.abs().toStringAsFixed(1)}%)'
                    : null,
                subtitleColor: balanceDifference >= 0 ? const Color(0xFF5AD8A4) : Colors.redAccent,
                color: const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.analytics_outlined,
                label: 'Average Balance',
                value: '₹${avgBalance.toStringAsFixed(2)}',
                color: const Color(0xFF2196F3),
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: subtitleColor ?? Colors.white.withOpacity(0.6),
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

