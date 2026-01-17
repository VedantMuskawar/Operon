import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VendorAnalyticsPage extends StatelessWidget {
  const VendorAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VendorsCubit, VendorsState>(
      builder: (context, state) {
        final vendors = state.vendors;
        
        if (vendors.isEmpty) {
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
                    'Analytics will appear once vendors are added.',
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
        final totalVendors = vendors.length;
        final activeVendors = vendors.where((v) => v.status == VendorStatus.active).length;
        final totalPayable = vendors.fold<double>(
          0.0,
          (sum, v) => sum + (v.currentBalance > 0 ? v.currentBalance : 0),
        );
        final totalReceivable = vendors.fold<double>(
          0.0,
          (sum, v) => sum + (v.currentBalance < 0 ? v.currentBalance.abs() : 0),
        );
        final totalCurrentBalance = vendors.fold<double>(
          0.0,
          (sum, v) => sum + v.currentBalance,
        );
        final avgBalance = totalVendors > 0
            ? totalCurrentBalance / totalVendors
            : 0.0;
        final totalOpeningBalance = vendors.fold<double>(
          0.0,
          (sum, v) => sum + v.openingBalance,
        );
        final balanceDifference = totalCurrentBalance - totalOpeningBalance;
        final balanceChangePercent = totalOpeningBalance != 0
            ? (balanceDifference / totalOpeningBalance * 100)
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Statistics Header
            _VendorsStatsHeader(
              totalVendors: totalVendors,
              activeVendors: activeVendors,
              totalPayable: totalPayable,
              totalReceivable: totalReceivable,
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
                    title: 'Total Vendors',
                    value: totalVendors.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    title: 'Active Vendors',
                    value: activeVendors.toString(),
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
                    'Vendor analytics charts will be available here.',
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

class _VendorsStatsHeader extends StatelessWidget {
  const _VendorsStatsHeader({
    required this.totalVendors,
    required this.activeVendors,
    required this.totalPayable,
    required this.totalReceivable,
    required this.avgBalance,
    required this.balanceDifference,
    required this.balanceChangePercent,
  });

  final int totalVendors;
  final int activeVendors;
  final double totalPayable;
  final double totalReceivable;
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
                icon: Icons.store_outlined,
                label: 'Total Vendors',
                value: totalVendors.toString(),
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Active Vendors',
                value: activeVendors.toString(),
                color: AuthColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Payable',
                value: '₹${totalPayable.toStringAsFixed(2)}',
                color: AuthColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.analytics_outlined,
                label: 'Average Balance',
                value: '₹${avgBalance.toStringAsFixed(2)}',
                subtitle: balanceDifference != 0
                    ? '${balanceDifference >= 0 ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)} (${balanceChangePercent >= 0 ? '+' : ''}${balanceChangePercent.abs().toStringAsFixed(1)}%)'
                    : null,
                subtitleColor: balanceDifference >= 0 ? AuthColors.success : AuthColors.error,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.background,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
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
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
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

