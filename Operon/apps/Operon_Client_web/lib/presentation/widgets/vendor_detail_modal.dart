import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashCard, DashSnackbar;
import 'package:core_ui/core_ui.dart' show showLedgerDateRangeModal, OperonPdfPreviewModal;
import 'package:core_utils/core_utils.dart' show calculateOpeningBalance, generateLedgerPdf, LedgerRowData;
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_web/presentation/widgets/detail_modal_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

/// Modal dialog for displaying vendor details
class VendorDetailModal extends StatefulWidget {
  const VendorDetailModal({
    super.key,
    required this.vendor,
    this.onVendorChanged,
    this.onEdit,
  });

  final Vendor vendor;
  final ValueChanged<Vendor>? onVendorChanged;
  final VoidCallback? onEdit;

  @override
  State<VendorDetailModal> createState() => _VendorDetailModalState();
}

class _VendorDetailModalState extends State<VendorDetailModal> {
  List<RawMaterial>? _assignedMaterials;
  bool _isLoadingMaterials = false;
  Vendor? _currentVendor;
  StreamSubscription<List<Vendor>>? _vendorsSubscription;

  @override
  void initState() {
    super.initState();
    _currentVendor = widget.vendor;
    _subscribeToVendorUpdates();
    if (widget.vendor.vendorType == VendorType.rawMaterial &&
        widget.vendor.rawMaterialDetails?.assignedMaterialIds.isNotEmpty == true) {
      _loadAssignedMaterials();
    }
  }

