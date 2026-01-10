import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PaymentAccountsPage extends StatelessWidget {
  const PaymentAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentAccountsCubit, PaymentAccountsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: const ModernPageHeader(
          title: 'Payment Accounts',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Add Payment Account',
                onPressed: () => _openAccountDialog(context),
              ),
            ),
            const SizedBox(height: 24),
            BlocBuilder<PaymentAccountsCubit, PaymentAccountsState>(
              builder: (context, state) {
                if (state.status == ViewStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.accounts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No payment accounts yet. Tap "Add Payment Account" to create one.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final account = state.accounts[index];
                    return _AccountTile(
                      account: account,
                      onEdit: () => _openAccountDialog(context, account: account),
                      onDelete: () => context.read<PaymentAccountsCubit>().deleteAccount(account.id),
                      onSetPrimary: () => context.read<PaymentAccountsCubit>().setPrimaryAccount(account.id),
                      onUnsetPrimary: () => context.read<PaymentAccountsCubit>().unsetPrimaryAccount(account.id),
                    );
                  },
                );
              },
            ),
          ],
                ),
                      ),
                    ),
            QuickNavBar(
              currentIndex: 4,
              onTap: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openAccountDialog(
    BuildContext context, {
    PaymentAccount? account,
  }) async {
    final cubit = context.read<PaymentAccountsCubit>();
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: _AccountDialog(account: account),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrimary,
    required this.onUnsetPrimary,
  });

  final PaymentAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;
  final VoidCallback onUnsetPrimary;

  IconData get _typeIcon {
    switch (account.type) {
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

  Color get _typeColor {
    switch (account.type) {
      case PaymentAccountType.bank:
        return const Color(0xFF2196F3);
      case PaymentAccountType.cash:
        return const Color(0xFF4CAF50);
      case PaymentAccountType.upi:
        return const Color(0xFF6F4BFF);
      case PaymentAccountType.other:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = account.isPrimary
        ? [
            const Color(0xFF2C1F40),
            const Color(0xFF1C122D),
            const Color(0xFF110A1E),
          ]
        : [
            const Color(0xFF1A1A2A),
            const Color(0xFF0A0A0A),
            const Color(0xFF0D0D14),
          ];

    final borderColor = account.isPrimary
        ? const Color(0xFFFFC857).withOpacity(0.6)
        : account.isActive
            ? _typeColor.withOpacity(0.35)
            : Colors.white10;

    final iconBackground = account.isPrimary
        ? const Color(0xFFFFC857).withOpacity(0.15)
        : _typeColor.withOpacity(0.2);

    final iconBorderColor = account.isPrimary
        ? const Color(0xFFFFC857).withOpacity(0.6)
        : _typeColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: iconBorderColor,
                width: 1.5,
              ),
            ),
            child: Icon(
              _typeIcon,
              color: _typeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _typeColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      account.type.name.toUpperCase(),
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                if (account.accountNumber != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Account: ${account.accountNumber}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (account.upiId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'UPI: ${account.upiId}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (account.qrCodeImageUrl != null) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 14,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'QR Code Available',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ActionButton(
                icon: account.isPrimary ? Icons.star : Icons.star_border,
                color:
                    account.isPrimary ? const Color(0xFFFFD700) : Colors.white54,
                onPressed: account.isPrimary ? onUnsetPrimary : onSetPrimary,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF6F4BFF),
                onPressed: onEdit,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.delete_outline,
                color: Colors.redAccent,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.account});

  final PaymentAccount? account;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _ifscCodeController;
  late final TextEditingController _upiIdController;
  
  PaymentAccountType _type = PaymentAccountType.bank;
  bool _isActive = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _accountNumberController = TextEditingController(text: account?.accountNumber ?? '');
    _ifscCodeController = TextEditingController(text: account?.ifscCode ?? '');
    _upiIdController = TextEditingController(text: account?.upiId ?? '');
    _type = account?.type ?? PaymentAccountType.bank;
    _isActive = account?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(400.0, 600.0);

    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      title: Text(
        isEditing ? 'Edit Payment Account' : 'Add Payment Account',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Account Name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter account name'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentAccountType>(
                  initialValue: _type,
                  dropdownColor: const Color(0xFF1B1B2C),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Account Type'),
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                  items: PaymentAccountType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                ),
                if (_type == PaymentAccountType.bank) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNumberController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Account Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ifscCodeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('IFSC Code'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('UPI ID (Optional)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_upiIdController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF6F4BFF),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'QR code will be auto-generated from UPI ID',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (_type == PaymentAccountType.upi) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiIdController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('UPI ID'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Enter UPI ID'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF6F4BFF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'QR code will be auto-generated from UPI ID',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Active',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  activeThumbColor: const Color(0xFF6F4BFF),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  setState(() => _isSubmitting = true);

                  try {
                    final cubit = context.read<PaymentAccountsCubit>();
                    final orgState = context.read<OrganizationContextCubit>().state;
                    final organizationId = orgState.organization?.id ?? '';
                    
                    if (organizationId.isEmpty) {
                      throw Exception('No organization selected');
                    }

                    final account = PaymentAccount(
                      id: widget.account?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      organizationId: organizationId,
                      name: _nameController.text.trim(),
                      type: _type,
                      accountNumber: _accountNumberController.text.trim().isEmpty
                          ? null
                          : _accountNumberController.text.trim(),
                      ifscCode: _ifscCodeController.text.trim().isEmpty
                          ? null
                          : _ifscCodeController.text.trim(),
                      upiId: _upiIdController.text.trim().isEmpty
                          ? null
                          : _upiIdController.text.trim(),
                      isActive: _isActive,
                    );

                    if (isEditing) {
                      await cubit.updateAccount(account);
                    } else {
                      await cubit.createAccount(account);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to ${isEditing ? 'update' : 'create'} account: ${e.toString()}',
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

