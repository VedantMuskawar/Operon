import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/models/combined_ledger_model.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.ledger});

  final dynamic ledger;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  int _selectedTabIndex = 0;

  dynamic get _ledger => widget.ledger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingXL,
                vertical: AppSpacing.paddingMD,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub),
                  ),
                  const SizedBox(width: AppSpacing.paddingSM),
                  Expanded(
                    child: Text(
                      'Ledger Details',
                      style: AppTypography.withColor(
                        AppTypography.h2,
                        AuthColors.textMain,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.avatarSM),
                ],
              ),
            ),
            // Ledger Header Info
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: _LedgerHeader(ledger: _ledger),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Tab Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.paddingXL),
              child: Container(
                decoration: BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(
                    color: AuthColors.textMainWithOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Accounts',
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Transactions',
                        isSelected: _selectedTabIndex == 1,
                        onTap: () => setState(() => _selectedTabIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            // Content
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _AccountsListTab(ledger: _ledger),
                  _TransactionsTab(ledger: _ledger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({required this.ledger});

  final CombinedLedger ledger;

  Color _getLedgerColor() {
    final hash = ledger.name.hashCode;
    const colors = [
      AuthColors.primary,
      AuthColors.secondary,
      AuthColors.success,
      AuthColors.warning,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials() {
    final words = ledger.name.trim().split(' ');
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '?';
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ledgerColor = _getLedgerColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingXL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
        gradient: LinearGradient(
          colors: [
            ledgerColor.withOpacity(0.3),
            AuthColors.backgroundAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ledgerColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ledgerColor.withOpacity(0.4),
                      ledgerColor.withOpacity(0.2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ledgerColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      color: ledgerColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.paddingLG),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ledger.name,
                      style: AppTypography.withColor(
                        AppTypography.withWeight(
                          AppTypography.h1,
                          FontWeight.w700,
                        ),
                        AuthColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ledger.accounts.length} accounts',
                      style: const TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountsListTab extends StatelessWidget {
  const _AccountsListTab({required this.ledger});

  final CombinedLedger ledger;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.paddingLG),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accounts (${ledger.accounts.length})',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                if (ledger.accounts.isEmpty)
                  const Center(
                    child: Text(
                      'No accounts in this ledger.',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.paddingSM,
                    runSpacing: AppSpacing.paddingSM,
                    children: ledger.accounts
                        .map((account) => _AccountChip(account: account))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.account});

  final AccountOption account;

  Color _getTypeColor() {
    return switch (account.type) {
      AccountType.employee => AuthColors.primary,
      AccountType.vendor => AuthColors.secondary,
      AccountType.client => AuthColors.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final typeLabel = account.type.name.substring(0, 1).toUpperCase() +
        account.type.name.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingMD,
        vertical: AppSpacing.paddingSM,
      ),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            account.name,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            typeLabel,
            style: TextStyle(
              color: typeColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        decoration: BoxDecoration(
          color: isSelected ? AuthColors.primaryWithOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AuthColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                isSelected ? AuthColors.primary : AuthColors.textSub,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab({required this.ledger});

  final dynamic ledger;

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  dynamic get _ledger => widget.ledger;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    try {
      _transactionsSubscription?.cancel();
      
      // Use accountsLedgerId which has the full ID with FY suffix (e.g., acc_1770722727952000_FY2526)
      final ledgerId = _ledger.accountsLedgerId;
      print('DEBUG: Loading transactions for accountsLedgerId=$ledgerId');
      
      if (ledgerId.isEmpty) {
        setState(() {
          _isLoading = false;
          _transactions = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ledger ID available')),
        );
        return;
      }
      
      _transactionsSubscription = FirebaseFirestore.instance
          .collection('ACCOUNTS_LEDGERS')
          .doc(ledgerId)
          .collection('TRANSACTIONS')
          .orderBy('yearMonth', descending: true)
          .limit(12) // Last 12 months
          .snapshots()
          .listen((snapshot) {
        print('DEBUG: Got ${snapshot.docs.length} month documents');
        final allTransactions = <Map<String, dynamic>>[];
        for (final monthDoc in snapshot.docs) {
          print('DEBUG: Processing month doc: ${monthDoc.id}');
          final monthData = monthDoc.data();
          final transactionsArray =
              (monthData['transactions'] as List<dynamic>?) ?? [];
          print('DEBUG: Found ${transactionsArray.length} transactions in ${monthDoc.id}');
          for (final txn in transactionsArray) {
            if (txn is Map<String, dynamic>) {
              allTransactions.add(txn);
            }
          }
        }
        // Sort by transactionDate descending
        allTransactions.sort((a, b) {
          final dateA = _getDateTime(a['transactionDate']);
          final dateB = _getDateTime(b['transactionDate']);
          return dateB.compareTo(dateA);
        });

        print('DEBUG: Total transactions loaded: ${allTransactions.length}');
        if (mounted) {
          setState(() {
            _transactions = allTransactions;
            _isLoading = false;
          });
        }
      }, onError: (e) {
        print('DEBUG: Error loading transactions: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load transactions: $e')),
          );
        }
      });
    } catch (e) {
      print('DEBUG: Exception in _loadTransactions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transactions: $e')),
        );
      }
    }
  }

  DateTime _getDateTime(dynamic value) {
    try {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found for this ledger.',
          style: TextStyle(color: AuthColors.textSub),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLG,
        0,
        AppSpacing.paddingLG,
        AppSpacing.paddingLG,
      ),
      child: _LedgerTable(
        openingBalance: 0.0,
        transactions: _transactions,
        formatCurrency: _formatCurrency,
        formatDate: _formatDate,
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    final visible = List<Map<String, dynamic>>.from(transactions);
    if (visible.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          const Text(
            'No transactions found.',
            style: TextStyle(color: AuthColors.textSub),
          ),
          const SizedBox(height: AppSpacing.paddingXL),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
      );
    }

    // Sort asc by transactionDate
    visible.sort((a, b) {
      final aDate = a['transactionDate'];
      final bDate = b['transactionDate'];
      try {
        final ad = aDate is Timestamp ? aDate.toDate() : (aDate as DateTime);
        final bd = bDate is Timestamp ? bDate.toDate() : (bDate as DateTime);
        return ad.compareTo(bd);
      } catch (_) {
        return 0;
      }
    });

    // Group transactions by DM number (cumulative amounts)
    // If no DM number, show category instead
    final List<_LedgerRowModel> rows = [];
    double running = openingBalance;

    int i = 0;
    while (i < visible.length) {
      final tx = visible[i];
      final type = (tx['type'] as String? ?? '').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final metadata = tx['metadata'] as Map<String, dynamic>? ?? {};
      final dmNumber = metadata['dmNumber'] ?? tx['dmNumber'];
      final category = tx['category'] as String?;
      final date = tx['transactionDate'];

      // Group all transactions with the same DM number
      if (dmNumber != null) {
        double totalCredit = 0;
        double totalDebit = 0;
        dynamic earliestDate = date;
        final List<_PaymentPart> parts = [];
        int j = i;

        while (j < visible.length) {
          final next = visible[j];
          final nMeta = next['metadata'] as Map<String, dynamic>? ?? {};
          final nDm = nMeta['dmNumber'] ?? next['dmNumber'];

          // Stop if DM number doesn't match
          if (nDm != dmNumber) break;

          final nt = (next['type'] as String? ?? '').toLowerCase();
          final nAmt = (next['amount'] as num?)?.toDouble() ?? 0.0;
          final nDate = next['transactionDate'];

          // Track earliest date
          try {
            final currentDate = earliestDate is Timestamp
                ? earliestDate.toDate()
                : (earliestDate as DateTime);
            final nextDate =
                nDate is Timestamp ? nDate.toDate() : (nDate as DateTime);
            if (nextDate.isBefore(currentDate)) {
              earliestDate = nDate;
            }
          } catch (_) {}

          // Calculate credit/debit
          if (nt == 'credit') {
            totalCredit += nAmt;
          } else {
            totalDebit += nAmt;
            if (nt == 'payment') {
              final acctType = (next['paymentAccountType'] as String?) ?? '';
              parts.add(_PaymentPart(amount: nAmt, accountType: acctType));
            }
          }

          j++;
        }

        final delta = totalCredit - totalDebit;
        running += delta;

        final firstDesc = (visible[i]['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: earliestDate,
          dmNumber: dmNumber,
          credit: totalCredit,
          debit: totalDebit,
          balanceAfter: running,
          type: 'Order',
          remarks:
              (firstDesc != null && firstDesc.isNotEmpty) ? firstDesc : '-',
          paymentParts: parts,
        ));

        i = j;
      } else {
        // No DM number - show as individual transaction with category
        final isCredit = type == 'credit';
        final delta = isCredit ? amount : -amount;
        running += delta;

        final desc = (tx['description'] as String?)?.trim();
        rows.add(_LedgerRowModel(
          date: date,
          dmNumber: null,
          credit: isCredit ? amount : 0,
          debit: isCredit ? 0 : amount,
          balanceAfter: running,
          type: _formatCategoryName(category),
          remarks: (desc != null && desc.isNotEmpty) ? desc : '-',
          category: category,
        ));
        i++;
      }
    }

    final totalDebit = rows.fold<double>(0, (s, r) => s + r.debit);
    final totalCredit = rows.fold<double>(0, (s, r) => s + r.credit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: AuthColors.textMain,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.paddingMD),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withOpacity(0.12)),
              ...rows.map((r) => _LedgerTableRow(
                    row: r,
                    formatCurrency: formatCurrency,
                    formatDate: formatDate,
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.paddingXL),
        _LedgerSummaryFooter(
          openingBalance: openingBalance,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          formatCurrency: formatCurrency,
        ),
      ],
    );
  }
}

class _LedgerRowModel {
  _LedgerRowModel({
    required this.date,
    required this.dmNumber,
    required this.credit,
    required this.debit,
    required this.balanceAfter,
    required this.type,
    required this.remarks,
    this.paymentParts = const [],
    this.category,
  });

  final dynamic date;
  final dynamic dmNumber;
  final double credit;
  final double debit;
  final double balanceAfter;
  final String type;
  final String remarks;
  final List<_PaymentPart> paymentParts;
  final String? category;
}

// Helper function to format category name (capitalize and add spaces)
String _formatCategoryName(String? category) {
  if (category == null || category.isEmpty) return '';
  // Convert camelCase to Title Case with spaces
  // e.g., "clientCredit" -> "Client Credit"
  return category
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ')
      .map((word) => word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

class _PaymentPart {
  _PaymentPart({required this.amount, required this.accountType});
  final double amount;
  final String accountType;
}

class _LedgerTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      child: Row(
        children: [
          Expanded(
              flex: 1,
              child: Text('Date',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Reference',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Debit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Credit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Balance',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.row,
    required this.formatCurrency,
    required this.formatDate,
  });

  final _LedgerRowModel row;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  Color _accountColor(String type) {
    switch (type.toLowerCase()) {
      case 'upi':
        return AuthColors.info;
      case 'bank':
        return AuthColors.secondary;
      case 'cash':
        return AuthColors.success;
      default:
        return AuthColors.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              formatDate(row.date),
              style: AppTypography.withColor(
                  AppTypography.captionSmall, AuthColors.textMain),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: row.dmNumber != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gapSM,
                          vertical: AppSpacing.paddingXS / 2),
                      decoration: BoxDecoration(
                        color: AuthColors.info.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                      child: Text(
                        'DM-${row.dmNumber}',
                        style: const TextStyle(
                          color: AuthColors.info,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : row.category != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.gapSM,
                              vertical: AppSpacing.paddingXS / 2),
                          decoration: BoxDecoration(
                            color: AuthColors.secondary.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusXS),
                          ),
                          child: Text(
                            _formatCategoryName(row.category!),
                            style: const TextStyle(
                              color: AuthColors.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : const Text('-',
                          style: TextStyle(
                              color: AuthColors.textSub, fontSize: 11),
                          textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 1,
            child: row.debit > 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        formatCurrency(row.debit),
                        style: AppTypography.withColor(
                            AppTypography.captionSmall, AuthColors.textMain),
                        textAlign: TextAlign.center,
                      ),
                      if (row.paymentParts.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: row.paymentParts
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.gapSM,
                                        vertical: AppSpacing.paddingXS / 2),
                                    decoration: BoxDecoration(
                                      color: _accountColor(p.accountType)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusXS),
                                    ),
                                    child: Text(
                                      formatCurrency(p.amount),
                                      style: TextStyle(
                                        color: _accountColor(p.accountType),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  )
                : Text('-',
                    style: AppTypography.withColor(
                        AppTypography.captionSmall, AuthColors.textSub),
                    textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 1,
            child: Text(
              row.credit > 0 ? formatCurrency(row.credit) : '-',
              style: AppTypography.withColor(
                  AppTypography.captionSmall, AuthColors.textMain),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              formatCurrency(row.balanceAfter),
              style: TextStyle(
                color: row.balanceAfter >= 0
                    ? AuthColors.warning
                    : AuthColors.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerSummaryFooter extends StatelessWidget {
  const _LedgerSummaryFooter({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.formatCurrency,
  });

  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingMD, vertical: AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border:
            Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Opening Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(openingBalance),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Debit',
                  style: AppTypography.withColor(
                      AppTypography.captionSmall, AuthColors.textSub),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalDebit),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total Credit',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(totalCredit),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.info),
                  textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Current Balance',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.paddingXS),
              Text(formatCurrency(currentBalance),
                  style: AppTypography.withColor(
                      AppTypography.withWeight(
                          AppTypography.bodySmall, FontWeight.w600),
                      AuthColors.success),
                  textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}
