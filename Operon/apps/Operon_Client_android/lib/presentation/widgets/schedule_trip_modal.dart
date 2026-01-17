import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/utils/network_error_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScheduleTripModal extends StatefulWidget {
  const ScheduleTripModal({
    super.key,
    required this.order,
    required this.clientId,
    required this.clientName,
    required this.clientPhones,
    required this.onScheduled,
  });

  final Map<String, dynamic> order;
  final String clientId;
  final String clientName;
  final List<Map<String, dynamic>> clientPhones;
  final VoidCallback onScheduled;

  @override
  State<ScheduleTripModal> createState() => _ScheduleTripModalState();
}

class _ScheduleTripModalState extends State<ScheduleTripModal> {
  String? _selectedPhoneNumber;
  String _paymentType = 'pay_later';
  DateTime? _selectedDate;
  Vehicle? _selectedVehicle;
  int? _selectedSlot;
  bool _isAddingNewPhone = false;
  final TextEditingController _newPhoneController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingVehicles = false;
  bool _isLoadingSlots = false;
  String? _vehiclesError;
  String? _slotsError;
  List<Vehicle> _eligibleVehicles = [];
  List<int> _availableSlots = [];
  Map<int, bool> _slotBookedStatus = {};
  Timer? _slotLoadDebounce;
  String? _lastSlotLoadKey; // Cache key for slot data

  @override
  void initState() {
    super.initState();
    // Set default phone to primary if available
    if (widget.clientPhones.isNotEmpty) {
      _selectedPhoneNumber = widget.clientPhones.first['number'] as String?;
    }
    _loadEligibleVehicles();
  }

