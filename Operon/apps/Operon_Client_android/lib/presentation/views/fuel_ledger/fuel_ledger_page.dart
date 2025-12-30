import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/page_workspace_layout.dart';
import 'package:dash_mobile/presentation/views/fuel_ledger/record_fuel_purchase_dialog.dart';
import 'package:dash_mobile/presentation/views/fuel_ledger/link_trips_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class FuelLedgerPage extends StatefulWidget {
  const FuelLedgerPage({super.key});

  @override
  State<FuelLedgerPage> createState() => _FuelLedgerPageState();
}

class _FuelLedgerPageState extends State<FuelLedgerPage> {
  List<Transaction> _fuelPurchases = [];
  final Map<String, String> _vendorNames = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFuelPurchases();
  }

  Future<void> _loadFuelPurchases() async {
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

      // Query fuel purchases
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
          .where((tx) {
            // Filter for fuel purchases
            final metadata = tx.metadata;
            return metadata != null && (metadata['purchaseType'] as String?) == 'fuel';
          })
          .toList();

      setState(() {
        _fuelPurchases = purchases;
        _isLoading = false;
      });

      // Fetch vendor names
      _fetchVendorNames();
    } catch (e) {
      setState(() {
        _error = 'Failed to load fuel purchases: $e';
        _isLoading = false;
      });
    }
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
          _loadFuelPurchases();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => RecordFuelPurchaseDialog(
              onPurchaseRecorded: () {
                _loadFuelPurchases();
              },
            ),
          );
        },
        backgroundColor: const Color(0xFF6F4BFF),
        icon: const Icon(Icons.add),
        label: const Text('Record Fuel Purchase'),
      ),
      body: PageWorkspaceLayout(
        title: 'Fuel Ledger',
        currentIndex: 0,
        onNavTap: (value) => context.go('/home', extra: value),
        onBack: () => context.go('/home'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fuel Purchases List
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
                              onPressed: _loadFuelPurchases,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _fuelPurchases.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.local_gas_station_outlined,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No fuel purchases found',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _fuelPurchases.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final purchase = _fuelPurchases[index];
                                return _FuelPurchaseTile(
                                  purchase: purchase,
                                  formatCurrency: _formatCurrency,
                                  formatDate: _formatDate,
                                  vendorName: _vendorNames[purchase.vendorId ?? ''] ?? 'Loading...',
                                  linkedTripsCount: _getLinkedTripsCount(purchase),
                                  onLinkTrips: () => _showLinkTripsDialog(purchase),
                                );
                              },
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}

class _FuelPurchaseTile extends StatelessWidget {
  const _FuelPurchaseTile({
    required this.purchase,
    required this.formatCurrency,
    required this.formatDate,
    required this.vendorName,
    required this.linkedTripsCount,
    this.onLinkTrips,
  });

  final Transaction purchase;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final String vendorName;
  final int linkedTripsCount;
  final VoidCallback? onLinkTrips;

  @override
  Widget build(BuildContext context) {
    final date = purchase.createdAt ?? DateTime.now();
    final metadata = purchase.metadata;
    final vehicleNumber = metadata?['vehicleNumber'] as String? ?? 'N/A';
    final voucherNumber = metadata?['voucherNumber'] as String? ?? 'N/A';

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
                            'Fuel',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vendorName != 'Loading...' ? vendorName : 'Unknown Vendor',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.directions_car, size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Vehicle: $vehicleNumber',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.receipt, size: 14, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Voucher: $voucherNumber',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (linkedTripsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6F4BFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6F4BFF).withOpacity(0.5)),
                  ),
                  child: Text(
                    '$linkedTripsCount trip${linkedTripsCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF6F4BFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (onLinkTrips != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onLinkTrips,
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(
                    linkedTripsCount > 0 ? 'Update Trips' : 'Link Trips (Optional)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6F4BFF),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