  @override
  void dispose() {
    _vendorsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToVendorUpdates() {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    final repository = context.read<VendorsRepository>();
    _vendorsSubscription = repository.watchVendors(organization.id).listen(
      (vendors) {
        final updatedVendor = vendors.firstWhere(
          (v) => v.id == widget.vendor.id,
          orElse: () => widget.vendor,
        );
        if (mounted && updatedVendor.id == widget.vendor.id) {
          setState(() {
            _currentVendor = updatedVendor;
          });
          // Notify parent if callback provided
          if (widget.onVendorChanged != null && updatedVendor != widget.vendor) {
            widget.onVendorChanged!(updatedVendor);
          }
        }
      },
      onError: (error) {
        // Silently fail - don't break the UI
        debugPrint('Error in vendor stream: $error');
      },
    );
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
      final vendor = _currentVendor ?? widget.vendor;
      final materialIds = vendor.rawMaterialDetails?.assignedMaterialIds ?? [];
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

  Future<void> _confirmDelete() async {
    final vendor = _currentVendor ?? widget.vendor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteVendorDialog(
        vendorName: vendor.name,
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final cubit = context.read<VendorsCubit>();
        await cubit.deleteVendor(vendor.id);
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Vendor deleted.', isError: false);
        Navigator.of(context).pop();
      } catch (error) {
        if (!mounted) return;
        DashSnackbar.show(context, message: 'Unable to delete vendor: $error', isError: true);
      }
    }
  }

  void _editVendor() {
    if (widget.onEdit != null) {
      Navigator.of(context).pop();
      widget.onEdit!();
    }
  }

  Color _getVendorColor(VendorType type) {
    switch (type) {
      case VendorType.rawMaterial:
        return const Color(0xFF6F4BFF);
      case VendorType.vehicle:
        return const Color(0xFF5AD8A4);
      case VendorType.fuel:
        return const Color(0xFFFF9800);
      case VendorType.repairMaintenance:
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFFE91E63);
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatVendorStatus(VendorStatus status) {
    switch (status) {
      case VendorStatus.active:
        return 'Active';
      case VendorStatus.inactive:
        return 'Inactive';
      case VendorStatus.suspended:
        return 'Suspended';
      case VendorStatus.blacklisted:
        return 'Blacklisted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendor = _currentVendor ?? widget.vendor;
    final vendorColor = _getVendorColor(vendor.vendorType);
    
    return DetailModalBase(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _ModalHeader(
            vendor: widget.vendor,
            vendorColor: vendorColor,
            onClose: () => Navigator.of(context).pop(),
            onEdit: _editVendor,
            onDelete: _confirmDelete,
            getInitials: _getInitials,
            formatVendorType: _formatVendorType,
            formatVendorStatus: _formatVendorStatus,
          ),

          // Content (no tabs - only Ledger section)
          Expanded(
            child: _TransactionsSection(vendor: widget.vendor),
          ),
        ],
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.vendor,
    required this.vendorColor,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.getInitials,
    required this.formatVendorType,
    required this.formatVendorStatus,
  });

  final Vendor vendor;
  final Color vendorColor;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) getInitials;
  final String Function(VendorType) formatVendorType;
  final String Function(VendorStatus) formatVendorStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            vendorColor.withOpacity(0.3),
            const Color(0xFF1B1B2C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      vendorColor,
                      vendorColor.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    getInitials(vendor.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vendorColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vendorColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            formatVendorType(vendor.vendorType),
                            style: TextStyle(
                              color: vendorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vendor.status == VendorStatus.active
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: vendor.status == VendorStatus.active
                                  ? const Color(0xFF4CAF50).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            formatVendorStatus(vendor.status),
                            style: TextStyle(
                              color: vendor.status == VendorStatus.active
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
                tooltip: 'Close',
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: onDelete,
                tooltip: 'Delete',
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.vendor,
    required this.vendorColor,
    required this.balanceDifference,
    required this.isPositive,
    this.assignedMaterials,
    this.isLoadingMaterials = false,
    required this.formatVendorType,
  });

  final Vendor vendor;
  final Color vendorColor;
  final double balanceDifference;
  final bool isPositive;
  final List<RawMaterial>? assignedMaterials;
  final bool isLoadingMaterials;
  final String Function(VendorType) formatVendorType;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AuthColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Net Change',
                  value: '${isPositive ? '+' : ''}${_formatCurrency(balanceDifference.abs())}',
                  color: isPositive ? AuthColors.success : AuthColors.error,
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
                  if (isLoadingMaterials)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AuthColors.accentPurple,
                      ),
                    )
                  else if (assignedMaterials == null || assignedMaterials?.isEmpty == true)
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
                      children: (assignedMaterials ?? []).map((material) {
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                material.name,
                                style: TextStyle(
                                  color: vendorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${material.stock} ${material.unitOfMeasurement})',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
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
    return DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
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
  bool _isInitialLoad = true;

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
            _isInitialLoad = false;
          });
        }
      },
      onError: (e) {
        // Check if it's an index error
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('index') || errorStr.contains('requires an index')) {
          // Try without orderBy as fallback
          final fallbackQuery = FirebaseFirestore.instance
              .collection('TRANSACTIONS')
              .where('organizationId', isEqualTo: orgId)
              .where('ledgerType', isEqualTo: 'vendorLedger')
              .where('vendorId', isEqualTo: widget.vendor.id)
              .limit(100);
          
          _transactionsSubscription?.cancel();
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
                  _isInitialLoad = false;
                });
              }
            },
            onError: (error) {
              if (mounted) {
                setState(() {
                  _error = 'Failed to load transactions: $error';
                  _isLoading = false;
                  _isInitialLoad = false;
                });
              }
            },
          );
        } else {
          if (mounted) {
            setState(() {
              _error = 'Failed to load transactions: $e';
              _isLoading = false;
              _isInitialLoad = false;
            });
          }
        }
      },
    );
  }

  Future<void> _loadTransactions() async {
    // Re-subscribe to refresh
    _isInitialLoad = true;
    _subscribeToTransactions();
  }

  @override
  void didUpdateWidget(_TransactionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If vendor changed, re-subscribe
    if (oldWidget.vendor.id != widget.vendor.id) {
      _subscribeToTransactions();
    }
  }

  // Legacy method for compatibility - now just re-subscribes
  void _legacyLoadTransactions() {
    _loadTransactions();
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
          _loadTransactions();
        }
      },
      child: (_isLoading && _isInitialLoad)
          ? const Center(
              child: CircularProgressIndicator(
                color: AuthColors.primary,
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
                          color: AuthColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        DashButton(
                          label: 'Retry',
                          onPressed: _loadTransactions,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _LedgerTable(
                    openingBalance: widget.vendor.openingBalance,
                    transactions: _transactions,
                    formatCurrency: _formatCurrency,
                    formatDate: _formatDate,
                    vendorId: widget.vendor.id,
                    vendorName: widget.vendor.name,
                    storedOpeningBalance: widget.vendor.openingBalance,
                  ),
                ),
    );
  }
}

