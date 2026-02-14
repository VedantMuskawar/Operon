import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/salary_voucher_modal.dart';
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
  final Map<String, String> _searchIndexCache = {};
  String? _lastSearchIndexHash;

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
          data: DashTheme.light(),
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
          data: DashTheme.light(),
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
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: SectionWorkspaceLayout(
        panelTitle: 'Financial Transactions',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              _buildSummaryCards(),
              const SizedBox(height: 24),
              // Filter Bar (Date Range + Search + Tab Selector)
              _buildFilterBar(),
              const SizedBox(height: 24),
              // Transaction list (virtualized) - shrink-wraps inside scrollable
              Flexible(
                fit: FlexFit.loose,
                child: _buildTransactionList(),
              ),
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
              child: DashButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: () => context.read<UnifiedFinancialTransactionsCubit>().refresh(),
                variant: DashButtonVariant.text,
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
        final transactionsHash =
            '${transactions.length}_${transactions.hashCode}';
        final searchIndex = _buildSearchIndex(transactions, transactionsHash);

        // Apply search filter
        if (state.searchQuery.isNotEmpty) {
          final query = state.searchQuery.toLowerCase();
          transactions = transactions.where((tx) {
            final indexText = searchIndex[tx.id] ?? '';
            return indexText.contains(query);
          }).toList();
        }

        if (isLoading && transactions.isEmpty) {
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
                  ...List.generate(8, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonLoader(
                      height: 56,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
                ],
              ),
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

        return AnimatedFade(
          duration: const Duration(milliseconds: 350),
          child: _buildVirtualizedTransactionTable(context, transactions),
        );
      },
    );
  }

  Map<String, String> _buildSearchIndex(
    List<Transaction> transactions,
    String transactionsHash,
  ) {
    if (_lastSearchIndexHash == transactionsHash &&
        _searchIndexCache.isNotEmpty) {
      return _searchIndexCache;
    }

    _searchIndexCache.clear();
    for (final tx in transactions) {
      final buffer = StringBuffer();
      void add(String? value) {
        if (value == null) return;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        buffer.write(trimmed.toLowerCase());
        buffer.write(' ');
      }

      add(tx.description);
      add(tx.referenceNumber);
      add(tx.amount.toString());
      add(tx.clientName);
      add(tx.paymentAccountName);
      add(tx.metadata?['clientName']?.toString());
      add(tx.metadata?['vendorName']?.toString());
      add(tx.metadata?['employeeName']?.toString());

      _searchIndexCache[tx.id] = buffer.toString();
    }

    _lastSearchIndexHash = transactionsHash;
    return _searchIndexCache;
  }

  List<custom_table.DataTableColumn<Transaction>> _transactionColumns() {
    return [
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
      custom_table.DataTableColumn<Transaction>(
        label: 'Account',
        icon: Icons.account_balance_wallet_outlined,
        flex: 2,
        alignment: Alignment.center,
        cellBuilder: (context, transaction, index) {
          final name = transaction.paymentAccountName ?? '-';
          return Text(
            name,
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
  }

  List<custom_table.DataTableRowAction<Transaction>> _rowActionsFor(
    BuildContext context,
    Transaction transaction,
  ) {
    final hasVoucher = transaction.category == TransactionCategory.salaryDebit &&
        transaction.metadata?['cashVoucherPhotoUrl'] != null &&
        (transaction.metadata!['cashVoucherPhotoUrl'] as String).isNotEmpty;
    return [
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.receipt_long,
        tooltip: hasVoucher ? 'View voucher' : 'No voucher',
        color: hasVoucher ? AuthColors.primary : AuthColors.textSub,
        onTap: (tx, index) {
          if (hasVoucher) {
            showSalaryVoucherModal(context, tx.id);
          } else {
            DashSnackbar.show(
              context,
              message: 'No voucher for this transaction',
              isError: false,
            );
          }
        },
      ),
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.delete_outline,
        tooltip: 'Delete',
        color: AuthColors.error,
        onTap: (tx, index) => _showDeleteConfirmation(context, tx),
      ),
    ];
  }

  Widget _buildVirtualizedTransactionTable(
    BuildContext context,
    List<Transaction> transactions,
  ) {
    final columns = _transactionColumns();
    return Container(
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TransactionTableHeader(
                columns: columns,
                rowActions: [
                  custom_table.DataTableRowAction<Transaction>(
                    icon: Icons.receipt_long,
                    tooltip: 'View voucher',
                    color: AuthColors.primary,
                    onTap: (_, __) {},
                  ),
                  custom_table.DataTableRowAction<Transaction>(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AuthColors.error,
                    onTap: (_, __) {},
                  ),
                ],
              ),
              Divider(
                height: 1,
                color: AuthColors.textMainWithOpacity(0.12),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isEven = index % 2 == 0;
                  final bgColor = isEven
                      ? Colors.transparent
                      : AuthColors.textMainWithOpacity(0.03);
                  final rowActions = _rowActionsFor(context, transaction);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0)
                        Divider(
                          height: 1,
                          color: AuthColors.textMainWithOpacity(0.12),
                        ),
                      _TransactionRow(
                        transaction: transaction,
                        rowIndex: index,
                        columns: columns,
                        rowActions: rowActions,
                        backgroundColor: bgColor,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            transaction.metadata?['clientName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Client Payment');
      case TransactionCategory.tripPayment:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            transaction.metadata?['clientName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Trip Payment');
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
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Transaction');
    }
  }


  void _showDeleteConfirmation(
    BuildContext context,
    Transaction transaction,
  ) {
    // Validate transaction ID before showing dialog
    if (transaction.id.isEmpty || transaction.id.trim().isEmpty) {
      DashSnackbar.show(
        context,
        message: 'Cannot delete transaction: Invalid transaction ID',
        isError: true,
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
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Delete',
            onPressed: () {
              if (transaction.id.isEmpty || transaction.id.trim().isEmpty) {
                Navigator.of(dialogContext).pop();
                DashSnackbar.show(
                  context,
                  message: 'Cannot delete transaction: Invalid transaction ID',
                  isError: true,
                );
                return;
              }
              context
                  .read<UnifiedFinancialTransactionsCubit>()
                  .deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            variant: DashButtonVariant.text,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _TransactionTableHeader extends StatelessWidget {
  const _TransactionTableHeader({
    required this.columns,
    required this.rowActions,
  });

  final List<custom_table.DataTableColumn<Transaction>> columns;
  final List<custom_table.DataTableRowAction<Transaction>> rowActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AuthColors.textMainWithOpacity(0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          ...columns.map((column) {
            final flex = column.flex ?? 1;
            return Expanded(
              flex: flex,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (column.icon != null) ...[
                      Icon(
                        column.icon,
                        size: 16,
                        color: AuthColors.textMain,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      column.label,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(
            width: (rowActions.length * 52).toDouble(),
            child: const Center(
              child: Text(
                'Actions',
                style: TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.rowIndex,
    required this.columns,
    required this.rowActions,
    required this.backgroundColor,
  });

  final Transaction transaction;
  final int rowIndex;
  final List<custom_table.DataTableColumn<Transaction>> columns;
  final List<custom_table.DataTableRowAction<Transaction>> rowActions;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: backgroundColor,
        child: Row(
          children: [
            ...columns.map((column) {
              final flex = column.flex ?? 1;
              Widget cell;
              if (column.cellBuilder != null) {
                cell = column.cellBuilder!(context, transaction, rowIndex);
              } else {
                cell = Text(
                  transaction.toString(),
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 13,
                    fontFamily: 'SF Pro Display',
                  ),
                  textAlign: TextAlign.center,
                );
              }
              cell = Align(
                alignment: column.alignment,
                child: cell,
              );
              return Expanded(
                flex: flex,
                child: cell,
              );
            }),
            SizedBox(
              width: (rowActions.length * 52).toDouble(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: rowActions.map((action) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: IconButton(
                      icon: Icon(
                        action.icon,
                        size: 24,
                        color: action.color ?? AuthColors.textSub,
                      ),
                      onPressed: () => action.onTap(transaction, rowIndex),
                      tooltip: action.tooltip,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
