import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:dash_web/domain/entities/payment_account.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_web/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PaymentAccountsPage extends StatelessWidget {
  const PaymentAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final orgId = orgState.organization?.id;
    final appAccessRole = orgState.appAccessRole;

    if (orgId == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    final visibleSections = appAccessRole != null
        ? _computeVisibleSections(appAccessRole)
        : const [0, 1, 2, 3, 4];

    return BlocProvider(
      create: (context) => PaymentAccountsCubit(
        repository: context.read<PaymentAccountsRepository>(),
        qrCodeService: context.read<QrCodeService>(),
        orgId: orgId,
      ),
      child: BlocListener<PaymentAccountsCubit, PaymentAccountsState>(
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.message != null) {
            DashSnackbar.show(context, message: state.message!, isError: true);
          }
        },
        child: BlocBuilder<PaymentAccountsCubit, PaymentAccountsState>(
          builder: (context, state) {
            return PageWorkspaceLayout(
              title: 'Payment Accounts',
              currentIndex: 4,
              onBack: () => context.go('/home'),
              onNavTap: (value) => context.go('/home?section=$value'),
              allowedSections: visibleSections,
              child: const PaymentAccountsPageContent(),
            );
          },
        ),
      ),
    );
  }

  List<int> _computeVisibleSections(appAccessRole) {
    final visible = <int>[0];
    if (appAccessRole.canAccessSection('pendingOrders')) visible.add(1);
    if (appAccessRole.canAccessSection('scheduleOrders')) visible.add(2);
    if (appAccessRole.canAccessSection('ordersMap')) visible.add(3);
    if (appAccessRole.canAccessSection('analyticsDashboard')) visible.add(4);
    return visible;
  }
}

