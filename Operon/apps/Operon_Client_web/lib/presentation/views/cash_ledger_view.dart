import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/cash_ledger/cash_ledger_cubit.dart';
import 'package:dash_web/presentation/blocs/cash_ledger/cash_ledger_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class CashLedgerView extends StatefulWidget {
  const CashLedgerView({super.key});

  @override
  State<CashLedgerView> createState() => _CashLedgerViewState();
}

class _CashLedgerViewState extends State<CashLedgerView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    context.read<CashLedgerCubit>().load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    context.read<CashLedgerCubit>().search(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<CashLedgerCubit>().search('');
  }

  String _formatDatePicker(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
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
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
  }

  Future<void> _selectStartDate() async {
    final state = context.read<CashLedgerCubit>().state;
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
      context.read<CashLedgerCubit>().setDateRange(
            startDate.isAfter(endDate) ? startDate : startDate,
            endDate.isBefore(startDate)
                ? DateTime(picked.year, picked.month, picked.day, 23, 59, 59)
                : endDate,
          );
    }
  }

  Future<void> _selectEndDate() async {
    final state = context.read<CashLedgerCubit>().state;
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
      context.read<CashLedgerCubit>().setDateRange(
            state.startDate,
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CashLedgerCubit, CashLedgerState>(
      listener: (context, state) {
        if (state.status == ViewStatus.failure && state.message != null) {
          DashSnackbar.show(context, message: state.message!, isError: true);
        }
      },
      child: SectionWorkspaceLayout(
        panelTitle: 'Cash Ledger',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 24),
              _buildFilterBar(),
              const SizedBox(height: 24),
              _buildTransactionList(),
              const SizedBox(height: 24),
              _buildPaymentAccountDistribution(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return BlocBuilder<CashLedgerCubit, CashLedgerState>(
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            final cards = [
              _SummaryCard(
                icon: Icons.receipt_long,
                label: 'Orders',
                value: _formatCurrency(state.totalOrderTransactions),
                color: AuthColors.primary,
              ),
              _SummaryCard(
                icon: Icons.payment,
                label: 'Payments',
                value: _formatCurrency(state.totalPayments),
                color: AuthColors.success,
              ),
              _SummaryCard(
                icon: Icons.shopping_cart,
                label: 'Purchases',
                value: _formatCurrency(state.totalPurchases),
                color: AuthColors.info,
              ),
              _SummaryCard(
                icon: Icons.trending_down,
                label: 'Expenses',
                value: _formatCurrency(state.totalExpenses),
                color: AuthColors.warning,
              ),
            ];
            if (isWide) {
              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return BlocBuilder<CashLedgerCubit, CashLedgerState>(
      builder: (context, state) {
        return Row(
          children: [
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
                      const Icon(Icons.calendar_today,
                          color: AuthColors.textSub, size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Start',
                              style: TextStyle(
                                  color: AuthColors.textSub, fontSize: 10)),
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
                      const Icon(Icons.calendar_today,
                          color: AuthColors.textSub, size: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('End',
                              style: TextStyle(
                                  color: AuthColors.textSub, fontSize: 10)),
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
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AuthColors.textMain),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search,
                      color: AuthColors.textSub, size: 20),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: AuthColors.textSub, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  hintText: 'Search...',
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
            FilledButton.icon(
              onPressed: () => context.read<CashLedgerCubit>().refresh(),
              icon: const Icon(Icons.refresh, size: 22),
              label: const Text('Refresh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList() {
    return BlocBuilder<CashLedgerCubit, CashLedgerState>(
      builder: (context, state) {
        final isLoading = state.status == ViewStatus.loading;
        var list = state.allRows;

        if (state.searchQuery.isNotEmpty) {
          final query = state.searchQuery.toLowerCase();
          list = list.where((tx) {
            final description = tx.description?.toLowerCase() ?? '';
            final reference = tx.referenceNumber?.toLowerCase() ?? '';
            final amount = tx.amount.toString();
            final clientName = tx.clientName?.toLowerCase() ?? '';
            final accountName = tx.paymentAccountName?.toLowerCase() ?? '';
            final vendorName = tx.metadata?['vendorName']?.toString().toLowerCase() ?? '';
            final typeLabel = _rowTypeLabel(tx).toLowerCase();
            return description.contains(query) ||
                reference.contains(query) ||
                amount.contains(query) ||
                clientName.contains(query) ||
                accountName.contains(query) ||
                vendorName.contains(query) ||
                typeLabel.contains(query);
          }).toList();
        }

        if (isLoading && list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: List.generate(4, (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SkeletonLoader(
                          height: 64,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(6, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonLoader(
                      height: 48,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
                ],
              ),
            ),
          );
        }

        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions found',
            message: 'There are no transactions for the selected date range.',
          );
        }

        return _buildTransactionTable(list, state);
      },
    );
  }

  Widget _buildPaymentAccountDistribution() {
    return BlocBuilder<CashLedgerCubit, CashLedgerState>(
      builder: (context, state) {
        final distribution = state.paymentAccountDistribution;
        if (distribution.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment account distribution',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return isWide
                    ? custom_table.DataTable<PaymentAccountSummary>(
                        columns: [
                          custom_table.DataTableColumn<PaymentAccountSummary>(
                            label: 'Account',
                            cellBuilder: (context, s, _) => Text(
                              s.displayName,
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          custom_table.DataTableColumn<PaymentAccountSummary>(
                            label: 'Income',
                            numeric: true,
                            cellBuilder: (context, s, _) => Text(
                              _formatCurrency(s.income),
                              style: const TextStyle(
                                color: AuthColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          custom_table.DataTableColumn<PaymentAccountSummary>(
                            label: 'Expenses',
                            numeric: true,
                            cellBuilder: (context, s, _) => Text(
                              _formatCurrency(s.expense),
                              style: const TextStyle(
                                color: AuthColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          custom_table.DataTableColumn<PaymentAccountSummary>(
                            label: 'Net',
                            numeric: true,
                            cellBuilder: (context, s, _) => Text(
                              _formatCurrency(s.net),
                              style: TextStyle(
                                color: s.net >= 0
                                    ? AuthColors.success
                                    : AuthColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        rows: distribution,
                        headerBackgroundColor: AuthColors.surface,
                      )
                    : Column(
                        children: distribution
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: DashCard(
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
                            )
                            .toList(),
                      );
              },
            ),
          ],
        );
      },
    );
  }

  String _rowTypeLabel(Transaction tx) {
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

  Widget _buildTransactionTable(List<Transaction> transactions, CashLedgerState state) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final isAdmin = orgState.isAdmin;

    final columns = <custom_table.DataTableColumn<Transaction>>[
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
        label: 'Type',
        icon: Icons.category,
        flex: 1,
        alignment: Alignment.center,
        cellBuilder: (context, transaction, index) {
          return Text(
            _rowTypeLabel(transaction),
            style: const TextStyle(
              color: AuthColors.textSub,
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
        label: 'Credit',
        icon: Icons.add_circle_outline,
        flex: 2,
        alignment: Alignment.center,
        numeric: true,
        cellBuilder: (context, transaction, index) {
          final isCredit = transaction.type == TransactionType.credit;
          return Text(
            isCredit ? _formatCurrency(transaction.amount) : '–',
            style: TextStyle(
              color: isCredit ? AuthColors.success : AuthColors.textSub,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
      custom_table.DataTableColumn<Transaction>(
        label: 'Debit',
        icon: Icons.remove_circle_outline,
        flex: 2,
        alignment: Alignment.center,
        numeric: true,
        cellBuilder: (context, transaction, index) {
          final isDebit = transaction.type == TransactionType.debit;
          return Text(
            isDebit ? _formatCurrency(transaction.amount) : '–',
            style: TextStyle(
              color: isDebit ? AuthColors.error : AuthColors.textSub,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro Display',
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    ];

    final rowActions = <custom_table.DataTableRowAction<Transaction>>[];
    if (isAdmin) {
      rowActions.add(
        custom_table.DataTableRowAction<Transaction>(
          icon: Icons.verified_user,
          tooltip: 'Verify / Unverify',
          color: AuthColors.success,
          onTap: (transaction, index) {
            if (transaction.verified) {
              _showUnverifyDialog(context, transaction);
            } else {
              _verifyDirect(context, transaction);
            }
          },
        ),
      );
    }
    rowActions.add(
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.delete_outline,
        tooltip: 'Delete',
        color: AuthColors.error,
        onTap: (transaction, index) {
          if (transaction.verified) {
            DashSnackbar.show(
              context,
              message: 'Verified entries cannot be edited or deleted.',
              isError: false,
            );
            return;
          }
          _showDeleteConfirmation(context, transaction);
        },
      ),
    );

    return custom_table.DataTable<Transaction>(
      columns: columns,
      rows: transactions,
      rowActions: rowActions,
      rowBackgroundColorBuilder: (transaction, index) =>
          transaction.verified
              ? AuthColors.success.withOpacity(0.15)
              : AuthColors.error.withOpacity(0.15),
      emptyStateMessage: 'No transactions found',
      emptyStateIcon: Icons.receipt_long_outlined,
    );
  }

  String _getTransactionTitle(Transaction transaction) {
    switch (transaction.category) {
      case TransactionCategory.advance:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            'Advance';
      case TransactionCategory.tripPayment:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            'Trip Payment';
      case TransactionCategory.clientPayment:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            transaction.metadata?['clientName']?.toString().trim() ??
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
                : 'Salary');
      case TransactionCategory.generalExpense:
        return transaction.metadata?['subCategoryName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Expense');
      default:
        return (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Transaction');
    }
  }

  void _verifyDirect(BuildContext context, Transaction transaction) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState.userProfile?.id ?? '';
    if (uid.isEmpty) return;
    context.read<CashLedgerCubit>().updateVerification(
          transactionId: transaction.id,
          verified: true,
          verifiedBy: uid,
        );
  }

  void _showUnverifyDialog(BuildContext context, Transaction transaction) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState.userProfile?.id ?? '';
    if (uid.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Unverify transaction?',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'This will allow the transaction to be edited again. Only use for corrections.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Unverify',
            onPressed: () {
              context.read<CashLedgerCubit>().updateVerification(
                    transactionId: transaction.id,
                    verified: false,
                    verifiedBy: uid,
                  );
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Transaction transaction) {
    if (transaction.id.isEmpty || transaction.id.trim().isEmpty) {
      DashSnackbar.show(
        context,
        message: 'Cannot delete: Invalid transaction ID',
        isError: true,
      );
      return;
    }
    if (transaction.verified) {
      DashSnackbar.show(
        context,
        message: 'Verified entries cannot be edited or deleted.',
        isError: false,
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
              context.read<CashLedgerCubit>().deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
