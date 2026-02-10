import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton;
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StockHistoryDialog extends StatefulWidget {
  const StockHistoryDialog({
    super.key,
    required this.material,
  });

  final RawMaterial material;

  @override
  State<StockHistoryDialog> createState() => _StockHistoryDialogState();
}

class _StockHistoryDialogState extends State<StockHistoryDialog> {
  List<StockHistoryEntry> _historyEntries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStockHistory();
  }

  Future<void> _loadStockHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) {
        setState(() {
          _error = 'No organization selected';
          _isLoading = false;
        });
        return;
      }

      final repository = RawMaterialsRepository(
        dataSource: RawMaterialsDataSource(),
      );
      final entries = await repository.fetchStockHistory(
        organization.id,
        widget.material.id,
        limit: 100,
      );

      setState(() {
        _historyEntries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stock history: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '$day $month $year, $hour:$minute $amPm';
  }

  Color _getTypeColor(StockHistoryType type) {
    switch (type) {
      case StockHistoryType.in_:
        return AuthColors.success;
      case StockHistoryType.out:
        return AuthColors.error;
      case StockHistoryType.adjustment:
        return AuthColors.warning;
    }
  }

  IconData _getTypeIcon(StockHistoryType type) {
    switch (type) {
      case StockHistoryType.in_:
        return Icons.arrow_downward;
      case StockHistoryType.out:
        return Icons.arrow_upward;
      case StockHistoryType.adjustment:
        return Icons.tune;
    }
  }

  String _getTypeLabel(StockHistoryType type) {
    switch (type) {
      case StockHistoryType.in_:
        return 'Stock In';
      case StockHistoryType.out:
        return 'Stock Out';
      case StockHistoryType.adjustment:
        return 'Adjustment';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AuthColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: AuthColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock History',
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.material.name,
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Current Stock Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AuthColors.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Stock',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.material.stock} ${widget.material.unitOfMeasurement}',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Minimum Level',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.material.minimumStockLevel} ${widget.material.unitOfMeasurement}',
                        style: TextStyle(
                          color: widget.material.isLowStock ? AuthColors.warning : AuthColors.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // History List
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AuthColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AuthColors.error,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: const TextStyle(color: AuthColors.error),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  DashButton(
                                    label: 'Retry',
                                    onPressed: _loadStockHistory,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _historyEntries.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      color: AuthColors.textDisabled,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No stock history yet',
                                      style: TextStyle(
                                        color: AuthColors.textSub,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _historyEntries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = _historyEntries[index];
                                  final typeColor = _getTypeColor(entry.type);
                                  
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AuthColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _getTypeIcon(entry.type),
                                            color: typeColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    _getTypeLabel(entry.type),
                                                    style: TextStyle(
                                                      color: typeColor,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    entry.quantity > 0
                                                        ? '+${entry.quantity.toStringAsFixed(2)}'
                                                        : entry.quantity.toStringAsFixed(2),
                                                    style: TextStyle(
                                                      color: entry.quantity > 0
                                                          ? AuthColors.success
                                                          : AuthColors.error,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    ' ${widget.material.unitOfMeasurement}',
                                                    style: const TextStyle(
                                                      color: AuthColors.textSub,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                entry.reason,
                                                style: const TextStyle(
                                                  color: AuthColors.textSub,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (entry.invoiceNumber != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Invoice: ${entry.invoiceNumber}',
                                                  style: const TextStyle(
                                                    color: AuthColors.textDisabled,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${entry.balanceBefore.toStringAsFixed(2)} → ${entry.balanceAfter.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AuthColors.textMain,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(entry.createdAt),
                                              style: const TextStyle(
                                                color: AuthColors.textDisabled,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

