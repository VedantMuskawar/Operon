import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/presentation/blocs/production_batches/production_batches_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProductionBatchDetailModal extends StatefulWidget {
  const ProductionBatchDetailModal({
    super.key,
    required this.batch,
    required this.organizationId,
    required this.employeesRepository,
    required this.productsRepository,
    required this.wageSettingsRepository,
  });

  final ProductionBatch batch;
  final String organizationId;
  final EmployeesRepository employeesRepository;
  final ProductsRepository productsRepository;
  final WageSettingsRepository wageSettingsRepository;

  @override
  State<ProductionBatchDetailModal> createState() =>
      _ProductionBatchDetailModalState();
}

class _ProductionBatchDetailModalState
    extends State<ProductionBatchDetailModal> {
  WageCalculationMethod? _wageMethod;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings =
          await widget.wageSettingsRepository.fetchWageSettings(widget.organizationId);
      setState(() {
        if (settings != null) {
          _wageMethod = settings.calculationMethods[widget.batch.methodId];
        }
        _isLoadingData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Color _getStatusColor(ProductionBatchStatus status) {
    switch (status) {
      case ProductionBatchStatus.recorded:
        return AuthColors.textDisabled;
      case ProductionBatchStatus.calculated:
        return AuthColors.info;
      case ProductionBatchStatus.approved:
        return AuthColors.success;
      case ProductionBatchStatus.processed:
        return AuthColors.secondary;
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

  Future<void> _handleApprove() async {
    if (widget.batch.batchId.isEmpty) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Error: Batch ID is missing. Please refresh and try again.',
          isError: true,
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<ProductionBatchesCubit>().approveBatch(widget.batch.batchId);
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(context, message: 'Batch approved successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleProcess() async {
    if (widget.batch.batchId.isEmpty) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Error: Batch ID is missing. Please refresh and try again.',
          isError: true,
        );
      }
      return;
    }

    final paymentDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
          child: child!,
        );
      },
    );

    if (paymentDate == null) return;

    setState(() => _isLoading = true);
    try {
      final transactionIds = await context
          .read<ProductionBatchesCubit>()
          .processWages(widget.batch.batchId, paymentDate);
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: 'Wages processed successfully. ${transactionIds.length} transaction(s) created.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.batch.batchId.isEmpty) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Error: Batch ID is missing. Please refresh and try again.',
          isError: true,
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Production Batch',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this production batch?',
              style: TextStyle(color: AuthColors.textSub),
            ),
            if (widget.batch.status == ProductionBatchStatus.processed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This batch has processed wages. Deleting will revert all wage transactions and attendance records.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await context.read<ProductionBatchesCubit>().deleteBatch(widget.batch.batchId);
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: 'Production batch deleted successfully. Wages and attendance have been reverted.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error deleting batch: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.batch.status);
    final statusLabel = _getStatusLabel(widget.batch.status);
    final employeeCount = widget.batch.employeeIds.length;
    final employeeNames = widget.batch.employeeNames ?? [];
    final requiresApproval = _wageMethod?.config is ProductionWageConfig
        ? (_wageMethod!.config as ProductionWageConfig).requiresBatchApproval
        : false;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 750,
        constraints: const BoxConstraints(maxHeight: 850),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isLoadingData
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 24, 16, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: statusColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Batch Details',
                                style: TextStyle(
                                  color: AuthColors.textMain,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.batch.batchDate.day}/${widget.batch.batchDate.month}/${widget.batch.batchDate.year} • $employeeCount employee${employeeCount != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(widget.batch.status),
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AuthColors.textMainWithOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close, color: AuthColors.textSub, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Batch Information
                          _Section(
                            title: 'Batch Information',
                            children: [
                              _InfoRow(
                                label: 'Date',
                                value: '${widget.batch.batchDate.day}/${widget.batch.batchDate.month}/${widget.batch.batchDate.year}',
                              ),
                              if (_wageMethod != null)
                                _InfoRow(
                                  label: 'Wage Method',
                                  value: _wageMethod!.name,
                                ),
                              if (widget.batch.productName != null)
                                _InfoRow(
                                  label: 'Product',
                                  value: widget.batch.productName!,
                                ),
                              if (widget.batch.notes != null)
                                _InfoRow(
                                  label: 'Notes',
                                  value: widget.batch.notes!,
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Employees
                          _Section(
                            title: 'Employees ($employeeCount)',
                            children: [
                              if (employeeNames.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: employeeNames.map((name) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AuthColors.textMainWithOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: AuthColors.textMain,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              else
                                Text(
                                  'No employee names available',
                                  style: TextStyle(
                                    color: AuthColors.textMainWithOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Production Data
                          _Section(
                            title: 'Production Data',
                            children: [
                              _InfoRow(
                                label: 'Bricks Produced',
                                value: '${widget.batch.totalBricksProduced}',
                              ),
                              _InfoRow(
                                label: 'Bricks Stacked',
                                value: '${widget.batch.totalBricksStacked}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Wage Calculation
                          if (widget.batch.totalWages != null &&
                              widget.batch.wagePerEmployee != null &&
                              _wageMethod != null) ...[
                            _Section(
                              title: 'Wage Calculation',
                              children: [
                                if (_wageMethod!.config is ProductionWageConfig) ...[
                                  Builder(
                                    builder: (context) {
                                      final config =
                                          _wageMethod!.config as ProductionWageConfig;
                                      double productionPrice =
                                          config.productionPricePerUnit;
                                      double stackingPrice =
                                          config.stackingPricePerUnit;

                                      if (widget.batch.productId != null &&
                                          config.productSpecificPricing != null &&
                                          config.productSpecificPricing!
                                              .containsKey(widget.batch.productId)) {
                                        final productPricing = config
                                            .productSpecificPricing![
                                                widget.batch.productId]!;
                                        productionPrice =
                                            productPricing.productionPricePerUnit;
                                        stackingPrice =
                                            productPricing.stackingPricePerUnit;
                                      }

                                      final productionWages = widget
                                              .batch.totalBricksProduced *
                                          productionPrice;
                                      final stackingWages =
                                          widget.batch.totalBricksStacked *
                                              stackingPrice;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _InfoRow(
                                            label: 'Production Wages',
                                            value:
                                                '${widget.batch.totalBricksProduced} × ₹${productionPrice.toStringAsFixed(2)} = ₹${productionWages.toStringAsFixed(2)}',
                                          ),
                                          _InfoRow(
                                            label: 'Stacking Wages',
                                            value:
                                                '${widget.batch.totalBricksStacked} × ₹${stackingPrice.toStringAsFixed(2)} = ₹${stackingWages.toStringAsFixed(2)}',
                                          ),
                                          const Divider(
                                            color: AuthColors.textDisabled,
                                            height: 24,
                                          ),
                                          _InfoRow(
                                            label: 'Total Wages',
                                            value:
                                                '₹${widget.batch.totalWages!.toStringAsFixed(2)}',
                                            isHighlight: true,
                                          ),
                                          _InfoRow(
                                            label: 'Wage Per Employee',
                                            value:
                                                '₹${widget.batch.wagePerEmployee!.toStringAsFixed(2)}',
                                            isHighlight: true,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ] else
                                  _InfoRow(
                                    label: 'Total Wages',
                                    value:
                                        '₹${widget.batch.totalWages!.toStringAsFixed(2)}',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Transactions
                          if (widget.batch.wageTransactionIds != null &&
                              widget.batch.wageTransactionIds!.isNotEmpty) ...[
                            _Section(
                              title: 'Transactions',
                              children: [
                                Text(
                                  '${widget.batch.wageTransactionIds!.length} transaction(s) created',
                                  style: TextStyle(
                                    color: AuthColors.textMainWithOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...widget.batch.wageTransactionIds!.take(5).map((id) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      id,
                                      style: TextStyle(
                                        color: AuthColors.textMainWithOpacity(0.6),
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  );
                                }),
                                if (widget.batch.wageTransactionIds!.length > 5)
                                  Text(
                                    '+${widget.batch.wageTransactionIds!.length - 5} more',
                                    style: TextStyle(
                                      color: AuthColors.textMainWithOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Footer with Actions
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AuthColors.textMainWithOpacity(0.03),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DashButton(
                          label: 'Delete',
                          icon: Icons.delete_outline,
                          onPressed: _isLoading ? null : _handleDelete,
                          isDestructive: true,
                          variant: DashButtonVariant.outlined,
                        ),
                        Row(
                          children: [
                            DashButton(
                              label: 'Close',
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              variant: DashButtonVariant.text,
                            ),
                            // Only show actions for batches that have calculated wages
                            if (widget.batch.status == ProductionBatchStatus.calculated ||
                                widget.batch.status == ProductionBatchStatus.approved) ...[
                              if (widget.batch.status == ProductionBatchStatus.calculated &&
                                  requiresApproval) ...[
                                const SizedBox(width: 12),
                                DashButton(
                                  label: 'Approve',
                                  icon: Icons.check_circle_outline,
                                  onPressed: _isLoading ? null : _handleApprove,
                                ),
                              ],
                              const SizedBox(width: 12),
                              DashButton(
                                label: 'Process Wages',
                                icon: Icons.account_balance_wallet_outlined,
                                onPressed: _isLoading ? null : _handleProcess,
                              ),
                            ],
                            // If batch is in recorded status (shouldn't happen with new flow, but handle it)
                            if (widget.batch.status == ProductionBatchStatus.recorded &&
                                widget.batch.totalWages == null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.orange.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Edit batch to calculate wages',
                                      style: TextStyle(
                                        color: Colors.orange.withValues(alpha: 0.9),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                                          color: AuthColors.textMain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? Colors.white : Colors.white.withValues(alpha: 0.9),
                fontSize: isHighlight ? 16 : 14,
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