// Content widget for sidebar use
class PaymentAccountsPageContent extends StatelessWidget {
  const PaymentAccountsPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentAccountsCubit, PaymentAccountsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openAccountDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Add Payment Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          BlocBuilder<PaymentAccountsCubit, PaymentAccountsState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (state.accounts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'No payment accounts yet. Tap "Add Payment Account" to create one.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
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
                    onEdit: () =>
                        _openAccountDialog(context, account: account),
                    onDelete: () =>
                        context.read<PaymentAccountsCubit>().deleteAccount(account.id),
                    onSetPrimary: () => context
                        .read<PaymentAccountsCubit>()
                        .setPrimaryAccount(account.id),
                    onUnsetPrimary: () => context
                        .read<PaymentAccountsCubit>()
                        .unsetPrimaryAccount(account.id),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAccountDialog(
    BuildContext context, {
    PaymentAccount? account,
  }) async {
    final cubit = context.read<PaymentAccountsCubit>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Account Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BlocProvider.value(
          value: cubit,
          child: _AccountDialog(account: account),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _AccountTile extends StatefulWidget {
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

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _isExpanded = false;

  IconData get _typeIcon {
    switch (widget.account.type) {
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
    switch (widget.account.type) {
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
    final gradientColors = widget.account.isPrimary
        ? [
            const Color(0xFF2C1F40),
            const Color(0xFF1C122D),
            const Color(0xFF110A1E),
          ]
        : [
            const Color(0xFF1A1A2A),
            const Color(0xFF11111B),
            const Color(0xFF0D0D14),
          ];

    final borderColor = widget.account.isPrimary
        ? const Color(0xFFFFC857).withValues(alpha: 0.6)
        : widget.account.isActive
            ? _typeColor.withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.1);

    final iconBackground = widget.account.isPrimary
        ? const Color(0xFFFFC857).withValues(alpha: 0.15)
        : _typeColor.withValues(alpha: 0.2);

    final iconBorderColor = widget.account.isPrimary
        ? const Color(0xFFFFC857).withValues(alpha: 0.6)
        : _typeColor.withValues(alpha: 0.5);

    final shouldShowDetails = (widget.account.displayPreference == PaymentDisplayPreference.qrCode && 
                                widget.account.qrCodeImageUrl != null) ||
                              (widget.account.displayPreference == PaymentDisplayPreference.bankDetails &&
                               (widget.account.accountNumber != null || widget.account.ifscCode != null));

    return Column(
      children: [
        AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
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
            color: widget.account.isPrimary
                ? const Color(0xFFFFC857).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: widget.account.isPrimary ? 25 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: shouldShowDetails
            ? () => setState(() => _isExpanded = !_isExpanded)
            : null,
        borderRadius: BorderRadius.circular(20),
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
                  widget.account.name,
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
                      color: _typeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _typeColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.account.type.name.toUpperCase(),
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                if (widget.account.accountNumber != null && 
                    widget.account.displayPreference != PaymentDisplayPreference.qrCode) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Account: ${widget.account.accountNumber}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (widget.account.upiId != null && 
                    widget.account.displayPreference != PaymentDisplayPreference.bankDetails) ...[
                  const SizedBox(height: 4),
                  Text(
                    'UPI: ${widget.account.upiId}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (shouldShowDetails) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        widget.account.displayPreference == PaymentDisplayPreference.qrCode
                            ? Icons.qr_code
                            : Icons.account_balance,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.account.displayPreference == PaymentDisplayPreference.qrCode
                            ? 'Tap to view QR Code'
                            : 'Tap to view Bank Details',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Colors.white54,
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
                icon: widget.account.isPrimary ? Icons.star : Icons.star_border,
                color:
                    widget.account.isPrimary ? const Color(0xFFFFD700) : Colors.white54,
                onPressed: widget.account.isPrimary ? widget.onUnsetPrimary : widget.onSetPrimary,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF6F4BFF),
                onPressed: widget.onEdit,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.delete_outline,
                color: Colors.redAccent,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
      ),
      ),
      if (_isExpanded && shouldShowDetails) ...[
        const SizedBox(height: 12),
        _buildExpandedContent(),
      ],
    ],
    );
  }

  Widget _buildExpandedContent() {
    if (widget.account.displayPreference == PaymentDisplayPreference.qrCode &&
        widget.account.qrCodeImageUrl != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Text(
              'QR Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                widget.account.qrCodeImageUrl!,
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else if (widget.account.displayPreference == PaymentDisplayPreference.bankDetails) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2A), Color(0xFF11111B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.account.accountNumber != null) ...[
              _buildDetailRow('Account Number', widget.account.accountNumber!),
              const SizedBox(height: 12),
            ],
            if (widget.account.ifscCode != null) ...[
              _buildDetailRow('IFSC Code', widget.account.ifscCode!),
            ],
            if (widget.account.accountNumber == null && widget.account.ifscCode == null)
              const Text(
                'No bank details available',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
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
  PaymentDisplayPreference? _displayPreference;
  bool _isActive = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _accountNumberController =
        TextEditingController(text: account?.accountNumber ?? '');
    _ifscCodeController = TextEditingController(text: account?.ifscCode ?? '');
    _upiIdController = TextEditingController(text: account?.upiId ?? '');
    _type = account?.type ?? PaymentAccountType.bank;
    _displayPreference = account?.displayPreference;
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
      backgroundColor: const Color(0xFF11111B),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
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
                                color: Colors.white.withValues(alpha: 0.7),
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
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
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
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Display preference for accounts with UPI or bank details
                if (_type == PaymentAccountType.bank || _type == PaymentAccountType.upi) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentDisplayPreference?>(
                    value: _displayPreference,
                    dropdownColor: const Color(0xFF1B1B2C),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Display Preference'),
                    hint: const Text(
                      'Select display preference',
                      style: TextStyle(color: Colors.white54),
                    ),
                    onChanged: (value) {
                      setState(() => _displayPreference = value);
                    },
                    items: [
                      const DropdownMenuItem(
                        value: PaymentDisplayPreference.qrCode,
                        child: Text('QR Code'),
                      ),
                      const DropdownMenuItem(
                        value: PaymentDisplayPreference.bankDetails,
                        child: Text('Bank Details'),
                      ),
                    ],
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
                    final orgState =
                        context.read<OrganizationContextCubit>().state;
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
                      accountNumber:
                          _accountNumberController.text.trim().isEmpty
                              ? null
                              : _accountNumberController.text.trim(),
                      ifscCode: _ifscCodeController.text.trim().isEmpty
                          ? null
                          : _ifscCodeController.text.trim(),
                      upiId: _upiIdController.text.trim().isEmpty
                          ? null
                          : _upiIdController.text.trim(),
                      displayPreference: _displayPreference,
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
                      DashSnackbar.show(
                        context,
                        message:
                            'Failed to ${isEditing ? 'update' : 'create'} account: ${e.toString()}',
                        isError: true,
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
