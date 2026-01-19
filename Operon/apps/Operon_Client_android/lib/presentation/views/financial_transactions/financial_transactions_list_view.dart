import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_state.dart';
import 'package:dash_mobile/presentation/widgets/date_range_picker.dart';
import 'package:dash_mobile/presentation/widgets/standard_search_bar.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
        final allTransactions = state.currentTransactions;
        final filteredTransactions = _getFilteredTransactions(
          allTransactions,
          state.searchQuery,
        );

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
                const SizedBox(height: 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: AnimationLimiter(
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= filteredTransactions.length) {
                          return _isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        final transaction = filteredTransactions[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 200),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              curve: Curves.easeOut,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTransactionTile(transaction),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount:
                          filteredTransactions.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
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
        const SizedBox(height: 16),
        // Date Range Picker
        DateRangePicker(
          startDate: state.startDate,
          endDate: state.endDate,
          onStartDateChanged: (date) {
            context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
                  date,
                  state.endDate,
                );
          },
          onEndDateChanged: (date) {
            context.read<UnifiedFinancialTransactionsCubit>().setDateRange(
                  state.startDate,
                  date,
                );
          },
        ),
        const SizedBox(height: 16),
        // Search Bar
        StandardSearchBar(
          controller: _searchController,
          hintText: 'Search transactions...',
          onChanged: (value) {
            // Handled by listener
          },
          onClear: _clearSearch,
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Transaction transaction) {
    String title;
    String? subtitle;

    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        // Use actual client name from metadata, fallback to description if available
        title = transaction.metadata?['clientName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Client Payment');
        if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
          subtitle = 'Ref: ${transaction.referenceNumber}';
        }
        break;
      case TransactionCategory.vendorPurchase:
        // Use actual vendor name from metadata
        title = transaction.metadata?['vendorName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Vendor Purchase');
        subtitle = transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty
            ? 'Ref: ${transaction.referenceNumber}'
            : transaction.description;
        break;
      case TransactionCategory.vendorPayment:
        // Use actual vendor name from metadata
        title = transaction.metadata?['vendorName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Vendor Payment');
        if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
          subtitle = 'Ref: ${transaction.referenceNumber}';
        }
        break;
      case TransactionCategory.salaryDebit:
        // Use actual employee name from metadata
        title = transaction.metadata?['employeeName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'Salary Payment');
        subtitle = 'Salary';
        break;
      case TransactionCategory.generalExpense:
        // Use actual subcategory name from metadata
        title = transaction.metadata?['subCategoryName']?.toString().trim() ??
                (transaction.description?.isNotEmpty == true 
                    ? transaction.description! 
                    : 'General Expense');
        subtitle = transaction.description;
        break;
      default:
        // For other categories, use description if available, otherwise generic title
        title = transaction.description?.isNotEmpty == true 
            ? transaction.description! 
            : 'Transaction';
        if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
          subtitle = 'Ref: ${transaction.referenceNumber}';
        }
    }

    return TransactionListTile(
      transaction: transaction,
      title: title,
      subtitle: subtitle,
      onDelete: () => _showDeleteConfirmation(context, transaction),
    );
  }

  // Caching for filtered transactions (similar to Employees page)
  static final _filteredCache = <String, List<Transaction>>{};
  static String? _lastTransactionsHash;
  static String? _lastSearchQuery;

  List<Transaction> _getFilteredTransactions(
    List<Transaction> transactions,
    String query,
  ) {
    // Cache key based on transactions hash and search query
    final transactionsHash = '${transactions.length}_${transactions.hashCode}';
    final cacheKey = '${transactionsHash}_$query';

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
              final description = tx.description?.toLowerCase() ?? '';
              final reference = tx.referenceNumber?.toLowerCase() ?? '';
              final amount = tx.amount.toString();
              final clientName = tx.metadata?['clientName']?.toString().toLowerCase() ?? '';
              final vendorName = tx.metadata?['vendorName']?.toString().toLowerCase() ?? '';
              final employeeName = tx.metadata?['employeeName']?.toString().toLowerCase() ?? '';
              
              return description.contains(queryLower) ||
                  reference.contains(queryLower) ||
                  amount.contains(queryLower) ||
                  clientName.contains(queryLower) ||
                  vendorName.contains(queryLower) ||
                  employeeName.contains(queryLower);
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
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
