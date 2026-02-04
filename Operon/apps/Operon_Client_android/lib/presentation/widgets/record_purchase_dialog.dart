import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/data/repositories/raw_materials_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecordPurchaseDialog extends StatefulWidget {
  const RecordPurchaseDialog({super.key});

  @override
  State<RecordPurchaseDialog> createState() => _RecordPurchaseDialogState();
}

class _RecordPurchaseDialogState extends State<RecordPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  VendorType? _selectedVendorType;
  Vendor? _selectedVendor;
  DateTime _selectedDate = DateTime.now();
  List<Vendor> _filteredVendors = [];
  Map<VendorType, List<Vendor>> _vendorsByType = {};
  List<VendorType> _availableTypes = [];
  
  // Raw materials for raw material vendors
  List<RawMaterial> _assignedMaterials = [];
  final Map<String, TextEditingController> _materialQuantityControllers = {};
  final Map<String, TextEditingController> _materialPriceControllers = {};
  bool _isLoadingMaterials = false;
  
  // Additional charges
  final TextEditingController _unloadingChargesController = TextEditingController();
  final TextEditingController _unloadingGstPercentController = TextEditingController(text: '18');
  bool _unloadingHasGst = true;
  
  // Fuel-specific fields
  Vehicle? _selectedVehicle;
  List<Vehicle> _vehicles = [];
  bool _isLoadingVehicles = false;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _unloadingChargesController.dispose();
    _unloadingGstPercentController.dispose();
    for (final controller in _materialQuantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _materialPriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _loadVehicles() async {
    if (_selectedVendor == null || _selectedVendor!.vendorType != VendorType.fuel) {
      setState(() {
        _vehicles = [];
        _selectedVehicle = null;
        _isLoadingVehicles = false;
      });
      return;
    }
    
    setState(() => _isLoadingVehicles = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return;
      
      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      final activeVehicles = allVehicles.where((v) => v.isActive).toList();
      
      setState(() {
        _vehicles = activeVehicles;
        _isLoadingVehicles = false;
      });
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vehicles: $e')),
        );
      }
    }
  }
  
  Future<void> _loadAssignedMaterials() async {
    if (_selectedVendor == null || _selectedVendor!.vendorType != VendorType.rawMaterial) {
      setState(() {
        _assignedMaterials = [];
        _isLoadingMaterials = false;
      });
      return;
    }
    
    setState(() => _isLoadingMaterials = true);
    try {
      final orgState = context.read<OrganizationContextCubit>().state;
      final organization = orgState.organization;
      if (organization == null) return;
      
      final assignedIds = _selectedVendor!.rawMaterialDetails?.assignedMaterialIds ?? [];
      if (assignedIds.isEmpty) {
        setState(() {
          _assignedMaterials = [];
          _isLoadingMaterials = false;
        });
        return;
      }
      
      final repository = RawMaterialsRepository(
        dataSource: RawMaterialsDataSource(),
      );
      final allMaterials = await repository.fetchRawMaterials(organization.id);
      final materials = allMaterials.where((m) => assignedIds.contains(m.id)).toList();
      
      // Initialize controllers for each material
      for (final material in materials) {
        if (!_materialQuantityControllers.containsKey(material.id)) {
          _materialQuantityControllers[material.id] = TextEditingController();
        }
        if (!_materialPriceControllers.containsKey(material.id)) {
          _materialPriceControllers[material.id] = TextEditingController(
            text: material.purchasePrice.toStringAsFixed(2),
          );
        }
      }
      
      setState(() {
        _assignedMaterials = materials;
        _isLoadingMaterials = false;
      });
    } catch (e) {
      setState(() => _isLoadingMaterials = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load materials: $e')),
        );
      }
    }
  }
  
  // Calculate material totals with GST
  Map<String, double> _calculateMaterialTotals() {
    double materialsSubtotal = 0;
    double materialsGst = 0;
    
    for (final material in _assignedMaterials) {
      final quantityText = _materialQuantityControllers[material.id]?.text.trim() ?? '0';
      final priceText = _materialPriceControllers[material.id]?.text.trim() ?? '0';
      final quantity = double.tryParse(quantityText) ?? 0;
      final price = double.tryParse(priceText) ?? 0;
      final materialSubtotal = quantity * price;
      materialsSubtotal += materialSubtotal;
      
      // Calculate GST for this material
      if (material.hasGst && material.gstPercent != null) {
        final gstAmount = materialSubtotal * (material.gstPercent! / 100);
        materialsGst += gstAmount;
      }
    }
    
    return {
      'subtotal': materialsSubtotal,
      'gst': materialsGst,
      'total': materialsSubtotal + materialsGst,
    };
  }
  
  // Calculate additional charges totals with GST
  Map<String, double> _calculateChargesTotals() {
    final unloadingAmount = double.tryParse(_unloadingChargesController.text.trim()) ?? 0;
    double chargesGst = 0;
    
    if (unloadingAmount > 0 && _unloadingHasGst) {
      final gstPercent = double.tryParse(_unloadingGstPercentController.text.trim()) ?? 18;
      chargesGst = unloadingAmount * (gstPercent / 100);
    }
    
    return {
      'subtotal': unloadingAmount,
      'gst': chargesGst,
      'total': unloadingAmount + chargesGst,
    };
  }
  
  // Calculate grand total
  double _calculateGrandTotal() {
    final materialTotals = _calculateMaterialTotals();
    final chargesTotals = _calculateChargesTotals();
    return materialTotals['total']! + chargesTotals['total']!;
  }
  
  // Update amount controller when values change
  void _updateTotalAmount() {
    final total = _calculateGrandTotal();
    _amountController.text = total.toStringAsFixed(2);
  }
  
  // Build breakdown row widget
  Widget _buildBreakdownRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AuthColors.textMain : AuthColors.textMainWithOpacity(0.7),
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isTotal ? AuthColors.legacyAccent : AuthColors.textMain,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              fontSize: isTotal ? 16 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVendors() async {
    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return;

    try {
      final vendorsSnapshot = await FirebaseFirestore.instance
          .collection('VENDORS')
          .where('organizationId', isEqualTo: organization.id)
          .where('status', isEqualTo: 'active')
          .get();

      final vendors = vendorsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            data['vendorId'] = doc.id;
            return Vendor.fromJson(data, doc.id);
          })
          .toList();

      // Group vendors by type
      final vendorsByType = <VendorType, List<Vendor>>{};
      for (final vendor in vendors) {
        if (!vendorsByType.containsKey(vendor.vendorType)) {
          vendorsByType[vendor.vendorType] = [];
        }
        vendorsByType[vendor.vendorType]!.add(vendor);
      }

      // Get available types (only types that have vendors)
      final availableTypes = vendorsByType.keys.toList();

      setState(() {
        _vendorsByType = vendorsByType;
        _availableTypes = availableTypes;
        
        // Auto-select first type if only one exists
        if (_availableTypes.length == 1) {
          _selectedVendorType = _availableTypes.first;
          _filteredVendors = _vendorsByType[_selectedVendorType] ?? [];
        } else if (_availableTypes.isNotEmpty) {
          // Select first type by default
          _selectedVendorType = _availableTypes.first;
          _filteredVendors = _vendorsByType[_selectedVendorType] ?? [];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vendors: $e')),
        );
      }
    }
  }

  void _onVendorTypeSelected(VendorType? type) {
    setState(() {
      _selectedVendorType = type;
      _selectedVendor = null; // Reset vendor selection
      _filteredVendors = type != null ? (_vendorsByType[type] ?? []) : [];
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatVendorType(VendorType type) {
    return type.name
        .split(RegExp(r'(?=[A-Z])'))
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  String _getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    // Financial year starts in April (month 4)
    if (month >= 4) {
      final startYear = year % 100;
      final endYear = (year + 1) % 100;
      return 'FY$startYear$endYear';
    } else {
      final startYear = (year - 1) % 100;
      final endYear = year % 100;
      return 'FY$startYear$endYear';
    }
  }

  Future<void> _submitPurchase() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor')),
      );
      return;
    }
    if (_selectedVendor!.vendorType == VendorType.fuel && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (organization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization not found')),
      );
      return;
    }
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text.trim());
      final invoiceNumber = _invoiceNumberController.text.trim();
      final description = _descriptionController.text.trim();
      final financialYear = _getFinancialYear(_selectedDate);

      // Build detailed metadata with breakdown
      final materialTotals = _calculateMaterialTotals();
      final chargesTotals = _calculateChargesTotals();
      
      Map<String, dynamic> metadata = {
        'invoiceNumber': invoiceNumber,
        'recordedVia': 'purchase-page',
      };
      
      // Add fuel-specific metadata
      if (_selectedVendor!.vendorType == VendorType.fuel) {
        metadata['purchaseType'] = 'fuel';
        metadata['vehicleNumber'] = _selectedVehicle?.vehicleNumber ?? '';
        metadata['voucherNumber'] = invoiceNumber; // Use invoice/voucher number as voucher number
        metadata['linkedTrips'] = <Map<String, dynamic>>[];
      }
      
      // Add raw materials with GST breakdown
      if (_selectedVendor!.vendorType == VendorType.rawMaterial && _assignedMaterials.isNotEmpty) {
        final rawMaterials = <Map<String, dynamic>>[];
        for (final material in _assignedMaterials) {
          final quantityText = _materialQuantityControllers[material.id]?.text.trim() ?? '0';
          final priceText = _materialPriceControllers[material.id]?.text.trim() ?? '0';
          final quantity = double.tryParse(quantityText) ?? 0;
          final price = double.tryParse(priceText) ?? 0;
          
          if (quantity > 0) {
            final materialSubtotal = quantity * price;
            final materialGst = material.hasGst && material.gstPercent != null
                ? materialSubtotal * (material.gstPercent! / 100)
                : 0.0;
            
            rawMaterials.add({
              'materialId': material.id,
              'materialName': material.name,
              'quantity': quantity,
              'unitPrice': price,
              'unitOfMeasurement': material.unitOfMeasurement,
              'subtotal': materialSubtotal,
              'gstPercent': material.hasGst ? material.gstPercent : null,
              'gstAmount': materialGst,
              'total': materialSubtotal + materialGst,
            });
          }
        }
        if (rawMaterials.isNotEmpty) {
          metadata['rawMaterials'] = rawMaterials;
        }
      }
      
      // Add additional charges
      final unloadingAmount = double.tryParse(_unloadingChargesController.text.trim()) ?? 0;
      if (unloadingAmount > 0) {
        final additionalCharges = <Map<String, dynamic>>[];
        final unloadingGst = _unloadingHasGst
            ? unloadingAmount * ((double.tryParse(_unloadingGstPercentController.text.trim()) ?? 18) / 100)
            : 0.0;
        
        additionalCharges.add({
          'type': 'unloading',
          'amount': unloadingAmount,
          'hasGst': _unloadingHasGst,
          'gstPercent': _unloadingHasGst ? (double.tryParse(_unloadingGstPercentController.text.trim()) ?? 18) : null,
          'gstAmount': unloadingGst,
          'total': unloadingAmount + unloadingGst,
        });
        
        metadata['additionalCharges'] = additionalCharges;
      }
      
      // Add totals breakdown
      metadata['totals'] = {
        'materialsSubtotal': materialTotals['subtotal']!,
        'materialsGst': materialTotals['gst']!,
        'materialsTotal': materialTotals['total']!,
        'chargesSubtotal': chargesTotals['subtotal']!,
        'chargesGst': chargesTotals['gst']!,
        'chargesTotal': chargesTotals['total']!,
        'grandTotal': amount,
      };

      // Create transaction
      final transaction = Transaction(
        id: '', // Will be auto-generated
        organizationId: organization.id,
        clientId: '', // Not used for vendor transactions
        vendorId: _selectedVendor!.id,
        ledgerType: LedgerType.vendorLedger,
        type: TransactionType.credit, // Credit = purchase (we owe vendor)
        category: TransactionCategory.vendorPurchase,
        amount: amount,
        createdBy: currentUser.uid,
        createdAt: _selectedDate,
        updatedAt: _selectedDate,
        financialYear: financialYear,
        referenceNumber: invoiceNumber,
        description: description.isNotEmpty ? description : null,
        metadata: metadata,
      );

      // Save to Firestore
      final transactionsRef = FirebaseFirestore.instance.collection('TRANSACTIONS');
      final transactionJson = transaction.toJson();
      // Add transactionDate field (used by Cloud Functions)
      transactionJson['transactionDate'] = Timestamp.fromDate(_selectedDate);
      await transactionsRef.add(transactionJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase recorded successfully'),
            backgroundColor: AuthColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record purchase: $e'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingXXL),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.paddingSM),
                      decoration: BoxDecoration(
                        color: AuthColors.legacyAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: AuthColors.legacyAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingMD),
                    const Expanded(
                      child: Text(
                        'Record Purchase',
                        style: TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AuthColors.textSub),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.paddingXXL),
                
                // Vendor Type Selection (Option Buttons)
                if (_availableTypes.isNotEmpty) ...[
                  const Text(
                    'Vendor Type',
                    style: TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingSM),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTypes.map((type) {
                      final isSelected = _selectedVendorType == type;
                      return FilterChip(
                        label: Text(_formatVendorType(type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          _onVendorTypeSelected(selected ? type : null);
                        },
                        selectedColor: AuthColors.legacyAccent.withOpacity(0.3),
                        checkmarkColor: AuthColors.legacyAccent,
                        labelStyle: TextStyle(
                          color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.paddingXXL),
                ],
                
                // Vendor Dropdown
                DropdownButtonFormField<Vendor>(
                  initialValue: _selectedVendor,
                  decoration: _inputDecoration('Vendor'),
                  dropdownColor: AuthColors.surface,
                  style: const TextStyle(color: AuthColors.textMain),
                  items: _filteredVendors.map((vendor) {
                    return DropdownMenuItem<Vendor>(
                      value: vendor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vendor.name,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AuthColors.textMain.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (vendor) {
                    setState(() {
                      _selectedVendor = vendor;
                      _selectedVehicle = null; // Reset vehicle selection
                    });
                    // Load assigned materials if raw material vendor
                    if (vendor != null && vendor.vendorType == VendorType.rawMaterial) {
                      _loadAssignedMaterials();
                    } else {
                      setState(() {
                        _assignedMaterials = [];
                      });
                    }
                    // Load vehicles if fuel vendor; clear additional charges (not used for fuel)
                    if (vendor != null && vendor.vendorType == VendorType.fuel) {
                      _loadVehicles();
                      _unloadingChargesController.clear();
                      _updateTotalAmount();
                    } else {
                      setState(() {
                        _vehicles = [];
                        _selectedVehicle = null;
                      });
                    }
                  },
                  validator: (value) => value == null ? 'Please select a vendor' : null,
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                
                // Date
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: _inputDecoration('Date'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(color: AuthColors.textMain),
                        ),
                        const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                
                // Invoice/Voucher Number (for fuel, this is the voucher number)
                TextFormField(
                  controller: _invoiceNumberController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration(
                    _selectedVendor != null && _selectedVendor!.vendorType == VendorType.fuel
                        ? 'Voucher Number'
                        : 'Invoice/Voucher Number'
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter ${_selectedVendor != null && _selectedVendor!.vendorType == VendorType.fuel ? "voucher" : "invoice/voucher"} number'
                          : null,
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                
                // Fuel-specific fields (vehicle option buttons)
                if (_selectedVendor != null && _selectedVendor!.vendorType == VendorType.fuel) ...[
                  _isLoadingVehicles
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(AppSpacing.paddingLG),
                          child: CircularProgressIndicator(),
                        ))
                      : InputDecorator(
                          decoration: _inputDecoration('Vehicle'),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _vehicles.map((vehicle) {
                              final isSelected = _selectedVehicle?.id == vehicle.id;
                              return FilterChip(
                                label: Text(
                                  vehicle.vehicleNumber,
                                  style: TextStyle(
                                    color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedVehicle = isSelected ? null : vehicle;
                                  });
                                },
                                selectedColor: AuthColors.primary,
                                checkmarkColor: AuthColors.textMain,
                                side: BorderSide(
                                  color: isSelected ? AuthColors.primary : AuthColors.textMain.withOpacity(0.3),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.paddingLG),
                ],
                
                // Raw Materials Section (for raw material vendors)
                if (_selectedVendor != null && _selectedVendor!.vendorType == VendorType.rawMaterial) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingLG),
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                        color: AuthColors.textMain.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: AuthColors.textSub,
                              size: 20,
                            ),
                            SizedBox(width: AppSpacing.paddingSM),
                            Text(
                              'Raw Materials Purchased',
                              style: TextStyle(
                                color: AuthColors.textMain,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.paddingMD),
                        if (_isLoadingMaterials)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.paddingLG),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_assignedMaterials.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.paddingSM),
                            child: Text(
                              'No materials assigned to this vendor. Assign materials in vendor settings.',
                              style: TextStyle(
                                color: AuthColors.textMain.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ..._assignedMaterials.map((material) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.paddingMD),
                                decoration: BoxDecoration(
                                  color: AuthColors.surface,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      material.name,
                                      style: const TextStyle(
                                        color: AuthColors.textMain,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.paddingSM),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _materialQuantityControllers[material.id],
                                            style: const TextStyle(color: AuthColors.textMain),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                              hintText: '0',
                                              filled: true,
                                              fillColor: AuthColors.backgroundAlt,
                                              labelStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
                                              suffixText: material.unitOfMeasurement,
                                              suffixStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.5)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                                borderSide: BorderSide(
                                                  color: AuthColors.textMain.withOpacity(0.1),
                                                ),
                                              ),
                                            ),
                                            onChanged: (_) {
                                              setState(() {
                                                _updateTotalAmount();
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.paddingMD),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _materialPriceControllers[material.id],
                                            style: const TextStyle(color: AuthColors.textMain),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Unit Price',
                                              hintText: '0.00',
                                              filled: true,
                                              fillColor: AuthColors.backgroundAlt,
                                              labelStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
                                              prefixText: '₹',
                                              prefixStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.5)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                                borderSide: BorderSide(
                                                  color: AuthColors.textMain.withOpacity(0.1),
                                                ),
                                              ),
                                            ),
                                            onChanged: (_) {
                                              setState(() {
                                                _updateTotalAmount();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if (_assignedMaterials.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.paddingSM),
                          // Material Totals Breakdown
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.paddingMD),
                            decoration: BoxDecoration(
                              color: AuthColors.surface,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                            ),
                            child: Column(
                              children: [
                                _buildBreakdownRow('Materials Subtotal', _calculateMaterialTotals()['subtotal']!),
                                _buildBreakdownRow('GST on Materials', _calculateMaterialTotals()['gst']!),
                                Divider(color: AuthColors.textMainWithOpacity(0.24), height: 16),
                                _buildBreakdownRow('Materials Total', _calculateMaterialTotals()['total']!, isTotal: true),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                ],
                
                // Additional Charges Section (hidden for fuel vendors)
                if (_selectedVendor == null || _selectedVendor!.vendorType != VendorType.fuel) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.paddingLG),
                  decoration: BoxDecoration(
                    color: AuthColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                    border: Border.all(
                      color: AuthColors.textMain.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: AuthColors.textSub,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.paddingSM),
                          Text(
                            'Additional Charges',
                            style: TextStyle(
                              color: AuthColors.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.paddingMD),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _unloadingChargesController,
                              style: const TextStyle(color: AuthColors.textMain),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Unloading Charges',
                                hintText: '0.00',
                                filled: true,
                                fillColor: AuthColors.surface,
                                labelStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
                                prefixText: '₹',
                                prefixStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                  borderSide: BorderSide(
                                    color: AuthColors.textMain.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _updateTotalAmount();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.paddingMD),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _unloadingHasGst,
                                  onChanged: (value) {
                                    setState(() {
                                      _unloadingHasGst = value ?? true;
                                      _updateTotalAmount();
                                    });
                                  },
                                  activeColor: AuthColors.primary,
                                ),
                                const Flexible(
                                  child: Text(
                                    'GST',
                                    style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_unloadingHasGst) ...[
                            const SizedBox(width: AppSpacing.paddingSM),
                            Expanded(
                              child: TextFormField(
                                controller: _unloadingGstPercentController,
                                style: const TextStyle(color: AuthColors.textMain),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'GST %',
                                  hintText: '18',
                                  filled: true,
                                  fillColor: AuthColors.surface,
                                  labelStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
                                  suffixText: '%',
                                  suffixStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.5)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                    borderSide: BorderSide(
                                      color: AuthColors.textMain.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    _updateTotalAmount();
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                      if ((double.tryParse(_unloadingChargesController.text.trim()) ?? 0) > 0) ...[
                        const SizedBox(height: AppSpacing.paddingSM),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.paddingMD),
                          decoration: BoxDecoration(
                            color: AuthColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          ),
                          child: Column(
                            children: [
                              _buildBreakdownRow('Charges Subtotal', _calculateChargesTotals()['subtotal']!),
                              if (_unloadingHasGst)
                                _buildBreakdownRow('GST on Charges', _calculateChargesTotals()['gst']!),
                              Divider(color: AuthColors.textMainWithOpacity(0.24), height: 16),
                              _buildBreakdownRow('Charges Total', _calculateChargesTotals()['total']!, isTotal: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                ],
                
                // Final Breakdown Summary
                if (_selectedVendor != null && 
                    _selectedVendor!.vendorType == VendorType.rawMaterial && 
                    (_assignedMaterials.isNotEmpty || 
                     (double.tryParse(_unloadingChargesController.text.trim()) ?? 0) > 0)) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.paddingLG),
                    decoration: BoxDecoration(
                      color: AuthColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      border: Border.all(
                        color: AuthColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_assignedMaterials.isNotEmpty) ...[
                          _buildBreakdownRow('Materials Total', _calculateMaterialTotals()['total']!),
                        ],
                        if ((double.tryParse(_unloadingChargesController.text.trim()) ?? 0) > 0) ...[
                          _buildBreakdownRow('Charges Total', _calculateChargesTotals()['total']!),
                        ],
                        Divider(color: AuthColors.textMainWithOpacity(0.24), height: 16),
                        _buildBreakdownRow('Grand Total', _calculateGrandTotal(), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingLG),
                ],
                
                // Amount
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(color: AuthColors.textMain),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Total Amount'),
                  readOnly: _selectedVendor != null && 
                           _selectedVendor!.vendorType == VendorType.rawMaterial && 
                           (_assignedMaterials.isNotEmpty || 
                            (double.tryParse(_unloadingChargesController.text.trim()) ?? 0) > 0),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter amount';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Enter valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.paddingLG),
                
                // Description (Optional)
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: _inputDecoration('Description (Optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.paddingXXL),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingMD),
                    ElevatedButton(
                      onPressed: _submitPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuthColors.primary,
                        foregroundColor: AuthColors.textMain,
                      ),
                      child: const Text('Record Purchase'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AuthColors.surface,
      labelStyle: TextStyle(color: AuthColors.textMain.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: BorderSide(
          color: AuthColors.textMain.withOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}

