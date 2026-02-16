import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

/// Transactions List view for Financial Transactions (Android)
/// Optimized with CustomScrollView + SliverList for better performance
class FinancialTransactionsListView extends StatefulWidget {
  const FinancialTransactionsListView({super.key});

  @override
  State<FinancialTransactionsListView> createState() =>
      _FinancialTransactionsListViewState();
}

class _FinancialTransactionsListViewState
    extends State<FinancialTransactionsListView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  final bool _isLoadingMore = false;
  bool _enableAnimations = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
    _scrollController = ScrollController()
      ..addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more if needed - for now just a placeholder
      // Future pagination support can be added here
    }
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

  Future<void> _handleDateRangePicker() async {
    final cubit = context.read<UnifiedFinancialTransactionsCubit>();
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
      cubit.setDateRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UnifiedFinancialTransactionsCubit,
        UnifiedFinancialTransactionsState>(
      buildWhen: (previous, current) {
        // Only rebuild when relevant state changes
        return previous.currentTransactions != current.currentTransactions ||
            previous.selectedTab != current.selectedTab ||
            previous.searchQuery != current.searchQuery ||
            previous.status != current.status ||
            previous.startDate != current.startDate ||
            previous.endDate != current.endDate;
      },
      builder: (context, state) {
        // Sync search controller with state
        if (_searchController.text != state.searchQuery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_searchController.text != state.searchQuery) {
              _searchController.text = state.searchQuery;
            }
          });
        }
        
        final allTransactions = state.currentTransactions;
        final filteredTransactions = _getFilteredTransactions(
          allTransactions,
          state.searchQuery,
        );

        if (_enableAnimations &&
            state.status == ViewStatus.success &&
            filteredTransactions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _enableAnimations = false;
              });
            }
          });
        }

        // Error state
        if (state.status == ViewStatus.failure) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              children: [
                _buildControls(state),
                const SizedBox(height: AppSpacing.paddingXXL),
                ErrorStateWidget(
                  message: state.message ?? 'Failed to load transactions',
                  errorType: ErrorType.network,
                  onRetry: () {
                    context.read<UnifiedFinancialTransactionsCubit>().load();
                  },
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Controls section (Tab selector, Date range, Search)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildControls(state),
              ),
            ),
            // Loading state
            if (state.status == ViewStatus.loading && allTransactions.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            // Search results or empty state
            else if (state.searchQuery.isNotEmpty && filteredTransactions.isEmpty)
              SliverFillRemaining(
                child: _EmptySearchState(query: state.searchQuery),
              )
            else if (filteredTransactions.isEmpty && state.status != ViewStatus.loading)
              SliverFillRemaining(
                child: _EmptyTransactionsState(
                  tabType: state.selectedTab,
                  hasSearch: state.searchQuery.isNotEmpty,
                ),
              )
            // Transaction list grouped by date
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG),
                sliver: _enableAnimations
                    ? AnimationLimiter(
                        child: _buildTransactionsSliverList(filteredTransactions),
                      )
                    : _buildTransactionsSliverList(filteredTransactions),
              ),
            ],
          ],
        );
      },
    );
  }

  SliverList _buildTransactionsSliverList(
    List<Transaction> filteredTransactions,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= filteredTransactions.length) {
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.paddingLG),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final transaction = filteredTransactions[index];
          if (!_enableAnimations) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
              child: _buildTransactionTile(transaction),
            );
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 200),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                  child: _buildTransactionTile(transaction),
                ),
              ),
            ),
          );
        },
        childCount: filteredTransactions.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }

  Widget _buildControls(UnifiedFinancialTransactionsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector
        TransactionTypeSegmentedControl(
          selectedIndex: state.selectedTab.index,
          onSelectionChanged: (index) {
            context.read<UnifiedFinancialTransactionsCubit>().selectTab(
                  TransactionTabType.values[index],
                );
          },
        ),
        const SizedBox(height: AppSpacing.paddingLG),
        // Date range picker and search bar row
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AuthColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AuthColors.surface.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
                child: StandardSearchBar(
                  controller: _searchController,
                  hintText: 'Search by name, ref, amount...',
                  onChanged: (value) {
                    // Handled by listener
                  },
                  onClear: _clearSearch,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.paddingSM),
            Container(
              decoration: BoxDecoration(
                color: AuthColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.surface.withValues(alpha: 0.8),
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
      ],
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    String title;
    String? subtitle;

    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        title = (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            transaction.metadata?['clientName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Client Payment');
        subtitle = _buildSubtitle(
          transaction.referenceNumber,
          transaction.paymentAccountName,
        );
        break;
      case TransactionCategory.tripPayment:
        title = (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            transaction.metadata?['clientName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Trip Payment');
        subtitle = _buildSubtitle(
          transaction.referenceNumber,
          transaction.paymentAccountName,
        );
        break;
      case TransactionCategory.vendorPurchase:
        title = transaction.metadata?['vendorName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Vendor Purchase');
        subtitle = _buildSubtitle(
          transaction.referenceNumber,
          transaction.paymentAccountName,
        ) ?? transaction.description;
        break;
      case TransactionCategory.vendorPayment:
        title = transaction.metadata?['vendorName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Vendor Payment');
        subtitle = _buildSubtitle(
          transaction.referenceNumber,
          transaction.paymentAccountName,
        );
        break;
      case TransactionCategory.salaryDebit:
        title = transaction.metadata?['employeeName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Salary Payment');
        subtitle = (transaction.paymentAccountName?.trim().isNotEmpty == true)
            ? 'Salary · ${transaction.paymentAccountName!.trim()}'
            : 'Salary';
        break;
      case TransactionCategory.generalExpense:
        title = transaction.metadata?['subCategoryName']?.toString().trim() ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'General Expense');
        subtitle = _buildSubtitle(
          null,
          transaction.paymentAccountName,
        ) ?? transaction.description;
        break;
      default:
        title = (transaction.clientName?.trim().isNotEmpty == true
                ? transaction.clientName!.trim()
                : null) ??
            (transaction.description?.isNotEmpty == true
                ? transaction.description!
                : 'Transaction');
        subtitle = _buildSubtitle(
          transaction.referenceNumber,
          transaction.paymentAccountName,
        );
    }

    final hasVoucher = transaction.category == TransactionCategory.salaryDebit &&
        transaction.metadata?['cashVoucherPhotoUrl'] != null &&
        (transaction.metadata!['cashVoucherPhotoUrl'] as String).isNotEmpty;

    return TransactionListTile(
      transaction: transaction,
      title: title,
      subtitle: subtitle,
      onTap: hasVoucher
          ? () => context.go('/salary-voucher?transactionId=${transaction.id}')
          : null,
      onDelete: () => _showDeleteConfirmation(context, transaction),
    );
  }

  /// Builds subtitle from reference and payment account. Prefers ref, then
  /// account, then "Ref · Account" when both present.
  String? _buildSubtitle(String? ref, String? accountName) {
    final hasRef = ref != null && ref.trim().isNotEmpty;
    final hasAccount = accountName != null && accountName.trim().isNotEmpty;
    if (hasRef && hasAccount) {
      return 'Ref: ${ref.trim()} · ${accountName.trim()}';
    }
    if (hasRef) return 'Ref: ${ref.trim()}';
    if (hasAccount) return accountName.trim();
    return null;
  }

  // Caching for filtered transactions (similar to Employees page)
  static final _filteredCache = <String, List<Transaction>>{};
  static String? _lastTransactionsHash;
  static String? _lastSearchQuery;
  static final _searchIndexCache = <String, String>{};
  static String? _lastSearchIndexHash;

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

  List<Transaction> _getFilteredTransactions(
    List<Transaction> transactions,
    String query,
  ) {
    // Cache key based on transactions hash and search query
    final transactionsHash = '${transactions.length}_${transactions.hashCode}';
    final cacheKey = '${transactionsHash}_$query';

    final searchIndex = _buildSearchIndex(transactions, transactionsHash);

    // Check if we can reuse cached result
    if (_lastTransactionsHash == transactionsHash &&
        _lastSearchQuery == query &&
        _filteredCache.containsKey(cacheKey)) {
      return _filteredCache[cacheKey]!;
    }

    // Invalidate cache if transactions list changed
    if (_lastTransactionsHash != transactionsHash) {
      _filteredCache.clear();
    }

    // Calculate filtered list
    final filtered = query.isEmpty
      ? transactions
      : transactions
        .where((tx) {
          final queryLower = query.toLowerCase();
          final indexText = searchIndex[tx.id] ?? '';
          return indexText.contains(queryLower);
        })
        .toList();

    // Cache result
    _filteredCache[cacheKey] = filtered;
    _lastTransactionsHash = transactionsHash;
    _lastSearchQuery = query;

    return filtered;
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Transaction transaction,
  ) {
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AuthColors.textSub),
            ),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<UnifiedFinancialTransactionsCubit>()
                  .deleteTransaction(transaction.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.error,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(color: AuthColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState({
    required this.tabType,
    required this.hasSearch,
  });

  final TransactionTabType tabType;
  final bool hasSearch;

  String _getTabName() {
    switch (tabType) {
      case TransactionTabType.transactions:
        return 'payments';
      case TransactionTabType.purchases:
        return 'purchases';
      case TransactionTabType.expenses:
        return 'expenses';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: 'No transactions found',
      message: hasSearch
          ? 'Try adjusting your search'
          : 'No $_getTabName() found for the selected period',
      iconColor: AuthColors.primary,
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AuthColors.textSub.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.paddingLG),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            'No transactions match "$query"',
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
