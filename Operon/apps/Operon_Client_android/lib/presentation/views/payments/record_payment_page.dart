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
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
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
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  PaymentAccountsCubit? _paymentAccountsCubit;
  String? _paymentAccountsOrgId;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _paymentAccountsCubit?.close();
    super.dispose();
  }

  void _onAmountChanged() {
    if (!mounted) return;
    final cubit = context.read<PaymentsCubit>();
    final splits = cubit.state.paymentAccountSplits;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    // Always update split for selected account(s)
    if (splits.isNotEmpty) {
      for (final accountId in splits.keys) {
        cubit.updatePaymentAccountSplit(accountId, amount);
      }
    }
    setState(() {});
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
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
      backgroundColor: AuthColors.transparent,
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
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
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
      backgroundColor: AuthColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AuthColors.textMain),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: AuthColors.textMain)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AuthColors.textMain),
              title: const Text('Take Photo',
                  style: TextStyle(color: AuthColors.textMain)),
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
      final totalSplit = state.paymentAccountSplits.values
          .fold<double>(0.0, (sum, amt) => sum + amt);
      if ((totalSplit - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Split amounts (${_formatCurrency(totalSplit)}) must equal total amount (${_formatCurrency(amount)})'),
            backgroundColor: AuthColors.error,
          ),
        );
        return;
      }
    }

    if (state.paymentAccountSplits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment account'),
          backgroundColor: AuthColors.error,
        ),
      );
      return;
    }

    final cubit = context.read<PaymentsCubit>();
    cubit.updatePaymentAmount(amount);
    cubit.setPaymentDescription(_descriptionController.text);

    // If exactly one payment account split, set selected account info for cubit
    final splits = cubit.state.paymentAccountSplits;
    if (splits.length == 1) {
      final accountId = splits.keys.first;
      // Find the PaymentAccount object from the UI's loaded accounts
      final accountsCubit = context.read<PaymentAccountsCubit>();
      final accounts = accountsCubit.state.accounts;
      final account = accounts.where((a) => a.id == accountId).toList();
      if (account.isNotEmpty) {
        final selected = account.first;
        cubit.setSelectedPaymentAccount(
          id: selected.id,
          name: selected.name,
          type: selected.type.name,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select exactly one payment account'),
          backgroundColor: AuthColors.error,
        ),
      );
      return;
    }
    await cubit.submitPayment();
  }

  @override
  Widget build(BuildContext context) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization != null &&
        (_paymentAccountsCubit == null ||
            _paymentAccountsOrgId != organization.id)) {
      _paymentAccountsCubit?.close();
      _paymentAccountsOrgId = organization.id;
      _paymentAccountsCubit = PaymentAccountsCubit(
        repository: PaymentAccountsRepository(
          dataSource: PaymentAccountsDataSource(),
        ),
        qrCodeService: QrCodeService(),
        orgId: organization.id,
      )..loadAccounts();
    }

    if (organization == null) {
      return const Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(child: Text('Please select an organization')),
      );
    }

    return BlocConsumer<PaymentsCubit, PaymentsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.success && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AuthColors.success,
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
        } else if (state.status == ViewStatus.failure &&
            state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AuthColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AuthColors.background,
          appBar: const ModernPageHeader(
            title: 'Record Payment',
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.paddingLG),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Client'),
                          const SizedBox(height: AppSpacing.paddingSM),
                          _buildClientSelection(state),
                          const SizedBox(height: AppSpacing.paddingXL),
                          if (state.selectedClientId != null &&
                              state.currentBalance != null) ...[
                            _sectionTitle('Current Balance'),
                            const SizedBox(height: AppSpacing.paddingSM),
                            _buildCurrentBalance(state.currentBalance!),
                            const SizedBox(height: AppSpacing.paddingXL),
                          ],
                          _sectionTitle('Amount'),
                          const SizedBox(height: AppSpacing.paddingSM),
                          _buildAmountField(),
                          const SizedBox(height: AppSpacing.paddingXL),
                          _buildPaymentAccountsSection(state),
                          const SizedBox(height: AppSpacing.paddingXL),
                          _sectionTitle('Description (Optional)'),
                          const SizedBox(height: AppSpacing.paddingSM),
                          _buildDescriptionField(),
                          const SizedBox(height: AppSpacing.paddingXL),
                          _sectionTitle('Payment Date'),
                          const SizedBox(height: AppSpacing.paddingSM),
                          _buildDateField(),
                          const SizedBox(height: AppSpacing.paddingXL),
                          _sectionTitle('Receipt Photo (Optional)'),
                          const SizedBox(height: AppSpacing.paddingSM),
                          _buildReceiptPhotoSection(state),
                          const SizedBox(height: AppSpacing.paddingXXL),
                          _buildSubmitButton(state),
                        ],
                      ),
                    ),
                  ),
                ),
                FloatingNavBar(
                  items: const [
                    NavBarItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      heroTag: 'nav_home',
                    ),
                    NavBarItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      heroTag: 'nav_pending',
                    ),
                    NavBarItem(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      heroTag: 'nav_schedule',
                    ),
                    NavBarItem(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      heroTag: 'nav_map',
                    ),
                    NavBarItem(
                      icon: Icons.event_available_rounded,
                      label: 'Cash Ledger',
                      heroTag: 'nav_cash_ledger',
                    ),
                  ],
                  currentIndex: 0,
                  onItemTapped: (value) => context.go('/home', extra: value),
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: hasClient
                ? AuthColors.textMainWithOpacity(0.24)
                : AuthColors.textMainWithOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: hasClient ? AuthColors.textMain : AuthColors.textSub,
            ),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.selectedClientName ?? 'Select Client',
                    style: TextStyle(
                      color:
                          hasClient ? AuthColors.textMain : AuthColors.textSub,
                      fontSize: 16,
                      fontWeight:
                          hasClient ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AuthColors.textSub),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalance(double balance) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
          color: balance >= 0
            ? AuthColors.success.withValues(alpha: 0.1)
            : AuthColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
            color: balance >= 0
              ? AuthColors.success.withValues(alpha: 0.3)
              : AuthColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            balance >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            color: balance >= 0 ? AuthColors.success : AuthColors.error,
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  _formatCurrency(balance.abs()),
                  style: TextStyle(
                    color: balance >= 0 ? AuthColors.success : AuthColors.error,
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
      style: const TextStyle(color: AuthColors.textMain, fontSize: 18),
      decoration: _inputDecoration(
        'Payment Amount',
        prefixIcon: Icons.currency_rupee,
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
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AuthColors.textSub, size: 20),
            const SizedBox(width: AppSpacing.paddingMD),
            Expanded(
              child: Text(
                _selectedDate != null
                    ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}'
                    : 'Select date',
                style:
                    const TextStyle(color: AuthColors.textMain, fontSize: 16),
              ),
            ),
            const Icon(Icons.chevron_right, color: AuthColors.textSub),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPhotoSection(PaymentsState state) {
    if (state.receiptPhoto != null) {
      return Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
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
              icon: const Icon(Icons.close, color: AuthColors.textMain),
              style: IconButton.styleFrom(
                backgroundColor: AuthColors.background.withValues(alpha: 0.54),
              ),
              onPressed: () =>
                  context.read<PaymentsCubit>().removeReceiptPhoto(),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _pickReceiptPhoto,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.fromBorderSide(
              BorderSide(color: AuthColors.textMainWithOpacity(0.12))),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate,
                color: AuthColors.textSub, size: 40),
            SizedBox(height: AppSpacing.paddingSM),
            Text(
              'Add Receipt Photo',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      style: const TextStyle(color: AuthColors.textMain, fontSize: 16),
      decoration: _inputDecoration('Description (optional)'),
    );
  }

  Widget _buildPaymentAccountsSection(PaymentsState state) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null || _paymentAccountsCubit == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider.value(
      value: _paymentAccountsCubit!,
      child: BlocBuilder<PaymentAccountsCubit, PaymentAccountsState>(
        builder: (context, accountsState) {
          final accounts =
              accountsState.accounts.where((a) => a.isActive).toList();

          if (accounts.isEmpty) {
            return const SizedBox.shrink();
          }

          final totalAmount =
              double.tryParse(_amountController.text.replaceAll(',', '')) ??
                  0.0;
          final totalSplit = state.paymentAccountSplits.values
              .fold<double>(0.0, (sum, amt) => sum + amt);
          final remaining = totalAmount - totalSplit;
          final hasSplits = state.paymentAccountSplits.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Account *',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
                            ? AuthColors.success
                            : AuthColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.paddingSM),
              Container(
                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border:
                      Border.all(color: AuthColors.textMainWithOpacity(0.12)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts.map((account) {
                    final isSelected =
                        state.paymentAccountSplits.containsKey(account.id);
                    return _PaymentAccountChip(
                      account: account,
                      isSelected: isSelected,
                      onTap: () {
                        final cubit = context.read<PaymentsCubit>();
                        if (isSelected) {
                          cubit.removePaymentAccountSplit(account.id);
                          return;
                        }
                        final selectedIds =
                            cubit.state.paymentAccountSplits.keys.toList();
                        for (final id in selectedIds) {
                          cubit.removePaymentAccountSplit(id);
                        }
                        final amount = totalAmount > 0 ? totalAmount : 0.0;
                        cubit.updatePaymentAccountSplit(account.id, amount);
                      },
                    );
                  }).toList(),
                ),
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
      state.paymentAccountSplits.isNotEmpty &&
      !state.isSubmitting;

    return SizedBox(
      width: double.infinity,
      child: DashButton(
        label: 'Record Payment',
        onPressed: isEnabled ? _submitPayment : null,
        isLoading: state.isSubmitting,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AuthColors.textSub,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AuthColors.textSub),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: AuthColors.textSub, size: 18),
      filled: true,
      fillColor: AuthColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(color: AuthColors.primary, width: 2),
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
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: const BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.paddingLG),
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.24),
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            ),
          ),
          const Text(
            'Select Client',
            style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: AuthColors.textMain),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                      onPressed: () {
                        _searchController.clear();
                        context.read<ClientsCubit>().search('');
                      },
                    )
                  : null,
              hintText: 'Search clients by name or phone',
              hintStyle: TextStyle(color: AuthColors.textMainWithOpacity(0.38)),
              filled: true,
              fillColor: AuthColors.backgroundAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
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
                      style: const TextStyle(color: AuthColors.textSub),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AuthColors.primary,
                        child: Text(
                          client.name.isNotEmpty
                              ? client.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: AuthColors.textMain),
                        ),
                      ),
                      title: Text(client.name,
                          style: const TextStyle(color: AuthColors.textMain)),
                      subtitle: client.primaryPhone != null
                          ? Text(client.primaryPhone!,
                              style: const TextStyle(color: AuthColors.textSub))
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

class _PaymentAccountChip extends StatelessWidget {
  const _PaymentAccountChip({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentAccount account;
  final bool isSelected;
  final VoidCallback onTap;

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLG,
          vertical: AppSpacing.paddingMD,
        ),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          border: Border.all(
            color: isSelected
                ? AuthColors.primaryWithOpacity(0.5)
                : AuthColors.textMainWithOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getAccountTypeIcon(account.type),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            Text(
              account.name,
              style: TextStyle(
                color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSpacing.paddingSM),
              const Icon(
                Icons.check_circle,
                color: AuthColors.primary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
