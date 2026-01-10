import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
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

  Future<void> _handleCalculate() async {
    setState(() => _isLoading = true);
    try {
      await context.read<ProductionBatchesCubit>().calculateWages(widget.batch.batchId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wages calculated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApprove() async {
    setState(() => _isLoading = true);
    try {
      await context.read<ProductionBatchesCubit>().approveBatch(widget.batch.batchId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch approved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleProcess() async {
    final paymentDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6F4BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B2C),
              onSurface: Colors.white,
            ),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Wages processed successfully. ${transactionIds.length} transaction(s) created.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Batch Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
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
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
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
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
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
                                    color: Colors.white.withValues(alpha: 0.7),
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
                                            color: Colors.white24,
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
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...widget.batch.wageTransactionIds!.take(5).map((id) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      id,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
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
                                      color: Colors.white.withValues(alpha: 0.5),
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
                  const SizedBox(height: 24),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      if (widget.batch.status == ProductionBatchStatus.recorded) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleCalculate,
                          icon: const Icon(Icons.calculate_outlined, size: 18),
                          label: const Text('Calculate Wages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      if (widget.batch.status == ProductionBatchStatus.calculated) ...[
                        if (requiresApproval) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleApprove,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleProcess,
                          icon: const Icon(Icons.account_balance_wallet_outlined,
                              size: 18),
                          label: const Text('Process Wages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      if (widget.batch.status == ProductionBatchStatus.approved) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleProcess,
                          icon: const Icon(Icons.account_balance_wallet_outlined,
                              size: 18),
                          label: const Text('Process Wages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
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
              color: Colors.white,
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

