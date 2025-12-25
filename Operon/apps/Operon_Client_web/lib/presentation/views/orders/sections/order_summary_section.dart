import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/create_order/create_order_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OrderSummarySection extends StatefulWidget {
  const OrderSummarySection({
    super.key,
    this.client,
  });

  final Client? client;

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
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Add products in Section 1 to see order summary',
            style: TextStyle(color: Colors.white70),
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
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Product Summary Table
          _buildProductTable(state.selectedItems),
          const SizedBox(height: 16),
          // Advance Payment
          _buildAdvancePaymentSection(),
          const SizedBox(height: 16),
          // Priority
          _buildPrioritySection(),
          const SizedBox(height: 16),
          // GST Toggle
          _buildGstToggleSection(),
          const SizedBox(height: 20),
          // Total Summary
          _buildTotalSummary(totalSubtotal, totalGst, totalAmount),
          const SizedBox(height: 24),
          // Create Order Button
          _buildCreateOrderButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProductTable(List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
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
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1.5),
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
                      color: isLast ? Colors.transparent : Colors.white10,
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? Colors.white70 : Colors.white,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
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
                activeColor: const Color(0xFF6F4BFF),
                checkColor: Colors.white,
              ),
              const Expanded(
                child: Text(
                  'Advance Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_hasAdvancePayment) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _advanceAmountController,
              enabled: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF13131E),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPaymentAccountId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1B2C),
              decoration: InputDecoration(
                labelText: 'Payment Account',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF13131E),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: Colors.white),
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
            Icon(Icons.money, size: 18, color: Colors.white70),
            SizedBox(width: 8),
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
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (account.isPrimary)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    '(Primary)',
                    style: TextStyle(
                      color: Color(0xFF6F4BFF),
                      fontSize: 11,
                    ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Priority',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriorityOption(
                  'Normal',
                  'normal',
                  const Color(0xFFC0C0C0), // Silver
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityOption(
                  'Priority',
                  'high',
                  const Color(0xFFD4AF37), // Gold
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
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
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGstToggleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
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
            activeColor: const Color(0xFF6F4BFF),
            checkColor: Colors.white,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Include GST in order',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary(double subtotal, double gst, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E2F), Color(0xFF13131E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6F4BFF), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _includeGst
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _includeGst
                        ? Colors.green.withValues(alpha: 0.35)
                        : Colors.red.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _includeGst ? 'GST Included' : 'GST Excluded',
                  style: TextStyle(
                    color: _includeGst ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_includeGst && gst > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total GST:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '₹${gst.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF5AD8A4),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF6F4BFF),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
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
          backgroundColor: const Color(0xFF6F4BFF),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isCreatingOrder
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      advanceAmount = double.tryParse(amountText);
      if (advanceAmount == null || advanceAmount < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid advance payment amount'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create order: ${e.toString()}'),
            backgroundColor: Colors.red,
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
