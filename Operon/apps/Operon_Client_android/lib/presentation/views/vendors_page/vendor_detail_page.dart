import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/raw_materials_repository.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({super.key, required this.vendor});

  final Vendor vendor;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  int _selectedTabIndex = 0;

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text(
          'Delete Vendor',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.vendor.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      context.read<VendorsCubit>().deleteVendor(widget.vendor.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor deleted.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete vendor: $error')),
      );
    }
  }

  Future<void> _openEditDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<VendorsCubit>(),
        child: _VendorEditDialog(vendor: widget.vendor),
      ),
    );
    // Refresh vendor data after edit
    if (mounted) {
      context.read<VendorsCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vendor Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Vendor Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _VendorHeader(
                vendor: widget.vendor,
                onEdit: _openEditDialog,
                onDelete: _confirmDelete,
              ),
            ),
            const SizedBox(height: 16),
            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131324),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Overview',
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
            const SizedBox(height: 16),
            // Content based on selected tab
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _OverviewSection(vendor: widget.vendor),
                  _TransactionsSection(vendor: widget.vendor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({
    required this.vendor,
    required this.onEdit,
    required this.onDelete,
  });

  final Vendor vendor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _getVendorColor() {
    final hash = vendor.vendorType.name.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[hash.abs() % colors.length];
  }

  IconData _getVendorTypeIcon() {
    switch (vendor.vendorType) {
      case VendorType.rawMaterial:
        return Icons.inventory_2;
      case VendorType.vehicle:
        return Icons.directions_car;
      case VendorType.repairMaintenance:
        return Icons.build;
      case VendorType.fuel:
        return Icons.local_gas_station;
      case VendorType.utilities:
        return Icons.bolt;
      case VendorType.rent:
        return Icons.home;
      case VendorType.professionalServices:
        return Icons.business_center;
      case VendorType.marketingAdvertising:
        return Icons.campaign;
      case VendorType.insurance:
        return Icons.shield;
      case VendorType.logistics:
        return Icons.local_shipping;
      case VendorType.officeSupplies:
        return Icons.description;
      case VendorType.security:
        return Icons.security;
      case VendorType.cleaning:
        return Icons.cleaning_services;
      case VendorType.taxConsultant:
        return Icons.account_balance;
      case VendorType.bankingFinancial:
        return Icons.account_balance_wallet;
      case VendorType.welfare:
        return Icons.favorite;
      case VendorType.other:
        return Icons.store;
    }
  }

  String _formatVendorType() {
    return vendor.vendorType.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatStatus() {
    return vendor.status.name[0].toUpperCase() + vendor.status.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final vendorColor = _getVendorColor();
    final balanceDifference = vendor.currentBalance - vendor.openingBalance;
    final isPositive = balanceDifference >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            vendorColor.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: vendorColor.withOpacity(0.2),
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
                      vendorColor,
                      vendorColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: vendorColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _getVendorTypeIcon(),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Phone
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            vendor.phoneNumber,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Delete',
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, color: Colors.white70),
                tooltip: 'Edit',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Type Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: vendorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: vendorColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getVendorTypeIcon(),
                      size: 14,
                      color: vendorColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatVendorType(),
                      style: TextStyle(
                        color: vendorColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: vendor.status == VendorStatus.active
                      ? const Color(0xFF5AD8A4).withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: vendor.status == VendorStatus.active
                        ? const Color(0xFF5AD8A4).withOpacity(0.5)
                        : Colors.grey.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  _formatStatus(),
                  style: TextStyle(
                    color: vendor.status == VendorStatus.active
                        ? const Color(0xFF5AD8A4)
                        : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Balance Change Indicator
              if (balanceDifference != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF5AD8A4).withOpacity(0.2)
                        : Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPositive
                          ? const Color(0xFF5AD8A4).withOpacity(0.5)
                          : Colors.redAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}₹${balanceDifference.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF5AD8A4) : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? const Color(0xFF6F4BFF)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatefulWidget {
  const _OverviewSection({required this.vendor});

  final Vendor vendor;

  @override
  State<_OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<_OverviewSection> {
  List<RawMaterial>? _assignedMaterials;
  bool _isLoadingMaterials = false;

  @override
  void initState() {
    super.initState();
    if (widget.vendor.vendorType == VendorType.rawMaterial &&
        widget.vendor.rawMaterialDetails?.assignedMaterialIds.isNotEmpty == true) {
      _loadAssignedMaterials();
    }
  }

  Future<void> _loadAssignedMaterials() async {
    if (_isLoadingMaterials) return;
    setState(() => _isLoadingMaterials = true);

    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) {
        setState(() => _isLoadingMaterials = false);
        return;
      }

      final repository = context.read<RawMaterialsRepository>();
      final materialIds = widget.vendor.rawMaterialDetails?.assignedMaterialIds ?? [];
      final allMaterials = await repository.fetchRawMaterials(organization.id);
      final materials = allMaterials
          .where((material) => materialIds.contains(material.id))
          .toList();

      if (mounted) {
        setState(() {
          _assignedMaterials = materials;
          _isLoadingMaterials = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMaterials = false);
      }
    }
  }

  Color _getVendorColor() {
    final hash = widget.vendor.vendorType.name.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final vendor = widget.vendor;
    final vendorColor = _getVendorColor();
    final balanceDifference = vendor.currentBalance - vendor.openingBalance;
    final isPositive = balanceDifference >= 0;
    final percentChange = vendor.openingBalance != 0
        ? (balanceDifference / vendor.openingBalance * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPositive
                    ? [
                        const Color(0xFF4CAF50).withOpacity(0.2),
                        const Color(0xFF4CAF50).withOpacity(0.05),
                      ]
                    : [
                        const Color(0xFFEF5350).withOpacity(0.2),
                        const Color(0xFFEF5350).withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))
                    .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(vendor.currentBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())} from opening',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (vendor.openingBalance != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${isPositive ? '+' : ''}${percentChange.abs().toStringAsFixed(1)}%)',
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Opening Balance',
                  value: _formatCurrency(vendor.openingBalance),
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Net Change',
                  value: '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())}',
                  color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131324),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 20,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        vendor.phoneNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (vendor.gstNumber != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 20,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'GST: ${vendor.gstNumber}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (vendor.contactPerson != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 20,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          vendor.contactPerson!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Raw Materials (if vendor type is rawMaterial)
          if (vendor.vendorType == VendorType.rawMaterial) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131324),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assigned Raw Materials',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingMaterials)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6F4BFF),
                      ),
                    )
                  else if (_assignedMaterials == null || _assignedMaterials?.isEmpty == true)
                    Text(
                      'No raw materials assigned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_assignedMaterials ?? []).map((material) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: vendorColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vendorColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            material.name,
                            style: TextStyle(
                              color: vendorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsSection extends StatefulWidget {
  const _TransactionsSection({required this.vendor});

  final Vendor vendor;

  @override
  State<_TransactionsSection> createState() => _TransactionsSectionState();
}

class _TransactionsSectionState extends State<_TransactionsSection> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _error;
  String? _currentOrgId;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToTransactions();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToTransactions() {
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
    if (_currentOrgId == orgId && _transactionsSubscription != null) {
      return; // Already subscribed
    }

    _currentOrgId = orgId;
    _transactionsSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Subscribe to transactions for this vendor
    Query query = FirebaseFirestore.instance
        .collection('TRANSACTIONS')
        .where('organizationId', isEqualTo: orgId)
        .where('ledgerType', isEqualTo: 'vendorLedger')
        .where('vendorId', isEqualTo: widget.vendor.id)
        .orderBy('createdAt', descending: true)
        .limit(100);

    _transactionsSubscription = query.snapshots().listen(
      (snapshot) {
        final transactions = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return <String, dynamic>{
            'id': doc.id,
            ...data,
          };
        }).toList();

        // Sort in memory by transactionDate or createdAt
        transactions.sort((a, b) {
          final dateA = a['transactionDate'] ?? a['createdAt'];
          final dateB = b['transactionDate'] ?? b['createdAt'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          
          Timestamp? tsA;
          Timestamp? tsB;
          if (dateA is Timestamp) {
            tsA = dateA;
          } else if (dateA is DateTime) {
            tsA = Timestamp.fromDate(dateA);
          }
          if (dateB is Timestamp) {
            tsB = dateB;
          } else if (dateB is DateTime) {
            tsB = Timestamp.fromDate(dateB);
          }
          
          if (tsA == null && tsB == null) return 0;
          if (tsA == null) return 1;
          if (tsB == null) return -1;
          
          return tsB.compareTo(tsA); // Descending
        });

        if (mounted) {
          setState(() {
            _transactions = transactions;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        // Try without orderBy as fallback
        final fallbackQuery = FirebaseFirestore.instance
            .collection('TRANSACTIONS')
            .where('organizationId', isEqualTo: orgId)
            .where('ledgerType', isEqualTo: 'vendorLedger')
            .where('vendorId', isEqualTo: widget.vendor.id)
            .limit(100);
        
        _transactionsSubscription?.cancel();
        _transactionsSubscription = fallbackQuery.snapshots().listen(
          (snapshot) {
            final transactions = snapshot.docs.map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                ...data,
              };
            }).toList();

            // Sort in memory
            transactions.sort((a, b) {
              final dateA = a['transactionDate'] ?? a['createdAt'];
              final dateB = b['transactionDate'] ?? b['createdAt'];
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              
              Timestamp? tsA;
              Timestamp? tsB;
              if (dateA is Timestamp) {
                tsA = dateA;
              } else if (dateA is DateTime) {
                tsA = Timestamp.fromDate(dateA);
              }
              if (dateB is Timestamp) {
                tsB = dateB;
              } else if (dateB is DateTime) {
                tsB = Timestamp.fromDate(dateB);
              }
              
              if (tsA == null && tsB == null) return 0;
              if (tsA == null) return 1;
              if (tsB == null) return -1;
              
              return tsB.compareTo(tsA);
            });

            if (mounted) {
              setState(() {
                _transactions = transactions;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _error = 'Failed to load transactions: $error';
                _isLoading = false;
              });
            }
          },
        );
      },
    );
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
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null && state.organization!.id != _currentOrgId) {
          _currentOrgId = null;
          _subscribeToTransactions();
        }
      },
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6F4BFF),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _transactions.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Transactions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No ledger entries found for this vendor',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LedgerBalanceCard(
                            vendor: widget.vendor,
                            formatCurrency: _formatCurrency,
                          ),
                          const SizedBox(height: 20),
                          _LedgerTable(
                            transactions: _transactions,
                            formatCurrency: _formatCurrency,
                            formatDate: _formatDate,
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _LedgerBalanceCard extends StatelessWidget {
  const _LedgerBalanceCard({
    required this.vendor,
    required this.formatCurrency,
  });

  final Vendor vendor;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final currentBalance = vendor.currentBalance;
    final openingBalance = vendor.openingBalance;
    final isReceivable = currentBalance > 0;
    final isPayable = currentBalance < 0;

    Color badgeColor() {
      if (isReceivable) return Colors.orangeAccent;
      if (isPayable) return Colors.greenAccent;
      return Colors.white70;
    }

    String badgeText() {
      if (isReceivable) return 'We owe vendor';
      if (isPayable) return 'Vendor owes us';
      return 'Settled';
    }

    final totalPurchases = currentBalance > openingBalance ? (currentBalance - openingBalance) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131324),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ledger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor().withOpacity(0.6)),
                ),
                child: Text(
                  badgeText(),
                  style: TextStyle(
                    color: badgeColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LedgerRow(label: 'Current Balance', value: formatCurrency(currentBalance.abs())),
          _LedgerRow(label: 'Opening Balance', value: formatCurrency(openingBalance)),
          _LedgerRow(label: 'Total Purchases', value: formatCurrency(totalPurchases)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Text(
        'No transactions found.',
        style: TextStyle(color: Colors.white54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ledger',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131324),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              const Divider(height: 1, color: Colors.white12),
              ...transactions.map((tx) {
                final type = tx['type'] as String? ?? 'credit';
                final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final balanceAfter = (tx['balanceAfter'] as num?)?.toDouble() ?? 0.0;
                final date = tx['transactionDate'] ?? tx['createdAt'];
                final referenceNumber = tx['referenceNumber'] as String? ?? tx['metadata']?['invoiceNumber'] as String? ?? '-';
                
                final isCredit = type == 'credit';
                final credit = isCredit ? amount : 0.0;
                final debit = !isCredit ? amount : 0.0;

                return _LedgerTableRow(
                  date: date,
                  reference: referenceNumber,
                  credit: credit,
                  debit: debit,
                  balance: balanceAfter,
                  formatCurrency: formatCurrency,
                  formatDate: formatDate,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _LedgerTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text('Date', style: TextStyle(color: Colors.white70, fontSize: 11))),
          SizedBox(width: 70, child: Text('Reference', style: TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(child: Text('Credit', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
          Expanded(child: Text('Debit', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
          Expanded(child: Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.date,
    required this.reference,
    required this.credit,
    required this.debit,
    required this.balance,
    required this.formatCurrency,
    required this.formatDate,
  });

  final dynamic date;
  final String reference;
  final double credit;
  final double debit;
  final double balance;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              formatDate(date),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              reference,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              credit > 0 ? formatCurrency(credit) : '-',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              debit > 0 ? formatCurrency(debit) : '-',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              formatCurrency(balance),
              style: TextStyle(
                color: balance >= 0 ? Colors.orangeAccent : Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorEditDialog extends StatefulWidget {
  const _VendorEditDialog({required this.vendor});

  final Vendor vendor;

  @override
  State<_VendorEditDialog> createState() => _VendorEditDialogState();
}

class _VendorEditDialogState extends State<_VendorEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _gstController;
  VendorType _selectedVendorType = VendorType.other;
  VendorStatus _selectedStatus = VendorStatus.active;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor.name);
    _phoneController = TextEditingController(text: vendor.phoneNumber);
    _gstController = TextEditingController(text: vendor.gstNumber ?? '');
    _selectedVendorType = vendor.vendorType;
    _selectedStatus = vendor.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatStatus(VendorStatus status) {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VendorsCubit>();

    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A0A),
      title: const Text(
        'Edit Vendor',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Vendor name'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter vendor name'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Phone number'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter phone number'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VendorType>(
                initialValue: _selectedVendorType,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: VendorType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_formatVendorType(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedVendorType = value);
                  }
                },
                decoration: _inputDecoration('Vendor Type'),
                validator: (value) => value == null ? 'Select vendor type' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gstController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('GST Number (optional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VendorStatus>(
                initialValue: _selectedStatus,
                dropdownColor: const Color(0xFF1B1B2C),
                style: const TextStyle(color: Colors.white),
                items: VendorStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_formatStatus(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                  }
                },
                decoration: _inputDecoration('Status'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: cubit.canEdit
              ? () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;

                  final normalizedPhone = _phoneController.text
                      .replaceAll(RegExp(r'[^0-9+]'), '');
                  final phoneNumber = normalizedPhone.startsWith('+')
                      ? normalizedPhone
                      : '+91$normalizedPhone';

                  final vendor = Vendor(
                    id: widget.vendor.id,
                    vendorCode: widget.vendor.vendorCode,
                    name: _nameController.text.trim(),
                    nameLowercase: _nameController.text.trim().toLowerCase(),
                    phoneNumber: phoneNumber,
                    phoneNumberNormalized: normalizedPhone,
                    phones: [
                      {'number': phoneNumber, 'normalized': normalizedPhone}
                    ],
                    phoneIndex: [normalizedPhone],
                    openingBalance: widget.vendor.openingBalance,
                    currentBalance: widget.vendor.currentBalance,
                    vendorType: _selectedVendorType,
                    status: _selectedStatus,
                    organizationId: cubit.organizationId,
                    gstNumber: _gstController.text.trim().isEmpty
                        ? null
                        : _gstController.text.trim(),
                    rawMaterialDetails: widget.vendor.rawMaterialDetails,
                    vehicleDetails: widget.vendor.vehicleDetails,
                    repairMaintenanceDetails: widget.vendor.repairMaintenanceDetails,
                    welfareDetails: widget.vendor.welfareDetails,
                    fuelDetails: widget.vendor.fuelDetails,
                    utilitiesDetails: widget.vendor.utilitiesDetails,
                    rentDetails: widget.vendor.rentDetails,
                    professionalServicesDetails: widget.vendor.professionalServicesDetails,
                    marketingAdvertisingDetails: widget.vendor.marketingAdvertisingDetails,
                    insuranceDetails: widget.vendor.insuranceDetails,
                    logisticsDetails: widget.vendor.logisticsDetails,
                    officeSuppliesDetails: widget.vendor.officeSuppliesDetails,
                    securityDetails: widget.vendor.securityDetails,
                    cleaningDetails: widget.vendor.cleaningDetails,
                    taxConsultantDetails: widget.vendor.taxConsultantDetails,
                    bankingFinancialDetails: widget.vendor.bankingFinancialDetails,
                  );

                  context.read<VendorsCubit>().updateVendor(vendor);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

