import 'dart:async';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/views/fuel_ledger/record_fuel_purchase_dialog.dart';
import 'package:dash_web/presentation/views/fuel_ledger/link_trips_dialog.dart';
import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class FuelLedgerPage extends StatefulWidget {
  const FuelLedgerPage({super.key});

  @override
  State<FuelLedgerPage> createState() => _FuelLedgerPageState();
}

enum _FuelSortOption {
  dateNewest,
  dateOldest,
  amountHigh,
  amountLow,
  vehicleAsc,
}

class _FuelLedgerPageState extends State<FuelLedgerPage> {
  List<Transaction> _fuelPurchases = [];
  final Map<String, String> _vendorNames = {};
  bool _isLoading = true;
  String? _error;
  double _totalFuelVendorBalance = 0.0;
  
  String _query = '';
  _FuelSortOption _sortOption = _FuelSortOption.dateNewest;
  
  // Pagination state
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _purchasesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vendorsSubscription;
  String? _currentOrgId;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }
  
  @override
  void dispose() {
    _purchasesSubscription?.cancel();
    _vendorsSubscription?.cancel();
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
      return; // Already subscribed
    }
    
    _currentOrgId = orgId;
    _purchasesSubscription?.cancel();
    _vendorsSubscription?.cancel();
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    // Subscribe to fuel purchases
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
            final purchases = snapshot.docs
                .map((doc) => Transaction.fromJson(doc.data(), doc.id))
                .where((tx) {
                  // Filter for fuel purchases
                  final metadata = tx.metadata;
                  return metadata != null && (metadata['purchaseType'] as String?) == 'fuel';
                })
                .toList();
            
            if (mounted) {
              setState(() {
                _fuelPurchases = purchases;
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
                _error = 'Failed to load fuel purchases: $error';
                _isLoading = false;
                _isInitialLoad = false;
              });
            }
          },
        );
    
    // Subscribe to fuel vendor balance
    _vendorsSubscription = FirebaseFirestore.instance
        .collection('VENDORS')
        .where('organizationId', isEqualTo: orgId)
        .where('vendorType', isEqualTo: 'fuel')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snapshot) {
            final totalBalance = snapshot.docs.fold<double>(
              0.0,
              (sum, doc) {
                final data = doc.data();
                final balance = (data['currentBalance'] as num?)?.toDouble() ?? 0.0;
                return sum + balance;
              },
            );
            
            if (mounted) {
              setState(() {
                _totalFuelVendorBalance = totalBalance;
              });
            }
          },
          onError: (error) {
            // Silently fail - don't block the UI
            if (mounted) {
              setState(() {
                _totalFuelVendorBalance = 0.0;
              });
            }
          },
        );
  }


  Future<void> _fetchVendorNames() async {
    final vendorIds = _fuelPurchases
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

  List<Transaction> _applyFiltersAndSort(List<Transaction> purchases) {
    var filtered = List<Transaction>.from(purchases);

    // Apply search filter
    if (_query.isNotEmpty) {
      final queryLower = _query.toLowerCase();
      filtered = filtered.where((p) {
        final metadata = p.metadata;
        final vehicleNumber = (metadata?['vehicleNumber'] as String?)?.toLowerCase() ?? '';
        final voucherNumber = (metadata?['voucherNumber'] as String?)?.toLowerCase() ?? '';
        final vendorName = (_vendorNames[p.vendorId ?? ''] ?? '').toLowerCase();
        return vehicleNumber.contains(queryLower) ||
            voucherNumber.contains(queryLower) ||
            vendorName.contains(queryLower);
      }).toList();
    }

    // Apply sorting
    final sortedList = List<Transaction>.from(filtered);
    switch (_sortOption) {
      case _FuelSortOption.dateNewest:
        sortedList.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
        break;
      case _FuelSortOption.dateOldest:
        sortedList.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
        break;
      case _FuelSortOption.amountHigh:
        sortedList.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _FuelSortOption.amountLow:
        sortedList.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case _FuelSortOption.vehicleAsc:
        sortedList.sort((a, b) {
          final aVehicle = (a.metadata?['vehicleNumber'] as String?) ?? '';
          final bVehicle = (b.metadata?['vehicleNumber'] as String?) ?? '';
          return aVehicle.toLowerCase().compareTo(bVehicle.toLowerCase());
        });
        break;
    }

    return sortedList;
  }
  
  List<Transaction> _getPaginatedData(List<Transaction> allData) {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, allData.length);
    if (startIndex >= allData.length) {
      return [];
    }
    return allData.sublist(startIndex, endIndex);
  }
  
  int _getTotalPages(int totalItems) {
    if (totalItems == 0) return 1;
    return ((totalItems - 1) ~/ _itemsPerPage) + 1;
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
    return '$day $month $year';
  }

  int _getLinkedTripsCount(Transaction purchase) {
    final metadata = purchase.metadata;
    if (metadata == null) return 0;
    final linkedTrips = metadata['linkedTrips'];
    if (linkedTrips is List) {
      return linkedTrips.length;
    }
    return 0;
  }

  void _showLinkTripsDialog(Transaction purchase) {
    final metadata = purchase.metadata;
    if (metadata == null) return;
    
    final vehicleNumber = metadata['vehicleNumber'] as String?;
    if (vehicleNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle number not found')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => LinkTripsDialog(
        transactionId: purchase.id,
        vehicleNumber: vehicleNumber,
        voucherNumber: metadata['voucherNumber'] as String? ?? '',
        onTripsLinked: () {
          // Streams will auto-update, no manual refresh needed
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(Transaction purchase) {
    // Validate transaction ID
    if (purchase.id.isEmpty || purchase.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete purchase: Invalid transaction ID'),
          backgroundColor: AuthColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Delete Fuel Purchase',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to delete this fuel purchase? This action cannot be undone.',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (purchase.id.isEmpty || purchase.id.trim().isEmpty) {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete purchase: Invalid transaction ID'),
                    backgroundColor: AuthColors.error,
                  ),
                );
                return;
              }

              try {
                // Delete the transaction from Firestore
                await FirebaseFirestore.instance
                    .collection('TRANSACTIONS')
                    .doc(purchase.id.trim())
                    .delete();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fuel purchase deleted successfully'),
                      backgroundColor: AuthColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete purchase: $e'),
                      backgroundColor: AuthColors.error,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionWorkspaceLayout(
      panelTitle: 'Fuel Ledger',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      child: BlocBuilder<OrganizationContextCubit, OrganizationContextState>(
        builder: (context, orgState) {
          // Re-subscribe if organization changed
          if (orgState.organization?.id != _currentOrgId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _subscribeToData();
            });
          }
          
          if (_isLoading && _isInitialLoad && _fuelPurchases.isEmpty) {
            return _LoadingState();
          }
          if (_error != null && _isInitialLoad && _fuelPurchases.isEmpty) {
            return _ErrorState(
              message: _error!,
              onRetry: () {
                setState(() {
                  _error = null;
                  _isLoading = true;
                  _isInitialLoad = true;
                });
                _subscribeToData();
              },
            );
          }

          final filtered = _applyFiltersAndSort(_fuelPurchases);
          final totalAmount = _fuelPurchases.fold<double>(0.0, (sum, p) => sum + p.amount);
          final totalLinkedTrips = _fuelPurchases.fold<int>(0, (sum, p) => sum + _getLinkedTripsCount(p));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Dashboard
              _FuelStatsHeader(
                totalAmount: totalAmount,
                totalLinkedTrips: totalLinkedTrips,
                totalFuelVendorBalance: _totalFuelVendorBalance,
              ),
              const SizedBox(height: 32),
              
              // Top Action Bar with Filters
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: AuthColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AuthColors.textMainWithOpacity(0.1),
                        ),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() {
                          _query = v;
                          _currentPage = 0; // Reset to first page on search
                        }),
                        style: const TextStyle(color: AuthColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Search by vehicle, voucher, or vendor...',
                          hintStyle: TextStyle(
                            color: AuthColors.textMainWithOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.search, color: AuthColors.textSub),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AuthColors.textSub),
                                  onPressed: () => setState(() => _query = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort Options
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AuthColors.textMainWithOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 16, color: AuthColors.textSub),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<_FuelSortOption>(
                            value: _sortOption,
                            dropdownColor: AuthColors.surface,
                            style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
                            items: const [
                              DropdownMenuItem(
                                value: _FuelSortOption.dateNewest,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AuthColors.textSub),
                                    SizedBox(width: 8),
                                    Text('Date (Newest)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _FuelSortOption.dateOldest,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today, size: 16, color: AuthColors.textSub),
                                    SizedBox(width: 8),
                                    Text('Date (Oldest)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _FuelSortOption.amountHigh,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_down, size: 16, color: AuthColors.textSub),
                                    SizedBox(width: 8),
                                    Text('Amount (High to Low)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _FuelSortOption.amountLow,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.trending_up, size: 16, color: AuthColors.textSub),
                                    SizedBox(width: 8),
                                    Text('Amount (Low to High)'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: _FuelSortOption.vehicleAsc,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions_car, size: 16, color: AuthColors.textSub),
                                    SizedBox(width: 8),
                                    Text('Vehicle (A-Z)'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _sortOption = value;
                                  _currentPage = 0; // Reset to first page on sort
                                });
                              }
                            },
                            icon: Icon(Icons.arrow_drop_down, color: AuthColors.textMainWithOpacity(0.7), size: 20),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Results count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AuthColors.textMainWithOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      '${filtered.length} ${filtered.length == 1 ? 'purchase' : 'purchases'}',
                      style: TextStyle(
                        color: AuthColors.textSub,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add Purchase Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Record Purchase'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => RecordFuelPurchaseDialog(
                          onPurchaseRecorded: () {
                            // Streams will auto-update, no manual refresh needed
                          },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Fuel Purchases Table
              if (filtered.isEmpty && _query.isNotEmpty)
                _EmptySearchState(query: _query)
              else if (filtered.isEmpty)
                _EmptyPurchasesState(
                  onRecordPurchase: () {
                    showDialog(
                      context: context,
                      builder: (context) => RecordFuelPurchaseDialog(
                        onPurchaseRecorded: () {
                          // Streams will auto-update, no manual refresh needed
                        },
                      ),
                    );
                  },
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Table
                    _FuelPurchaseTable(
                      purchases: _getPaginatedData(filtered),
                      formatCurrency: _formatCurrency,
                      formatDate: _formatDate,
                      vendorNames: _vendorNames,
                      getLinkedTripsCount: _getLinkedTripsCount,
                      onLinkTrips: _showLinkTripsDialog,
                      onDelete: _showDeleteConfirmationDialog,
                    ),
                    const SizedBox(height: 16),
                    // Pagination Controls
                    _PaginationControls(
                      currentPage: _currentPage,
                      totalPages: _getTotalPages(filtered.length),
                      totalItems: filtered.length,
                      itemsPerPage: _itemsPerPage,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FuelStatsHeader extends StatelessWidget {
  const _FuelStatsHeader({
    required this.totalAmount,
    required this.totalLinkedTrips,
    required this.totalFuelVendorBalance,
  });

  final double totalAmount;
  final int totalLinkedTrips;
  final double totalFuelVendorBalance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1200;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Amount',
                      value: '₹${totalAmount.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                      color: AuthColors.warning,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.route,
                      label: 'Linked Trips',
                      value: totalLinkedTrips.toString(),
                      color: AuthColors.successVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.account_balance,
                      label: 'Fuel Vendor Balance',
                      value: '₹${totalFuelVendorBalance.toStringAsFixed(0).replaceAllMapped(
                        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}',
                      color: AuthColors.info,
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total Amount',
                    value: '₹${totalAmount.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    color: AuthColors.warning,
                  ),
                  _StatCard(
                    icon: Icons.route,
                    label: 'Linked Trips',
                    value: totalLinkedTrips.toString(),
                    color: AuthColors.successVariant,
                  ),
                  _StatCard(
                    icon: Icons.account_balance,
                    label: 'Fuel Vendor Balance',
                    value: '₹${totalFuelVendorBalance.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    color: AuthColors.info,
                  ),
                ],
              );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthColors.surface,
            AuthColors.backgroundAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withValues(alpha: 0.3),
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
                  label,
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading fuel purchases...',
            style: TextStyle(
              color: AuthColors.textSub,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AuthColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AuthColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AuthColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load fuel purchases',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPurchasesState extends StatelessWidget {
  const _EmptyPurchasesState({required this.onRecordPurchase});

  final VoidCallback onRecordPurchase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuthColors.surface.withValues(alpha: 0.6),
              AuthColors.backgroundAlt.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AuthColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_gas_station_outlined,
                size: 40,
                color: AuthColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No fuel purchases yet',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by recording your first fuel purchase',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Record Purchase'),
              onPressed: onRecordPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AuthColors.primary,
                foregroundColor: AuthColors.textMain,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AuthColors.textDisabled,
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No purchases match "$query"',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FuelPurchaseTable extends StatelessWidget {
  const _FuelPurchaseTable({
    required this.purchases,
    required this.formatCurrency,
    required this.formatDate,
    required this.vendorNames,
    required this.getLinkedTripsCount,
    required this.onLinkTrips,
    required this.onDelete,
  });

  final List<Transaction> purchases;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final Map<String, String> vendorNames;
  final int Function(Transaction) getLinkedTripsCount;
  final void Function(Transaction) onLinkTrips;
  final void Function(Transaction) onDelete;

  @override
  Widget build(BuildContext context) {
    return custom_table.DataTable<Transaction>(
      columns: [
        custom_table.DataTableColumn<Transaction>(
          label: 'Date',
          icon: Icons.calendar_today,
          flex: 2,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              final date = purchase.createdAt ?? DateTime.now();
              return Text(
                formatDate(date),
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
        custom_table.DataTableColumn<Transaction>(
          label: 'Vendor',
          icon: Icons.store,
          flex: 3,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              final vendorName = vendorNames[purchase.vendorId ?? ''] ?? 'Unknown Vendor';
              return Text(
                vendorName,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
        custom_table.DataTableColumn<Transaction>(
          label: 'Amount',
          icon: Icons.currency_rupee,
          flex: 2,
          numeric: true,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              return Text(
                formatCurrency(purchase.amount),
                style: const TextStyle(
                  color: AuthColors.warning,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
        custom_table.DataTableColumn<Transaction>(
          label: 'Vehicle',
          icon: Icons.directions_car,
          flex: 2,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              final metadata = purchase.metadata;
              final vehicleNumber = metadata?['vehicleNumber'] as String? ?? 'N/A';
              return Text(
                vehicleNumber,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
        custom_table.DataTableColumn<Transaction>(
          label: 'Voucher',
          icon: Icons.receipt,
          flex: 2,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              final metadata = purchase.metadata;
              final voucherNumber = metadata?['voucherNumber'] as String? ?? 'N/A';
              return Text(
                voucherNumber,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
        custom_table.DataTableColumn<Transaction>(
          label: 'Trips',
          icon: Icons.route,
          flex: 1,
          numeric: true,
          alignment: Alignment.center,
          cellBuilder: (context, purchase, index) {
              final linkedTripsCount = getLinkedTripsCount(purchase);
              if (linkedTripsCount > 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AuthColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    linkedTripsCount.toString(),
                    style: TextStyle(
                      color: AuthColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return Text(
                '0',
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              );
          },
        ),
      ],
      rows: purchases,
      rowActions: [
        custom_table.DataTableRowAction<Transaction>(
          icon: Icons.link,
          color: AuthColors.primary,
          tooltip: 'Link Trips',
          onTap: (purchase, index) => onLinkTrips(purchase),
        ),
        custom_table.DataTableRowAction<Transaction>(
          icon: Icons.delete_outline,
          color: AuthColors.error,
          tooltip: 'Delete Purchase',
          onTap: (purchase, index) => onDelete(purchase),
        ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final startItem = (currentPage * itemsPerPage) + 1;
    final endItem = ((currentPage + 1) * itemsPerPage).clamp(0, totalItems);

    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AuthColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Items info
            Text(
              'Showing $startItem-$endItem of $totalItems',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            // Pagination buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              // First page
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                color: currentPage == 0
                    ? AuthColors.textDisabled
                    : AuthColors.textSub,
                onPressed: currentPage == 0
                    ? null
                    : () => onPageChanged(0),
                tooltip: 'First page',
              ),
              // Previous page
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 24),
                color: currentPage == 0
                    ? AuthColors.textDisabled
                    : AuthColors.textSub,
                onPressed: currentPage == 0
                    ? null
                    : () => onPageChanged(currentPage - 1),
                tooltip: 'Previous page',
              ),
              // Page numbers
              ...List.generate(
                totalPages.clamp(0, 7), // Show max 7 page numbers
                (index) {
                  int pageIndex;
                  if (totalPages <= 7) {
                    pageIndex = index;
                  } else if (currentPage < 4) {
                    pageIndex = index;
                  } else if (currentPage > totalPages - 4) {
                    pageIndex = totalPages - 7 + index;
                  } else {
                    pageIndex = currentPage - 3 + index;
                  }

                  final isCurrentPage = pageIndex == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isCurrentPage
                          ? AuthColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onPageChanged(pageIndex),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                            child: Text(
                            '${pageIndex + 1}',
                              style: TextStyle(
                              color: isCurrentPage
                                  ? AuthColors.textMain
                                  : AuthColors.textSub,
                                fontSize: 14,
                              fontWeight: isCurrentPage
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Next page
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 24),
                color: currentPage >= totalPages - 1
                    ? AuthColors.textDisabled
                    : AuthColors.textSub,
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => onPageChanged(currentPage + 1),
                tooltip: 'Next page',
              ),
              // Last page
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                color: currentPage >= totalPages - 1
                    ? AuthColors.textDisabled
                    : AuthColors.textSub,
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => onPageChanged(totalPages - 1),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
