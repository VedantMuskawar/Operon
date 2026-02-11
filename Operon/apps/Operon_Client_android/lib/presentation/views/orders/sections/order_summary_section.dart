import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_mobile/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrderSummarySection extends StatefulWidget {
  const OrderSummarySection({
    super.key,
    this.client,
  });

  final ClientRecord? client;

  @override
  State<OrderSummarySection> createState() => _OrderSummarySectionState();
}

class _OrderSummarySectionState extends State<OrderSummarySection> {
  bool _includeGst = true;
  bool _hasAdvancePayment = false;
  final TextEditingController _advanceAmountController = TextEditingController();
  String? _selectedPaymentAccountId;
  String _priority = 'normal'; // 'normal' or 'high'
  List<PaymentAccount> _paymentAccounts = [];
  bool _loadingAccounts = true;
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaymentAccounts();
    });
  }

  Future<void> _loadPaymentAccounts() async {
    if (!mounted) return;
    
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      setState(() => _loadingAccounts = false);
      return;
    }

    setState(() => _loadingAccounts = true);
    try {
      final repository = context.read<PaymentAccountsRepository>();
      final accounts = await repository.fetchAccounts(organization.id);
      if (mounted) {
        setState(() {
          _paymentAccounts = accounts.where((a) => a.isActive).toList();
          _loadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAccounts = false);
      }
    }
  }

  @override
  void dispose() {
    _advanceAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CreateOrderCubit>();
    final state = cubit.state;

    if (state.selectedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.paddingXXXL),
          child: Text(
                'Add products in Section 1 to see order summary',
            style: TextStyle(color: AuthColors.textSub),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Calculate totals
    double totalSubtotal = 0;
    double totalGst = 0;
    for (final item in state.selectedItems) {
      totalSubtotal += item.subtotal;
      if (_includeGst && item.hasGst) {
        totalGst += item.gstAmount;
      }
    }
    final totalAmount = totalSubtotal + totalGst;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTypography.withColor(AppTypography.h3, AuthColors.textMain),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          // Product Summary Table
          _buildProductTable(state.selectedItems),
          const SizedBox(height: AppSpacing.paddingLG),
          // Advance Payment
          _buildAdvancePaymentSection(),
          const SizedBox(height: AppSpacing.paddingLG),
          // Priority
          _buildPrioritySection(),
          const SizedBox(height: AppSpacing.paddingLG),
          // GST Toggle
          _buildGstToggleSection(),
          const SizedBox(height: AppSpacing.paddingXL),
          // Total Summary
          _buildTotalSummary(totalSubtotal, totalGst, totalAmount),
          const SizedBox(height: AppSpacing.paddingXXL),
          // Create Order Button
          _buildCreateOrderButton(),
          const SizedBox(height: AppSpacing.paddingXXL),
        ],
      ),
    );
  }

  Widget _buildProductTable(List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
              colors: [AuthColors.backgroundAlt, AuthColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Table(
          defaultColumnWidth: const FlexColumnWidth(1),
          columnWidths: const {
            0: FixedColumnWidth(150),
            1: FixedColumnWidth(60),
            2: FixedColumnWidth(80),
            3: FixedColumnWidth(80),
            4: FixedColumnWidth(100),
            5: FixedColumnWidth(100),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AuthColors.textMainWithOpacity(0.24), width: 1.5),
                ),
              ),
              children: [
                _buildTableCell('Product', isHeader: true),
                _buildTableCell('Trips', isHeader: true),
                _buildTableCell('Qty/Trip', isHeader: true),
                _buildTableCell('Total Qty', isHeader: true),
                _buildTableCell('Rate', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            // Data Rows
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isLast ? AuthColors.transparent : AuthColors.textMainWithOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                children: [
                  _buildTableCell(item.productName),
                  _buildTableCell(item.estimatedTrips.toString()),
                  _buildTableCell(item.fixedQuantityPerTrip.toString()),
                  _buildTableCell(item.totalQuantity.toString()),
                  _buildTableCell('₹${item.unitPrice.toStringAsFixed(2)}'),
                  _buildTableCell('₹${item.subtotal.toStringAsFixed(2)}'),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD, horizontal: AppSpacing.paddingSM),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AuthColors.textSub : AuthColors.textMain,
          fontSize: isHeader ? 12 : 13,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: isHeader ? TextAlign.center : TextAlign.start,
      ),
    );
  }

  Widget _buildAdvancePaymentSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _hasAdvancePayment,
                onChanged: (value) {
                  setState(() {
                    _hasAdvancePayment = value ?? false;
                    if (!_hasAdvancePayment) {
                      _advanceAmountController.clear();
                      _selectedPaymentAccountId = null;
                    }
                  });
                },
                activeColor: AuthColors.secondary,
                checkColor: AuthColors.textMain,
              ),
              Expanded(
                child: Text(
                  'Advance Payment',
                  style: AppTypography.withColor(
                    AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                    AuthColors.textMain,
                  ),
                ),
              ),
            ],
          ),
          if (_hasAdvancePayment) ...[
            const SizedBox(height: AppSpacing.paddingLG),
            TextField(
              controller: _advanceAmountController,
              enabled: true,
              style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
                filled: true,
                fillColor: AuthColors.backgroundAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: const BorderSide(color: AuthColors.secondary, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingMD),
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentAccountId,
              isExpanded: true,
              dropdownColor: AuthColors.backgroundAlt,
              decoration: InputDecoration(
                labelText: 'Payment Account',
                labelStyle: AppTypography.withColor(AppTypography.label, AuthColors.textSub),
                filled: true,
                fillColor: AuthColors.backgroundAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: const BorderSide(color: AuthColors.secondary, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
              items: _buildPaymentAccountItems(),
              onChanged: (value) {
                if (value != null && value != 'loading' && value != 'none') {
                  setState(() {
                    _selectedPaymentAccountId = value;
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildPaymentAccountItems() {
    if (_loadingAccounts) {
      return [
        const DropdownMenuItem(
          value: 'loading',
          enabled: false,
          child: Text('Loading...'),
        ),
      ];
    }

    if (_paymentAccounts.isEmpty) {
      return [
        const DropdownMenuItem(
          value: 'none',
          enabled: false,
          child: Text('No accounts available'),
        ),
      ];
    }

    return [
      // Add "Cash" option first
      const DropdownMenuItem(
        value: 'cash',
        child: Row(
          children: [
            Icon(Icons.money, size: 18, color: AuthColors.textSub),
            SizedBox(width: AppSpacing.paddingSM),
            Text('Cash'),
          ],
        ),
      ),
      // Then add payment accounts
      ..._paymentAccounts.map((account) {
        return DropdownMenuItem(
          value: account.id,
          child: Row(
            children: [
              Icon(
                _getAccountIcon(account.type),
                size: 18,
                color: AuthColors.textSub,
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              Expanded(
                child: Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (account.isPrimary)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.paddingXS),
                  child: Text(
                    '(Primary)',
                    style: AppTypography.withColor(AppTypography.captionSmall, AuthColors.secondary),
                  ),
                ),
            ],
          ),
        );
      }),
    ];
  }

  Widget _buildPrioritySection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority',
            style: AppTypography.withColor(
              AppTypography.withWeight(AppTypography.body, FontWeight.w600),
              AuthColors.textMain,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: [
              Expanded(
                child: _buildPriorityOption(
                  'Normal',
                  'normal',
                  AuthColors.textSub, // Silver (closest to 0xFFC0C0C0)
                ),
              ),
              const SizedBox(width: AppSpacing.paddingMD),
              Expanded(
                child: _buildPriorityOption(
                  'Priority',
                  'high',
                  AuthColors.secondary, // Gold
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityOption(String label, String value, Color color) {
    final isSelected = _priority == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _priority = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG, horizontal: AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AuthColors.backgroundAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isSelected ? color : AuthColors.textMainWithOpacity(0.24),
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
              style: AppTypography.withColor(
                AppTypography.withWeight(
                  AppTypography.body,
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                isSelected ? color : AuthColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstToggleSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _includeGst,
            onChanged: (value) {
              setState(() {
                _includeGst = value ?? true;
              });
            },
            activeColor: AuthColors.secondary,
                checkColor: AuthColors.textMain,
          ),
            const SizedBox(width: AppSpacing.paddingSM),
          Expanded(
            child: Text(
              'Include GST in order',
              style: AppTypography.withColor(AppTypography.body, AuthColors.textMain),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary(double subtotal, double gst, double total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
              colors: [AuthColors.backgroundAlt, AuthColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(color: AuthColors.secondary, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingMD, vertical: AppSpacing.gapSM),
                decoration: BoxDecoration(
                  color: _includeGst
                      ? AuthColors.success.withOpacity(0.15)
                      : AuthColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  border: Border.all(
                    color: _includeGst
                        ? AuthColors.success.withOpacity(0.35)
                        : AuthColors.error.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  _includeGst ? 'GST Included' : 'GST Excluded',
                  style: AppTypography.withColor(
                    AppTypography.withWeight(AppTypography.labelSmall, FontWeight.w600),
                    _includeGst ? AuthColors.successVariant : AuthColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal:',
                style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(2)}',
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.body, FontWeight.w600),
                  AuthColors.textMain,
                ),
              ),
            ],
          ),
          if (_includeGst && gst > 0) ...[
            const SizedBox(height: AppSpacing.paddingSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total GST:',
                  style: AppTypography.withColor(AppTypography.body, AuthColors.textSub),
                ),
                Text(
                  '₹${gst.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AuthColors.successVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.paddingMD),
          Divider(color: AuthColors.textMainWithOpacity(0.24)),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount:',
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
                  AuthColors.textMain,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.h2, FontWeight.w700),
                  AuthColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCreatingOrder
            ? null
            : () async {
                await _createOrder();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.secondary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
        ),
        child: _isCreatingOrder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                ),
              )
            : Text(
                'Create Order',
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.h4, FontWeight.w600),
                  AuthColors.textMain,
                ),
              ),
      ),
    );
  }

  Future<void> _createOrder() async {
    // Validate client
    final client = widget.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client information is required'),
          backgroundColor: AuthColors.error,
        ),
      );
      return;
    }

    // Validate advance payment amount
    double? advanceAmount;
    if (_hasAdvancePayment) {
      final amountText = _advanceAmountController.text.trim();
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter advance payment amount'),
            backgroundColor: AuthColors.error,
          ),
        );
        return;
      }
      advanceAmount = double.tryParse(amountText);
      if (advanceAmount == null || advanceAmount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid advance payment amount'),
            backgroundColor: AuthColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isCreatingOrder = true);

    try {
      // Get current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final cubit = context.read<CreateOrderCubit>();
      
      // Create order
      await cubit.createOrder(
        clientId: client.id,
        clientName: client.name,
        clientPhone: client.primaryPhone ?? '',
        priority: _priority,
        includeGstInTotal: _includeGst,
        advancePaymentAccountId: _hasAdvancePayment ? _selectedPaymentAccountId : null,
        advanceAmount: advanceAmount,
        createdBy: currentUser.uid,
      );

      // Success - navigate back
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully'),
            backgroundColor: AuthColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create order: ${e.toString()}'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
  }

  IconData _getAccountIcon(PaymentAccountType type) {
    switch (type) {
      case PaymentAccountType.bank:
        return Icons.account_balance;
      case PaymentAccountType.cash:
        return Icons.money;
      case PaymentAccountType.upi:
        return Icons.qr_code;
      case PaymentAccountType.other:
        return Icons.payment;
    }
  }
}
