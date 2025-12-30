import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/payments/payments_cubit.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  @override
  Widget build(BuildContext context) {
    // PaymentsCubit is now provided at the route level
    return BlocConsumer<PaymentsCubit, PaymentsState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        return PageWorkspaceLayout(
          title: 'Transactions',
          currentIndex: 0,
          onNavTap: (value) => context.go('/home', extra: value),
          onBack: () => context.go('/home'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transactions List
              _buildTransactionsList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList() {
    return BlocBuilder<PaymentsCubit, PaymentsState>(
      builder: (context, state) {
        final isLoading = state.isLoadingPayments;
        final allPayments = state.recentPayments;

        // TEMPORARY: Filter to show only clientPayment category
        final payments = allPayments
            .where((payment) => payment is Transaction && payment.category == TransactionCategory.clientPayment)
            .cast<Transaction>()
            .toList();

        debugPrint('[TransactionsPage] Builder - isLoading: $isLoading, allPayments.length: ${allPayments.length}, filtered: ${payments.length}');

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  'No payment transactions found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '(Showing only clientPayment category)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final payment = payments[index];
            return _PaymentTile(transaction: payment);
          },
        );
      },
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.transaction});

  final Transaction transaction;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _getTransactionTypeLabel() {
    switch (transaction.category) {
      case TransactionCategory.advance:
        return 'Advance Payment';
      case TransactionCategory.clientCredit:
        return 'Order Credit';
      case TransactionCategory.tripPayment:
        return 'Trip Payment';
      case TransactionCategory.clientPayment:
        return 'Payment';
      case TransactionCategory.refund:
        return 'Refund';
      case TransactionCategory.adjustment:
        return 'Adjustment';
    }
  }

  Color _getTransactionTypeColor() {
    switch (transaction.type) {
      case TransactionType.credit:
        return Colors.orange; // Credit = client owes (increases receivable)
      case TransactionType.debit:
        return Colors.green; // Debit = client paid (decreases receivable)
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReceipt = transaction.metadata?['receiptPhotoUrl'] != null;
    final date = transaction.createdAt ?? DateTime.now();
    final typeColor = _getTransactionTypeColor();
    final typeLabel = _getTransactionTypeLabel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: typeColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            transaction.type == TransactionType.credit ? 'Credit' : 'Debit',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(transaction.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (hasReceipt)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt, color: Colors.white70, size: 20),
                ),
            ],
          ),
          if (transaction.balanceAfter != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Text(
                    'Balance after: ${_formatCurrency(transaction.balanceAfter!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
