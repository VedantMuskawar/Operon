import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../bloc/android_payment_account_bloc.dart';
import '../../repositories/android_payment_account_repository.dart';
import '../../models/payment_account.dart';
import '../widgets/android_payment_account_form_dialog.dart';

class AndroidPaymentAccountManagementPage extends StatelessWidget {
  final String organizationId;
  final String userId;

  const AndroidPaymentAccountManagementPage({
    super.key,
    required this.organizationId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AndroidPaymentAccountBloc(
        repository: AndroidPaymentAccountRepository(),
      )..add(AndroidLoadPaymentAccounts(organizationId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment Accounts'),
          backgroundColor: AppTheme.surfaceColor,
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: BlocListener<AndroidPaymentAccountBloc, AndroidPaymentAccountState>(
          listener: (context, state) {
            if (state is AndroidPaymentAccountOperationSuccess) {
              context.read<AndroidPaymentAccountBloc>().add(
                    AndroidLoadPaymentAccounts(organizationId),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } else if (state is AndroidPaymentAccountError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: BlocBuilder<AndroidPaymentAccountBloc, AndroidPaymentAccountState>(
            builder: (context, state) {
              if (state is AndroidPaymentAccountLoading || state is AndroidPaymentAccountInitial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is AndroidPaymentAccountError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(state.message, style: const TextStyle(color: AppTheme.textPrimaryColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<AndroidPaymentAccountBloc>().add(
                            AndroidLoadPaymentAccounts(organizationId),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidPaymentAccountEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textSecondaryColor),
                      const SizedBox(height: 16),
                      const Text('No payment accounts found', style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddAccountDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Account'),
                      ),
                    ],
                  ),
                );
              }

              if (state is AndroidPaymentAccountLoaded) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Accounts (${state.accounts.length})',
                            style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddAccountDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AndroidConfig.defaultPadding),
                        itemCount: state.accounts.length,
                        itemBuilder: (context, index) {
                          final account = state.accounts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.surfaceColor,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                child: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
                              ),
                              title: Text(
                                account.accountName,
                                style: const TextStyle(color: AppTheme.textPrimaryColor, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ID: ${account.accountId}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  Text('${account.accountType} • ${account.currency}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  if (account.accountNumber != null)
                                    Text('Account: ${account.accountNumber}', style: const TextStyle(color: AppTheme.textSecondaryColor)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: account.isActive
                                              ? AppTheme.successColor.withOpacity(0.2)
                                              : AppTheme.errorColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          account.status,
                                          style: TextStyle(
                                            color: account.isActive ? AppTheme.successColor : AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (account.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.infoColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Default',
                                            style: TextStyle(color: AppTheme.infoColor, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                color: AppTheme.surfaceColor,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showEditAccountDialog(context, account),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () => _showDeleteConfirmDialog(context, account),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddAccountDialog(context),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidPaymentAccountFormDialog(
        onSubmit: (account) {
          context.read<AndroidPaymentAccountBloc>().add(
            AndroidAddPaymentAccount(
              organizationId: organizationId,
              account: account,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditAccountDialog(BuildContext context, PaymentAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AndroidPaymentAccountFormDialog(
        account: account,
        onSubmit: (account) {
          context.read<AndroidPaymentAccountBloc>().add(
            AndroidUpdatePaymentAccount(
              organizationId: organizationId,
              accountId: account.id!,
              account: account,
              userId: userId,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, PaymentAccount account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Payment Account', style: TextStyle(color: AppTheme.textPrimaryColor)),
        content: Text(
          'Are you sure you want to delete ${account.accountName}?',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AndroidPaymentAccountBloc>().add(
                AndroidDeletePaymentAccount(
                  organizationId: organizationId,
                  accountId: account.id!,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

