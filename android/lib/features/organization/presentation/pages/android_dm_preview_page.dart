import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/app_theme.dart';
import '../../models/scheduled_order.dart';
import '../../../vehicle/models/vehicle.dart' as android_vehicle;

class AndroidDmPreviewPage extends StatelessWidget {
  const AndroidDmPreviewPage({
    super.key,
    required this.schedule,
    required this.organizationId,
    this.vehicle,
  });

  final ScheduledOrder schedule;
  final String organizationId;
  final android_vehicle.Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final dmLabel =
        schedule.dmNumber != null ? 'DM-${schedule.dmNumber}' : 'Delivery Memo';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dmLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Printing from Android will be enabled soon.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSummaryCard(context),
              const SizedBox(height: 16),
              _buildClientCard(),
              const SizedBox(height: 16),
              _buildTripCard(),
              const SizedBox(height: 16),
              _buildTotalsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Memo Preview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                icon: Icons.badge_outlined,
                label: 'DM Number',
                value: schedule.dmNumber != null
                    ? 'DM-${schedule.dmNumber}'
                    : 'Pending',
              ),
              _buildInfoChip(
                icon: Icons.event_outlined,
                label: 'Generated',
                value: schedule.dmGeneratedAt != null
                    ? _formatDate(schedule.dmGeneratedAt!)
                    : 'Not generated',
              ),
              _buildInfoChip(
                icon: Icons.directions_car_filled_outlined,
                label: 'Vehicle',
                value: vehicle?.vehicleNo ?? schedule.vehicleId,
              ),
              _buildInfoChip(
                icon: Icons.payments_outlined,
                label: 'Payment Mode',
                value: schedule.paymentType,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildLabelValue('Name', schedule.clientName ?? '—'),
          const SizedBox(height: 8),
          _buildLabelValue('Phone', schedule.clientPhone ?? '—'),
          const SizedBox(height: 8),
          _buildLabelValue('Region', schedule.orderRegion),
          const SizedBox(height: 4),
          _buildLabelValue('City', schedule.orderCity),
        ],
      ),
    );
  }

  Widget _buildTripCard() {
    final driverDisplay =
        [schedule.driverName, schedule.driverPhone].where((value) {
      return value != null && value.trim().isNotEmpty;
    }).join(' • ');

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildLabelValue('Trip', schedule.slotLabel),
          const SizedBox(height: 8),
          _buildLabelValue('Quantity', '${schedule.quantity} units'),
          const SizedBox(height: 8),
          _buildLabelValue(
            'Scheduled At',
            _formatDate(schedule.scheduledDate),
          ),
          const SizedBox(height: 8),
          _buildLabelValue(
            'Driver',
            driverDisplay.isNotEmpty ? driverDisplay : 'Not assigned',
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    final subtotal = schedule.totalAmount - schedule.gstAmount;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildAmountRow('Subtotal', subtotal),
          const SizedBox(height: 8),
          if (schedule.gstApplicable && schedule.gstAmount > 0)
            _buildAmountRow(
              'GST (${schedule.gstRate.toStringAsFixed(2)}%)',
              schedule.gstAmount,
            )
          else
            _buildLabelValue('GST', 'Not applied'),
          const Divider(
            height: 24,
            color: AppTheme.borderColor,
          ),
          _buildAmountRow(
            'Total Amount',
            schedule.totalAmount,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(String label, double value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: highlight ? 18 : 15,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy • hh:mm a').format(date);
  }

  String _formatCurrency(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }
}

