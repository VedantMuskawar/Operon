import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organization')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment recorded successfully. Photo upload failed: $photoUploadError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/transactions');
          }
        });
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
                    _selectedClientName ?? 'Select Client',
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
                child: FutureBuilder<Uint8List>(
                  future: Future.value(_receiptPhotoBytes!),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey[800],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white70, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: Colors.white70),
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
                            color: Colors.grey[800],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white70),
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
                                child: CircularProgressIndicator(color: Colors.white70),
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
      backgroundColor: const Color(0xFF1B1B2C),
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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
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

