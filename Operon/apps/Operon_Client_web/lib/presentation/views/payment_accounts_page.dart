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
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SkeletonLoader(
                          height: 40,
                          width: double.infinity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(6, (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SkeletonLoader(
                            height: 64,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              }
              if (state.accounts.isEmpty) {
                return const EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No payment accounts yet',
                  message: 'Tap "Add Payment Account" to create one.',
                );
              }
              return AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final account = state.accounts[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 200),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          curve: Curves.easeOut,
                          child: _AccountDataListItem(
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
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
      barrierColor: AuthColors.background.withValues(alpha: 0.6),
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

class _AccountDataListItem extends StatefulWidget {
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

  @override
  State<_AccountDataListItem> createState() => _AccountDataListItemState();
}

class _AccountDataListItemState extends State<_AccountDataListItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));
  }
  
  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  Color get _typeColor {
    switch (widget.account.type) {
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
    parts.add(widget.account.type.name.toUpperCase());
    if (widget.account.isPrimary) {
      parts.add('Primary');
    }
    if (widget.account.accountNumber != null && 
        widget.account.displayPreference != PaymentDisplayPreference.qrCode) {
      parts.add(widget.account.accountNumber!);
    } else if (widget.account.upiId != null && 
               widget.account.displayPreference != PaymentDisplayPreference.bankDetails) {
      parts.add(widget.account.upiId!);
    }
    if (widget.account.qrCodeImageUrl != null) {
      parts.add('QR Code');
    }
    return parts.join(' • ');
  }

  Color _getStatusColor() {
    if (!widget.account.isActive) {
      return AuthColors.textDisabled;
    }
    return widget.account.isPrimary ? AuthColors.secondary : _typeColor;
  }

  bool get _shouldShowDetails {
    return (widget.account.displayPreference == PaymentDisplayPreference.qrCode && 
            widget.account.qrCodeImageUrl != null) ||
           (widget.account.displayPreference == PaymentDisplayPreference.bankDetails &&
            (widget.account.accountNumber != null || widget.account.ifscCode != null));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          DataList(
            title: widget.account.name,
            subtitle: _formatSubtitle(),
            leading: DataListAvatar(
              initial: widget.account.name.isNotEmpty ? widget.account.name[0].toUpperCase() : 'A',
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
                    widget.account.isPrimary ? Icons.star : Icons.star_border,
                    color: widget.account.isPrimary ? AuthColors.secondary : AuthColors.textSub,
                    size: 20,
                  ),
                  onPressed: widget.account.isPrimary ? widget.onUnsetPrimary : widget.onSetPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: widget.account.isPrimary ? 'Remove Primary' : 'Set Primary',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AuthColors.textSub,
                    size: 20,
                  ),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AuthColors.error,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (_shouldShowDetails) ...[
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AuthColors.textSub,
                        size: 24,
                      ),
                      onPressed: _toggleExpanded,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ],
            ),
            onTap: _shouldShowDetails ? _toggleExpanded : widget.onEdit,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _shouldShowDetails ? _buildExpandedContent() : const SizedBox.shrink(),
            crossFadeState: _isExpanded && _shouldShowDetails
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (widget.account.displayPreference == PaymentDisplayPreference.qrCode &&
        widget.account.qrCodeImageUrl != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AuthColors.background,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'QR Code',
              style: TextStyle(
                color: AuthColors.textMain,
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
                cacheWidth: 400,
                cacheHeight: 400,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  );
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) {
                    return child;
                  }
                  if (frame == null) {
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return child;
                },
              ),
            ),
          ],
        ),
      );
    } else if (widget.account.displayPreference == PaymentDisplayPreference.bankDetails) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AuthColors.background,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bank Details',
              style: TextStyle(
                color: AuthColors.textMain,
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
                style: TextStyle(color: AuthColors.textSub, fontSize: 14),
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
              color: AuthColors.textSub,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
      backgroundColor: AuthColors.surface,
      title: Text(
        isEditing ? 'Edit Payment Account' : 'Add Payment Account',
        style: const TextStyle(color: AuthColors.textMain),
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
                  style: const TextStyle(color: AuthColors.textMain),
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
                  style: const TextStyle(color: AuthColors.textMain),
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
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('Account Number'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ifscCodeController,
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('IFSC Code'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upiIdController,
                    style: const TextStyle(color: AuthColors.textMain),
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
                        border: Border.all(
                          color: AuthColors.textMain.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AuthColors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
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
                    style: const TextStyle(color: AuthColors.textMain),
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
                    initialValue: _displayPreference,
                    dropdownColor: AuthColors.surface,
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: _inputDecoration('Display Preference'),
                    hint: const Text(
                      'Select display preference',
                      style: TextStyle(color: Colors.white54),
                    ),
                    onChanged: (value) {
                      setState(() => _displayPreference = value);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: PaymentDisplayPreference.qrCode,
                        child: Text('QR Code'),
                      ),
                      DropdownMenuItem(
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
        DashButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
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
      labelStyle: const TextStyle(color: AuthColors.textSub),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
