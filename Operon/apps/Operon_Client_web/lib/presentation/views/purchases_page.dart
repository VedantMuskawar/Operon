import 'dart:async';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
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
  List<Map<String, dynamic>> _purchases = [];
  final Map<String, String> _vendorNames = {}; // Cache for vendor names
  bool _isLoading = true;
  String? _error;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isListView = false;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _purchasesSubscription;
  String? _currentOrgId;
  bool _isInitialLoad = true; // Track if this is the first load to show loading state

  @override
  void initState() {
    super.initState();
    // Set default to today's period (start of today to end of today)
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _subscribeToData();
  }
  
  @override
  void dispose() {
    _purchasesSubscription?.cancel();
    super.dispose();
  }
  
  void _subscribeToData() {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      setState(() {
        _error = 'No organization selected';
        _isLoading = false;
      });
      return;
    }
    
    final orgId = organization.id;
    if (_currentOrgId == orgId && _purchasesSubscription != null) {
      // Date range might have changed, recreate subscription
      _purchasesSubscription?.cancel();
    }
    
    _currentOrgId = orgId;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    // Subscribe to purchases
    _purchasesSubscription = FirebaseFirestore.instance
        .collection('TRANSACTIONS')
        .where('organizationId', isEqualTo: orgId)
        .where('ledgerType', isEqualTo: 'vendorLedger')
        .where('category', isEqualTo: 'vendorPurchase')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snapshot) {
            // Filter by date range in memory
            final startTimestamp = Timestamp.fromDate(_startDate);
            final endTimestamp = Timestamp.fromDate(_endDate);
            
            final allPurchases = snapshot.docs
                .map((doc) {
                  final data = doc.data();
                  return <String, dynamic>{
                    'id': doc.id,
                    ...data,
                  };
                })
                .toList();
            
            // Filter by transactionDate or createdAt within date range
            final purchases = allPurchases.where((tx) {
              final txDate = tx['transactionDate'] ?? tx['createdAt'];
              if (txDate == null) return false;
              
              Timestamp? timestamp;
              if (txDate is Timestamp) {
                timestamp = txDate;
              } else if (txDate is DateTime) {
                timestamp = Timestamp.fromDate(txDate);
              } else {
                return false;
              }
              
              return timestamp.compareTo(startTimestamp) >= 0 && 
                     timestamp.compareTo(endTimestamp) <= 0;
            }).toList();
            
            if (mounted) {
              setState(() {
                _purchases = purchases;
                _isLoading = false;
                _isInitialLoad = false;
              });
              
              // Fetch vendor names for new purchases
              _fetchVendorNames();
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = 'Failed to load purchases: $error';
                _isLoading = false;
                _isInitialLoad = false;
              });
            }
          },
        );
  }

  // Calculate summary statistics
  Map<String, dynamic> _calculateSummary() {
    if (_purchases.isEmpty) {
      return {
        'totalCount': 0,
        'totalAmount': 0.0,
        'totalCredits': 0.0,
        'averageAmount': 0.0,
      };
    }

    double totalAmount = 0.0;
    double totalCredits = 0.0;

    for (final purchase in _purchases) {
      final amount = (purchase['amount'] as num?)?.toDouble() ?? 0.0;
      totalAmount += amount;
      totalCredits += amount; // All purchases are credits
    }

    return {
      'totalCount': _purchases.length,
      'totalAmount': totalAmount,
      'totalCredits': totalCredits,
      'averageAmount': totalAmount / _purchases.length,
    };
  }

  // Fetch vendor names in batch
  Future<void> _fetchVendorNames() async {
    final vendorIds = _purchases
        .map((tx) => tx['vendorId'] as String?)
        .where((id) => id != null && !_vendorNames.containsKey(id))
        .toSet();

    if (vendorIds.isEmpty) return;

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return;

      // Batch fetch vendors
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
      // Silently fail - vendor names are optional
    }
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
      } else if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return 'N/A';
      }
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      final hour = date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour < 12 ? 'am' : 'pm';
      return '$day $month $year • ${hour == 0 ? 12 : hour}:$minute $period';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDatePicker(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6F4BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        // If start date is after end date, update end date to start date
        if (_startDate.isAfter(_endDate)) {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        } else {
          // Ensure end date is end of day
          _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
        }
      });
      // Recreate subscription with new date range
      _subscribeToData();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6F4BFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
      // Recreate subscription with new date range
      _subscribeToData();
    }
  }

  Future<void> _deletePurchase(String transactionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('TRANSACTIONS')
          .doc(transactionId)
          .delete();
      
      // Streams will auto-update, no manual refresh needed
      
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

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> purchase) {
    final amount = (purchase['amount'] as num?)?.toDouble() ?? 0.0;
    final vendorName = _vendorNames[purchase['vendorId'] as String?] ?? 'this purchase';
    
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
          'Amount: ${_formatCurrency(amount)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final transactionId = purchase['id'] as String? ?? purchase['transactionId'] as String?;
              if (transactionId != null) {
                _deletePurchase(transactionId);
              }
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrganizationContextCubit, OrganizationContextState>(
      builder: (context, orgState) {
        // Re-subscribe if organization changed
        if (orgState.organization?.id != _currentOrgId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _subscribeToData();
          });
        }
        
        return SectionWorkspaceLayout(
          panelTitle: 'Purchases',
          currentIndex: -1,
          onNavTap: (index) => context.go('/home?section=$index'),
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fuel Ledger Shortcut
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: InkWell(
                onTap: () => context.go('/fuel-ledger'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6F4BFF).withValues(alpha: 0.1),
                        const Color(0xFF6F4BFF).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_gas_station,
                          color: Color(0xFF6F4BFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fuel Ledger',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track fuel purchases and link to trips',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFF6F4BFF),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Top Action Bar with Filters
            Row(
              children: [
                // Date Range Pickers (narrower)
                Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Start',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                              Text(
                                _formatDatePicker(_startDate),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                        color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'End',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                              Text(
                                _formatDatePicker(_endDate),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // View Toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewToggleButton(
                        icon: Icons.grid_view,
                        isSelected: !_isListView,
                        onTap: () => setState(() => _isListView = false),
                        tooltip: 'Grid View',
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _ViewToggleButton(
                        icon: Icons.list,
                        isSelected: _isListView,
                        onTap: () => setState(() => _isListView = true),
                        tooltip: 'List View',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Refresh Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                        _isInitialLoad = true;
                      });
                      _subscribeToData();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
                    label: const Text('Refresh', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Summary Statistics Cards
            if (!_isLoading && _error == null && _purchases.isNotEmpty) ...[
              _SummaryCards(summary: _calculateSummary(), formatCurrency: _formatCurrency),
              const SizedBox(height: 24),
            ],
            // Purchases List
            (_isLoading && _isInitialLoad)
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
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _error = null;
                                    _isLoading = true;
                                    _isInitialLoad = true;
                                  });
                                  _subscribeToData();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _purchases.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No purchases found',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _isListView
                            ? Column(
                                children: [
                                  ..._purchases.map((purchase) => _PurchaseTile(
                                        purchase: purchase,
                                        formatCurrency: _formatCurrency,
                                        formatDate: _formatDate,
                                        vendorName: _vendorNames[purchase['vendorId'] as String?] ?? 'Loading...',
                                        onDelete: () => _showDeleteConfirmation(context, purchase),
                                        isGridView: false,
                                      )),
                                ],
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _purchases.length,
                                itemBuilder: (context, index) {
                                  final purchase = _purchases[index];
                                  return _PurchaseTile(
                                    purchase: purchase,
                                    formatCurrency: _formatCurrency,
                                    formatDate: _formatDate,
                                    vendorName: _vendorNames[purchase['vendorId'] as String?] ?? 'Loading...',
                                    onDelete: () => _showDeleteConfirmation(context, purchase),
                                    isGridView: true,
                                  );
                                },
                              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.summary,
    required this.formatCurrency,
  });

  final Map<String, dynamic> summary;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.shopping_cart,
            label: 'Total Purchases',
            value: '${summary['totalCount']}',
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_wallet,
            label: 'Total Amount',
            value: formatCurrency(summary['totalAmount'] as double),
            color: const Color(0xFF6F4BFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.arrow_downward,
            label: 'Total Credits',
            value: formatCurrency(summary['totalCredits'] as double),
            color: Colors.orange,
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatefulWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.formatCurrency,
    required this.formatDate,
    required this.vendorName,
    this.onDelete,
    this.isGridView = false,
  });

  final Map<String, dynamic> purchase;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;
  final String vendorName;
  final VoidCallback? onDelete;
  final bool isGridView;

  @override
  State<_PurchaseTile> createState() => _PurchaseTileState();
}

class _PurchaseTileState extends State<_PurchaseTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.purchase['amount'] as num?)?.toDouble() ?? 0.0;
    final date = widget.purchase['createdAt'] ?? widget.purchase['transactionDate'];
    final invoiceNumber = widget.purchase['referenceNumber'] ?? widget.purchase['metadata']?['invoiceNumber'] ?? 'N/A';
    final typeColor = Colors.orange; // Credit = purchase (orange)
    final balanceAfter = (widget.purchase['balanceAfter'] as num?)?.toDouble();

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final containerDecoration = BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F1F33), Color(0xFF1A1A28)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? typeColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: _isHovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              if (_isHovered)
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: -3,
                  offset: const Offset(0, 5),
                ),
            ],
          );

          if (widget.isGridView) {
            // Grid view: Vertical card layout
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: containerDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vendorName != 'Loading...' ? widget.vendorName : 'Unknown Vendor',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.formatDate(date),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: typeColor.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'C',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (invoiceNumber != 'N/A') ...[
                    Text(
                      'Invoice: $invoiceNumber',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.formatCurrency(amount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (balanceAfter != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Bal: ${widget.formatCurrency(balanceAfter)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.onDelete != null)
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.4,
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.redAccent,
                            onPressed: widget.onDelete,
                            tooltip: 'Delete',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            // List view: Horizontal compact layout
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: containerDecoration,
              child: Row(
                children: [
                  // Type Badge
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Vendor Avatar/Initial
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor,
                          typeColor.withValues(alpha: 0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.vendorName != 'Loading...' && widget.vendorName.isNotEmpty
                            ? widget.vendorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Vendor Name and Date
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.vendorName != 'Loading...' ? widget.vendorName : 'Unknown Vendor',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: typeColor.withOpacity(0.5)),
                              ),
                              child: const Text(
                                'C',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.formatDate(date),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        if (invoiceNumber != 'N/A') ...[
                          const SizedBox(height: 2),
                          Text(
                            'Invoice: $invoiceNumber',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Amount
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.formatCurrency(amount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (balanceAfter != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Bal: ${widget.formatCurrency(balanceAfter)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Icon
                  if (widget.onDelete != null)
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.redAccent,
                        onPressed: widget.onDelete,
                        tooltip: 'Delete',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

