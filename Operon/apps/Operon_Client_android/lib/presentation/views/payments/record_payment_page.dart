import 'dart:io';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payments/payments_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/services/qr_code_service.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class RecordPaymentPage extends StatefulWidget {
  const RecordPaymentPage({super.key});

  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  Future<void> _selectClient() async {
    final client = await showModalBottomSheet<ClientRecord>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => BlocProvider.value(
        value: context.read<ClientsCubit>(),
        child: const _ClientSelectionSheet(),
      ),
    );

    if (client != null && mounted) {
      // Store client info in a local variable for use in the cubit
      // The cubit's selectClient method expects ClientRecord
      context.read<PaymentsCubit>().selectClient(client);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      context.read<PaymentsCubit>().updatePaymentDate(picked);
    }
  }

  Future<void> _pickReceiptPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1B1B2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      if (source == ImageSource.gallery) {
        context.read<PaymentsCubit>().pickReceiptPhoto();
      } else {
        context.read<PaymentsCubit>().takeReceiptPhoto();
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Validate payment account splits if any are selected
    final state = context.read<PaymentsCubit>().state;
    if (state.paymentAccountSplits.isNotEmpty) {
      final totalSplit = state.paymentAccountSplits.values.fold<double>(0.0, (sum, amt) => sum + amt);
      if ((totalSplit - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split amounts (${_formatCurrency(totalSplit)}) must equal total amount (${_formatCurrency(amount)})'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    context.read<PaymentsCubit>().updatePaymentAmount(amount);
    await context.read<PaymentsCubit>().submitPayment();
  }

  @override
  Widget build(BuildContext context) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: Text('Please select an organization')),
      );
    }

    return BlocConsumer<PaymentsCubit, PaymentsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.success && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.green,
            ),
          );
          if (state.selectedClientId != null && state.paymentAmount != null) {
            // Navigate back after successful payment
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                context.go('/transactions');
              }
            });
          }
        } else if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: const ModernPageHeader(
            title: 'Record Payment',
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Client Selection
                _buildClientSelection(state),
                const SizedBox(height: 20),

                // Current Balance (if client selected)
                if (state.selectedClientId != null && state.currentBalance != null)
                  _buildCurrentBalance(state.currentBalance!),

                // Payment Amount
                _buildAmountField(),
                const SizedBox(height: 20),

                // Payment Accounts
                _buildPaymentAccountsSection(state),
                const SizedBox(height: 20),

                // Payment Date
                _buildDateField(),
                const SizedBox(height: 20),

                // Receipt Photo
                _buildReceiptPhotoSection(state),
                const SizedBox(height: 30),

                // Submit Button
                _buildSubmitButton(state),
              ],
                    ),
                      ),
                    ),
            ),
            QuickNavBar(
              currentIndex: 0,
              onTap: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildClientSelection(PaymentsState state) {
    final hasClient = state.selectedClientId != null;
    return InkWell(
      onTap: _selectClient,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasClient ? Colors.white24 : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: hasClient ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.selectedClientName ?? 'Select Client',
                    style: TextStyle(
                      color: hasClient ? Colors.white : Colors.white54,
                      fontSize: 16,
                      fontWeight: hasClient ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalance(double balance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: balance >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: balance >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            balance >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: balance >= 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(balance.abs()),
                  style: TextStyle(
                    color: balance >= 0 ? Colors.green : Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: 'Payment Amount',
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1B1B2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter payment amount';
        }
        final amount = double.tryParse(value.replaceAll(',', ''));
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Date',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}'
                        : 'Select date',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPhotoSection(PaymentsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Receipt Photo (Optional)',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (state.receiptPhoto != null)
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(state.receiptPhoto!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                  onPressed: () => context.read<PaymentsCubit>().removeReceiptPhoto(),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _pickReceiptPhoto,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2C),
                borderRadius: BorderRadius.circular(14),
                border: const Border.fromBorderSide(BorderSide(color: Colors.white12)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: Colors.white54, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Add Receipt Photo',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentAccountsSection(PaymentsState state) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    
    if (organization == null) return const SizedBox.shrink();

    return BlocProvider(
      create: (_) => PaymentAccountsCubit(
        repository: PaymentAccountsRepository(
          dataSource: PaymentAccountsDataSource(),
        ),
        qrCodeService: QrCodeService(),
        orgId: organization.id,
      )..loadAccounts(),
      child: BlocBuilder<PaymentAccountsCubit, PaymentAccountsState>(
        builder: (context, accountsState) {
          final accounts = accountsState.accounts.where((a) => a.isActive).toList();
          
          if (accounts.isEmpty) {
            return const SizedBox.shrink();
          }

          final totalAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
          final totalSplit = state.paymentAccountSplits.values.fold<double>(0.0, (sum, amt) => sum + amt);
          final remaining = totalAmount - totalSplit;
          final hasSplits = state.paymentAccountSplits.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Accounts (Optional)',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (hasSplits && totalAmount > 0)
                    Text(
                      remaining > 0.01
                          ? 'Remaining: ${_formatCurrency(remaining)}'
                          : remaining < -0.01
                              ? 'Excess: ${_formatCurrency(remaining.abs())}'
                              : 'Balanced',
                      style: TextStyle(
                        color: remaining.abs() < 0.01
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accounts.map((account) {
                  final isSelected = state.paymentAccountSplits.containsKey(account.id);
                  return _PaymentAccountChip(
                    account: account,
                    isSelected: isSelected,
                    amount: state.paymentAccountSplits[account.id] ?? 0.0,
                    onTap: () {
                      if (isSelected) {
                        context.read<PaymentsCubit>().removePaymentAccountSplit(account.id);
                      } else {
                        context.read<PaymentsCubit>().updatePaymentAccountSplit(account.id, 0.0);
                      }
                    },
                    onAmountChanged: (amount) {
                      context.read<PaymentsCubit>().updatePaymentAccountSplit(account.id, amount);
                    },
                    formatCurrency: _formatCurrency,
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton(PaymentsState state) {
    final isEnabled = state.selectedClientId != null &&
        _amountController.text.isNotEmpty &&
        _selectedDate != null &&
        !state.isSubmitting;

    return ElevatedButton(
      onPressed: isEnabled ? _submitPayment : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6F4BFF),
        disabledBackgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: state.isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Record Payment',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _ClientSelectionSheet extends StatefulWidget {
  const _ClientSelectionSheet();

  @override
  State<_ClientSelectionSheet> createState() => _ClientSelectionSheetState();
}

class _ClientSelectionSheetState extends State<_ClientSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<ClientsCubit>().search(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Text(
            'Select Client',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ClientsCubit>().search('');
                      },
                    )
                  : null,
              hintText: 'Search clients by name or phone',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF252530),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<ClientsCubit, ClientsState>(
              builder: (context, state) {
                final clients = state.searchQuery.isEmpty
                    ? state.recentClients
                    : state.searchResults;

                if (state.isRecentLoading || state.isSearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      state.searchQuery.isEmpty
                          ? 'No recent clients'
                          : 'No clients found',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF6F4BFF),
                        child: Text(
                          client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(client.name, style: const TextStyle(color: Colors.white)),
                      subtitle: client.primaryPhone != null
                          ? Text(client.primaryPhone!, style: const TextStyle(color: Colors.white54))
                          : null,
                      onTap: () => Navigator.pop(context, client),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentAccountChip extends StatefulWidget {
  const _PaymentAccountChip({
    required this.account,
    required this.isSelected,
    required this.amount,
    required this.onTap,
    required this.onAmountChanged,
    required this.formatCurrency,
  });

  final PaymentAccount account;
  final bool isSelected;
  final double amount;
  final VoidCallback onTap;
  final ValueChanged<double> onAmountChanged;
  final String Function(double) formatCurrency;

  @override
  State<_PaymentAccountChip> createState() => _PaymentAccountChipState();
}

class _PaymentAccountChipState extends State<_PaymentAccountChip> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    if (widget.isSelected && widget.amount > 0) {
      _amountController.text = widget.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PaymentAccountChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected && oldWidget.isSelected) {
      _amountController.clear();
    }
  }

  String _getAccountTypeIcon(PaymentAccountType type) {
    switch (type) {
      case PaymentAccountType.cash:
        return '💵';
      case PaymentAccountType.upi:
        return '📱';
      case PaymentAccountType.bank:
        return '🏦';
      case PaymentAccountType.other:
        return '💳';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelected) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getAccountTypeIcon(widget.account.type),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Text(
                widget.account.name,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6F4BFF).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getAccountTypeIcon(widget.account.type),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.account.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                onPressed: widget.onTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white54, size: 16),
                filled: true,
                fillColor: const Color(0xFF252530),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (value) {
                final amount = double.tryParse(value.replaceAll(',', '')) ?? 0.0;
                widget.onAmountChanged(amount);
              },
            ),
          ),
        ],
      ),
    );
  }
}

