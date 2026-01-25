import 'package:core_models/core_models.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_web/presentation/views/fuel_ledger/link_trips_dialog.dart';

class RecordFuelPurchaseDialog extends StatefulWidget {
  final VoidCallback? onPurchaseRecorded;

  const RecordFuelPurchaseDialog({
    super.key,
    this.onPurchaseRecorded,
  });

  @override
  State<RecordFuelPurchaseDialog> createState() => _RecordFuelPurchaseDialogState();
}

class _RecordFuelPurchaseDialogState extends State<RecordFuelPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _voucherNumberController = TextEditingController();
  
  Vendor? _selectedVendor;
  Vehicle? _selectedVehicle;
  DateTime _selectedDate = DateTime.now();
  List<Vendor> _fuelVendors = [];
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _isLoadingVehicles = false;
  bool _linkTripsNow = false;

  @override
  void initState() {
    super.initState();
    _loadFuelVendors();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _voucherNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _loadVehicles() async {
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

  Future<void> _loadFuelVendors() async {
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
          .where((vendor) => vendor.vendorType == VendorType.fuel)
          .toList();

      setState(() {
        _fuelVendors = vendors;
        if (vendors.length == 1) {
          _selectedVendor = vendors.first;
        }
      });
      // Load vehicles when vendors are loaded
      _loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vendors: $e')),
        );
      }
    }
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

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      final vehicleNumber = _selectedVehicle?.vehicleNumber ?? '';
      final voucherNumber = _voucherNumberController.text.trim();
      final financialYear = _getFinancialYear(_selectedDate);

      // Build metadata for fuel purchase
      Map<String, dynamic> metadata = {
        'purchaseType': 'fuel',
        'vehicleNumber': vehicleNumber,
        'voucherNumber': voucherNumber,
        'recordedVia': 'fuel-ledger-page',
        'linkedTrips': <Map<String, dynamic>>[],
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
        referenceNumber: voucherNumber,
        description: 'Fuel purchase - Vehicle: $vehicleNumber',
        metadata: metadata,
      );

      // Save to Firestore
      final transactionsRef = FirebaseFirestore.instance.collection('TRANSACTIONS');
      final transactionJson = transaction.toJson();
      // Add transactionDate field (used by Cloud Functions)
      transactionJson['transactionDate'] = Timestamp.fromDate(_selectedDate);
      final docRef = await transactionsRef.add(transactionJson);
      final transactionId = docRef.id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fuel purchase recorded successfully'),
            backgroundColor: AuthColors.success,
          ),
        );
        
        // If link trips now is checked, show link trips dialog
        if (_linkTripsNow) {
          Navigator.of(context).pop();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => LinkTripsDialog(
                transactionId: transactionId,
                vehicleNumber: vehicleNumber,
                voucherNumber: voucherNumber,
                onTripsLinked: () {
                  widget.onPurchaseRecorded?.call();
                },
              ),
            );
          }
        } else {
          Navigator.of(context).pop();
          widget.onPurchaseRecorded?.call();
        }
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.backgroundAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
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
                      color: AuthColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: AuthColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Record Fuel Purchase',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AuthColors.textSub),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Vendor Dropdown
              DropdownButtonFormField<Vendor>(
                initialValue: _selectedVendor,
                decoration: _inputDecoration('Fuel Vendor'),
                dropdownColor: AuthColors.surface,
                style: TextStyle(color: AuthColors.textMain),
                items: _fuelVendors.map((vendor) {
                  return DropdownMenuItem<Vendor>(
                    value: vendor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vendor.name,
                          style: TextStyle(
                            color: AuthColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AuthColors.textSub,
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
                  });
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
                        style: TextStyle(color: AuthColors.textMain),
                      ),
                      Icon(Icons.calendar_today, color: AuthColors.textSub, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: AuthColors.textMain),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration('Amount'),
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
              
              // Vehicle Dropdown
              _isLoadingVehicles
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ))
                  : DropdownButtonFormField<Vehicle>(
                      initialValue: _selectedVehicle,
                      decoration: _inputDecoration('Vehicle'),
                      dropdownColor: AuthColors.surface,
                      style: TextStyle(color: AuthColors.textMain),
                      items: _vehicles.map((vehicle) {
                        return DropdownMenuItem<Vehicle>(
                          value: vehicle,
                          child: Text(
                            vehicle.vehicleNumber,
                            style: TextStyle(
                              color: AuthColors.textMain,
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
              
              // Voucher Number
              TextFormField(
                controller: _voucherNumberController,
                style: TextStyle(color: AuthColors.textMain),
                decoration: _inputDecoration('Voucher Number'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter voucher number'
                        : null,
              ),
              const SizedBox(height: 16),
              
              // Link Trips Now Checkbox
              CheckboxListTile(
                value: _linkTripsNow,
                onChanged: (value) {
                  setState(() {
                    _linkTripsNow = value ?? false;
                  });
                },
                title: Text(
                  'Link trips now (Optional)',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                ),
                subtitle: Text(
                  'Open trip selection dialog after recording',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                ),
                activeColor: AuthColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuthColors.primary,
                      foregroundColor: AuthColors.textMain,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                            ),
                          )
                        : const Text('Record Purchase'),
                  ),
                ],
              ),
            ],
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
      labelStyle: TextStyle(color: AuthColors.textSub),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMainWithOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.error,
          width: 2,
        ),
      ),
    );
  }
}

