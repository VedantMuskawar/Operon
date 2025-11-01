import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/page_container.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../contexts/organization_context.dart';
import '../../bloc/payment_account_bloc.dart';
import '../../bloc/payment_account_event.dart';
import '../../bloc/payment_account_state.dart';
import '../../repositories/payment_account_repository.dart';
import '../../models/payment_account.dart';
import '../widgets/payment_account_form_dialog.dart';
import '../../../auth/bloc/auth_bloc.dart';
import 'package:uuid/uuid.dart';

class PaymentAccountManagementPage extends StatelessWidget {
  final VoidCallback? onBack;

  const PaymentAccountManagementPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OrganizationAwareWidget(
      builder: (context, orgContext) {
        final organizationId = orgContext.organizationId;
        
        if (organizationId == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Organization not found',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            ),
          );
        }

        return BlocProvider(
          create: (context) => PaymentAccountBloc(
            paymentAccountRepository: PaymentAccountRepository(),
          )..add(LoadPaymentAccounts(organizationId)),
          child: PaymentAccountManagementView(
            organizationId: organizationId,
            userRole: orgContext.userRole ?? 0,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class PaymentAccountManagementView extends StatelessWidget {
  final String organizationId;
  final int userRole;
  final VoidCallback? onBack;

  const PaymentAccountManagementView({
    super.key,
    required this.organizationId,
    required this.userRole,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentAccountBloc, PaymentAccountState>(
      listener: (context, state) {
        if (state is PaymentAccountOperationSuccess) {
          CustomSnackBar.showSuccess(context, state.message);
        } else if (state is PaymentAccountError) {
          CustomSnackBar.showError(context, state.message);
        }
      },
      child: PageContainer(
        fullHeight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PageHeader(
              title: 'Payment Accounts',
              onBack: onBack,
              role: _getRoleString(userRole),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  minWidth: 800,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppTheme.spacingLg),
                    _buildContent(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleString(int userRole) {
    switch (userRole) {
      case 0:
        return 'admin';
      case 1:
        return 'admin';
      case 2:
        return 'manager';
      case 3:
        return 'driver';
      default:
        return 'member';
    }
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter Bar - matching Vehicle Management styling
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingLg,
          ),
          child: _buildFilterBar(context),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        
        // Payment Accounts Table - matching Vehicle Management styling
        LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141618).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with emoji and title
                  Row(
                    children: [
                      const Text(
                        '💳',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      const Text(
                        'Payment Accounts',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  BlocBuilder<PaymentAccountBloc, PaymentAccountState>(
                    builder: (context, state) {
                      // Show loading on initial state or loading state
                      if (state is PaymentAccountInitial || 
                          state is PaymentAccountLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppTheme.spacing2xl),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      
                      if (state is PaymentAccountError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.errorColor,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                CustomButton(
                                  text: 'Retry',
                                  variant: CustomButtonVariant.primary,
                                  onPressed: () {
                                    context.read<PaymentAccountBloc>().add(
                                      LoadPaymentAccounts(organizationId),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is PaymentAccountEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing2xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '💳',
                                  style: TextStyle(fontSize: 64),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Text(
                                  state.searchQuery != null
                                      ? 'No Payment Accounts Found'
                                      : 'No Payment Accounts',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingSm),
                                Text(
                                  state.searchQuery != null
                                      ? 'No accounts match your search criteria'
                                      : 'Add your first payment account to get started',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spacingLg),
                                if (state.searchQuery != null)
                                  CustomButton(
                                    text: 'Clear Search',
                                    variant: CustomButtonVariant.outline,
                                    onPressed: () {
                                      context.read<PaymentAccountBloc>().add(
                                        const ResetSearch(),
                                      );
                                      context.read<PaymentAccountBloc>().add(
                                        LoadPaymentAccounts(organizationId),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (state is PaymentAccountLoaded) {
                        return _buildAccountsTable(context, state.accounts);
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Row(
      children: [
        // Add Payment Account button on the left
        CustomButton(
          text: '➕ Add Payment Account',
          variant: CustomButtonVariant.primary,
          onPressed: () => _showAddAccountDialog(context),
        ),
        const Spacer(),
        // Search field on the right
        SizedBox(
          width: 300,
          child: BlocBuilder<PaymentAccountBloc, PaymentAccountState>(
            builder: (context, state) {
              return CustomTextField(
                hintText: 'Search accounts...',
                prefixIcon: const Icon(Icons.search, size: 18),
                variant: CustomTextFieldVariant.search,
                onChanged: (query) {
                  if (query.isEmpty) {
                    context.read<PaymentAccountBloc>().add(
                      const ResetSearch(),
                    );
                    context.read<PaymentAccountBloc>().add(
                      LoadPaymentAccounts(organizationId),
                    );
                  } else {
                    context.read<PaymentAccountBloc>().add(
                      SearchPaymentAccounts(
                        organizationId: organizationId,
                        query: query,
                      ),
                    );
                  }
                },
                suffixIcon: state is PaymentAccountLoaded && 
                            state.searchQuery != null &&
                            state.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          context.read<PaymentAccountBloc>().add(
                            const ResetSearch(),
                          );
                          context.read<PaymentAccountBloc>().add(
                            LoadPaymentAccounts(organizationId),
                          );
                        },
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsTable(
    BuildContext context,
    List<PaymentAccount> accounts,
  ) {
    // Calculate minimum table width based on columns
    const double minTableWidth = 1200;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final tableWidth = availableWidth > minTableWidth 
            ? availableWidth 
            : minTableWidth;
            
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DataTable(
                headingRowHeight: 52,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 80,
                horizontalMargin: 0,
                columnSpacing: 24,
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xFF1F2937).withValues(alpha: 0.8),
                ),
                dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF374151).withValues(alpha: 0.5);
                    }
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFF374151).withValues(alpha: 0.3);
                    }
                    return Colors.transparent;
                  },
                ),
                dividerThickness: 1,
                columns: [
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ACCOUNT ID',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ACCOUNT NAME',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'TYPE',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ACCOUNT NUMBER',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'BANK NAME',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'CURRENCY',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'STATUS',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'ACTIONS',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
                rows: accounts.map((account) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.accountId,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.accountName,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.accountType,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.accountNumber ?? '—',
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.bankName ?? '—',
                            style: const TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            account.currency,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: _buildStatusBadge(account.status),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: _buildDefaultBadge(account.isDefault),
                        ),
                      ),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AppTheme.warningColor,
                                onPressed: () => _showEditAccountDialog(
                                  context,
                                  account,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.warningColor
                                      .withValues(alpha: 0.1),
                                  padding: const EdgeInsets.all(8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingXs),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: AppTheme.errorColor,
                                onPressed: () => _showDeleteConfirmation(
                                  context,
                                  account,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.errorColor
                                      .withValues(alpha: 0.1),
                                  padding: const EdgeInsets.all(8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    if (status == 'Active') {
      color = AppTheme.successColor;
    } else {
      color = AppTheme.textTertiaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDefaultBadge(bool isDefault) {
    if (!isDefault) {
      return const Text(
        '—',
        style: TextStyle(
          color: AppTheme.textTertiaryColor,
          fontSize: 14,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Text(
        'Default',
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => PaymentAccountFormDialog(
        onSubmit: (account) {
          Navigator.of(dialogContext).pop();
          _submitAccount(context, account);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showEditAccountDialog(
    BuildContext context,
    PaymentAccount account,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => PaymentAccountFormDialog(
        account: account,
        onSubmit: (updatedAccount) {
          Navigator.of(dialogContext).pop();
          _updateAccount(context, account, updatedAccount);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    PaymentAccount account,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Payment Account',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${account.accountName}"?',
          style: const TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CustomButton(
            text: 'Cancel',
            variant: CustomButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          CustomButton(
            text: 'Delete',
            variant: CustomButtonVariant.danger,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAccount(context, account);
            },
          ),
        ],
      ),
    );
  }

  void _submitAccount(
    BuildContext context,
    PaymentAccount account,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<PaymentAccountBloc>().add(
      AddPaymentAccount(
        organizationId: organizationId,
        account: account,
        userId: userId,
      ),
    );
  }

  void _updateAccount(
    BuildContext context,
    PaymentAccount oldAccount,
    PaymentAccount newAccount,
  ) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated
        ? authState.firebaseUser.uid
        : const Uuid().v4();

    context.read<PaymentAccountBloc>().add(
      UpdatePaymentAccount(
        organizationId: organizationId,
        accountId: oldAccount.id!,
        account: newAccount,
        userId: userId,
      ),
    );
  }

  void _deleteAccount(
    BuildContext context,
    PaymentAccount account,
  ) {
    context.read<PaymentAccountBloc>().add(
      DeletePaymentAccount(
        organizationId: organizationId,
        accountId: account.id!,
      ),
    );
  }
}

