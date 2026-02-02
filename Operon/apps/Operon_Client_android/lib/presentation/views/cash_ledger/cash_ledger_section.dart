import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/cash_ledger/cash_ledger_cubit.dart';
import 'package:dash_mobile/presentation/blocs/cash_ledger/cash_ledger_state.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/shared/utils/permission_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cash Ledger section for Android home (replaces Analytics).
/// Single list of all transactions and payment account distribution below.
class CashLedgerSection extends StatelessWidget {
  const CashLedgerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) {
      return const Center(child: Text('Select an organization'));
    }
    final transactionsRepository = context.read<TransactionsRepository>();
    final vendorsRepository = context.read<VendorsRepository>();
    return BlocProvider(
      create: (_) => CashLedgerCubit(
        transactionsRepository: transactionsRepository,
        vendorsRepository: vendorsRepository,
        organizationId: organization.id,
      )..load(),
      child: const _CashLedgerContent(),
    );
  }
}

class _CashLedgerContent extends StatefulWidget {
  const _CashLedgerContent();

  @override
  State<_CashLedgerContent> createState() => _CashLedgerContentState();
}

class _CashLedgerContentState extends State<_CashLedgerContent> {
  @override
  void initState() {
    super.initState();
    context.read<CashLedgerCubit>().load();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CashLedgerCubit, CashLedgerState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AuthColors.error,
            ),
          );
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: BlocBuilder<CashLedgerCubit, CashLedgerState>(
                builder: (context, state) {
                  final totalIncome = state.totalIncome;
                  final totalOutcome = state.totalOutcome;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash Ledger',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Income: ${_formatCurrency(totalIncome)} • Out: ${_formatCurrency(totalOutcome)} • Net: ${_formatCurrency(state.netBalance)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AuthColors.textSub,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () =>
                                context.read<CashLedgerCubit>().refresh(),
                            icon: const Icon(Icons.refresh, size: 22),
                            label: const Text('Refresh',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AuthColors.primary,
                              foregroundColor: AuthColors.textMain,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          SizedBox(
                            width: 72,
                            child: Text(
                              'Credit',
                              style: TextStyle(
                                fontSize: 11,
                                color: AuthColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text(
                              'Debit',
                              style: TextStyle(
                                fontSize: 11,
                                color: AuthColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          BlocBuilder<CashLedgerCubit, CashLedgerState>(
            builder: (context, state) {
              if (state.status == ViewStatus.loading &&
                  state.allRows.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = state.allRows;
              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No transactions',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }
              final isAdmin = PermissionHelper.isAdmin(context);
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final tx = list[index];
                    return _CashLedgerTile(
                      transaction: tx,
                      typeLabel: _rowTypeLabel(tx),
                      formatCurrency: _formatCurrency,
                      isAdmin: isAdmin,
                      onVerify: () => _verifyDirect(context, tx),
                      onUnverify: () => _showUnverifyDialog(context, tx),
                      onDelete: () {
                        if (tx.verified) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Verified entries cannot be edited or deleted.'),
                              backgroundColor: AuthColors.warning,
                            ),
                          );
                          return;
                        }
                        _showDeleteDialog(context, tx);
                      },
                    );
                  },
                  childCount: list.length,
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: BlocBuilder<CashLedgerCubit, CashLedgerState>(
              builder: (context, state) {
                final distribution = state.paymentAccountDistribution;
                if (distribution.isEmpty) return const SizedBox(height: 24);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment account distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...distribution.map(
                        (s) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: AuthColors.surface.withOpacity(0.6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.displayName,
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Income',
                                        style: TextStyle(
                                            color: AuthColors.textSub,
                                            fontSize: 12)),
                                    Text(_formatCurrency(s.income),
                                        style: const TextStyle(
                                            color: AuthColors.success,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Expenses',
                                        style: TextStyle(
                                            color: AuthColors.textSub,
                                            fontSize: 12)),
                                    Text(_formatCurrency(s.expense),
                                        style: const TextStyle(
                                            color: AuthColors.error,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net',
                                        style: TextStyle(
                                            color: AuthColors.textSub,
                                            fontSize: 12)),
                                    Text(
                                      _formatCurrency(s.net),
                                      style: TextStyle(
                                        color: s.net >= 0
                                            ? AuthColors.success
                                            : AuthColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _rowTypeLabel(Transaction tx) {
    switch (tx.category) {
      case TransactionCategory.advance:
      case TransactionCategory.tripPayment:
        return 'Orders';
      case TransactionCategory.clientPayment:
      case TransactionCategory.refund:
        return 'Payments';
      case TransactionCategory.vendorPurchase:
        return 'Purchases';
      case TransactionCategory.vendorPayment:
      case TransactionCategory.salaryDebit:
      case TransactionCategory.generalExpense:
      default:
        return 'Expenses';
    }
  }

  void _verifyDirect(BuildContext context, Transaction transaction) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    context.read<CashLedgerCubit>().updateVerification(
          transactionId: transaction.id,
          verified: true,
          verifiedBy: uid,
        );
  }

  void _showUnverifyDialog(BuildContext context, Transaction transaction) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unverify transaction?'),
        content: const Text(
          'This will allow the transaction to be edited again. Only use for corrections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CashLedgerCubit>().updateVerification(
                    transactionId: transaction.id,
                    verified: false,
                    verifiedBy: uid,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Unverify'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Transaction transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<CashLedgerCubit>().deleteTransaction(transaction.id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AuthColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _CashLedgerTile extends StatelessWidget {
  const _CashLedgerTile({
    required this.transaction,
    required this.typeLabel,
    required this.formatCurrency,
    required this.isAdmin,
    required this.onVerify,
    required this.onUnverify,
    required this.onDelete,
  });

  final Transaction transaction;
  final String typeLabel;
  final String Function(double) formatCurrency;
  final bool isAdmin;
  final VoidCallback onVerify;
  final VoidCallback onUnverify;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = transaction.createdAt ?? DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final title = _title(transaction);
    final isCredit = transaction.type == TransactionType.credit;
    final verifiedColor = transaction.verified
        ? AuthColors.success.withOpacity(0.2)
        : AuthColors.error.withOpacity(0.2);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: verifiedColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: (isCredit
                          ? AuthColors.success
                          : AuthColors.error)
                      .withOpacity(0.2),
                  child: Icon(
                    Icons.receipt,
                    color: isCredit ? AuthColors.success : AuthColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AuthColors.textMain,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$typeLabel • $dateStr • ${transaction.referenceNumber ?? "-"}',
                        style: const TextStyle(
                            color: AuthColors.textSub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            isCredit ? formatCurrency(transaction.amount) : '–',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isCredit
                                  ? AuthColors.success
                                  : AuthColors.textSub,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            !isCredit ? formatCurrency(transaction.amount) : '–',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: !isCredit
                                  ? AuthColors.error
                                  : AuthColors.textSub,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilledButton.icon(
                              onPressed: transaction.verified
                                  ? onUnverify
                                  : onVerify,
                              icon: Icon(
                                transaction.verified
                                    ? Icons.cancel_outlined
                                    : Icons.verified_user,
                                size: 20,
                              ),
                              label: Text(
                                transaction.verified ? 'Unverify' : 'Verify',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: transaction.verified
                                    ? AuthColors.warning
                                    : AuthColors.success,
                                foregroundColor: AuthColors.textMain,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                minimumSize: const Size(0, 40),
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (transaction.verified) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Verified entries cannot be edited or deleted.'),
                                  backgroundColor: AuthColors.warning,
                                ),
                              );
                              return;
                            }
                            onDelete();
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text('Delete', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AuthColors.error,
                            side: const BorderSide(color: AuthColors.error),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _title(Transaction tx) {
    switch (tx.category) {
      case TransactionCategory.advance:
        return tx.clientName?.trim().isNotEmpty == true
            ? tx.clientName!
            : 'Advance';
      case TransactionCategory.tripPayment:
        return tx.clientName?.trim().isNotEmpty == true
            ? tx.clientName!
            : 'Trip Payment';
      case TransactionCategory.clientPayment:
        return tx.clientName?.trim().isNotEmpty == true
            ? tx.clientName!
            : 'Payment';
      case TransactionCategory.vendorPurchase:
        return tx.metadata?['vendorName']?.toString() ?? 'Purchase';
      case TransactionCategory.vendorPayment:
        return tx.metadata?['vendorName']?.toString() ?? 'Vendor Payment';
      default:
        return tx.description ?? 'Transaction';
    }
  }
}
