import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart' show AuthColors, DashButton, DashButtonVariant, DashDialogHeader, DashSnackbar;
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
        DashSnackbar.show(context, message: 'Failed to load vehicles: $e', isError: true);
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
          .where('vendorType', isEqualTo: 'fuel')
          .get();

      final vendors = vendorsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            data['vendorId'] = doc.id;
            return Vendor.fromJson(data, doc.id);
          })
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
        DashSnackbar.show(context, message: 'Failed to load vendors: $e', isError: true);
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
      DashSnackbar.show(context, message: 'Please select a vendor', isError: true);
      return;
    }

    final orgState = context.read<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (organization == null) {
      DashSnackbar.show(context, message: 'Organization not found', isError: true);
      return;
    }
    
    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not authenticated', isError: true);
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
        'vendorName': _selectedVendor!.name,
        'recordedVia': 'fuel-ledger-page',
        'linkedTrips': <Map<String, dynamic>>[],
      };

      // Create transaction
      final transaction = Transaction(
        id: '', // Will be auto-generated
        organizationId: organization.id,
        clientId: '', // Not used for vendor transactions
        vendorId: _selectedVendor!.id,
        vendorName: _selectedVendor!.name,
        ledgerType: LedgerType.vendorLedger,
        type: TransactionType.credit, // Credit = purchase (we owe vendor)
        category: TransactionCategory.vendorPurchase,
        amount: amount,
        createdBy: currentUser.uid,
        transactionDate: _selectedDate,
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
      final docRef = await transactionsRef.add(transactionJson);
      final transactionId = docRef.id;

      if (mounted) {
        DashSnackbar.show(context, message: 'Fuel purchase recorded successfully', isError: false);
        
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
        DashSnackbar.show(context, message: 'Failed to record purchase: $e', isError: true);
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
              DashDialogHeader(
                title: 'Record Fuel Purchase',
                icon: Icons.local_gas_station,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),
              
              // Vendor Dropdown
              DropdownButtonFormField<Vendor>(
                initialValue: _selectedVendor,
                decoration: _inputDecoration('Fuel Vendor'),
                dropdownColor: AuthColors.surface,
                style: const TextStyle(color: AuthColors.textMain),
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
                            color: AuthColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
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
                        style: const TextStyle(color: AuthColors.textMain),
                      ),
                      const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                style: const TextStyle(color: AuthColors.textMain),
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
                      style: const TextStyle(color: AuthColors.textMain),
                      items: _vehicles.map((vehicle) {
                        return DropdownMenuItem<Vehicle>(
                          value: vehicle,
                          child: Text(
                            vehicle.vehicleNumber,
                            style: const TextStyle(
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
                style: const TextStyle(color: AuthColors.textMain),
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
                title: const Text(
                  'Link trips now (Optional)',
                  style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                ),
                subtitle: const Text(
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
                  DashButton(
                    label: 'Cancel',
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.text,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Record Purchase',
                    onPressed: _submitPurchase,
                    isLoading: _isLoading,
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
      labelStyle: const TextStyle(color: AuthColors.textSub),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AuthColors.textMainWithOpacity(0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AuthColors.error,
          width: 2,
        ),
      ),
    );
  }
}

