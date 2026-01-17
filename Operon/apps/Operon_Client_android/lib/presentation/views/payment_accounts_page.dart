import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
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
        backgroundColor: AuthColors.background,
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
                        color: AuthColors.textSub,
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
                    return _AccountDataListItem(
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
                  icon: Icons.dashboard_rounded,
                  label: 'Analytics',
                  heroTag: 'nav_analytics',
                ),
              ],
              currentIndex: -1,
              onItemTapped: (index) {
                context.go('/home', extra: index);
              },
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

class _AccountDataListItem extends StatelessWidget {
  const _AccountDataListItem({
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

  Color get _typeColor {
    switch (account.type) {
      case PaymentAccountType.bank:
        return AuthColors.primary;
      case PaymentAccountType.cash:
        return AuthColors.success;
      case PaymentAccountType.upi:
        return AuthColors.primary;
      case PaymentAccountType.other:
        return AuthColors.secondary;
    }
  }

  String _formatSubtitle() {
    final parts = <String>[];
    parts.add(account.type.name.toUpperCase());
    if (account.isPrimary) {
      parts.add('Primary');
    }
    if (account.accountNumber != null) {
      parts.add(account.accountNumber!);
    } else if (account.upiId != null) {
      parts.add(account.upiId!);
    }
    if (account.qrCodeImageUrl != null) {
      parts.add('QR Code');
    }
    return parts.join(' • ');
  }

  Color _getStatusColor() {
    if (!account.isActive) {
      return AuthColors.textDisabled;
    }
    return account.isPrimary ? AuthColors.secondary : _typeColor;
  }

  String _getInitial() {
    return account.name.isNotEmpty ? account.name[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DataList(
        title: account.name,
        subtitle: _formatSubtitle(),
        leading: DataListAvatar(
          initial: _getInitial(),
          radius: 28,
          statusRingColor: _getStatusColor(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DataListStatusDot(
              color: _getStatusColor(),
              size: 8,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                account.isPrimary ? Icons.star : Icons.star_border,
                color: account.isPrimary ? AuthColors.secondary : AuthColors.textSub,
                size: 20,
              ),
              onPressed: account.isPrimary ? onUnsetPrimary : onSetPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: account.isPrimary ? 'Remove Primary' : 'Set Primary',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: AuthColors.textSub,
                size: 20,
              ),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AuthColors.error,
                size: 20,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onEdit,
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
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Payment Account' : 'Add Payment Account',
        style: TextStyle(color: AuthColors.textMain),
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
                  style: TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Account Name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter account name'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PaymentAccountType>(
                  initialValue: _type,
                  dropdownColor: AuthColors.surface,
                  style: TextStyle(color: AuthColors.textMain),
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
                    style: TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('Account Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ifscCodeController,
                    style: TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('IFSC Code'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiIdController,
                    style: TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('UPI ID (Optional)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_upiIdController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AuthColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AuthColors.textMain.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AuthColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'QR code will be auto-generated from UPI ID',
                              style: TextStyle(
                                color: AuthColors.textSub,
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
                    style: TextStyle(color: AuthColors.textMain),
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
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AuthColors.textMain.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AuthColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'QR code will be auto-generated from UPI ID',
                            style: TextStyle(
                              color: AuthColors.textSub,
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
                  title: Text(
                    'Active',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  activeThumbColor: AuthColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: isEditing ? 'Save' : 'Create',
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
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