String _formatCategoryName(String? category) {
  if (category == null || category.isEmpty) return '';
  return category
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .split(' ')
      .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ')
      .trim();
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({
    required this.openingBalance,
    required this.transactions,
    required this.formatCurrency,
    required this.formatDate,
    required this.vendorId,
    required this.vendorName,
    required this.storedOpeningBalance,
  });

  final double openingBalance;
  final List<Map<String, dynamic>> transactions;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;
  final String vendorId;
  final String vendorName;
  final double storedOpeningBalance;

  Future<void> _generateLedgerPdf(BuildContext context) async {
    try {
      // Show date range picker
      final dateRange = await showLedgerDateRangeModal(context);
      if (dateRange == null) return; // User cancelled

      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get organization ID
      final orgContext = context.read<OrganizationContextCubit>().state;
      final organization = orgContext.organization;
      if (organization == null || !context.mounted) {
        Navigator.of(context).pop(); // Close loading
        DashSnackbar.show(context, message: 'No organization selected', isError: true);
        return;
      }

      // Fetch all transactions for opening balance calculation
      final transactionsDataSource = TransactionsDataSource();
      final financialYear = FinancialYearUtils.getCurrentFinancialYear();
      
      // Get all vendor transactions (both purchases and payments)
      final allPurchases = await transactionsDataSource.getVendorPurchases(
        organizationId: organization.id,
        financialYear: financialYear,
      );
      final allPayments = await transactionsDataSource.getVendorExpenses(
        organizationId: organization.id,
        financialYear: financialYear,
        vendorId: vendorId,
      );
      
      // Combine and filter by vendor
      final allTransactions = [
        ...allPurchases.where((tx) => tx.vendorId == vendorId),
        ...allPayments,
      ];

      // Calculate opening balance for date range
      // Use stored opening balance if no transactions before start date
      final openingBal = calculateOpeningBalance(
        allTransactions: allTransactions,
        startDate: dateRange.start,
        storedOpeningBalance: storedOpeningBalance,
      );

      // Filter transactions in date range
      final transactionsInRange = allTransactions.where((tx) {
        final txDate = tx.createdAt ?? tx.updatedAt;
        if (txDate == null) return false;
        return txDate.isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
               txDate.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();

      // Sort chronologically
      transactionsInRange.sort((a, b) {
        final aDate = a.createdAt ?? a.updatedAt ?? DateTime(1970);
        final bDate = b.createdAt ?? b.updatedAt ?? DateTime(1970);
        return aDate.compareTo(bDate);
      });

      // Convert to LedgerRowData
      double runningBalance = openingBal;
      final ledgerRows = <LedgerRowData>[];
      
      for (final tx in transactionsInRange) {
        final txDate = tx.createdAt ?? tx.updatedAt ?? DateTime.now();
        final type = tx.type;
        final amount = tx.amount;
        final metadata = tx.metadata ?? {};
        final invoiceNumber = tx.referenceNumber ?? metadata['invoiceNumber'];
        final description = tx.description ?? '';

        // Calculate debit/credit
        double debit = 0.0;
        double credit = 0.0;
        if (type == TransactionType.credit) {
          credit = amount;
          runningBalance += amount;
        } else if (type == TransactionType.debit) {
          debit = amount;
          runningBalance -= amount;
        }

        // Get reference (Invoice No. for vendor)
        final reference = invoiceNumber?.toString() ?? '-';

        // Get type name
        final typeName = _formatCategoryName(tx.category.name);

        ledgerRows.add(LedgerRowData(
          date: txDate,
          reference: reference,
          debit: debit,
          credit: credit,
          balance: runningBalance,
          type: typeName,
          remarks: description.isNotEmpty ? description : '-',
        ));
      }

      // Fetch DM settings for company header
      final dmSettingsRepo = context.read<DmSettingsRepository>();
      final dmSettings = await dmSettingsRepo.fetchDmSettings(organization.id);
      if (dmSettings == null || !context.mounted) {
        Navigator.of(context).pop(); // Close loading
        DashSnackbar.show(context, message: 'DM settings not found. Please configure DM settings first.', isError: true);
        return;
      }

      // Load logo if available
      Uint8List? logoBytes;
      if (dmSettings.header.logoImageUrl != null && dmSettings.header.logoImageUrl!.isNotEmpty) {
        try {
          final logoUrl = dmSettings.header.logoImageUrl!;
          final response = await http.get(Uri.parse(logoUrl));
          if (response.statusCode == 200) {
            logoBytes = response.bodyBytes;
          }
        } catch (e) {
          // Logo loading failed, continue without it
        }
      }

      // Generate PDF
      final pdfBytes = await generateLedgerPdf(
        ledgerType: LedgerType.vendorLedger,
        entityName: vendorName,
        transactions: ledgerRows,
        openingBalance: openingBal,
        companyHeader: dmSettings.header,
        startDate: dateRange.start,
        endDate: dateRange.end,
        logoBytes: logoBytes,
      );

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Show PDF preview modal
      await OperonPdfPreviewModal.show(
        context: context,
        pdfBytes: pdfBytes,
        title: 'Ledger of $vendorName',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading if still open
        DashSnackbar.show(context, message: 'Failed to generate ledger PDF: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    for (final tx in transactions) {
      final type = (tx['type'] as String? ?? 'credit').toLowerCase();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
      final isCredit = type == 'credit';
      if (isCredit) {
        totalCredit += amount;
      } else {
        totalDebit += amount;
      }
    }

    if (transactions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ledger',
            style: TextStyle(
              color: AuthColors.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'SF Pro Display',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No transactions found.',
            style: TextStyle(color: AuthColors.textSub, fontSize: 13, fontFamily: 'SF Pro Display'),
          ),
          const SizedBox(height: 20),
          _LedgerSummaryFooter(
            openingBalance: openingBalance,
            totalDebit: 0,
            totalCredit: 0,
            formatCurrency: formatCurrency,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ledger',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
            DashButton(
              label: 'Generate Ledger',
              icon: Icons.picture_as_pdf,
              onPressed: () => _generateLedgerPdf(context),
              variant: DashButtonVariant.text,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              _LedgerTableHeader(),
              Divider(height: 1, color: AuthColors.textMain.withOpacity(0.12)),
              ...transactions.map((tx) {
                final type = tx['type'] as String? ?? 'credit';
                final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final balanceAfter = (tx['balanceAfter'] as num?)?.toDouble() ?? 0.0;
                final date = tx['transactionDate'] ?? tx['createdAt'];
                final invoiceNo = tx['referenceNumber'] as String? ?? tx['metadata']?['invoiceNumber'] as String? ?? '-';
                final category = tx['category'] as String?;
                final desc = (tx['description'] as String?)?.trim();
                final isCredit = type == 'credit';
                final credit = isCredit ? amount : 0.0;
                final debit = !isCredit ? amount : 0.0;

                return _LedgerTableRow(
                  date: date,
                  invoiceNo: invoiceNo,
                  debit: debit,
                  credit: credit,
                  balance: balanceAfter,
                  type: _formatCategoryName(category),
                  remarks: (desc != null && desc.isNotEmpty) ? desc : '-',
                  formatCurrency: formatCurrency,
                  formatDate: formatDate,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
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

class _LedgerTableHeader extends StatelessWidget {
  static const _labelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: _borderedCell('Date')),
        Expanded(flex: 1, child: _borderedCell('Invoice No.')),
        Expanded(flex: 1, child: _borderedCell('Debit')),
        Expanded(flex: 1, child: _borderedCell('Credit')),
        Expanded(flex: 1, child: _borderedCell('Balance')),
        Expanded(flex: 1, child: _borderedCell('Type')),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            alignment: Alignment.center,
            child: Text('Remarks', style: _labelStyle, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _borderedCell(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(border: _cellBorder),
      alignment: Alignment.center,
      child: Text(label, style: _labelStyle, textAlign: TextAlign.center),
    );
  }
}

class _LedgerTableRow extends StatelessWidget {
  const _LedgerTableRow({
    required this.date,
    required this.invoiceNo,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.type,
    required this.remarks,
    required this.formatCurrency,
    required this.formatDate,
  });

  final dynamic date;
  final String invoiceNo;
  final double debit;
  final double credit;
  final double balance;
  final String type;
  final String remarks;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatDate;

  static const _cellStyle = TextStyle(
    color: AuthColors.textMain,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static final _cellBorder = Border(
    right: BorderSide(color: AuthColors.textMain.withOpacity(0.12), width: 1),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 1, child: _cell(Text(formatDate(date), style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(invoiceNo, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(debit > 0 ? formatCurrency(debit) : '-', style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(credit > 0 ? formatCurrency(credit) : '-', style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(formatCurrency(balance), style: _cellStyle.copyWith(color: balance >= 0 ? AuthColors.warning : AuthColors.success, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(flex: 1, child: _cell(Text(type.isEmpty ? '-' : type, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            alignment: Alignment.center,
            child: Text(remarks, style: _cellStyle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Widget _cell(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(border: _cellBorder),
      alignment: Alignment.center,
      child: child,
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

  static const _footerLabelStyle = TextStyle(
    color: AuthColors.textSub,
    fontSize: 13,
    fontFamily: 'SF Pro Display',
  );
  static const _footerValueStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'SF Pro Display',
  );

  @override
  Widget build(BuildContext context) {
    final currentBalance = openingBalance + totalCredit - totalDebit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Opening Balance', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(openingBalance), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Debit', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalDebit), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Credit', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(totalCredit), style: _footerValueStyle.copyWith(color: AuthColors.info), textAlign: TextAlign.center),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Balance', style: _footerLabelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(formatCurrency(currentBalance), style: _footerValueStyle.copyWith(color: AuthColors.success), textAlign: TextAlign.center),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteVendorDialog extends StatelessWidget {
  const _DeleteVendorDialog({required this.vendorName});

  final String vendorName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete vendor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will permanently remove $vendorName and all related data. This action cannot be undone.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Delete vendor',
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DashButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context, false),
                variant: DashButtonVariant.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