  @override
  void dispose() {
    _newPhoneController.dispose();
    _slotLoadDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadEligibleVehicles() async {
    if (!mounted) return;
    setState(() {
      _isLoadingVehicles = true;
      _vehiclesError = null;
    });
    try {
      final orgContext = context.read<OrganizationContextCubit>();
      final organization = orgContext.state.organization;
      if (organization == null) {
        if (mounted) {
          setState(() {
            _isLoadingVehicles = false;
            _vehiclesError = 'Organization not selected';
          });
        }
        return;
      }

      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      
      // Show all active vehicles (ignore product matching)
      final eligible = allVehicles.where((v) => v.isActive).toList();

      if (!mounted) return;
      setState(() {
        _eligibleVehicles = eligible;
        _isLoadingVehicles = false;
        _vehiclesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMessage = NetworkErrorHelper.isNetworkError(e)
          ? NetworkErrorHelper.getNetworkErrorMessage(e)
          : 'Failed to load vehicles: $e';
      setState(() {
        _isLoadingVehicles = false;
        _vehiclesError = errorMessage;
      });
    }
  }

  Future<void> _loadAvailableSlots({bool immediate = false}) async {
    if (_selectedVehicle == null || _selectedDate == null) return;

    // Create cache key
    final cacheKey = '${_selectedVehicle!.id}_${_selectedDate!.toIso8601String()}';
    
    // Check if we already have this data cached
    if (_lastSlotLoadKey == cacheKey && _availableSlots.isNotEmpty) {
      return; // Use cached data
    }

    // Debounce slot loading to prevent excessive API calls
    if (!immediate) {
      _slotLoadDebounce?.cancel();
      _slotLoadDebounce = Timer(const Duration(milliseconds: 300), () {
        _loadAvailableSlots(immediate: true);
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
    });
    
    try {
      final orgContext = context.read<OrganizationContextCubit>();
      final organization = orgContext.state.organization;
      if (organization == null) return;

      final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
      
      // Get day name
      final dayName = _getDayName(_selectedDate!);
      
      // Get vehicle capacity for this day
      final weeklyCapacity = _selectedVehicle!.weeklyCapacity;
      
      // Check if weeklyCapacity exists and has the day
      if (weeklyCapacity == null || weeklyCapacity.isEmpty) {
        setState(() {
          _availableSlots = [];
          _slotBookedStatus = {};
          _selectedSlot = null;
          _isLoadingSlots = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle has no weekly capacity configured'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!weeklyCapacity.containsKey(dayName)) {
        setState(() {
          _availableSlots = [];
          _slotBookedStatus = {};
          _selectedSlot = null;
          _isLoadingSlots = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No capacity configured for $dayName'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final dayCapacityValue = weeklyCapacity[dayName];
      final dayCapacity = dayCapacityValue?.toInt() ?? 0;

      if (dayCapacity <= 0) {
        setState(() {
          _availableSlots = [];
          _slotBookedStatus = {};
          _selectedSlot = null;
          _isLoadingSlots = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No slots available for $dayName (capacity: 0)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Get already scheduled trips for this day and vehicle
      final scheduledTrips = await scheduledTripsRepo.getScheduledTripsForDayAndVehicle(
        organizationId: organization.id,
        scheduledDay: dayName,
        scheduledDate: _selectedDate!,
        vehicleId: _selectedVehicle!.id,
      );

      // Get booked slots
      final bookedSlots = scheduledTrips
          .map((trip) => trip['slot'] as int?)
          .where((slot) => slot != null)
          .toList();

      // Generate available slots (1 to dayCapacity)
      final allSlots = List.generate(dayCapacity, (index) => index + 1);
      final availableSlots = allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
      final slotBookedStatus = Map.fromEntries(
        allSlots.map((slot) => MapEntry(slot, bookedSlots.contains(slot))),
      );

      if (!mounted) return;
      setState(() {
        _availableSlots = availableSlots;
        _slotBookedStatus = slotBookedStatus;
        _selectedSlot = null; // Reset selection
        _isLoadingSlots = false;
        _slotsError = null;
        _lastSlotLoadKey = cacheKey; // Cache the result
      });
    } catch (e) {
      if (!mounted) return;
      final errorMessage = NetworkErrorHelper.isNetworkError(e)
          ? NetworkErrorHelper.getNetworkErrorMessage(e)
          : 'Failed to load slots: $e';
      setState(() {
        _isLoadingSlots = false;
        _slotsError = errorMessage;
      });
    }
  }

  String _getDayName(DateTime date) {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year} (${weekdays[date.weekday - 1]})';
  }

  Future<void> _scheduleTrip() async {
    // Validation
    if (_selectedPhoneNumber == null || _selectedPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a contact number')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a slot')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orgContext = context.read<OrganizationContextCubit>();
      final organization = orgContext.state.organization;
      if (organization == null) {
        throw Exception('Organization not selected');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if new phone number needs to be added
      final phoneExists = widget.clientPhones.any(
      (phone) =>
          (phone['e164'] == _selectedPhoneNumber) ||
          (phone['number'] == _selectedPhoneNumber),
      );

      if (!phoneExists && _isAddingNewPhone) {
        // Add new phone to client
        final clientService = ClientService();
        await clientService.addContactToExistingClient(
          clientId: widget.clientId,
          contactName: widget.clientName,
          phoneNumber: _selectedPhoneNumber!,
        );
      }

      // Get day name
      final dayName = _getDayName(_selectedDate!);

      // Get order items to determine itemIndex and productId
      // For now, default to first item (itemIndex 0) for backward compatibility
      // TODO: Add UI to select which item/product to schedule for multi-product orders
      final orderItems = widget.order['items'] as List<dynamic>? ?? [];
      final itemIndex = 0; // Default to first item
      String? productId;
      if (orderItems.isNotEmpty && itemIndex < orderItems.length) {
        final item = orderItems[itemIndex];
        if (item is Map<String, dynamic>) {
          productId = item['productId'] as String?;
        }
      }

      // Create scheduled trip
      final scheduledTripsRepo = context.read<ScheduledTripsRepository>();
      await scheduledTripsRepo.createScheduledTrip(
        organizationId: organization.id,
        orderId: widget.order['id'] as String,
        clientId: widget.clientId,
        clientName: widget.clientName,
        customerNumber: _selectedPhoneNumber!,
        clientPhone: _selectedPhoneNumber!,
        paymentType: _paymentType,
        scheduledDate: _selectedDate!,
        scheduledDay: dayName,
        vehicleId: _selectedVehicle!.id,
        vehicleNumber: _selectedVehicle!.vehicleNumber,
        driverId: _selectedVehicle!.driver?.id,
        driverName: _selectedVehicle!.driver?.name,
        driverPhone: _selectedVehicle!.driver?.phone,
        slot: _selectedSlot!,
        slotName: 'Slot $_selectedSlot',
        deliveryZone: widget.order['deliveryZone'] as Map<String, dynamic>? ?? {},
        items: orderItems,
        // ❌ REMOVED: pricing snapshot (redundant)
        // ❌ REMOVED: includeGstInTotal (not needed with conditional GST storage)
        priority: widget.order['priority'] as String? ?? 'normal',
        createdBy: currentUser.uid,
        itemIndex: itemIndex, // ✅ Pass itemIndex
        productId: productId, // ✅ Pass productId
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AuthColors.textMain, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trip scheduled successfully',
                    style: TextStyle(color: AuthColors.textMain),
                  ),
                ),
              ],
            ),
            backgroundColor: AuthColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = NetworkErrorHelper.isNetworkError(e)
            ? NetworkErrorHelper.getNetworkErrorMessage(e)
            : 'Failed to schedule trip: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AuthColors.textMain, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: AuthColors.textMain),
                  ),
                ),
              ],
            ),
            backgroundColor: AuthColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: AuthColors.textMain,
              onPressed: _scheduleTrip,
            ),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Schedule Trip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AuthColors.textSub, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(color: AuthColors.textMainWithOpacity(0.1), height: 1),
            // Compact Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactNumberSection(),
                    const SizedBox(height: 16),
                    _buildPaymentTypeSection(),
                    const SizedBox(height: 16),
                    _buildDatePickerSection(),
                    const SizedBox(height: 16),
                    _buildVehicleSelectionSection(),
                    if (_selectedVehicle != null && _selectedDate != null) ...[
                      const SizedBox(height: 16),
                      _buildSlotSelectionSection(),
                    ],
                  ],
                ),
              ),
            ),
            // Compact Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                    Expanded(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(0, 48), // Minimum touch target
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _scheduleTrip();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuthColors.legacyAccent,
                        disabledBackgroundColor: AuthColors.legacyAccent.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                              ),
                            )
                          : const Text(
                              'Schedule',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AuthColors.textMain,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactNumberSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!_isAddingNewPhone) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedPhoneNumber,
            decoration: InputDecoration(
              filled: true,
              fillColor: AuthColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AuthColors.legacyAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: AuthColors.surface,
            style: const TextStyle(color: AuthColors.textMain),
            items: [
              ...widget.clientPhones.map((phone) {
              final number = (phone['e164'] as String?) ??
                  (phone['number'] as String?) ??
                  '';
                return DropdownMenuItem(
                  value: number,
                  child: Text(number),
                );
              }),
              const DropdownMenuItem(
                value: '__add_new__',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: AuthColors.legacyAccent),
                    SizedBox(width: 8),
                    Text('Add New Number'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              HapticFeedback.selectionClick();
              if (value == '__add_new__') {
                setState(() {
                  _isAddingNewPhone = true;
                  _selectedPhoneNumber = null;
                });
              } else {
                setState(() => _selectedPhoneNumber = value);
              }
            },
          ),
        ] else ...[
          TextField(
            controller: _newPhoneController,
            style: const TextStyle(color: AuthColors.textMain),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: const TextStyle(color: AuthColors.textSub),
              filled: true,
              fillColor: AuthColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AuthColors.legacyAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.add_call, color: AuthColors.textSub, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: AuthColors.textSub, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isAddingNewPhone = false;
                    _newPhoneController.clear();
                    if (widget.clientPhones.isNotEmpty) {
                      _selectedPhoneNumber =
                          (widget.clientPhones.first['e164'] as String?) ??
                              (widget.clientPhones.first['number'] as String?);
                    }
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            onChanged: (value) {
              setState(() => _selectedPhoneNumber = value.trim());
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPaymentTypeOption('Pay Later', 'pay_later', Icons.schedule_outlined),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentTypeOption('Pay on Delivery', 'pay_on_delivery', Icons.local_shipping_outlined),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentTypeOption(String label, String value, IconData icon) {
    final isSelected = _paymentType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _paymentType = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.legacyAccent.withOpacity(0.2)
              : AuthColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AuthColors.legacyAccent : AuthColors.textMainWithOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AuthColors.legacyAccent : AuthColors.textSub,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AuthColors.textMain : AuthColors.textSub,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AuthColors.legacyAccent,
                      onPrimary: AuthColors.textMain,
                      surface: AuthColors.surface,
                      onSurface: AuthColors.textMain,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedDate = date;
                _selectedSlot = null; // Reset slot when date changes
                _lastSlotLoadKey = null; // Clear cache on date change
              });
              _loadAvailableSlots();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedDate != null
                    ? AuthColors.legacyAccent.withOpacity(0.5)
                    : AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Select Date',
                    style: TextStyle(
                      color: _selectedDate != null ? AuthColors.textMain : AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingVehicles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: AuthColors.legacyAccent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_vehiclesError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthColors.error.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: AuthColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _vehiclesError!,
                        style: const TextStyle(color: AuthColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _loadEligibleVehicles,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: AuthColors.legacyAccent, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_eligibleVehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AuthColors.textSub, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No eligible vehicles available',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<Vehicle>(
            initialValue: _selectedVehicle,
            decoration: InputDecoration(
              filled: true,
              fillColor: AuthColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AuthColors.legacyAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: AuthColors.surface,
            style: const TextStyle(color: AuthColors.textMain),
            items: _eligibleVehicles.map((vehicle) {
              return DropdownMenuItem(
                value: vehicle,
                child: Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
            onChanged: (vehicle) {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedVehicle = vehicle;
                _selectedSlot = null; // Reset slot when vehicle changes
                _lastSlotLoadKey = null; // Clear cache on vehicle change
              });
              if (_selectedDate != null) {
                _loadAvailableSlots();
              }
            },
          ),
      ],
    );
  }

  Widget _buildSlotSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Slot',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_availableSlots.isNotEmpty)
              Text(
                '${_availableSlots.length} available',
                style: const TextStyle(
                  color: AuthColors.legacyAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingSlots)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuthColors.legacyAccent,
                ),
              ),
            ),
          )
        else if (_slotsError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AuthColors.error.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _slotsError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _loadAvailableSlots(immediate: true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Color(0xFF6F4BFF), fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_availableSlots.isEmpty && _slotBookedStatus.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No slots available for this day',
                    style: TextStyle(color: AuthColors.textSub, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _slotBookedStatus.keys.map((slot) {
              final isBooked = _slotBookedStatus[slot] ?? false;
              final isSelected = _selectedSlot == slot;
              final isAvailable = !isBooked;

              return RepaintBoundary(
                key: ValueKey('slot_$slot'),
                child: GestureDetector(
                  onTap: isAvailable
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSlot = slot);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                            ? AuthColors.legacyAccent.withOpacity(0.2)
                          : isBooked
                              ? AuthColors.surface.withOpacity(0.5)
                              : AuthColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AuthColors.legacyAccent
                            : isBooked
                                ? AuthColors.textMainWithOpacity(0.1)
                                : AuthColors.textMainWithOpacity(0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AuthColors.legacyAccent.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBooked)
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: AuthColors.textMainWithOpacity(0.3),
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AuthColors.legacyAccent,
                          )
                        else
                          const SizedBox(width: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Slot $slot',
                          style: TextStyle(
                            color: isSelected
                                ? AuthColors.textMain
                                : isBooked
                                    ? AuthColors.textMainWithOpacity(0.3)
                                    : AuthColors.textSub,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

