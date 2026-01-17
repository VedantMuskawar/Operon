import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

class ProductionBatchCard extends StatelessWidget {
  const ProductionBatchCard({
    super.key,
    required this.batch,
    required this.onTap,
  });

  final ProductionBatch batch;
  final VoidCallback onTap;

  Color _getStatusColor(ProductionBatchStatus status) {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return Colors.grey;
      case ProductionBatchStatus.calculated:
        return const Color(0xFF2196F3);
      case ProductionBatchStatus.approved:
        return const Color(0xFF4CAF50);
      case ProductionBatchStatus.processed:
        return const Color(0xFF9C27B0);
    }
  }

  String _getStatusLabel(ProductionBatchStatus status) {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return 'Recorded';
      case ProductionBatchStatus.calculated:
        return 'Calculated';
      case ProductionBatchStatus.approved:
        return 'Approved';
      case ProductionBatchStatus.processed:
        return 'Processed';
    }
  }

  IconData _getStatusIcon(ProductionBatchStatus status) {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return Icons.edit_outlined;
      case ProductionBatchStatus.calculated:
        return Icons.calculate_outlined;
      case ProductionBatchStatus.approved:
        return Icons.check_circle_outline;
      case ProductionBatchStatus.processed:
        return Icons.done_all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(batch.status);
    final statusLabel = _getStatusLabel(batch.status);
    final statusIcon = _getStatusIcon(batch.status);
    final employeeCount = batch.employeeIds.length;
    final employeeNames = batch.employeeNames ?? [];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${batch.batchDate.day}/${batch.batchDate.month}/${batch.batchDate.year}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Workflow Progress Indicator
              _WorkflowProgress(status: batch.status),
              const SizedBox(height: 16),
              // Production quantities
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Produced',
                      value: '${batch.totalBricksProduced}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.layers_outlined,
                      label: 'Stacked',
                      value: '${batch.totalBricksStacked}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Employees
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$employeeCount employee${employeeCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  if (employeeNames.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        employeeNames.take(3).join(', ') +
                            (employeeNames.length > 3
                                ? ' +${employeeNames.length - 3} more'
                                : ''),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              // Wages (if calculated)
              if (batch.totalWages != null && batch.wagePerEmployee != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: ₹${batch.totalWages!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Per Employee: ₹${batch.wagePerEmployee!.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Product (if applicable)
              if (batch.productName != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      batch.productName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowProgress extends StatelessWidget {
  const _WorkflowProgress({required this.status});

  final ProductionBatchStatus status;

  int get _currentStep {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return 1;
      case ProductionBatchStatus.calculated:
        return 2;
      case ProductionBatchStatus.approved:
        return 3;
      case ProductionBatchStatus.processed:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _WorkflowStep(label: 'Recorded', completed: _currentStep >= 1),
      _WorkflowStep(label: 'Calculated', completed: _currentStep >= 2),
      _WorkflowStep(label: 'Approved', completed: _currentStep >= 3),
      _WorkflowStep(label: 'Processed', completed: _currentStep >= 4),
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.completed
                            ? const Color(0xFF6F4BFF)
                            : Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: step.completed
                              ? const Color(0xFF6F4BFF)
                              : Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: step.completed
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.label,
                      style: TextStyle(
                        color: step.completed
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: step.completed ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: step.completed
                          ? const Color(0xFF6F4BFF)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WorkflowStep {
  const _WorkflowStep({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

