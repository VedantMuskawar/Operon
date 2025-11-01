import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/payment_account.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';

class AndroidPaymentAccountFormDialog extends StatefulWidget {
  final PaymentAccount? account;
  final Function(PaymentAccount) onSubmit;

  const AndroidPaymentAccountFormDialog({
    super.key,
    this.account,
    required this.onSubmit,
  });

  @override
  State<AndroidPaymentAccountFormDialog> createState() => _AndroidPaymentAccountFormDialogState();
}

class _AndroidPaymentAccountFormDialogState extends State<AndroidPaymentAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountIdController;
  late TextEditingController _accountNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _bankNameController;
  late TextEditingController _ifscCodeController;

  String? _selectedAccountType;
  String _selectedStatus = PaymentAccountStatus.active;
  String _currency = 'INR';
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _accountIdController = TextEditingController();
    _accountNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _bankNameController = TextEditingController();
    _ifscCodeController = TextEditingController();

    if (widget.account != null) {
      _accountIdController.text = widget.account!.accountId;
      _accountNameController.text = widget.account!.accountName;
      _selectedAccountType = widget.account!.accountType;
      _accountNumberController.text = widget.account!.accountNumber ?? '';
      _bankNameController.text = widget.account!.bankName ?? '';
      _ifscCodeController.text = widget.account!.ifscCode ?? '';
      _selectedStatus = widget.account!.status;
      _currency = widget.account!.currency;
      _isDefault = widget.account!.isDefault;
    } else {
      _accountIdController.text = _generateAccountId();
    }
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
  }

  String _generateAccountId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(21, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedAccountType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select account type')),
        );
        return;
      }

      final account = PaymentAccount(
        id: widget.account?.id,
        accountId: _accountIdController.text.trim(),
        accountName: _accountNameController.text.trim(),
        accountType: _selectedAccountType!,
        accountNumber: _accountNumberController.text.trim().isEmpty ? null : _accountNumberController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
        ifscCode: _ifscCodeController.text.trim().isEmpty ? null : _ifscCodeController.text.trim(),
        currency: _currency,
        status: _selectedStatus,
        isDefault: _isDefault,
        createdAt: widget.account?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.account?.createdBy,
        updatedBy: widget.account?.updatedBy,
      );

      widget.onSubmit(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.account == null ? 'Add Payment Account' : 'Edit Payment Account',
                      style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: AppTheme.textSecondaryColor,
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _accountIdController,
                          decoration: InputDecoration(
                            labelText: 'Account ID',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            enabled: widget.account == null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Account ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _accountNameController,
                          decoration: InputDecoration(
                            labelText: 'Account Name',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Account name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedAccountType,
                          decoration: InputDecoration(
                            labelText: 'Account Type',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          dropdownColor: AppTheme.surfaceColor,
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          items: PaymentAccountType.all.map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedAccountType = value),
                          validator: (value) => value == null ? 'Please select account type' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _accountNumberController,
                          decoration: InputDecoration(
                            labelText: 'Account Number (Optional)',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bankNameController,
                          decoration: InputDecoration(
                            labelText: 'Bank Name (Optional)',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ifscCodeController,
                          decoration: InputDecoration(
                            labelText: 'IFSC Code (Optional)',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                              borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                            ),
                          ),
                          dropdownColor: AppTheme.surfaceColor,
                          style: const TextStyle(color: AppTheme.textPrimaryColor),
                          items: PaymentAccountStatus.all.map((status) {
                            return DropdownMenuItem(value: status, child: Text(status));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedStatus = value!),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('Set as Default', style: TextStyle(color: AppTheme.textPrimaryColor)),
                          value: _isDefault,
                          onChanged: (value) => setState(() => _isDefault = value ?? false),
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.account == null ? 'Add Account' : 'Update Account',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

