import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashFormField, DashSnackbar, DashTheme;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class RecordPaymentPage extends StatefulWidget {
  const RecordPaymentPage({super.key});

  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedClientId;
  String? _selectedClientName;
  double? _currentBalance;
  bool _isSubmitting = false;
  PlatformFile? _selectedReceiptPhoto;
  Uint8List? _receiptPhotoBytes;

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
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      DashSnackbar.show(context, message: 'Please select an organization', isError: true);
      return;
    }

    // Show client selection dialog
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ClientsCubit>(),
        child: _ClientSelectionDialog(organizationId: organization.id),
      ),
    );

    if (client != null && mounted) {
      setState(() {
        _selectedClientId = client['id'] as String;
        _selectedClientName = client['name'] as String;
        _currentBalance = null; // Will be fetched
      });
      
      // Fetch client balance
      _fetchClientBalance();
    }
  }

  Future<void> _fetchClientBalance() async {
    if (_selectedClientId == null) return;
    
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      // Get current financial year
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
      // Ignore error, balance will remain null
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
        DashSnackbar.show(context, message: 'Failed to pick image: $e', isError: true);
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
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

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      DashSnackbar.show(context, message: 'Please select a client', isError: true);
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current financial year
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;
      final fyStartYear = month >= 4 ? year : year - 1;
      final fyEndYear = fyStartYear + 1;
      final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
      final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
      final financialYear = 'FY$startStr$endStr';

      // Create transaction
      final transactionData = {
        'organizationId': organization.id,
        'clientId': _selectedClientId,
        'ledgerType': 'clientLedger',
        'type': 'debit', // Debit = client paid us (decreases receivable)
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
        },
      };

      final transactionDocRef = await FirebaseFirestore.instance.collection('TRANSACTIONS').add(transactionData);
      final transactionId = transactionDocRef.id;

      // Upload receipt photo if provided (optional - payment is already recorded)
      String? photoUrl;
      bool photoUploadFailed = false;
      String? photoUploadError;
      
      if (_selectedReceiptPhoto != null) {
        try {
          photoUrl = await _uploadReceiptPhoto(transactionId);
          
          // Update transaction with photo URL in metadata
          await transactionDocRef.update({
            'metadata.receiptPhotoUrl': photoUrl,
            'metadata.receiptPhotoPath': 'payments/${organization.id}/$_selectedClientId/$transactionId/receipt.jpg',
          });
        } catch (e) {
          // Photo upload failed, but transaction is already created successfully
          // Payment is recorded - photo upload is optional
          photoUploadFailed = true;
          photoUploadError = e.toString();
        }
      }

      // Payment is always recorded successfully (photo upload is optional)
      if (mounted) {
        if (photoUploadFailed) {
          // Show warning that photo upload failed, but payment was recorded
          DashSnackbar.show(
            context,
            message: 'Payment recorded successfully. Photo upload failed: $photoUploadError',
            isError: false,
          );
        } else {
          DashSnackbar.show(context, message: 'Payment recorded successfully', isError: false);
        }
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/transactions');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Failed to record payment: $e', isError: true);
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
    return SectionWorkspaceLayout(
      panelTitle: 'Record Payment',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client Selection
              _buildClientSelection(),
              const SizedBox(height: 20),

              // Current Balance (if client selected)
              if (_selectedClientId != null && _currentBalance != null)
                _buildCurrentBalance(_currentBalance!),

              // Payment Amount
              _buildAmountField(),
              const SizedBox(height: 20),

              // Payment Date
              _buildDateField(),
              const SizedBox(height: 20),

              // Receipt Photo
              _buildReceiptPhotoSection(),
              const SizedBox(height: 30),

              // Submit Button
              _buildSubmitButton(),
            ],
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
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasClient ? AuthColors.textMainWithOpacity(0.24) : AuthColors.textMainWithOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              color: hasClient ? AuthColors.textMain : AuthColors.textSub,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedClientName ?? 'Select Client',
                    style: TextStyle(
                      color: hasClient ? AuthColors.textMain : AuthColors.textSub,
                      fontSize: 16,
                      fontWeight: hasClient ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AuthColors.textSub),
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
                  style: TextStyle(color: AuthColors.textSub, fontSize: 12),
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
    return DashFormField(
      controller: _amountController,
      label: 'Payment Amount',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefix: Icon(Icons.currency_rupee, color: AuthColors.textSub),
      style: TextStyle(color: AuthColors.textMain, fontSize: 18),
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
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AuthColors.textSub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Date',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}'
                        : 'Select date',
                    style: TextStyle(color: AuthColors.textMain, fontSize: 16),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AuthColors.textSub),
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
          style: TextStyle(color: AuthColors.textSub, fontSize: 14),
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
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
                ),
                child: FutureBuilder<Uint8List>(
                  future: Future.value(_receiptPhotoBytes!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: AuthColors.surface,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: AuthColors.textSub, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: AuthColors.textSub),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: AuthColors.textSub),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        // Optimize memory usage for web
                        cacheWidth: 800,
                        cacheHeight: 600,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: AuthColors.surface,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: AuthColors.textSub, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: AuthColors.textSub),
                                ),
                              ],
                            ),
                          );
                        },
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) {
                            return child;
                          }
                          if (frame == null) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(color: AuthColors.textSub),
                              ),
                            );
                          }
                          return child;
                        },
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: AuthColors.textMain),
                  style: IconButton.styleFrom(
                    backgroundColor: AuthColors.background.withOpacity(0.54),
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
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.12)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, color: AuthColors.textSub, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Add Receipt Photo',
                    style: TextStyle(color: AuthColors.textSub),
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

    return DashButton(
      label: 'Record Payment',
      onPressed: isEnabled ? _submitPayment : null,
      isLoading: _isSubmitting,
    );
  }
}

class _ClientSelectionDialog extends StatelessWidget {
  const _ClientSelectionDialog({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      child: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Client',
                    style: TextStyle(color: AuthColors.textMain, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AuthColors.textSub),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AuthColors.textMainWithOpacity(0.12)),
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
                        style: TextStyle(color: AuthColors.textSub),
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
                            client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                            style: TextStyle(color: AuthColors.textMain),
                          ),
                        ),
                        title: Text(client.name, style: TextStyle(color: AuthColors.textMain)),
                        subtitle: client.primaryPhone != null
                            ? Text(client.primaryPhone!, style: TextStyle(color: AuthColors.textSub))
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

