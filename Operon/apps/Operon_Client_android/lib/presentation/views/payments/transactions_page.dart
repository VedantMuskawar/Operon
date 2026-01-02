import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/payments/payments_cubit.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:dash_mobile/presentation/widgets/date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<Transaction> _filterByDateRange(List<Transaction> transactions) {
    if (_startDate == null && _endDate == null) return transactions;
    
    return transactions.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      final start = _startDate ?? DateTime(1970);
      final end = _endDate ?? DateTime.now();
      
      // Check if transaction date is within range (inclusive)
      return txDate.isAfter(start.subtract(const Duration(days: 1))) &&
             txDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

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
              // Date Range Picker
              DateRangePicker(
                startDate: _startDate,
                endDate: _endDate,
                onStartDateChanged: (date) {
                  setState(() => _startDate = date);
                },
                onEndDateChanged: (date) {
                  setState(() => _endDate = date);
                },
              ),
              const SizedBox(height: 16),
              // Transactions Table
              _buildTransactionsTable(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTable() {
    return BlocBuilder<PaymentsCubit, PaymentsState>(
      builder: (context, state) {
        final isLoading = state.isLoadingPayments;
        final allPayments = state.recentPayments;

        // Filter to show only clientPayment category
        var payments = allPayments
            .where((payment) => payment is Transaction && payment.category == TransactionCategory.clientPayment)
            .cast<Transaction>()
            .toList();

        // Apply date range filter
        payments = _filterByDateRange(payments);

        if (isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (payments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
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
                  if (_startDate != null || _endDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting the date range',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _TransactionsTable(transactions: payments),
        );
      },
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({required this.transactions});

  final List<Transaction> transactions;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year\n${hour == 0 ? 12 : hour}:$minute $period';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _getTransactionTypeLabel(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.advance:
        return 'Advance';
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
      case TransactionCategory.vendorPurchase:
        return 'Purchase';
      case TransactionCategory.vendorPayment:
        return 'Vendor Payment';
      case TransactionCategory.salaryCredit:
        return 'Salary';
      case TransactionCategory.salaryDebit:
        return 'Salary Payment';
      case TransactionCategory.bonus:
        return 'Bonus';
      case TransactionCategory.employeeAdvance:
        return 'Emp Advance';
      case TransactionCategory.employeeAdjustment:
        return 'Emp Adjustment';
      case TransactionCategory.generalExpense:
        return 'General Expense';
    }
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return Colors.orange;
      case TransactionType.debit:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 100),
      constraints: const BoxConstraints(minWidth: 700),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(140), // Date
          1: FixedColumnWidth(100), // Type
          2: FixedColumnWidth(150), // Category
          3: FixedColumnWidth(120), // Amount
          4: FixedColumnWidth(120), // Balance After
          5: FixedColumnWidth(80), // Receipt
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            children: [
              _TableHeaderCell('Date'),
              _TableHeaderCell('Type'),
              _TableHeaderCell('Category'),
              _TableHeaderCell('Amount'),
              _TableHeaderCell('Balance'),
              _TableHeaderCell('Receipt'),
            ],
          ),
          // Data Rows
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final transaction = entry.value;
            final date = transaction.createdAt ?? DateTime.now();
            final typeColor = _getTransactionTypeColor(transaction.type);
            final typeLabel = transaction.type == TransactionType.credit ? 'Credit' : 'Debit';
            final categoryLabel = _getTransactionTypeLabel(transaction.category);
            final hasReceipt = transaction.metadata?['receiptPhotoUrl'] != null;
            final isLast = index == transactions.length - 1;

            return TableRow(
              decoration: BoxDecoration(
                color: index % 2 == 0
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.02),
                borderRadius: isLast
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      )
                    : null,
              ),
              children: [
                _TableDataCell(
                  _formatDate(date),
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  typeLabel,
                  alignment: Alignment.center,
                  typeColor: typeColor,
                ),
                _TableDataCell(
                  categoryLabel,
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  _formatCurrency(transaction.amount),
                  alignment: Alignment.centerRight,
                  isAmount: true,
                ),
                _TableDataCell(
                  transaction.balanceAfter != null
                      ? _formatCurrency(transaction.balanceAfter!)
                      : '-',
                  alignment: Alignment.centerRight,
                ),
                _TableDataCell(
                  hasReceipt ? '✓' : '-',
                  alignment: Alignment.center,
                  hasReceipt: hasReceipt,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  const _TableDataCell(
    this.text, {
    required this.alignment,
    this.isAmount = false,
    this.typeColor,
    this.hasReceipt = false,
  });

  final String text;
  final Alignment alignment;
  final bool isAmount;
  final Color? typeColor;
  final bool hasReceipt;

  @override
  Widget build(BuildContext context) {
    Widget content = Text(
      text,
      style: TextStyle(
        color: isAmount
            ? const Color(0xFFFF9800)
            : typeColor != null
                ? typeColor!
                : hasReceipt
                    ? Colors.green
                    : Colors.white70,
        fontSize: 13,
        fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    if (typeColor != null) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: typeColor!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: typeColor!.withOpacity(0.5),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: typeColor!,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(
        alignment: alignment,
        child: content,
      ),
    );
  }
}
