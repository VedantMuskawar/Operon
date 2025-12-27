import 'package:core_models/core_models.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  List<Vehicle> _eligibleVehicles = [];
  List<int> _availableSlots = [];
  Map<int, bool> _slotBookedStatus = {};

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
    super.dispose();
  }

  Future<void> _loadEligibleVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final orgContext = context.read<OrganizationContextCubit>();
      final organization = orgContext.state.organization;
      if (organization == null) return;

      final vehiclesRepo = context.read<VehiclesRepository>();
      final allVehicles = await vehiclesRepo.fetchVehicles(organization.id);
      
      // Show all active vehicles (ignore product matching)
      final eligible = allVehicles.where((v) => v.isActive).toList();

      setState(() {
        _eligibleVehicles = eligible;
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

  Future<void> _loadAvailableSlots() async {
    if (_selectedVehicle == null || _selectedDate == null) return;

    setState(() => _isLoadingSlots = true);
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

      setState(() {
        _availableSlots = availableSlots;
        _slotBookedStatus = slotBookedStatus;
        _selectedSlot = null; // Reset selection
        _isLoadingSlots = false;
      });
    } catch (e) {
      setState(() => _isLoadingSlots = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load slots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDayName(DateTime date) {
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
        items: widget.order['items'] as List<dynamic>? ?? [],
        pricing: widget.order['pricing'] as Map<String, dynamic>? ?? {},
        includeGstInTotal:
            widget.order['includeGstInTotal'] as bool? ?? true,
        priority: widget.order['priority'] as String? ?? 'normal',
        createdBy: currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip scheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule trip: $e'),
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
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
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
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
                color: Color(0xFF13131E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _scheduleTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6F4BFF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
              fillColor: const Color(0xFF13131E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1B1B2C),
            style: const TextStyle(color: Colors.white),
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
                    Icon(Icons.add, size: 18, color: Color(0xFF6F4BFF)),
                    SizedBox(width: 8),
                    Text('Add New Number'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
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
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF13131E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.add_call, color: Colors.white54, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
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
      onTap: () => setState(() => _paymentType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF).withOpacity(0.2)
              : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6F4BFF) : Colors.white.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6F4BFF) : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
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
                      primary: Color(0xFF6F4BFF),
                      onPrimary: Colors.white,
                      surface: Color(0xFF1B1B2C),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
                _selectedSlot = null; // Reset slot when date changes
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
                    ? const Color(0xFF6F4BFF).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Select Date',
                    style: TextStyle(
                      color: _selectedDate != null ? Colors.white : Colors.white54,
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_eligibleVehicles.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No eligible vehicles available',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          DropdownButtonFormField<Vehicle>(
            initialValue: _selectedVehicle,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF13131E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6F4BFF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: const Color(0xFF1B1B2C),
            style: const TextStyle(color: Colors.white),
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
              setState(() {
                _selectedVehicle = vehicle;
                _selectedSlot = null; // Reset slot when vehicle changes
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
                  color: Color(0xFF6F4BFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_availableSlots.isEmpty && _slotBookedStatus.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'No slots available for this day',
              style: TextStyle(color: Colors.white70, fontSize: 12),
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

              return GestureDetector(
                onTap: isAvailable
                    ? () => setState(() => _selectedSlot = slot)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6F4BFF).withOpacity(0.2)
                        : isBooked
                            ? const Color(0xFF13131E).withOpacity(0.5)
                            : const Color(0xFF13131E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6F4BFF)
                          : isBooked
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    'Slot $slot',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isBooked
                              ? Colors.white30
                              : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

