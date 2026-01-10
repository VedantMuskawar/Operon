import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: const ModernPageHeader(
            title: 'Fuel Ledger',
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
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
                          mainAxisSize: MainAxisSize.min,
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
                              onPressed: _loadFuelPurchases,
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
                  : _fuelPurchases.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to record a fuel purchase',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _FuelPurchasesTable(
                            purchases: _fuelPurchases,
                            vendorNames: _vendorNames,
                            formatCurrency: _formatCurrency,
                            formatDate: _formatDate,
                            getLinkedTripsCount: _getLinkedTripsCount,
                            onLinkTrips: _showLinkTripsDialog,
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
        ),
        // Floating Action Button - positioned like Add Client button
        Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            final bottomPadding = media.padding.bottom;
            // Nav bar height (~80px) + safe area bottom + spacing (20px)
            final bottomOffset = 80 + bottomPadding + 20;
            return Positioned(
              right: 40,
              bottom: bottomOffset,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => RecordFuelPurchaseDialog(
                        onPurchaseRecorded: () {
                          _loadFuelPurchases();
                        },
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6F4BFF).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Record Fuel Purchase',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FuelPurchasesTable extends StatelessWidget {
  const _FuelPurchasesTable({
    required this.purchases,
    required this.vendorNames,
    required this.formatCurrency,
    required this.formatDate,
    required this.getLinkedTripsCount,
    required this.onLinkTrips,
  });

  final List<Transaction> purchases;
  final Map<String, String> vendorNames;
  final String Function(double) formatCurrency;
  final String Function(DateTime) formatDate;
  final int Function(Transaction) getLinkedTripsCount;
  final void Function(Transaction) onLinkTrips;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 100),
      constraints: const BoxConstraints(minWidth: 840),
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
          2: FixedColumnWidth(120), // Vehicle
          3: FixedColumnWidth(120), // Voucher
          4: FixedColumnWidth(120), // Amount
          5: FixedColumnWidth(100), // Trips
          6: FixedColumnWidth(110), // Actions
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
              _TableHeaderCell('Vehicle'),
              _TableHeaderCell('Voucher'),
              _TableHeaderCell('Amount'),
              _TableHeaderCell('Trips'),
              _TableHeaderCell('Actions'),
            ],
          ),
          // Data Rows
          ...purchases.asMap().entries.map((entry) {
            final index = entry.key;
            final purchase = entry.value;
            final date = purchase.createdAt ?? DateTime.now();
            final metadata = purchase.metadata;
            final vehicleNumber = metadata?['vehicleNumber'] as String? ?? 'N/A';
            final voucherNumber = metadata?['voucherNumber'] as String? ?? 'N/A';
            final vendorName = vendorNames[purchase.vendorId ?? ''] ?? 'Loading...';
            final linkedTripsCount = getLinkedTripsCount(purchase);
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
                  vehicleNumber,
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  voucherNumber,
                  alignment: Alignment.centerLeft,
                ),
                _TableDataCell(
                  formatCurrency(purchase.amount),
                  alignment: Alignment.centerRight,
                  isAmount: true,
                ),
                _TableDataCell(
                  linkedTripsCount > 0 ? linkedTripsCount.toString() : '-',
                  alignment: Alignment.center,
                  hasBadge: linkedTripsCount > 0,
                ),
                _TableActionCell(
                  onLinkTrips: () => onLinkTrips(purchase),
                  linkedTripsCount: linkedTripsCount,
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
    this.hasBadge = false,
  });

  final String text;
  final Alignment alignment;
  final bool isAmount;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    Widget content = Text(
      text,
      style: TextStyle(
        color: isAmount ? const Color(0xFFFF9800) : Colors.white70,
        fontSize: 13,
        fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    if (hasBadge) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF6F4BFF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF6F4BFF).withOpacity(0.5),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6F4BFF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(
        alignment: alignment,
        child: content,
      ),
    );
  }
}

class _TableActionCell extends StatelessWidget {
  const _TableActionCell({
    required this.onLinkTrips,
    required this.linkedTripsCount,
  });

  final VoidCallback onLinkTrips;
  final int linkedTripsCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center(
        child: TextButton(
          onPressed: onLinkTrips,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6F4BFF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 14),
              const SizedBox(width: 4),
              Text(
                linkedTripsCount > 0 ? 'Update' : 'Link',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

