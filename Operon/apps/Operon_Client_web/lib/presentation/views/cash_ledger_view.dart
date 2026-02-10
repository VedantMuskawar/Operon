import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/cash_ledger/cash_ledger_cubit.dart';
import 'package:dash_web/presentation/blocs/cash_ledger/cash_ledger_state.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/salary_voucher_modal.dart';
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
  Map<String, String> _paymentAccountNames = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    context.read<CashLedgerCubit>().load();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) {
      return;
    }

    try {
      final repository = context.read<PaymentAccountsRepository>();
      final accounts = await repository.fetchAccounts(organization.id);
      final nameMap = <String, String>{};
      for (final account in accounts) {
        nameMap[account.id] = account.name;
      }
      // Add "cash" as a special case
      nameMap['cash'] = 'Cash';
      if (mounted) {
        setState(() {
          _paymentAccountNames = nameMap;
        });
      }
    } catch (e) {
      // Silently fail - will fallback to ID or name from transaction
    }
  }

  String _getPaymentAccountDisplayName(String displayName) {
    // Check if displayName is actually an ID (exists as a key in our map)
    final trimmed = displayName.trim();
    if (_paymentAccountNames.containsKey(trimmed)) {
      return _paymentAccountNames[trimmed]!;
    }
    // Otherwise, it's already a name, use it as-is
    return trimmed.isEmpty ? 'Unknown' : trimmed;
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
            custom_table.DataTable<PaymentAccountSummary>(
              columns: [
                custom_table.DataTableColumn<PaymentAccountSummary>(
                  label: 'Account',
                  flex: 2,
                  alignment: Alignment.center,
                  cellBuilder: (context, s, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 16,
                        color: AuthColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getPaymentAccountDisplayName(s.displayName),
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            fontFamily: 'SF Pro Display',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                custom_table.DataTableColumn<PaymentAccountSummary>(
                  label: 'Income',
                  flex: 2,
                  numeric: true,
                  alignment: Alignment.center,
                  cellBuilder: (context, s, _) => Text(
                    _formatCurrency(s.income),
                    style: const TextStyle(
                      color: AuthColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'SF Pro Display',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                custom_table.DataTableColumn<PaymentAccountSummary>(
                  label: 'Expenses',
                  flex: 2,
                  numeric: true,
                  alignment: Alignment.center,
                  cellBuilder: (context, s, _) => Text(
                    _formatCurrency(s.expense),
                    style: const TextStyle(
                      color: AuthColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'SF Pro Display',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                custom_table.DataTableColumn<PaymentAccountSummary>(
                  label: 'Net',
                  flex: 2,
                  numeric: true,
                  alignment: Alignment.center,
                  cellBuilder: (context, s, _) => Text(
                    _formatCurrency(s.net),
                    style: TextStyle(
                      color: s.net >= 0
                          ? AuthColors.success
                          : AuthColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'SF Pro Display',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              rows: distribution,
              headerBackgroundColor: AuthColors.surface,
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
      case TransactionCategory.clientCredit:
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
    
    final rowActions = <custom_table.DataTableRowAction<Transaction>>[];

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
          // Show client name for order transactions and payments
          String clientName = '-';
          if (transaction.category == TransactionCategory.advance ||
              transaction.category == TransactionCategory.tripPayment ||
              transaction.category == TransactionCategory.clientCredit ||
              transaction.category == TransactionCategory.clientPayment ||
              transaction.category == TransactionCategory.refund) {
            clientName = transaction.clientName?.trim() ?? 
                        transaction.metadata?['clientName']?.toString().trim() ?? 
                        '-';
          } else if (transaction.category == TransactionCategory.vendorPurchase ||
                     transaction.category == TransactionCategory.vendorPayment) {
            // For vendor transactions, show vendor name
            clientName = transaction.metadata?['vendorName']?.toString().trim() ?? 
                        transaction.description?.trim() ?? 
                        '-';
          } else if (transaction.category == TransactionCategory.salaryDebit) {
            // For salary transactions, show employee name
            clientName = transaction.metadata?['employeeName']?.toString().trim() ?? 
                        transaction.description?.trim() ?? 
                        '-';
          } else {
            // For other transactions, show description or fallback
            clientName = transaction.description?.trim() ?? '-';
          }
          
          return Text(
            clientName,
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
          // Show DM number if available, otherwise show reference number
          final dmNumber = transaction.metadata?['dmNumber'];
          String ref = '-';
          if (dmNumber != null) {
            ref = 'DM-$dmNumber';
          } else if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
            ref = transaction.referenceNumber!;
          }
          
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
          final transactionCount = transaction.metadata?['transactionCount'] as int?;
          final isGrouped = transactionCount != null && transactionCount > 1;
          
          double creditAmount = 0.0;
          List<Map<String, dynamic>> paymentAccounts = []; // List of {name, amount}
          
          if (isGrouped) {
            // For grouped transactions, use cumulative credit from metadata
            creditAmount = (transaction.metadata?['cumulativeCredit'] as num?)?.toDouble() ?? 0.0;
            // Get payment accounts with amounts from metadata
            final creditAccounts = transaction.metadata?['creditPaymentAccounts'] as List?;
            if (creditAccounts != null) {
              paymentAccounts = creditAccounts
                  .map((acc) {
                    final accMap = acc as Map<String, dynamic>?;
                    var name = accMap?['name']?.toString().trim() ?? '';
                    final amount = (accMap?['amount'] as num?)?.toDouble() ?? 0.0;
                    if (name.isNotEmpty && amount > 0) {
                      // If name looks like an ID (exists in paymentAccountNames map), resolve it
                      if (_paymentAccountNames.containsKey(name)) {
                        name = _paymentAccountNames[name]!;
                      } else {
                        // Try to resolve using getPaymentAccountDisplayName
                        name = _getPaymentAccountDisplayName(name);
                      }
                      return {'name': name, 'amount': amount};
                    }
                    return null;
                  })
                  .whereType<Map<String, dynamic>>()
                  .toList();
            }
          } else {
            // For single transactions, use amount if credit type
            final isCredit = transaction.type == TransactionType.credit;
            creditAmount = isCredit ? transaction.amount : 0.0;
            // Get payment account name for single transaction
            if (creditAmount > 0) {
              final accountName = transaction.paymentAccountName?.trim();
              final accountId = transaction.paymentAccountId?.trim();
              String? name;
              if (accountName != null && accountName.isNotEmpty) {
                name = accountName;
              } else if (accountId != null && accountId.isNotEmpty) {
                name = _getPaymentAccountDisplayName(accountId);
              }
              if (name != null && name.isNotEmpty) {
                paymentAccounts = [{'name': name, 'amount': creditAmount}];
              }
            }
          }
          
          // Format amount string: "X+Y" if multiple accounts, otherwise just the total
          String amountText = creditAmount > 0 ? _formatCurrency(creditAmount) : '–';
          if (creditAmount > 0 && paymentAccounts.length > 1) {
            final amounts = paymentAccounts.map((acc) => _formatCurrency(acc['amount'] as double)).join('+');
            amountText = amounts;
          }
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  color: creditAmount > 0 ? AuthColors.success : AuthColors.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (creditAmount > 0 && paymentAccounts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: paymentAccounts.map((acc) {
                    final name = acc['name'] as String;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AuthColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AuthColors.success.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AuthColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
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
          final transactionCount = transaction.metadata?['transactionCount'] as int?;
          final isGrouped = transactionCount != null && transactionCount > 1;
          
          double debitAmount = 0.0;
          List<Map<String, dynamic>> paymentAccounts = []; // List of {name, amount}
          
          if (isGrouped) {
            // For grouped transactions, use cumulative debit from metadata
            debitAmount = (transaction.metadata?['cumulativeDebit'] as num?)?.toDouble() ?? 0.0;
            // Get payment accounts with amounts from metadata
            final debitAccounts = transaction.metadata?['debitPaymentAccounts'] as List?;
            if (debitAccounts != null) {
              paymentAccounts = debitAccounts
                  .map((acc) {
                    final accMap = acc as Map<String, dynamic>?;
                    var name = accMap?['name']?.toString().trim() ?? '';
                    final amount = (accMap?['amount'] as num?)?.toDouble() ?? 0.0;
                    if (name.isNotEmpty && amount > 0) {
                      // If name looks like an ID (exists in paymentAccountNames map), resolve it
                      if (_paymentAccountNames.containsKey(name)) {
                        name = _paymentAccountNames[name]!;
                      } else {
                        // Try to resolve using getPaymentAccountDisplayName
                        name = _getPaymentAccountDisplayName(name);
                      }
                      return {'name': name, 'amount': amount};
                    }
                    return null;
                  })
                  .whereType<Map<String, dynamic>>()
                  .toList();
            }
          } else {
            // For single transactions, use amount if debit type
            final isDebit = transaction.type == TransactionType.debit;
            debitAmount = isDebit ? transaction.amount : 0.0;
            // Get payment account name for single transaction
            if (debitAmount > 0) {
              final accountName = transaction.paymentAccountName?.trim();
              final accountId = transaction.paymentAccountId?.trim();
              String? name;
              if (accountName != null && accountName.isNotEmpty) {
                name = accountName;
              } else if (accountId != null && accountId.isNotEmpty) {
                name = _getPaymentAccountDisplayName(accountId);
              }
              if (name != null && name.isNotEmpty) {
                paymentAccounts = [{'name': name, 'amount': debitAmount}];
              }
            }
          }
          
          // Format amount string: "X+Y" if multiple accounts, otherwise just the total
          String amountText = debitAmount > 0 ? _formatCurrency(debitAmount) : '–';
          if (debitAmount > 0 && paymentAccounts.length > 1) {
            final amounts = paymentAccounts.map((acc) => _formatCurrency(acc['amount'] as double)).join('+');
            amountText = amounts;
          }
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  color: debitAmount > 0 ? AuthColors.error : AuthColors.textSub,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (debitAmount > 0 && paymentAccounts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: paymentAccounts.map((acc) {
                    final name = acc['name'] as String;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AuthColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AuthColors.error.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AuthColors.error,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    ];

    rowActions.add(
      custom_table.DataTableRowAction<Transaction>(
        icon: Icons.receipt_long,
        tooltip: 'View voucher',
        color: AuthColors.primary,
        onTap: (transaction, index) {
          final hasVoucher = transaction.category == TransactionCategory.salaryDebit &&
              transaction.metadata?['cashVoucherPhotoUrl'] != null &&
              (transaction.metadata!['cashVoucherPhotoUrl'] as String).isNotEmpty;
          if (hasVoucher) {
            showSalaryVoucherModal(context, transaction.id);
          } else {
            DashSnackbar.show(
              context,
              message: 'No voucher for this transaction',
              isError: false,
            );
          }
        },
      ),
    );
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        custom_table.DataTable<Transaction>(
          columns: columns,
          rows: transactions,
          rowActions: rowActions,
          rowBackgroundColorBuilder: (transaction, index) =>
              transaction.verified
                  ? AuthColors.success.withOpacity(0.15)
                  : AuthColors.error.withOpacity(0.15),
          emptyStateMessage: 'No transactions found',
          emptyStateIcon: Icons.receipt_long_outlined,
        ),
        if (transactions.isNotEmpty) _buildTableFooter(state, rowActions.length),
      ],
    );
  }

  Widget _buildTableFooter(CashLedgerState state, int actionButtonCount) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.primary.withOpacity(0.15),
            AuthColors.primary.withOpacity(0.05),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AuthColors.primary.withOpacity(0.5),
            width: 2,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            // Date column
            Expanded(
              flex: 2,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate,
                      size: 18,
                      color: AuthColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Type column (empty)
            Expanded(
              flex: 1,
              child: SizedBox.shrink(),
            ),
            // Name column (empty)
            Expanded(
              flex: 3,
              child: SizedBox.shrink(),
            ),
            // Reference column (empty)
            Expanded(
              flex: 2,
              child: SizedBox.shrink(),
            ),
            // Credit column
            Expanded(
              flex: 2,
              child: Text(
                _formatCurrency(state.totalCredit),
                style: TextStyle(
                  color: AuthColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Debit column
            Expanded(
              flex: 2,
              child: Text(
                _formatCurrency(state.totalDebit),
                style: TextStyle(
                  color: AuthColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Actions column spacing (approximate width for action buttons)
            if (actionButtonCount > 0)
              SizedBox(
                width: actionButtonCount * 48.0, // Approximate width per action button
              ),
          ],
        ),
      ),
    );
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
