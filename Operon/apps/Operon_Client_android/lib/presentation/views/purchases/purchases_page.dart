import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  List<Transaction> _purchases = [];
  final Map<String, String> _vendorNames = {};
  bool _isLoading = true;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;

  List<Transaction> _filterByDateRange(List<Transaction> purchases) {
    if (_startDate == null && _endDate == null) return purchases;
    
    return purchases.where((tx) {
      final txDate = tx.createdAt ?? DateTime(1970);
      final start = _startDate ?? DateTime(1970);
      final end = _endDate ?? DateTime.now();
      
      return txDate.isAfter(start.subtract(const Duration(days: 1))) &&
             txDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      
      if (organization == null) {
        setState(() {
          _error = 'No organization selected';
          _isLoading = false;
        });
        return;
      }

      // Query purchases (vendorPurchase category, vendorLedger type)
      final snapshot = await FirebaseFirestore.instance
          .collection('TRANSACTIONS')
          .where('organizationId', isEqualTo: organization.id)
          .where('ledgerType', isEqualTo: 'vendorLedger')
          .where('category', isEqualTo: 'vendorPurchase')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final purchases = snapshot.docs
          .map((doc) => Transaction.fromJson(doc.data(), doc.id))
          .toList();

      setState(() {
        _purchases = purchases;
        _isLoading = false;
      });

      // Fetch vendor names
      _fetchVendorNames();
    } catch (e) {
      setState(() {
        _error = 'Failed to load purchases: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchVendorNames() async {
    final vendorIds = _purchases
        .where((tx) => tx.vendorId != null && !_vendorNames.containsKey(tx.vendorId))
        .map((tx) => tx.vendorId!)
        .toSet();

    if (vendorIds.isEmpty) return;

    try {
      final vendorDocs = await Future.wait(
        vendorIds.map((id) => FirebaseFirestore.instance
            .collection('VENDORS')
            .doc(id)
            .get()),
      );

      final newVendorNames = <String, String>{};
      for (final doc in vendorDocs) {
        if (doc.exists) {
          final data = doc.data();
          final name = data?['name'] as String? ?? 'Unknown Vendor';
          newVendorNames[doc.id] = name;
        }
      }

      setState(() {
        _vendorNames.addAll(newVendorNames);
      });
    } catch (e) {
      // Silently fail
    }
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'am' : 'pm';
    return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
  }

  Future<void> _deletePurchase(String transactionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('TRANSACTIONS')
          .doc(transactionId)
          .delete();
      
      _loadPurchases();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Transaction purchase) {
    final vendorName = _vendorNames[purchase.vendorId ?? ''] ?? 'this purchase';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Delete Purchase',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this purchase?\n\n'
          'Vendor: $vendorName\n'
          'Amount: ${_formatCurrency(purchase.amount)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deletePurchase(purchase.id);
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPurchases = _filterByDateRange(_purchases);
    
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: const ModernPageHeader(
        title: 'Purchases',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fuel Ledger Shortcut
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => context.go('/fuel-ledger'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F4BFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6F4BFF).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6F4BFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_gas_station,
                        color: Color(0xFF6F4BFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fuel Ledger',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Track fuel purchases and link to trips',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF6F4BFF),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
          // Purchases Table
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.redAccent.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPurchases,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6F4BFF),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filteredPurchases.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No purchases found',
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
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _PurchasesTable(
                            purchases: filteredPurchases,
                            vendorNames: _vendorNames,
                            formatCurrency: _formatCurrency,
                            formatDate: _formatDate,
                            onDelete: (purchase) => _showDeleteConfirmation(context, purchase),
                          ),
                        ),
        ],
                ),
                      ),
                    ),
            QuickNavBar(
              currentIndex: 0,
              onTap: (value) => context.go('/home', extra: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({
    required this.purchases,
    required this.vendorNames,
    required this.formatCurrency,
    required this.formatDate,
    required this.onDelete,
  });

  final List<Transaction> purchases;
  final Map<String, String> vendorNames;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final void Function(Transaction) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 100),
      constraints: const BoxConstraints(minWidth: 910),
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
          0: FixedColumnWidth(120), // Date
          1: FixedColumnWidth(150), // Vendor
          2: FixedColumnWidth(120), // Invoice
          3: FixedColumnWidth(120), // Amount
          4: FixedColumnWidth(200), // Description
          5: FixedColumnWidth(120), // Balance After
          6: FixedColumnWidth(80), // Actions
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
              _TableHeaderCell('Vendor'),
              _TableHeaderCell('Invoice'),
              _TableHeaderCell('Amount'),
              _TableHeaderCell('Description'),
              _TableHeaderCell('Balance'),
              _TableHeaderCell('Actions'),
            ],
          ),
          // Data Rows
          ...purchases.asMap().entries.map((entry) {
            final index = entry.key;
            final purchase = entry.value;
            final date = purchase.createdAt ?? DateTime.now();
            final vendorName = vendorNames[purchase.vendorId ?? ''] ?? 'Loading...';
            final invoiceNumber = purchase.referenceNumber ?? purchase.metadata?['invoiceNumber'] ?? 'N/A';
            final description = purchase.description ?? '-';
            final isLast = index == purchases.length - 1;

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
                  formatDate(date),
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  vendorName != 'Loading...' ? vendorName : 'Unknown',
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  invoiceNumber,
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  formatCurrency(purchase.amount),
                  alignment: Alignment.centerRight,
                  isAmount: true,
                ),
                _TableDataCell(
                  description,
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  purchase.balanceAfter != null
                      ? formatCurrency(purchase.balanceAfter!)
                      : '-',
                  alignment: Alignment.centerRight,
                ),
                _TableActionCell(
                  onDelete: () => onDelete(purchase),
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
  });

  final String text;
  final Alignment alignment;
  final bool isAmount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            color: isAmount ? const Color(0xFFFF9800) : Colors.white70,
            fontSize: 13,
            fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TableActionCell extends StatelessWidget {
  const _TableActionCell({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: onDelete,
          tooltip: 'Delete',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }
}

