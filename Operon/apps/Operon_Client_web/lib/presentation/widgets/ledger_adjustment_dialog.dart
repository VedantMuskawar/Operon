import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart'
    show AuthColors, DashButton, DashButtonVariant, DashSnackbar;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LedgerAdjustmentDialog extends StatefulWidget {
  const LedgerAdjustmentDialog({
    super.key,
    required this.organizationId,
    required this.ledgerType,
    required this.entityId,
    required this.entityName,
    required this.transactionCategory,
  });

  final String organizationId;
  final LedgerType ledgerType;
  final String entityId;
  final String entityName;
  final TransactionCategory transactionCategory;

  @override
  State<LedgerAdjustmentDialog> createState() => _LedgerAdjustmentDialogState();
}

class _LedgerAdjustmentDialogState extends State<LedgerAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isIncrease = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _financialYearFromDate(DateTime date) {
    final fyStartYear = date.month >= 4 ? date.year : date.year - 1;
    final fyEndYear = fyStartYear + 1;
    final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
    final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
    return 'FY$startStr$endStr';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      DashSnackbar.show(context,
          message: 'Please enter a valid amount', isError: true);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? clientId;
      String? clientName;
      String? vendorId;
      String? vendorName;
      String? employeeId;
      String? employeeName;

      switch (widget.ledgerType) {
        case LedgerType.clientLedger:
          clientId = widget.entityId;
          clientName = widget.entityName;
          break;
        case LedgerType.vendorLedger:
          vendorId = widget.entityId;
          vendorName = widget.entityName;
          break;
        case LedgerType.employeeLedger:
          employeeId = widget.entityId;
          employeeName = widget.entityName;
          break;
        case LedgerType.organizationLedger:
          break;
      }

      final tx = Transaction(
        id: '',
        organizationId: widget.organizationId,
        clientId: clientId,
        clientName: clientName,
        vendorId: vendorId,
        vendorName: vendorName,
        employeeId: employeeId,
        employeeName: employeeName,
        ledgerType: widget.ledgerType,
        type: _isIncrease ? TransactionType.credit : TransactionType.debit,
        category: widget.transactionCategory,
        amount: amount,
        createdBy: currentUser.uid,
        transactionDate: _selectedDate,
        createdAt: _selectedDate,
        updatedAt: _selectedDate,
        financialYear: _financialYearFromDate(_selectedDate),
        description: _descriptionController.text.trim().isEmpty
            ? 'Ledger adjustment'
            : _descriptionController.text.trim(),
        metadata: {
          'recordedVia': 'web-app',
          'entryType': 'adjustment',
          'adjustmentEffect': _isIncrease ? 'increase' : 'decrease',
        },
      );

      await TransactionsDataSource().createTransaction(tx);

      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'Adjustment recorded successfully', isError: false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'Failed to record adjustment: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Adjustment',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.entityName,
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Increase Balance'),
                      icon: Icon(Icons.add_circle_outline),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Decrease Balance'),
                      icon: Icon(Icons.remove_circle_outline),
                    ),
                  ],
                  selected: {_isIncrease},
                  onSelectionChanged: (selection) {
                    setState(() => _isIncrease = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter amount';
                    }
                    final parsed =
                        double.tryParse(value.trim().replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateLabel,
                            style: const TextStyle(color: AuthColors.textMain)),
                        const Icon(Icons.calendar_today,
                            size: 18, color: AuthColors.textSub),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DashButton(
                      label: 'Cancel',
                      variant: DashButtonVariant.text,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    DashButton(
                      label: 'Save Adjustment',
                      onPressed: _save,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}