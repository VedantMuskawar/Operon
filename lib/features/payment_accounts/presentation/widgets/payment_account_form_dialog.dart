import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../models/payment_account.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/theme/app_theme.dart';
import 'dart:math';

class PaymentAccountFormDialog extends StatefulWidget {
  final PaymentAccount? account;
  final Function(PaymentAccount) onSubmit;
  final Function() onCancel;

  const PaymentAccountFormDialog({
    super.key,
    this.account,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<PaymentAccountFormDialog> createState() => _PaymentAccountFormDialogState();
}

class _PaymentAccountFormDialogState extends State<PaymentAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountIdController;
  late TextEditingController _accountNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _bankNameController;
  late TextEditingController _ifscCodeController;
  late TextEditingController _currencyController;

  bool _autoGenerateId = true;
  String _selectedType = '';
  String _selectedStatus = PaymentAccountStatus.active;
  String _selectedCurrency = 'INR';
  bool _isDefault = false;
  dynamic _selectedQrFile; // File on mobile, Uint8List on web
  String? _selectedQrFileName;
  String? _currentQrUrl;

  Map<String, String> _errors = {};

  final List<String> _currencyOptions = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'AUD',
    'CAD',
    'CHF',
    'CNY',
  ];

  @override
  void initState() {
    super.initState();
    
    _accountIdController = TextEditingController();
    _accountNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _bankNameController = TextEditingController();
    _ifscCodeController = TextEditingController();
    _currencyController = TextEditingController();

    if (widget.account != null) {
      // Editing existing account
      _autoGenerateId = false;
      _accountIdController.text = widget.account!.accountId;
      _accountNameController.text = widget.account!.accountName;
      _selectedType = widget.account!.accountType;
      _selectedStatus = widget.account!.status;
      _accountNumberController.text = widget.account!.accountNumber ?? '';
      _bankNameController.text = widget.account!.bankName ?? '';
      _ifscCodeController.text = widget.account!.ifscCode ?? '';
      _selectedCurrency = widget.account!.currency;
      _currencyController.text = widget.account!.currency;
      _isDefault = widget.account!.isDefault;
      _currentQrUrl = widget.account!.staticQr;
    } else {
      // New account - generate ID if auto-generate is enabled
      if (_autoGenerateId) {
        _accountIdController.text = _generateAccountId();
      }
      _currencyController.text = 'INR';
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _ifscCodeController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  String _generateAccountId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return 'PAY${String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    )}';
  }

  void _onAutoGenerateChanged(bool value) {
    setState(() {
      _autoGenerateId = value;
      if (value) {
        _accountIdController.text = _generateAccountId();
      } else {
        _accountIdController.text = '';
      }
    });
  }

  void _regenerateId() {
    if (_autoGenerateId) {
      setState(() {
        _accountIdController.text = _generateAccountId();
      });
    }
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors.remove(field);
      });
    }
  }

  bool _validateForm() {
    _errors.clear();
    bool isValid = true;

    if (_accountIdController.text.trim().isEmpty) {
      _errors['accountId'] = 'Account ID is required';
      isValid = false;
    }

    if (_accountNameController.text.trim().isEmpty) {
      _errors['accountName'] = 'Account name is required';
      isValid = false;
    }

    if (_selectedType.isEmpty) {
      _errors['accountType'] = 'Account type is required';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  void _handleSubmit() {
    if (!_validateForm()) {
      return;
    }

    final now = DateTime.now();
    final account = PaymentAccount(
      id: widget.account?.id,
      accountId: _accountIdController.text.trim(),
      accountName: _accountNameController.text.trim(),
      accountType: _selectedType,
      accountNumber: _accountNumberController.text.trim().isEmpty 
          ? null 
          : _accountNumberController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty 
          ? null 
          : _bankNameController.text.trim(),
      ifscCode: _ifscCodeController.text.trim().isEmpty 
          ? null 
          : _ifscCodeController.text.trim(),
      currency: _selectedCurrency,
      status: _selectedStatus,
      isDefault: _isDefault,
      staticQr: _currentQrUrl, // Will be handled via file upload separately
      createdAt: widget.account?.createdAt ?? now,
      updatedAt: now,
      createdBy: widget.account?.createdBy,
      updatedBy: null,
    );

    widget.onSubmit(account);
  }

  Future<void> _pickQrImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        if (pickedFile.bytes != null) {
          setState(() {
            _selectedQrFile = pickedFile.bytes;
            _selectedQrFileName = pickedFile.name;
          });
          // In a real implementation, you would upload this to Firebase Storage
          // and set the URL. For now, we'll just store the file reference.
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick QR image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F1F1F),
              Color(0xFF2A2A2A),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0x33FFFFFF),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💳', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Text(
                        widget.account == null 
                            ? 'Add Payment Account' 
                            : 'Edit Payment Account',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00C3FF),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: const Color(0xFFFF4444),
                        onPressed: widget.onCancel,
                      ),
                    ],
                  ),
                ),
                
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information Section
                          _buildSectionTitle('📋 Basic Information'),
                          const SizedBox(height: 16),
                          
                          // Account ID
                          _buildAccountIdField(),
                          const SizedBox(height: 16),
                          
                          // Account Name and Type
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _accountNameController,
                                  labelText: 'Account Name *',
                                  hintText: 'e.g., Main Bank Account',
                                  errorText: _errors['accountName'],
                                  onChanged: (_) => _clearError('accountName'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedType.isEmpty ? null : _selectedType,
                                  labelText: 'Account Type *',
                                  hintText: 'Select Type',
                                  errorText: _errors['accountType'],
                                  items: PaymentAccountType.all.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedType = value ?? '';
                                      _clearError('accountType');
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Account Details Section
                          _buildSectionTitle('💰 Account Details'),
                          const SizedBox(height: 16),
                          
                          // Account Number
                          CustomTextField(
                            controller: _accountNumberController,
                            labelText: 'Account Number',
                            hintText: 'Enter account number',
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          
                          // Bank Name and IFSC Code
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _bankNameController,
                                  labelText: 'Bank Name',
                                  hintText: 'Enter bank name',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomTextField(
                                  controller: _ifscCodeController,
                                  labelText: 'IFSC Code',
                                  hintText: 'Enter IFSC code',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Currency and Status
                          Row(
                            children: [
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedCurrency,
                                  labelText: 'Currency',
                                  items: _currencyOptions.map((currency) {
                                    return DropdownMenuItem(
                                      value: currency,
                                      child: Text(currency),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCurrency = value ?? 'INR';
                                      _currencyController.text = _selectedCurrency;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomDropdown<String>(
                                  value: _selectedStatus,
                                  labelText: 'Status',
                                  items: PaymentAccountStatus.all.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStatus = value ?? PaymentAccountStatus.active;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          
                          // Payment Settings Section
                          _buildSectionTitle('⚙️ Payment Settings'),
                          const SizedBox(height: 16),
                          
                          // Is Default Checkbox
                          CheckboxListTile(
                            title: const Text(
                              'Set as Default Account',
                              style: TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'This will be used as the default payment account',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() {
                                _isDefault = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF00C3FF),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                          
                          // Static QR Code Section
                          _buildSectionTitle('📱 Static QR Code'),
                          const SizedBox(height: 16),
                          
                          _buildQrSection(),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0x33FFFFFF),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A84FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          widget.account == null 
                              ? 'Add Account' 
                              : 'Update Account',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00C3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoGenerateId,
              onChanged: widget.account == null
                  ? (value) => _onAutoGenerateChanged(value ?? true)
                  : null,
            ),
            const Text(
              'Auto-generate Account ID',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _accountIdController,
                labelText: 'Account ID *',
                hintText: _autoGenerateId
                    ? 'Auto-generated ID'
                    : 'e.g., PAY001, MAIN_ACC',
                errorText: _errors['accountId'],
                enabled: !_autoGenerateId || widget.account != null,
                onChanged: (_) => _clearError('accountId'),
              ),
            ),
            if (_autoGenerateId && widget.account == null) ...[
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _regenerateId,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('🔄 Regenerate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C3FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQrSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // QR Preview
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4B5563)),
              ),
              child: _selectedQrFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedQrFile as Uint8List,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _currentQrUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _currentQrUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.qr_code,
                                color: Colors.white70,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.qr_code,
                          color: Colors.white70,
                          size: 32,
                        ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickQrImage,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Upload QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF374151),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  const Text(
                    'Recommended: Square image, PNG or JPG',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

