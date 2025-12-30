import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        backgroundColor: const Color(0xFF11111B),
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
    return PageWorkspaceLayout(
      title: 'Purchases',
      currentIndex: 0,
      onNavTap: (value) => context.go('/home', extra: value),
      onBack: () => context.go('/home'),
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
          // Purchases List
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadPurchases,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _purchases.isEmpty
                      ? Center(
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
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _purchases.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final purchase = _purchases[index];
                            return _PurchaseTile(
                              purchase: purchase,
                              formatCurrency: _formatCurrency,
                              formatDate: _formatDate,
                              vendorName: _vendorNames[purchase.vendorId ?? ''] ?? 'Loading...',
                              onDelete: () => _showDeleteConfirmation(context, purchase),
                            );
                          },
                        ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.formatCurrency,
    required this.formatDate,
    required this.vendorName,
    this.onDelete,
  });

  final Transaction purchase;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final String vendorName;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final date = purchase.createdAt ?? DateTime.now();
    final invoiceNumber = purchase.referenceNumber ?? purchase.metadata?['invoiceNumber'] ?? 'N/A';
    final description = purchase.description;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'Credit',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Purchase',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vendorName != 'Loading...' ? vendorName : 'Unknown Vendor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(purchase.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(date),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (invoiceNumber != 'N/A') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Invoice: $invoiceNumber',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
            ],
          ),
          if (purchase.balanceAfter != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Text(
                    'Balance after: ${formatCurrency(purchase.balanceAfter!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

