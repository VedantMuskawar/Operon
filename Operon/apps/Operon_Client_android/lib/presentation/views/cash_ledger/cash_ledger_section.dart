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

  List<PaymentAccountSummary> _filterActualPaymentAccounts(
    List<PaymentAccountSummary> distribution,
  ) {
    if (_paymentAccountNames.isEmpty) {
      return distribution;
    }
    final ids = _paymentAccountNames.keys
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = _paymentAccountNames.values
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();

    return distribution.where((summary) {
      final normalized = summary.displayName.trim().toLowerCase();
      return ids.contains(normalized) || names.contains(normalized);
    }).toList();
  }

  int? _getDmNumber(Transaction tx) {
    final dmNumber = tx.metadata?['dmNumber'];
    if (dmNumber == null) return null;
    if (dmNumber is int) return dmNumber;
    if (dmNumber is num) return dmNumber.toInt();
    return null;
  }

  bool _groupHasDebit(List<Transaction> group) {
    for (final tx in group) {
      final count = tx.metadata?['transactionCount'] as int?;
      if (count != null && count > 1) {
        final cumulativeDebit =
            (tx.metadata?['cumulativeDebit'] as num?)?.toDouble() ?? 0.0;
        if (cumulativeDebit > 0) {
          return true;
        }
      } else if (tx.type == TransactionType.debit) {
        return true;
      }
    }
    return false;
  }

  double _groupTrueClientCreditTotal(List<Transaction> group) {
    double total = 0.0;
    var usedCumulative = false;
    for (final tx in group) {
      if (tx.category != TransactionCategory.clientCredit) {
        continue;
      }
      final count = tx.metadata?['transactionCount'] as int?;
      if (count != null && count > 1) {
        if (!usedCumulative) {
          total +=
              (tx.metadata?['cumulativeCredit'] as num?)?.toDouble() ?? 0.0;
          usedCumulative = true;
        }
      } else if (tx.type == TransactionType.credit) {
        total += tx.amount;
      }
    }
    return total;
  }

  double _calculateTrueClientCreditTotal(List<Transaction> orderTransactions) {
    final withDmNumber = <int, List<Transaction>>{};
    final withoutDmNumber = <Transaction>[];

    for (final tx in orderTransactions) {
      final dmNumber = _getDmNumber(tx);
      if (dmNumber != null) {
        withDmNumber.putIfAbsent(dmNumber, () => []).add(tx);
      } else {
        withoutDmNumber.add(tx);
      }
    }

    double total = 0.0;
    for (final group in withDmNumber.values) {
      if (!_groupHasDebit(group)) {
        total += _groupTrueClientCreditTotal(group);
      }
    }
    for (final tx in withoutDmNumber) {
      if (tx.category == TransactionCategory.clientCredit &&
          tx.type == TransactionType.credit) {
        total += tx.amount;
      }
    }

    return total;
  }

  Widget _buildCreditTransactionsTable(CashLedgerState state) {
    double totalFrom(List<Transaction> rows) {
      var total = 0.0;
      for (final tx in rows) {
        final count = tx.metadata?['transactionCount'] as int?;
        if (count != null && count > 1) {
          total +=
              (tx.metadata?['cumulativeCredit'] as num?)?.toDouble() ?? 0.0;
        } else if (tx.type == TransactionType.credit) {
          total += tx.amount;
        }
      }
      return total;
    }

    final clientTotal =
        _calculateTrueClientCreditTotal(state.orderTransactions);
    final vendorTotal = totalFrom(state.vendorCreditRows);
    final employeeTotal = totalFrom(state.employeeCreditRows);

    if (clientTotal == 0 && vendorTotal == 0 && employeeTotal == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit summary',
            style: AppTypography.withColor(
              AppTypography.withWeight(AppTypography.h3, FontWeight.w700),
              AuthColors.textMain,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Container(
            decoration: BoxDecoration(
              color: AuthColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AuthColors.surface.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.paddingSM,
                    horizontal: AppSpacing.paddingMD,
                  ),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Type',
                          style: TextStyle(
                            fontSize: 12,
                            color: AuthColors.textSub,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.paddingSM),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: AuthColors.success,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCreditSummaryRow('Client Credit', clientTotal, false),
                _buildCreditSummaryRow('Vendor Credit', vendorTotal, false),
                _buildCreditSummaryRow('Employee Credit', employeeTotal, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditSummaryRow(String label, double amount, bool isLast) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: AuthColors.surface.withValues(alpha: 0.3),
                  width: 1,
                ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.paddingMD,
          horizontal: AppSpacing.paddingMD,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: AppTypography.withColor(
                  AppTypography.body,
                  AuthColors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                _formatCurrency(amount),
                style: AppTypography.withColor(
                  AppTypography.withWeight(AppTypography.body, FontWeight.w700),
                  AuthColors.success,
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
        buildWhen: (previous, current) =>
            previous.allRows != current.allRows ||
            previous.status != current.status ||
            previous.selectedTab != current.selectedTab ||
            previous.searchQuery != current.searchQuery ||
            previous.totalIncome != current.totalIncome ||
            previous.totalOutcome != current.totalOutcome ||
            previous.netBalance != current.netBalance,
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
                            color: AuthColors.surface.withValues(alpha: 0.3),
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
                                      color:
                                          AuthColors.surface.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            AuthColors.surface.withValues(alpha: 0.8),
                                        width: 1,
                                      ),
                                    ),
                                    child: StandardSearchBar(
                                      controller: _searchController,
                                      hintText:
                                          'Search by name, ref, amount...',
                                      onChanged: (value) {
                                        context
                                            .read<CashLedgerCubit>()
                                            .search(value);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.paddingSM),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AuthColors.surface.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          AuthColors.surface.withValues(alpha: 0.8),
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
                                color: AuthColors.surface.withValues(alpha: 0.4),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
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
                                  SizedBox(width: AppSpacing.paddingSM),
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
                  if (state.status == ViewStatus.loading &&
                      state.allRows.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: AuthColors.primary,
                        minHeight: 2,
                      ),
                    ),
                  // Loading state when empty
                  if (state.status == ViewStatus.loading &&
                      state.allRows.isEmpty)
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
                      buildWhen: (previous, current) =>
                          previous.allRows != current.allRows ||
                          previous.totalCredit != current.totalCredit ||
                          previous.totalDebit != current.totalDebit,
                      builder: (context, state) {
                        final list = state.allRows;

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == list.length) {
                                  // Footer row with totals
                                  return _TransactionTableFooter(
                                    totalCredit: state.totalCredit,
                                    totalDebit: state.totalDebit,
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
                                  paymentAccountNames: _paymentAccountNames,
                                  getPaymentAccountDisplayName:
                                      _getPaymentAccountDisplayName,
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
                      buildWhen: (previous, current) =>
                          previous.clientCreditRows !=
                              current.clientCreditRows ||
                          previous.vendorCreditRows !=
                              current.vendorCreditRows ||
                          previous.employeeCreditRows !=
                              current.employeeCreditRows,
                      builder: (context, state) =>
                          _buildCreditTransactionsTable(state),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: BlocBuilder<CashLedgerCubit, CashLedgerState>(
                      buildWhen: (previous, current) =>
                          previous.paymentAccountDistribution !=
                          current.paymentAccountDistribution,
                      builder: (context, state) {
                        final distribution = _filterActualPaymentAccounts(
                            state.paymentAccountDistribution);
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
                                  AppTypography.withWeight(
                                      AppTypography.h3, FontWeight.w700),
                                  AuthColors.textMain,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.paddingMD),
                              Container(
                                decoration: BoxDecoration(
                                  color: AuthColors.surface.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AuthColors.surface.withValues(alpha: 0.8),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.paddingSM,
                                        horizontal: AppSpacing.paddingMD,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            AuthColors.surface.withValues(alpha: 0.4),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Account',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.textSub,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Income',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.success,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Expenses',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.error,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Net',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AuthColors.textMain,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Table Rows
                                    ...distribution
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final s = entry.value;
                                      final isLast =
                                          index == distribution.length - 1;
                                      return Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: isLast
                                                ? BorderSide.none
                                                : BorderSide(
                                                    color: AuthColors.surface
                                                        .withValues(alpha: 0.3),
                                                    width: 1,
                                                  ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppSpacing.paddingMD,
                                            horizontal: AppSpacing.paddingMD,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .account_balance_wallet,
                                                      size: 16,
                                                      color: AuthColors.primary,
                                                    ),
                                                    const SizedBox(
                                                        width: AppSpacing
                                                            .paddingSM),
                                                    Expanded(
                                                      child: Text(
                                                        _getPaymentAccountDisplayName(
                                                            s.displayName),
                                                        style: AppTypography
                                                            .withColor(
                                                          AppTypography.body,
                                                          AuthColors.textMain,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  _formatCurrency(s.income),
                                                  style:
                                                      AppTypography.withColor(
                                                    AppTypography.body,
                                                    AuthColors.success,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  _formatCurrency(s.expense),
                                                  style:
                                                      AppTypography.withColor(
                                                    AppTypography.body,
                                                    AuthColors.error,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  _formatCurrency(s.net),
                                                  style: TextStyle(
                                                    color: s.net >= 0
                                                        ? AuthColors.success
                                                        : AuthColors.error,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
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
        color: AuthColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
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
            AuthColors.primary.withValues(alpha: 0.15),
            AuthColors.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AuthColors.primary.withValues(alpha: 0.5),
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
                  const Icon(
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
                    style: const TextStyle(
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
    required this.paymentAccountNames,
    required this.getPaymentAccountDisplayName,
  });

  final Transaction transaction;
  final String typeLabel;
  final String Function(double) formatCurrency;
  final bool isEven;
  final Map<String, String> paymentAccountNames;
  final String Function(String) getPaymentAccountDisplayName;

  @override
  Widget build(BuildContext context) {
    final date = transaction.createdAt ?? DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    // Show client name instead of transaction title
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

    final isCredit = transaction.type == TransactionType.credit;

    return Container(
      decoration: BoxDecoration(
        color:
            isEven ? Colors.transparent : AuthColors.surface.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: AuthColors.surface.withValues(alpha: 0.2),
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
                          clientName,
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
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AuthColors.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final transactionCount =
                          transaction.metadata?['transactionCount'] as int?;
                      final dmNumber = transaction.metadata?['dmNumber'];
                      final isGrouped =
                          transactionCount != null && transactionCount > 1;

                      final parts = <String>[
                        typeLabel,
                        dateStr,
                      ];

                      if (isGrouped && dmNumber != null) {
                        parts.add('$transactionCount transactions');
                      }

                      // Show DM number instead of reference number
                      if (dmNumber != null) {
                        parts.add('DM-$dmNumber');
                      } else if (transaction.referenceNumber != null &&
                          transaction.referenceNumber!.isNotEmpty) {
                        parts.add(transaction.referenceNumber!);
                      }

                      return Text(
                        parts.join(' • '),
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Credit column
            Builder(
              builder: (context) {
                final transactionCount =
                    transaction.metadata?['transactionCount'] as int?;
                final isGrouped =
                    transactionCount != null && transactionCount > 1;

                double creditAmount = 0.0;
                List<Map<String, dynamic>> paymentAccounts =
                    []; // List of {name, amount}

                if (isGrouped) {
                  // For grouped transactions, use cumulative credit from metadata
                  creditAmount =
                      (transaction.metadata?['cumulativeCredit'] as num?)
                              ?.toDouble() ??
                          0.0;
                  // Get payment accounts with amounts from metadata
                  final creditAccounts =
                      transaction.metadata?['creditPaymentAccounts'] as List?;
                  if (creditAccounts != null) {
                    paymentAccounts = creditAccounts
                        .map((acc) {
                          final accMap = acc as Map<String, dynamic>?;
                          var name = accMap?['name']?.toString().trim() ?? '';
                          final amount =
                              (accMap?['amount'] as num?)?.toDouble() ?? 0.0;
                          if (name.isNotEmpty && amount > 0) {
                            // If name looks like an ID (exists in paymentAccountNames map), resolve it
                            if (paymentAccountNames.containsKey(name)) {
                              name = paymentAccountNames[name]!;
                            } else {
                              // Try to resolve using getPaymentAccountDisplayName
                              name = getPaymentAccountDisplayName(name);
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
                  creditAmount = isCredit ? transaction.amount : 0.0;
                  // Get payment account name for single transaction
                  if (creditAmount > 0) {
                    final accountName = transaction.paymentAccountName?.trim();
                    final accountId = transaction.paymentAccountId?.trim();
                    String? name;
                    if (accountName != null && accountName.isNotEmpty) {
                      name = accountName;
                    } else if (accountId != null && accountId.isNotEmpty) {
                      name = getPaymentAccountDisplayName(accountId);
                    }
                    if (name != null && name.isNotEmpty) {
                      paymentAccounts = [
                        {'name': name, 'amount': creditAmount}
                      ];
                    }
                  }
                }

                // Format amount string: "X+Y" if multiple accounts, otherwise just the total
                String amountText =
                    creditAmount > 0 ? formatCurrency(creditAmount) : '–';
                if (creditAmount > 0 && paymentAccounts.length > 1) {
                  final amounts = paymentAccounts
                      .map((acc) => formatCurrency(acc['amount'] as double))
                      .join('+');
                  amountText = amounts;
                }

                return SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountText,
                        style: AppTypography.withColor(
                          AppTypography.body,
                          creditAmount > 0
                              ? AuthColors.success
                              : AuthColors.textSub,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (creditAmount > 0 && paymentAccounts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          runSpacing: 2,
                          children: paymentAccounts.map((acc) {
                            final name = acc['name'] as String;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AuthColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AuthColors.success.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: AuthColors.success,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            // Debit column
            Builder(
              builder: (context) {
                final transactionCount =
                    transaction.metadata?['transactionCount'] as int?;
                final isGrouped =
                    transactionCount != null && transactionCount > 1;

                double debitAmount = 0.0;
                List<Map<String, dynamic>> paymentAccounts =
                    []; // List of {name, amount}

                if (isGrouped) {
                  // For grouped transactions, use cumulative debit from metadata
                  debitAmount =
                      (transaction.metadata?['cumulativeDebit'] as num?)
                              ?.toDouble() ??
                          0.0;
                  // Get payment accounts with amounts from metadata
                  final debitAccounts =
                      transaction.metadata?['debitPaymentAccounts'] as List?;
                  if (debitAccounts != null) {
                    paymentAccounts = debitAccounts
                        .map((acc) {
                          final accMap = acc as Map<String, dynamic>?;
                          var name = accMap?['name']?.toString().trim() ?? '';
                          final amount =
                              (accMap?['amount'] as num?)?.toDouble() ?? 0.0;
                          if (name.isNotEmpty && amount > 0) {
                            // If name looks like an ID (exists in paymentAccountNames map), resolve it
                            if (paymentAccountNames.containsKey(name)) {
                              name = paymentAccountNames[name]!;
                            } else {
                              // Try to resolve using getPaymentAccountDisplayName
                              name = getPaymentAccountDisplayName(name);
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
                  debitAmount = !isCredit ? transaction.amount : 0.0;
                  // Get payment account name for single transaction
                  if (debitAmount > 0) {
                    final accountName = transaction.paymentAccountName?.trim();
                    final accountId = transaction.paymentAccountId?.trim();
                    String? name;
                    if (accountName != null && accountName.isNotEmpty) {
                      name = accountName;
                    } else if (accountId != null && accountId.isNotEmpty) {
                      name = getPaymentAccountDisplayName(accountId);
                    }
                    if (name != null && name.isNotEmpty) {
                      paymentAccounts = [
                        {'name': name, 'amount': debitAmount}
                      ];
                    }
                  }
                }

                // Format amount string: "X+Y" if multiple accounts, otherwise just the total
                String amountText =
                    debitAmount > 0 ? formatCurrency(debitAmount) : '–';
                if (debitAmount > 0 && paymentAccounts.length > 1) {
                  final amounts = paymentAccounts
                      .map((acc) => formatCurrency(acc['amount'] as double))
                      .join('+');
                  amountText = amounts;
                }

                return SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                          color: debitAmount > 0
                              ? AuthColors.error
                              : AuthColors.textSub,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (debitAmount > 0 && paymentAccounts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          runSpacing: 2,
                          children: paymentAccounts.map((acc) {
                            final name = acc['name'] as String;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AuthColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AuthColors.error.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: AuthColors.error,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
