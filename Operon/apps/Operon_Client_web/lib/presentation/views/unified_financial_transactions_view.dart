import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UnifiedFinancialTransactionsView extends StatefulWidget {
  const UnifiedFinancialTransactionsView({super.key});

  @override
  State<UnifiedFinancialTransactionsView> createState() =>
      _UnifiedFinancialTransactionsViewState();
}

class _UnifiedFinancialTransactionsViewState
    extends State<UnifiedFinancialTransactionsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    // Load data on init
    context.read<UnifiedFinancialTransactionsCubit>().load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context
        .read<UnifiedFinancialTransactionsCubit>()
        .search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<UnifiedFinancialTransactionsCubit>().search('');
  }

  String _formatDatePicker(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
  }

  Future<void> _selectStartDate() async {
    final state = context.read<UnifiedFinancialTransactionsCubit>().state;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: state.endDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final startDate = DateTime(picked.year, picked.month, picked.day);
      final endDate = state.endDate ?? DateTime.now();
      context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
            startDate.isAfter(endDate) ? startDate : startDate,
            endDate.isBefore(startDate) ? DateTime(picked.year, picked.month, picked.day, 23, 59, 59) : endDate,
          );
    }
  }

  Future<void> _selectEndDate() async {
    final state = context.read<UnifiedFinancialTransactionsCubit>().state;
    final picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? DateTime.now(),
      firstDate: state.startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
            state.startDate,
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
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
      child: SectionWorkspaceLayout(
        panelTitle: 'Financial Transactions',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(),
              const SizedBox(height: 24),
              // Filter Bar (Date Range + Search + Tab Selector)
              _buildFilterBar(),
              const SizedBox(height: 24),
              // Transaction List/Grid
              _buildTransactionList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return TransactionSummaryCards(
          totalPayments: state.totalIncome,
          totalPurchases: state.totalPurchases,
          totalExpenses: state.totalExpenses,
          formatCurrency: _formatCurrency,
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return TransactionTypeSegmentedControl(
          selectedIndex: state.selectedTab.index,
          onSelectionChanged: (index) {
            context.read<UnifiedFinancialTransactionsCubit>().selectTab(
                  TransactionTabType.values[index],
                );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        return Row(
          children: [
            // Date Range Pickers
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: InkWell(
                onTap: _selectStartDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Start',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 10),
                          ),
                          Text(
                            state.startDate != null
                                ? _formatDatePicker(state.startDate!)
                                : 'Select',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
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
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: InkWell(
                onTap: _selectEndDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'End',
                            style: TextStyle(color: AuthColors.textSub, fontSize: 10),
                          ),
                          Text(
                            state.endDate != null
                                ? _formatDatePicker(state.endDate!)
                                : 'Select',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
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
            const SizedBox(width: 12),
            // Search Bar
            Expanded(
              child:               TextField(
                controller: _searchController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AuthColors.textSub, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AuthColors.textSub, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  hintText: 'Search transactions...',
                  hintStyle: const TextStyle(color: AuthColors.textSub),
                  filled: true,
                  fillColor: AuthColors.surface.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Refresh Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuthColors.surface.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              child: TextButton.icon(
                onPressed: () => context.read<UnifiedFinancialTransactionsCubit>().refresh(),
                icon: const Icon(Icons.refresh, color: AuthColors.textSub, size: 16),
                label: const Text('Refresh', style: TextStyle(color: AuthColors.textSub, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tab Selector (Sections Pill)
            _buildTabSelector(),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList() {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      builder: (context, state) {
        final isLoading = state.status == ViewStatus.loading;
        var transactions = state.currentTransactions;

        // Apply search filter
        if (state.searchQuery.isNotEmpty) {
          final query = state.searchQuery.toLowerCase();
          transactions = transactions.where((tx) {
            final description = tx.description?.toLowerCase() ?? '';
            final reference = tx.referenceNumber?.toLowerCase() ?? '';
            final amount = tx.amount.toString();
            return description.contains(query) ||
                reference.contains(query) ||
                amount.contains(query);
          }).toList();
        }

        if (isLoading && transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AuthColors.textDisabled,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildTransactionTable(transactions);
      },
    );
  }

  Widget _buildTransactionTable(List<Transaction> transactions) {
    // Build columns - Date column must be first
    final columns = <custom_table.DataTableColumn<Transaction>>[
      // 1st Column: Date (compact width for date/time display)
      custom_table.DataTableColumn<Transaction>(
        label: 'Date',
        icon: Icons.calendar_today,
        flex: 2,
        alignment: Alignment.center,
        cellBuilder: (context, transaction, index) {
          final date = transaction.createdAt ?? DateTime.now();
          return Text(
            _formatDate(date),
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 13,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
      // 2nd Column: Name (flexible to take remaining space)
      custom_table.DataTableColumn<Transaction>(
        label: 'Name',
        icon: Icons.person,
        flex: 3,
        alignment: Alignment.center,
        cellBuilder: (context, transaction, index) {
          final title = _getTransactionTitle(transaction);
          return Text(
            title,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro Display',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          );
        },
      ),
      // 3rd Column: Reference (flexible width for reference numbers)
      custom_table.DataTableColumn<Transaction>(
        label: 'Reference',
        icon: Icons.receipt,
        flex: 2,
        alignment: Alignment.center,
        cellBuilder: (context, transaction, index) {
          final ref = transaction.referenceNumber ?? '-';
          return Text(
            ref,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 13,
              fontFamily: 'SF Pro Display',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          );
        },
      ),
      // 4th Column: Amount (flexible width for currency values)
      custom_table.DataTableColumn<Transaction>(
        label: 'Amount',
        icon: Icons.currency_rupee,
        flex: 2,
        alignment: Alignment.center,
        numeric: true,
        cellBuilder: (context, transaction, index) {
          final amountColor = transaction.type == TransactionType.credit
              ? AuthColors.success
              : AuthColors.error;
          return Text(
            _formatCurrency(transaction.amount),
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
      // 5th Column: Balance (flexible width for currency values)
      custom_table.DataTableColumn<Transaction>(
        label: 'Balance',
        icon: Icons.account_balance_wallet,
        flex: 2,
        alignment: Alignment.center,
        numeric: true,
        cellBuilder: (context, transaction, index) {
          final balance = transaction.balanceAfter;
          if (balance == null) {
            return const Text(
              '-',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
                fontFamily: 'SF Pro Display',
              ),
              textAlign: TextAlign.center,
            );
          }
          return Text(
            _formatCurrency(balance),
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 13,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    ];

    return custom_table.DataTable<Transaction>(
      columns: columns,
      rows: transactions,
      rowActions: [
        custom_table.DataTableRowAction<Transaction>(
          icon: Icons.delete_outline,
          tooltip: 'Delete',
          color: AuthColors.error,
          onTap: (transaction, index) {
            _showDeleteConfirmation(context, transaction);
          },
        ),
      ],
      emptyStateMessage: 'No transactions found',
      emptyStateIcon: Icons.receipt_long_outlined,
    );
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        return transaction.metadata?['clientName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Client Payment');
      case TransactionCategory.vendorPurchase:
        return transaction.metadata?['vendorName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Vendor Purchase');
      case TransactionCategory.vendorPayment:
        return transaction.metadata?['vendorName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Vendor Payment');
      case TransactionCategory.salaryDebit:
        return transaction.metadata?['employeeName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Salary Payment');
      case TransactionCategory.generalExpense:
        return transaction.metadata?['subCategoryName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'General Expense');
      default:
        return transaction.description?.isNotEmpty == true 
            ? transaction.description! 
            : 'Transaction';
    }
  }


  void _showDeleteConfirmation(
    BuildContext context,
    Transaction transaction,
  ) {
    // Validate transaction ID before showing dialog
    if (transaction.id.isEmpty || transaction.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot delete transaction: Invalid transaction ID'),
          backgroundColor: AuthColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Transaction',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to delete this transaction?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (transaction.id.isEmpty || transaction.id.trim().isEmpty) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cannot delete transaction: Invalid transaction ID'),
                    backgroundColor: AuthColors.error,
                  ),
                );
                return;
              }
              context
                  .read<UnifiedFinancialTransactionsCubit>()
                  .deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
