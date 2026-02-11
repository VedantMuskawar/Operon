import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditOrderDialog extends StatefulWidget {
  const EditOrderDialog({
    super.key,
    required this.order,
    required this.onSave,
  });

  final Map<String, dynamic> order;
  final Future<void> Function({
    String? priority,
    double? advanceAmount,
    String? advancePaymentAccountId,
  }) onSave;

  @override
  State<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<EditOrderDialog> {
  late String _priority;
  final TextEditingController _advanceAmountController = TextEditingController();
  String? _selectedPaymentAccountId;
  List<Map<String, dynamic>> _paymentAccounts = [];
  bool _isLoadingAccounts = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priority = widget.order['priority'] as String? ?? 'normal';
    final advanceAmount = widget.order['advanceAmount'] as num?;
    if (advanceAmount != null && advanceAmount > 0) {
      _advanceAmountController.text = advanceAmount.toStringAsFixed(2);
    }
    _selectedPaymentAccountId = widget.order['advancePaymentAccountId'] as String?;
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    if (!mounted) return;
    
    setState(() => _isLoadingAccounts = true);
    try {
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null) {
        setState(() => _isLoadingAccounts = false);
        return;
      }

      final repository = context.read<PaymentAccountsRepository>();
      final accounts = await repository.fetchAccounts(organization.id);
      if (mounted) {
        setState(() {
          _paymentAccounts = accounts
              .where((a) => a.isActive)
              .map((a) => {
                    'id': a.id,
                    'name': a.name,
                  })
              .toList();
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAccounts = false);
      }
    }
  }

  @override
  void dispose() {
    _advanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    
    double? advanceAmount;
    if (_advanceAmountController.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_advanceAmountController.text.trim());
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a valid advance amount',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      advanceAmount = parsed;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        priority: _priority != widget.order['priority'] ? _priority : null,
        advanceAmount: advanceAmount,
        advancePaymentAccountId: _selectedPaymentAccountId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order updated successfully',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update order: $e',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.paddingLG),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderDefault,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                    size: AppSpacing.iconMD,
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  const Expanded(
                    child: Text(
                      'Edit Order',
                      style: AppTypography.h3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: AppSpacing.iconMD,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.paddingLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority Section
                    Text(
                      'Priority',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    Row(
                      children: [
                        Expanded(
                          child: _PriorityOption(
                            label: 'Normal',
                            value: 'normal',
                            isSelected: _priority == 'normal',
                            color: AuthColors.textDisabled,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _priority = 'normal');
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.paddingMD),
                        Expanded(
                          child: _PriorityOption(
                            label: 'High',
                            value: 'high',
                            isSelected: _priority == 'high',
                            color: AuthColors.secondary,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _priority = 'high');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.paddingXL),
                    
                    // Advance Payment Section
                    Text(
                      'Advance Payment',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    TextField(
                      controller: _advanceAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Enter advance amount',
                        prefixText: '₹ ',
                        prefixStyle: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          borderSide: BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          borderSide: BorderSide(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingMD),
                    
                    // Payment Account Selection
                    if (_isLoadingAccounts)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.paddingMD),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (_paymentAccounts.isNotEmpty) ...[
                      Text(
                        'Payment Account',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.paddingSM),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          border: Border.all(
                            color: AppColors.borderDefault,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPaymentAccountId,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.paddingMD,
                            ),
                            hint: Text(
                              'Select payment account',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('None'),
                              ),
                              ..._paymentAccounts.map((account) {
                                return DropdownMenuItem<String>(
                                  value: account['id'] as String,
                                  child: Text(
                                    account['name'] as String,
                                    style: AppTypography.body,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedPaymentAccountId = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.paddingLG),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderDefault,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: AppTypography.buttonSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.paddingMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : Text(
                              'Save',
                              style: AppTypography.buttonSmall.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                    ),
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

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.paddingMD,
          horizontal: AppSpacing.paddingLG,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isSelected ? color : AppColors.borderDefault,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            Text(
              label,
              style: AppTypography.body.copyWith(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
