import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
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

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedClientId;
  String? _selectedClientName;
  double? _currentBalance;
  bool _isSubmitting = false;
  PlatformFile? _selectedReceiptPhoto;
  Uint8List? _receiptPhotoBytes;
  
  // Payment account splits
  final Map<String, double> _accountSplits = {}; // accountId -> amount
  final Map<String, TextEditingController> _splitControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (var controller in _splitControllers.values) {
      controller.dispose();
    }
    _splitControllers.clear();
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
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organization')),
      );
      return;
    }

    final clientsRepository = context.read<ClientsRepository>();
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => BlocProvider(
        create: (_) => ClientsCubit(
          repository: clientsRepository,
          orgId: organization.id,
          analyticsRepository: context.read<AnalyticsRepository>(),
        )..loadRecentClients(),
        child: _ClientSelectionDialog(organizationId: organization.id),
      ),
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
    }
  }

  Future<void> _pickReceiptPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedReceiptPhoto = result.files.single;
          _receiptPhotoBytes = result.files.single.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeReceiptPhoto() {
    setState(() {
      _selectedReceiptPhoto = null;
      _receiptPhotoBytes = null;
    });
  }

  Future<String?> _uploadReceiptPhoto(String transactionId) async {
    if (_receiptPhotoBytes == null || _selectedClientId == null) return null;

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payments')
          .child(organization.id)
          .child(_selectedClientId!)
          .child(transactionId)
          .child('receipt.jpg');

      await storageRef.putData(
        _receiptPhotoBytes!,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Validate payment account splits if any are selected
    if (_accountSplits.isNotEmpty) {
      final totalSplit = _accountSplits.values.fold<double>(0.0, (sum, amt) => sum + amt);
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organization selected')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final fyStartYear = month >= 4 ? year : year - 1;
      final fyEndYear = fyStartYear + 1;
      final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
      final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
      final financialYear = 'FY$startStr$endStr';

      final transactionData = {
        'organizationId': organization.id,
        'clientId': _selectedClientId,
        'ledgerType': 'clientLedger',
        'type': 'debit',
        'category': 'clientPayment',
        'amount': amount,
        'financialYear': financialYear,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
        'transactionDate': Timestamp.fromDate(_selectedDate ?? DateTime.now()),
        'metadata': {
          'recordedVia': 'web-app',
          'photoUploaded': _selectedReceiptPhoto != null,
          if (_accountSplits.isNotEmpty)
            'paymentAccounts': _accountSplits.entries.map((e) => {
                  'accountId': e.key,
                  'amount': e.value,
                }).toList(),
        },
      };

      final transactionDocRef = await FirebaseFirestore.instance.collection('TRANSACTIONS').add(transactionData);
      final transactionId = transactionDocRef.id;

      String? photoUrl;
      bool photoUploadFailed = false;
      String? photoUploadError;
      
      if (_selectedReceiptPhoto != null) {
        try {
          photoUrl = await _uploadReceiptPhoto(transactionId);
          
          await transactionDocRef.update({
            'metadata.receiptPhotoUrl': photoUrl,
            'metadata.receiptPhotoPath': 'payments/${organization.id}/$_selectedClientId/$transactionId/receipt.jpg',
          });
        } catch (e) {
          photoUploadFailed = true;
          photoUploadError = e.toString();
        }
      }

      if (mounted) {
        if (photoUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment recorded successfully. Photo upload failed: $photoUploadError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'Please select an organization first',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Record Payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildClientSelection(),
                const SizedBox(height: 20),
                if (_selectedClientId != null && _currentBalance != null)
                  _buildCurrentBalance(_currentBalance!),
                if (_selectedClientId != null && _currentBalance != null)
                  const SizedBox(height: 20),
                _buildAmountField(),
                const SizedBox(height: 20),
                _buildPaymentAccountsSection(),
                const SizedBox(height: 20),
                _buildDateField(),
                const SizedBox(height: 20),
                _buildReceiptPhotoSection(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientSelection() {
    final hasClient = _selectedClientId != null;
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
              child: Text(
                _selectedClientName ?? 'Select Client',
                style: TextStyle(
                  color: hasClient ? Colors.white : Colors.white54,
                  fontSize: 16,
                  fontWeight: hasClient ? FontWeight.w600 : FontWeight.normal,
                ),
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

  Widget _buildPaymentAccountsSection() {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
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
          final totalSplit = _accountSplits.values.fold<double>(0.0, (sum, amt) => sum + amt);
          final remaining = totalAmount - totalSplit;
          final hasSplits = _accountSplits.isNotEmpty;

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
                  final isSelected = _accountSplits.containsKey(account.id);
                  return _PaymentAccountChip(
                    account: account,
                    isSelected: isSelected,
                    amount: _accountSplits[account.id] ?? 0.0,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _accountSplits.remove(account.id);
                          _splitControllers[account.id]?.dispose();
                          _splitControllers.remove(account.id);
                        } else {
                          _accountSplits[account.id] = 0.0;
                          _splitControllers[account.id] = TextEditingController();
                        }
                      });
                    },
                    onAmountChanged: (amount) {
                      setState(() {
                        _accountSplits[account.id] = amount;
                      });
                    },
                    controller: _splitControllers[account.id],
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

  Widget _buildReceiptPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Receipt Photo (Optional)',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        if (_selectedReceiptPhoto != null && _receiptPhotoBytes != null)
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
                  child: Image.memory(
                    _receiptPhotoBytes!,
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
                  onPressed: _removeReceiptPhoto,
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
                border: Border.all(color: Colors.white12),
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

  Widget _buildSubmitButton() {
    final isEnabled = _selectedClientId != null &&
        _amountController.text.isNotEmpty &&
        _selectedDate != null &&
        !_isSubmitting;

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
      child: _isSubmitting
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

class _ClientSelectionDialog extends StatelessWidget {
  const _ClientSelectionDialog({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Client',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<ClientsCubit, ClientsState>(
                builder: (context, state) {
                  final clients = state.recentClients;
                  
                  if (state.isRecentLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (clients.isEmpty) {
                    return const Center(
                      child: Text(
                        'No clients found',
                        style: TextStyle(color: Colors.white54),
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
                        onTap: () => Navigator.of(context).pop({
                          'id': client.id,
                          'name': client.name,
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    this.controller,
    required this.formatCurrency,
  });

  final PaymentAccount account;
  final bool isSelected;
  final double amount;
  final VoidCallback onTap;
  final ValueChanged<double> onAmountChanged;
  final TextEditingController? controller;
  final String Function(double) formatCurrency;

  @override
  State<_PaymentAccountChip> createState() => _PaymentAccountChipState();
}

class _PaymentAccountChipState extends State<_PaymentAccountChip> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = widget.controller ?? TextEditingController();
    if (widget.isSelected && widget.amount > 0) {
      _amountController.text = widget.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _amountController.dispose();
    }
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

