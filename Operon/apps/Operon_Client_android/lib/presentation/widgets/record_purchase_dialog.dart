import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/data/repositories/raw_materials_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white.withOpacity(0.7),
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isTotal ? const Color(0xFF6F4BFF) : Colors.white,
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
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record purchase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF11111B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6F4BFF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Color(0xFF6F4BFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Record Purchase',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Vendor Type Selection (Option Buttons)
                if (_availableTypes.isNotEmpty) ...[
                  const Text(
                    'Vendor Type',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        selectedColor: const Color(0xFF6F4BFF).withOpacity(0.3),
                        checkmarkColor: const Color(0xFF6F4BFF),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Vendor Dropdown
                DropdownButtonFormField<Vendor>(
                  value: _selectedVendor,
                  decoration: _inputDecoration('Vendor'),
                  dropdownColor: const Color(0xFF2B2B3C),
                  style: const TextStyle(color: Colors.white),
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
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
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
                    // Load vehicles if fuel vendor
                    if (vendor != null && vendor.vendorType == VendorType.fuel) {
                      _loadVehicles();
                    } else {
                      setState(() {
                        _vehicles = [];
                        _selectedVehicle = null;
                      });
                    }
                  },
                  validator: (value) => value == null ? 'Please select a vendor' : null,
                ),
                const SizedBox(height: 16),
                
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
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Invoice/Voucher Number (for fuel, this is the voucher number)
                TextFormField(
                  controller: _invoiceNumberController,
                  style: const TextStyle(color: Colors.white),
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
                const SizedBox(height: 16),
                
                // Fuel-specific fields
                if (_selectedVendor != null && _selectedVendor!.vendorType == VendorType.fuel) ...[
                  _isLoadingVehicles
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ))
                      : DropdownButtonFormField<Vehicle>(
                          value: _selectedVehicle,
                          decoration: _inputDecoration('Vehicle'),
                          dropdownColor: const Color(0xFF2B2B3C),
                          style: const TextStyle(color: Colors.white),
                          items: _vehicles.map((vehicle) {
                            return DropdownMenuItem<Vehicle>(
                              value: vehicle,
                              child: Text(
                                vehicle.vehicleNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (vehicle) {
                            setState(() {
                              _selectedVehicle = vehicle;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a vehicle' : null,
                        ),
                  const SizedBox(height: 16),
                ],
                
                // Raw Materials Section (for raw material vendors)
                if (_selectedVendor != null && _selectedVendor!.vendorType == VendorType.rawMaterial) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B3C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Raw Materials Purchased',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingMaterials)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_assignedMaterials.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'No materials assigned to this vendor. Assign materials in vendor settings.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          ..._assignedMaterials.map((material) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1B2C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      material.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _materialQuantityControllers[material.id],
                                            style: const TextStyle(color: Colors.white),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                              hintText: '0',
                                              filled: true,
                                              fillColor: const Color(0xFF0D0D15),
                                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                              suffixText: material.unitOfMeasurement,
                                              suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.white.withOpacity(0.1),
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
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _materialPriceControllers[material.id],
                                            style: const TextStyle(color: Colors.white),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: 'Unit Price',
                                              hintText: '0.00',
                                              filled: true,
                                              fillColor: const Color(0xFF0D0D15),
                                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                              prefixText: '₹',
                                              prefixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Colors.white.withOpacity(0.1),
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
                          }).toList(),
                        if (_assignedMaterials.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Material Totals Breakdown
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1B2C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildBreakdownRow('Materials Subtotal', _calculateMaterialTotals()['subtotal']!),
                                _buildBreakdownRow('GST on Materials', _calculateMaterialTotals()['gst']!),
                                const Divider(color: Colors.white24, height: 16),
                                _buildBreakdownRow('Materials Total', _calculateMaterialTotals()['total']!, isTotal: true),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Additional Charges Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B3C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Additional Charges',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _unloadingChargesController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Unloading Charges',
                                hintText: '0.00',
                                filled: true,
                                fillColor: const Color(0xFF1B1B2C),
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixText: '₹',
                                prefixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
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
                          const SizedBox(width: 12),
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
                                  activeColor: const Color(0xFF6F4BFF),
                                ),
                                Flexible(
                                  child: Text(
                                    'GST',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_unloadingHasGst) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _unloadingGstPercentController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'GST %',
                                  hintText: '18',
                                  filled: true,
                                  fillColor: const Color(0xFF1B1B2C),
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  suffixText: '%',
                                  suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.1),
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
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B2C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _buildBreakdownRow('Charges Subtotal', _calculateChargesTotals()['subtotal']!),
                              if (_unloadingHasGst)
                                _buildBreakdownRow('GST on Charges', _calculateChargesTotals()['gst']!),
                              const Divider(color: Colors.white24, height: 16),
                              _buildBreakdownRow('Charges Total', _calculateChargesTotals()['total']!, isTotal: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Final Breakdown Summary
                if (_selectedVendor != null && 
                    _selectedVendor!.vendorType == VendorType.rawMaterial && 
                    (_assignedMaterials.isNotEmpty || 
                     (double.tryParse(_unloadingChargesController.text.trim()) ?? 0) > 0)) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6F4BFF).withOpacity(0.3),
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
                        const Divider(color: Colors.white24, height: 16),
                        _buildBreakdownRow('Grand Total', _calculateGrandTotal(), isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Amount
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
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
                const SizedBox(height: 16),
                
                // Description (Optional)
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Description (Optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submitPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4BFF),
                        foregroundColor: Colors.white,
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
      fillColor: const Color(0xFF2B2B3C),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF6F4BFF),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}

