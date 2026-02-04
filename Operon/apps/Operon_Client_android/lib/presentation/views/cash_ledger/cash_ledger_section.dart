import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/presentation/blocs/cash_ledger/cash_ledger_cubit.dart';
import 'package:dash_mobile/presentation/blocs/cash_ledger/cash_ledger_state.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> _paymentAccountNames = {};

  @override
  void initState() {
    super.initState();
    context.read<CashLedgerCubit>().load();
    _searchController.addListener(_onSearchChanged);
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
    // If it's in the map, it means the state used the ID as fallback
    final trimmed = displayName.trim();
    if (_paymentAccountNames.containsKey(trimmed)) {
      return _paymentAccountNames[trimmed]!;
    }
    // Otherwise, it's already a name, use it as-is
    return trimmed.isEmpty ? 'Unknown' : trimmed;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<CashLedgerCubit>().search(_searchController.text);
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  Future<void> _handleDateRangePicker() async {
    final cubit = context.read<CashLedgerCubit>();
    final state = cubit.state;
    
    // Pass current date range from state, or default to today-today
    final currentRange = (state.startDate != null && state.endDate != null)
        ? DateTimeRange(start: state.startDate!, end: state.endDate!)
        : null;
    
    final range = await showLedgerDateRangeModal(
      context,
      initialRange: currentRange,
    );
    
    if (range != null && mounted) {
      await cubit.setDateRange(range.start, range.end);
    }
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
      child: BlocBuilder<CashLedgerCubit, CashLedgerState>(
        builder: (context, state) {
          // Sync search controller with state
          if (_searchController.text != state.searchQuery) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_searchController.text != state.searchQuery) {
                _searchController.text = state.searchQuery;
              }
            });
          }
          
          return RefreshIndicator(
            onRefresh: () => context.read<CashLedgerCubit>().refresh(),
            color: AuthColors.primary,
            child: SizedBox.expand(
              child: CustomScrollView(
                slivers: [
                  // Header section with summary stats and search
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AuthColors.background,
                        border: Border(
                          bottom: BorderSide(
                            color: AuthColors.surface.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Stats Cards Row
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Income',
                                    amount: state.totalIncome,
                                    color: AuthColors.success,
                                    formatCurrency: _formatCurrency,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.paddingSM),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Out',
                                    amount: state.totalOutcome,
                                    color: AuthColors.error,
                                    formatCurrency: _formatCurrency,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.paddingSM),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Net',
                                    amount: state.netBalance,
                                    color: state.netBalance >= 0
                                        ? AuthColors.success
                                        : AuthColors.error,
                                    formatCurrency: _formatCurrency,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.paddingMD),
                            // Date range picker and search bar row
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AuthColors.surface.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AuthColors.surface.withOpacity(0.8),
                                        width: 1,
                                      ),
                                    ),
                                    child: StandardSearchBar(
                                      controller: _searchController,
                                      hintText: 'Search by name, ref, amount...',
                                      onChanged: (value) {
                                        context.read<CashLedgerCubit>().search(value);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.paddingSM),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AuthColors.surface.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AuthColors.surface.withOpacity(0.8),
                                      width: 1,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      color: AuthColors.textMain,
                                      size: 20,
                                    ),
                                    tooltip: 'Select date range',
                                    onPressed: _handleDateRangePicker,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.paddingMD),
                            // Column headers with background
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.paddingSM,
                                horizontal: 0,
                              ),
                              decoration: BoxDecoration(
                                color: AuthColors.surface.withOpacity(0.4),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        'Transaction',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AuthColors.textSub,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Credit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AuthColors.success,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.paddingSM),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Debit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AuthColors.error,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // LinearProgressIndicator for stream updates when list is not empty
                  if (state.status == ViewStatus.loading && state.allRows.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: AuthColors.primary,
                        minHeight: 2,
                      ),
                    ),
                  // Loading state when empty
                  if (state.status == ViewStatus.loading && state.allRows.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  // Empty state
                  else if (state.allRows.isEmpty)
                    SliverFillRemaining(
                      child: EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'No transactions found',
                        message: state.searchQuery.isNotEmpty
                            ? 'No transactions match your search'
                            : 'Add your first transaction to get started',
                      ),
                    )
                  // Transaction table
                  else ...[
                    BlocBuilder<CashLedgerCubit, CashLedgerState>(
                      builder: (context, state) {
                        final list = state.allRows;
                        // Calculate totals
                        double totalCredit = 0;
                        double totalDebit = 0;
                        for (final tx in list) {
                          if (tx.type == TransactionType.credit) {
                            totalCredit += tx.amount;
                          } else {
                            totalDebit += tx.amount;
                          }
                        }
                        
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == list.length) {
                                  // Footer row with totals
                                  return _TransactionTableFooter(
                                    totalCredit: totalCredit,
                                    totalDebit: totalDebit,
                                    formatCurrency: _formatCurrency,
                                  );
                                }
                                final tx = list[index];
                                final isEven = index % 2 == 0;
                                return _TransactionTableRow(
                                  transaction: tx,
                                  typeLabel: _rowTypeLabel(tx),
                                  formatCurrency: _formatCurrency,
                                  isEven: isEven,
                                );
                              },
                              childCount: list.length + 1, // +1 for footer
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                            ),
                          ),
                        );
                      },
                    ),
                    // Load More trigger (for future pagination)
                    const SliverToBoxAdapter(
                      child: _LoadMoreTrigger(),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: BlocBuilder<CashLedgerCubit, CashLedgerState>(
                      builder: (context, state) {
                        final distribution = state.paymentAccountDistribution;
                        if (distribution.isEmpty) {
                          return const SizedBox(height: AppSpacing.paddingXXL);
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment account distribution',
                                style: AppTypography.withColor(
                                  AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
                                  AuthColors.textMain,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.paddingMD),
                              ...distribution.map(
                                (s) => Card(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.paddingSM),
                                  color: AuthColors.surface.withOpacity(0.6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.paddingMD),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 18,
                                              color: AuthColors.primary,
                                            ),
                                            const SizedBox(width: AppSpacing.paddingSM),
                                            Expanded(
                                              child: Text(
                                                _getPaymentAccountDisplayName(s.displayName),
                                                style: AppTypography.withColor(
                                                  AppTypography.withWeight(
                                                    AppTypography.bodyLarge,
                                                    FontWeight.w700,
                                                  ),
                                                  AuthColors.textMain,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.paddingMD),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_downward,
                                                  size: 14,
                                                  color: AuthColors.success,
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Income',
                                                  style: TextStyle(
                                                    color: AuthColors.textSub,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              _formatCurrency(s.income),
                                              style: AppTypography.withColor(
                                                AppTypography.withWeight(
                                                  AppTypography.labelSmall,
                                                  FontWeight.w600,
                                                ),
                                                AuthColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.paddingSM),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward,
                                                  size: 14,
                                                  color: AuthColors.error,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Expenses',
                                                  style: AppTypography.withColor(
                                                    AppTypography.labelSmall,
                                                    AuthColors.textSub,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              _formatCurrency(s.expense),
                                              style: AppTypography.withColor(
                                                AppTypography.withWeight(
                                                  AppTypography.labelSmall,
                                                  FontWeight.w600,
                                                ),
                                                AuthColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.paddingSM),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppSpacing.paddingSM,
                                            horizontal: AppSpacing.paddingMD,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (s.net >= 0
                                                    ? AuthColors.success
                                                    : AuthColors.error)
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (s.net >= 0
                                                      ? AuthColors.success
                                                      : AuthColors.error)
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Net Balance',
                                                style: AppTypography.withColor(
                                                  AppTypography.withWeight(
                                                    AppTypography.labelSmall,
                                                    FontWeight.w600,
                                                  ),
                                                  AuthColors.textMain,
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(s.net),
                                                style: AppTypography.withColor(
                                                  AppTypography.withWeight(
                                                    AppTypography.body,
                                                    FontWeight.w700,
                                                  ),
                                                  s.net >= 0
                                                      ? AuthColors.success
                                                      : AuthColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
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
            ),
          );
        },
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

}

/// Summary card widget for displaying income/outcome/net stats
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.formatCurrency,
  });

  final String label;
  final double amount;
  final Color color;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingSM),
      decoration: BoxDecoration(
        color: AuthColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AuthColors.textSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Load More trigger widget for future pagination support
class _LoadMoreTrigger extends StatelessWidget {
  const _LoadMoreTrigger();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingLG),
      child: Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: Opacity(
            opacity: 0.5,
            child: Icon(
              Icons.more_horiz,
              color: AuthColors.textSub,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer row widget for displaying totals
class _TransactionTableFooter extends StatelessWidget {
  const _TransactionTableFooter({
    required this.totalCredit,
    required this.totalDebit,
    required this.formatCurrency,
  });

  final double totalCredit;
  final double totalDebit;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
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
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Transaction column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(
                    Icons.calculate,
                    size: 18,
                    color: AuthColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total',
                    style: AppTypography.withColor(
                      AppTypography.withWeight(
                        AppTypography.bodyLarge,
                        FontWeight.w700,
                      ),
                      AuthColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            // Credit column
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(totalCredit),
                    style: AppTypography.withColor(
                      AppTypography.withWeight(
                        AppTypography.bodyLarge,
                        FontWeight.w700,
                      ),
                      AuthColors.success,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            // Debit column
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(totalDebit),
                    style: TextStyle(
                      color: AuthColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Table row widget for displaying transactions in a read-only table format
class _TransactionTableRow extends StatelessWidget {
  const _TransactionTableRow({
    required this.transaction,
    required this.typeLabel,
    required this.formatCurrency,
    required this.isEven,
  });

  final Transaction transaction;
  final String typeLabel;
  final String Function(double) formatCurrency;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    final date = transaction.createdAt ?? DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final title = _title(transaction);
    final isCredit = transaction.type == TransactionType.credit;
    
    return Container(
      decoration: BoxDecoration(
        color: isEven
            ? Colors.transparent
            : AuthColors.surface.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.surface.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction column
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: isCredit ? AuthColors.success : AuthColors.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.withColor(
                            AppTypography.body,
                            AuthColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transaction.verified) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: AuthColors.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$typeLabel • $dateStr${transaction.referenceNumber != null ? ' • ${transaction.referenceNumber}' : ''}',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Credit column
            SizedBox(
              width: 80,
              child: Text(
                isCredit ? formatCurrency(transaction.amount) : '–',
                style: AppTypography.withColor(
                  AppTypography.body,
                  isCredit ? AuthColors.success : AuthColors.textSub,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            // Debit column
            SizedBox(
              width: 80,
              child: Text(
                !isCredit ? formatCurrency(transaction.amount) : '–',
                style: TextStyle(
                  color: !isCredit ? AuthColors.error : AuthColors.textSub,
                  fontSize: 14,
                ),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(Transaction tx) {
    // Extract Vendor Name, Client Name, or Employee Name based on transaction category
    switch (tx.category) {
      case TransactionCategory.advance:
      case TransactionCategory.tripPayment:
      case TransactionCategory.clientPayment:
        // Show Client Name
        return tx.clientName?.trim().isNotEmpty == true
            ? tx.clientName!
            : tx.metadata?['clientName']?.toString().trim() ?? 
              (tx.description?.isNotEmpty == true ? tx.description! : 'Client');
      
      case TransactionCategory.vendorPurchase:
      case TransactionCategory.vendorPayment:
        // Show Vendor Name
        return tx.metadata?['vendorName']?.toString().trim() ?? 
               (tx.description?.isNotEmpty == true ? tx.description! : 'Vendor');
      
      case TransactionCategory.salaryDebit:
        // Show Employee Name
        return tx.metadata?['employeeName']?.toString().trim() ?? 
               (tx.description?.isNotEmpty == true ? tx.description! : 'Employee');
      
      case TransactionCategory.generalExpense:
        // Show Sub Category Name if available, otherwise description
        return tx.metadata?['subCategoryName']?.toString().trim() ?? 
               (tx.description?.isNotEmpty == true ? tx.description! : 'Expense');
      
      default:
        // Fallback: try to get client name, vendor name, or employee name from metadata
        return tx.clientName?.trim().isNotEmpty == true
            ? tx.clientName!
            : tx.metadata?['clientName']?.toString().trim() ??
              tx.metadata?['vendorName']?.toString().trim() ??
              tx.metadata?['employeeName']?.toString().trim() ??
              (tx.description?.isNotEmpty == true ? tx.description! : 'Transaction');
    }
  }
}
