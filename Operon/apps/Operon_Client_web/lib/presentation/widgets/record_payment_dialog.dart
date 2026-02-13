import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:core_ui/core_ui.dart'
  show AuthColors, DashButton, DashButtonVariant, DashDialog, DashSnackbar, DashTheme, DialogActionHandler;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class RecordPaymentDialog extends StatefulWidget {
  const RecordPaymentDialog({super.key});

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> with DialogActionHandler {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedClientId;
  String? _selectedClientName;
  double? _currentBalance;
  PlatformFile? _selectedReceiptPhoto;
  Uint8List? _receiptPhotoBytes;
  final _descriptionController = TextEditingController();
  List<PaymentAccount> _paymentAccounts = [];
  PaymentAccount? _selectedPaymentAccount;
  bool _isLoadingPaymentAccounts = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaymentAccounts();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentAccounts() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;
    setState(() => _isLoadingPaymentAccounts = true);
    try {
      final repository = context.read<PaymentAccountsRepository>();
      final accounts = await repository.fetchAccounts(organization.id);
      final active = accounts.where((a) => a.isActive).toList();
      if (!mounted) return;
      setState(() {
        _paymentAccounts = active;
        if (active.isEmpty) {
          _selectedPaymentAccount = null;
        } else {
          _selectedPaymentAccount = active.firstWhere(
            (a) => a.isPrimary,
            orElse: () => active.first,
          );
        }
        _isLoadingPaymentAccounts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPaymentAccounts = false);
        DashSnackbar.show(
          context,
          message: 'Failed to load payment accounts: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildPaymentAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Account',
          style: TextStyle(
            color: AuthColors.textSub,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingPaymentAccounts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_paymentAccounts.isEmpty)
          Text(
            'No payment accounts available. Add one in Settings → Payment Accounts.',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentAccounts.map((account) {
              final isSelected = _selectedPaymentAccount?.id == account.id;
              return ChoiceChip(
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedPaymentAccount = account),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _paymentAccountIcon(account.type),
                      size: 16,
                      color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      account.name,
                      style: TextStyle(
                        color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (account.isPrimary) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Primary',
                        style: TextStyle(
                          color: isSelected ? AuthColors.primary : AuthColors.textDisabled,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                selectedColor: AuthColors.primaryWithOpacity(0.18),
                backgroundColor: AuthColors.backgroundAlt,
                side: BorderSide(
                  color: isSelected ? AuthColors.primary : AuthColors.textMainWithOpacity(0.1),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  IconData _paymentAccountIcon(PaymentAccountType type) {
    switch (type) {
      case PaymentAccountType.bank:
        return Icons.account_balance;
      case PaymentAccountType.cash:
        return Icons.money;
      case PaymentAccountType.upi:
        return Icons.qr_code;
      case PaymentAccountType.other:
        return Icons.payments;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _formatCurrency(double amount) {
    return '₹' + amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description (optional)',
        labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 12),
        filled: true,
        fillColor: AuthColors.backgroundAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuthColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (value) {
        // Optional: allow empty description
        return null;
      },
    );
  }

  Future<void> _selectClient() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    print('[DEBUG] _selectClient called in RecordPaymentDialog for orgId: \'${organization?.id}\'');
    if (organization == null) {
      DashSnackbar.show(context, message: 'Please select an organization', isError: true);
      return;
    }

    final clientsRepository = context.read<ClientsRepository>();
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: AuthColors.background.withOpacity(0.7),
      builder: (dialogContext) {
        print('[DEBUG] Building BlocProvider for _ClientSelectionDialog in RecordPaymentDialog');
        return BlocProvider(
          create: (_) => ClientsCubit(
            repository: clientsRepository,
            orgId: organization.id,
            analyticsRepository: context.read<AnalyticsRepository>(),
          )..loadRecentClients(),
          child: _ClientSelectionDialog(organizationId: organization.id),
        );
      },
    );

    if (client != null && mounted) {
      setState(() {
        _selectedClientId = client['id'] as String;
        _selectedClientName = client['name'] as String;
        _currentBalance = null;
      });
      _fetchClientBalance();
    }
  }

  Future<void> _fetchClientBalance() async {
    if (_selectedClientId == null) return;

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final fyStartYear = month >= 4 ? year : year - 1;
      final fyEndYear = fyStartYear + 1;
      final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
      final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
      final financialYear = 'FY$startStr$endStr';

      final ledgerDoc = await FirebaseFirestore.instance
          .collection('CLIENT_LEDGERS')
          .doc('${_selectedClientId}_$financialYear')
          .get();

      if (ledgerDoc.exists) {
        final balance = (ledgerDoc.data()?['currentBalance'] as num?)?.toDouble();
        setState(() {
          _currentBalance = balance ?? 0.0;
        });
      } else {
        setState(() {
          _currentBalance = 0.0;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  // ignore: unused_element
  Future<String?> _uploadReceiptPhoto(String transactionId) async {
    if (_receiptPhotoBytes == null || _selectedClientId == null) return null;
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) {
        return null;
      }
      final storageRef = FirebaseStorage.instance
        .ref()
        .child('payments')
        .child(organization.id)
        .child(_selectedClientId!)
        .child(transactionId)
        .child('receipt.jpg');
      await storageRef.putData(
        _receiptPhotoBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  void _removeReceiptPhoto() {
    setState(() {
      _selectedReceiptPhoto = null;
      _receiptPhotoBytes = null;
    });
  }

  Future<void> _pickReceiptPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() {
        _selectedReceiptPhoto = file;
        _receiptPhotoBytes = file.bytes;
      });
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to pick photo: $e', isError: true);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: DashTheme.light(), child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixText: '₹',
        filled: true,
        fillColor: AuthColors.backgroundAlt,
        labelStyle: const TextStyle(color: AuthColors.textSub, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuthColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Enter amount';
        final parsed = double.tryParse(value.replaceAll(',', ''));
        if (parsed == null || parsed <= 0) return 'Enter a valid amount';
        return null;
      },
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      DashSnackbar.show(context, message: 'Please select a client', isError: true);
      return;
    }
    if (_selectedDate == null) {
      DashSnackbar.show(context, message: 'Please select a date', isError: true);
      return;
    }
    if (_selectedPaymentAccount == null) {
      DashSnackbar.show(context, message: 'Please select a payment account', isError: true);
      return;
    }
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      DashSnackbar.show(context, message: 'Please enter a valid amount', isError: true);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) {
      DashSnackbar.show(context, message: 'No organization selected', isError: true);
      return;
    }

    await runDialogAction(() async {
      try {
        final selectedDate = _selectedDate ?? DateTime.now();
        final month = selectedDate.month;
        final year = selectedDate.year;
        final fyStartYear = month >= 4 ? year : year - 1;
        final fyEndYear = fyStartYear + 1;
        final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
        final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
        final financialYear = 'FY$startStr$endStr';

        final transactionData = {
          'organizationId': organization.id,
          'clientId': _selectedClientId,
          if (_selectedClientName != null) 'clientName': _selectedClientName,
          'ledgerType': 'clientLedger',
          'type': 'debit',
          'category': 'clientPayment',
          'amount': amount,
          'financialYear': financialYear,
          'createdAt': Timestamp.fromDate(selectedDate),
          'updatedAt': Timestamp.fromDate(selectedDate),
          'createdBy': currentUser.uid,
          'transactionDate': Timestamp.fromDate(selectedDate),
          'paymentAccountId': _selectedPaymentAccount!.id,
          'paymentAccountName': _selectedPaymentAccount!.name,
          'paymentAccountType': _selectedPaymentAccount!.type.name,
          if (_descriptionController.text.trim().isNotEmpty)
            'description': _descriptionController.text.trim(),
          'metadata': {
            'recordedVia': 'web-app',
            'photoUploaded': _selectedReceiptPhoto != null,
          },
        };

        final transactionDocRef = await FirebaseFirestore.instance
            .collection('TRANSACTIONS')
            .add(transactionData);
        final transactionId = transactionDocRef.id;

        String? photoUrl;
        bool photoUploadFailed = false;
        String? photoUploadError;

        if (_selectedReceiptPhoto != null) {
          try {
            photoUrl = await _uploadReceiptPhoto(transactionId);
            await transactionDocRef.update({
              'metadata.receiptPhotoUrl': photoUrl,
              'metadata.receiptPhotoPath':
                  'payments/${organization.id}/$_selectedClientId/$transactionId/receipt.jpg',
            });
          } catch (e) {
            photoUploadFailed = true;
            photoUploadError = e.toString();
          }
        }

        if (mounted) {
          if (photoUploadFailed) {
            DashSnackbar.show(
              context,
              message:
                  'Payment recorded successfully. Photo upload failed: $photoUploadError',
              isError: false,
            );
          } else {
            DashSnackbar.show(context,
                message: 'Payment recorded successfully', isError: false);
          }
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          DashSnackbar.show(context,
              message: 'Failed to record payment: $e', isError: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasClient = _selectedClientId != null;
    final hasBalance = _currentBalance != null;
    final date = _selectedDate;
    final dateLabel = date == null
        ? 'Select Date'
        : '${date.day} ${_getMonthName(date.month)} ${date.year}';

    return DashDialog(
      title: 'Record Payment',
      icon: Icons.payments_outlined,
      onClose: () => Navigator.of(context).pop(),
      constraints: const BoxConstraints(maxWidth: 640),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCard(
                title: 'Client',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _selectClient,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AuthColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AuthColors.textMainWithOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline,
                                color: hasClient ? AuthColors.textMain : AuthColors.textSub),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedClientName ?? 'Select Client',
                                style: TextStyle(
                                  color: hasClient ? AuthColors.textMain : AuthColors.textSub,
                                  fontWeight: hasClient ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AuthColors.textSub),
                          ],
                        ),
                      ),
                    ),
                    if (hasClient && hasBalance) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current balance: ${_formatCurrency(_currentBalance!)}',
                        style: const TextStyle(color: AuthColors.textSub, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Payment details',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildAmountField()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AuthColors.backgroundAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AuthColors.textMainWithOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      color: AuthColors.textSub, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                        color: date == null
                                            ? AuthColors.textSub
                                            : AuthColors.textMain,
                                        fontWeight:
                                            date == null ? FontWeight.w400 : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentAccountSection(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionCard(
                title: 'Notes & receipt',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDescriptionField(),
                    const SizedBox(height: 12),
                    if (_selectedReceiptPhoto != null && _receiptPhotoBytes != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AuthColors.backgroundAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_outlined, color: AuthColors.textSub),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedReceiptPhoto!.name,
                                style: const TextStyle(color: AuthColors.textMain),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AuthColors.textSub),
                              onPressed: _removeReceiptPhoto,
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _pickReceiptPhoto,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload receipt photo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: AuthColors.primary,
                          side: const BorderSide(color: AuthColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.text,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Record Payment',
                    onPressed: _submitPayment,
                    isLoading: isDialogActionLoading,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ClientSelectionDialog extends StatefulWidget {
  const _ClientSelectionDialog({required this.organizationId});
  final String organizationId;

  @override
  State<_ClientSelectionDialog> createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<_ClientSelectionDialog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch(BuildContext context) {
    _searchController.clear();
    context.read<ClientsCubit>().search('');
  }

  void _onClientSelected(Client client) {
    Navigator.of(context).pop({
      'id': client.id,
      'name': client.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthColors.surface, AuthColors.background],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Client',
                    style: TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AuthColors.textSub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSearchBar(context),
            const SizedBox(height: 20),
            Expanded(
              child: BlocBuilder<ClientsCubit, ClientsState>(
                builder: (context, state) {
                  if (state.searchQuery.isNotEmpty) {
                    return _SearchResultsSection(
                      state: state,
                      onClear: () => _clearSearch(context),
                      onClientSelected: _onClientSelected,
                    );
                  }
                  return _RecentClientsSection(
                    state: state,
                    onClientSelected: _onClientSelected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
        return TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AuthColors.textMain),
          onChanged: (value) => context.read<ClientsCubit>().search(value),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: () => _clearSearch(context),
                  )
                : null,
            hintText: 'Search clients by name or phone',
            hintStyle: const TextStyle(color: AuthColors.textDisabled),
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.state,
    required this.onClear,
    required this.onClientSelected,
  });

  final ClientsState state;
  final VoidCallback onClear;
  final ValueChanged<Client> onClientSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DashButton(
                label: 'Clear',
                onPressed: onClear,
                variant: DashButtonVariant.text,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.isSearchLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No clients found for "${state.searchQuery}".',
                style: const TextStyle(color: AuthColors.textSub),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: state.searchResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final client = state.searchResults[index];
                  return _ClientTile(
                    client: client,
                    onTap: () => onClientSelected(client),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentClientsSection extends StatelessWidget {
  const _RecentClientsSection({
    required this.state,
    required this.onClientSelected,
  });

  final ClientsState state;
  final ValueChanged<Client> onClientSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Clients',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (state.isRecentLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.recentClients.isEmpty && !state.isRecentLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No clients found. Please create a client first.',
              style: TextStyle(color: AuthColors.textSub),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: state.recentClients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final client = state.recentClients[index];
                return _ClientTile(
                  client: client,
                  onTap: () => onClientSelected(client),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.client,
    required this.onTap,
  });

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phoneLabel = client.primaryPhone ??
        (client.phones.isNotEmpty
            ? (client.phones.first['number'] as String? ?? '-')
            : '-');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuthColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AuthColors.primaryWithOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: AuthColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phoneLabel,
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AuthColors.textSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
