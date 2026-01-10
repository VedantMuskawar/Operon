import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dash_mobile/presentation/views/fuel_ledger/link_trips_dialog.dart';

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
          const SnackBar(
            content: Text('Fuel purchase recorded successfully'),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFF0A0A0A),
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
                        Icons.local_gas_station,
                        color: Color(0xFF6F4BFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Record Fuel Purchase',
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
                
                // Vendor Dropdown
                DropdownButtonFormField<Vendor>(
                  value: _selectedVendor,
                  decoration: _inputDecoration('Fuel Vendor'),
                  dropdownColor: const Color(0xFF2B2B3C),
                  style: const TextStyle(color: Colors.white),
                  items: _fuelVendors.map((vendor) {
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
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Amount
                TextFormField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
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
                
                // Voucher Number
                TextFormField(
                  controller: _voucherNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Voucher Number'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Enter voucher number'
                          : null,
                ),
                const SizedBox(height: 16),
                
                // Link Trips Now Checkbox (Optional)
                CheckboxListTile(
                  value: _linkTripsNow,
                  onChanged: (value) {
                    setState(() {
                      _linkTripsNow = value ?? false;
                    });
                  },
                  title: const Text(
                    'Link trips now (Optional)',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Open trip selection dialog after recording',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF6F4BFF),
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
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitPurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4BFF),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

