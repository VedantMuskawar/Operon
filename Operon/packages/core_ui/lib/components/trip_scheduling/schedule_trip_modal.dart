import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Callback for adding a phone number to a client
typedef PhoneNumberAdder = Future<void> Function({
  required String clientId,
  required String contactName,
  required String phoneNumber,
});

/// Callback for formatting error messages
typedef ErrorMessageFormatter = String Function(dynamic error);

/// Interface for scheduled trips repository operations needed by the modal
abstract class ScheduledTripsRepositoryInterface {
  Future<String> createScheduledTrip({
    required String organizationId,
    required String orderId,
    required String clientId,
    required String clientName,
    required String customerNumber,
    String? clientPhone,
    required String paymentType,
    required DateTime scheduledDate,
    required String scheduledDay,
    required String vehicleId,
    required String vehicleNumber,
    required String? driverId,
    required String? driverName,
    required String? driverPhone,
    required int slot,
    required String slotName,
    required Map<String, dynamic> deliveryZone,
    required List<dynamic> items,
    Map<String, dynamic>? pricing,
    bool? includeGstInTotal,
    required String priority,
    required String createdBy,
    int? itemIndex,
    String? productId,
    String? meterType,
    String? transportMode,
  });

  Future<List<Map<String, dynamic>>> getScheduledTripsForDayAndVehicle({
    required String organizationId,
    required String scheduledDay,
    required DateTime scheduledDate,
    required String vehicleId,
  });
}

/// Interface for vehicles repository operations
abstract class VehiclesRepositoryInterface {
  Future<List<Vehicle>> fetchVehicles(String organizationId);
}

/// Shared ScheduleTripModal widget that works on both Android and Web
///
/// This widget is platform-adaptive:
/// - Android: Uses AuthColors, Material design, haptic feedback
/// - Web: Uses custom colors, no haptic feedback
class ScheduleTripModal extends StatefulWidget {
  const ScheduleTripModal({
    super.key,
    required this.order,
    required this.clientId,
    required this.clientName,
    required this.clientPhones,
    required this.onScheduled,
    required this.scheduledTripsRepository,
    required this.vehiclesRepository,
    required this.addPhoneNumber,
    this.errorFormatter,
    this.organizationContextCubit,
  });

  final Map<String, dynamic> order;
  final String clientId;
  final String clientName;
  final List<Map<String, dynamic>> clientPhones;
  final VoidCallback onScheduled;
  final ScheduledTripsRepositoryInterface scheduledTripsRepository;
  final VehiclesRepositoryInterface vehiclesRepository;
  final PhoneNumberAdder addPhoneNumber;
  final ErrorMessageFormatter? errorFormatter;
  final dynamic organizationContextCubit; // OrganizationContextCubit from app

  @override
  State<ScheduleTripModal> createState() => _ScheduleTripModalState();
}

class _ScheduleTripModalState extends State<ScheduleTripModal> {
  static const String _transportCompany = 'company';
  static const String _transportSelf = 'self';

  String? _selectedPhoneNumber;
  String _paymentType = 'pay_later';
  DateTime? _selectedDate;
  Vehicle? _selectedVehicle;
  int? _selectedSlot;
  int? _selectedItemIndex;
  String _transportMode = _transportCompany;
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
  String? _lastSlotLoadKey;

  // Platform detection
  bool get _isAndroid => !kIsWeb;
  bool get _isWeb => kIsWeb;
  bool get _isSelfTransport => _transportMode == _transportSelf;

  // Use AuthColors consistently across all platforms
  Color get _primaryColor => AuthColors.legacyAccent;
  Color get _surfaceColor => AuthColors.surface;
  Color get _textMainColor => AuthColors.textMain;
  Color get _textSubColor => AuthColors.textSub;
  Color get _errorColor => AuthColors.error;
  Color get _successColor => AuthColors.success;
  Color get _whiteColor =>
      AuthColors.textMain; // Use textMain for white text on dark backgrounds

  @override
  void initState() {
    super.initState();
    // Set default phone to primary if available
    if (widget.clientPhones.isNotEmpty) {
      _selectedPhoneNumber = _isWeb
          ? (widget.clientPhones.first['e164'] as String?) ??
              (widget.clientPhones.first['number'] as String?)
          : widget.clientPhones.first['number'] as String?;
    }
    // Auto-select first item if single-item order
    final orderItems = widget.order['items'] as List<dynamic>? ?? [];
    if (orderItems.length == 1) {
      _selectedItemIndex = 0;
    } else {
      _selectedItemIndex = null;
    }
    _loadEligibleVehicles();

    // Reload vehicles when item selection changes (for multi-product orders)
    // This is handled in the product selection UI
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
      final organization = _getOrganization();
      if (organization == null) {
        if (mounted) {
          setState(() {
            _isLoadingVehicles = false;
            _vehiclesError = 'Organization not selected';
          });
        }
        return;
      }

      final allVehicles =
          await widget.vehiclesRepository.fetchVehicles(organization.id);
      final List<Vehicle> eligible =
          allVehicles.where((v) => v.isActive && v.tag == 'Delivery').toList();

      if (mounted) {
        setState(() {
          _eligibleVehicles = eligible;
          _isLoadingVehicles = false;
          if (eligible.isEmpty) {
            _vehiclesError = "No vehicles with tag 'Delivery' available";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
          _vehiclesError = 'Failed to load vehicles: $e';
        });
      }
    }
  }

  dynamic _getOrganization() {
    if (widget.organizationContextCubit == null) return null;
    try {
      // Try to access state.organization using dynamic access
      final state = widget.organizationContextCubit.state;
      return state?.organization;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAvailableSlots({bool immediate = false}) async {
    if (_selectedVehicle == null || _selectedDate == null) return;

    final cacheKey =
        '${_selectedVehicle!.id}_${_selectedDate!.toIso8601String()}';

    if (_lastSlotLoadKey == cacheKey && _availableSlots.isNotEmpty) {
      return; // Use cached data
    }

    if (!immediate && _isAndroid) {
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
      final organization = _getOrganization();
      if (organization == null) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _slotsError = 'Organization not selected';
            _availableSlots = [];
            _slotBookedStatus = {};
          });
        }
        return;
      }

      final dayName = _getDayName(_selectedDate!);
      final weeklyCapacity = _selectedVehicle!.weeklyCapacity;

      if (weeklyCapacity == null || weeklyCapacity.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _slotsError =
                'Vehicle does not have weekly capacity configured. Please configure capacity for each day in vehicle settings.';
            _availableSlots = [];
            _slotBookedStatus = {};
            _selectedSlot = null;
          });
        }
        return;
      }

      if (!weeklyCapacity.containsKey(dayName)) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _slotsError =
                'No capacity configured for $dayName. Available days: ${weeklyCapacity.keys.join(", ")}';
            _availableSlots = [];
            _slotBookedStatus = {};
            _selectedSlot = null;
          });
        }
        return;
      }

      final dayCapacity = (weeklyCapacity[dayName] as num?)?.toInt() ?? 0;

      if (dayCapacity <= 0) {
        if (mounted) {
          setState(() {
            _isLoadingSlots = false;
            _slotsError =
                'Capacity for $dayName is 0. Please configure a valid capacity in vehicle settings.';
            _availableSlots = [];
            _slotBookedStatus = {};
            _selectedSlot = null;
          });
        }
        return;
      }

      final scheduledTrips = await widget.scheduledTripsRepository
          .getScheduledTripsForDayAndVehicle(
        organizationId: organization.id,
        scheduledDay: dayName,
        scheduledDate: _selectedDate!,
        vehicleId: _selectedVehicle!.id,
      );

      final bookedSlots = scheduledTrips
          .map((trip) => trip['slot'] as int?)
          .where((slot) => slot != null)
          .toList();

      final allSlots = List.generate(dayCapacity, (index) => index + 1);
      final availableSlots =
          allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
      final slotBookedStatus = Map.fromEntries(
        allSlots.map((slot) => MapEntry(slot, bookedSlots.contains(slot))),
      );

      if (mounted) {
        setState(() {
          _availableSlots = availableSlots;
          _slotBookedStatus = slotBookedStatus;
          _selectedSlot = null;
          _isLoadingSlots = false;
          _lastSlotLoadKey = cacheKey;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSlots = false;
          _slotsError = 'Failed to load slots: $e';
          _lastSlotLoadKey = null;
        });
      }
    }
  }

  String _getDayName(DateTime date) {
    // Use lowercase day names to match Cloud Functions and vehicle weeklyCapacity format
    // Cloud Functions use: ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']
    // DateTime.weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    // Adjust index: weekday 1 (Monday) -> index 0, weekday 7 (Sunday) -> index 6
    final dayIndex = date.weekday - 1;
    return days[dayIndex];
  }

  bool _shouldShowProductSelection() {
    final orderItems = widget.order['items'] as List<dynamic>? ?? [];
    return orderItems.length > 1;
  }

  bool _canSchedule() {
    if (_selectedPhoneNumber == null || _selectedPhoneNumber!.isEmpty)
      return false;
    if (_selectedDate == null) return false;
    if (!_isSelfTransport) {
      if (_selectedVehicle == null) return false;
      if (_selectedSlot == null) return false;
    }
    if (_shouldShowProductSelection() && _selectedItemIndex == null)
      return false;
    return true;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _generateSelfTransportSlot() {
    final now = DateTime.now().toUtc();
    final slot = now.microsecondsSinceEpoch % 1000000000;
    return slot == 0 ? 1 : slot;
  }

  void _triggerHapticFeedback() {
    if (_isAndroid) {
      HapticFeedback.selectionClick();
    }
  }

  void _triggerMediumHaptic() {
    if (_isAndroid) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _scheduleTrip() async {
    // Validation
    if (_selectedPhoneNumber == null || _selectedPhoneNumber!.isEmpty) {
      _showSnackBar('Please select or enter a contact number', isError: true);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select a date', isError: true);
      return;
    }

    if (!_isSelfTransport) {
      if (_selectedVehicle == null) {
        _showSnackBar('Please select a vehicle', isError: true);
        return;
      }

      if (_selectedSlot == null) {
        _showSnackBar('Please select a slot', isError: true);
        return;
      }
    }

    final orderItems = widget.order['items'] as List<dynamic>? ?? [];

    // Ensure itemIndex is set for single-product orders
    if (orderItems.length == 1 && _selectedItemIndex == null) {
      _selectedItemIndex = 0;
    }

    if (orderItems.length > 1 && _selectedItemIndex == null) {
      _showSnackBar('Please select a product to schedule', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _lastSlotLoadKey = null;
    });

    try {
      final organization = _getOrganization();
      if (organization == null) {
        throw Exception('Organization not selected');
      }

      if (organization.id == null || organization.id.isEmpty) {
        throw Exception('Organization ID is invalid');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (currentUser.uid.isEmpty) {
        throw Exception('User ID is invalid');
      }

      // Check if new phone number needs to be added
      final phoneExists = widget.clientPhones.any(
        (phone) =>
            (phone['e164'] == _selectedPhoneNumber) ||
            (phone['number'] == _selectedPhoneNumber),
      );

      if (!phoneExists && _isAddingNewPhone) {
        await widget.addPhoneNumber(
          clientId: widget.clientId,
          contactName: widget.clientName,
          phoneNumber: _selectedPhoneNumber!,
        );
      }

      final dayName = _getDayName(_selectedDate!);
      final itemIndex = _selectedItemIndex ?? 0;

      if (orderItems.isEmpty) {
        throw Exception('Order has no items. Cannot schedule trip.');
      }

      if (itemIndex < 0 || itemIndex >= orderItems.length) {
        throw Exception(
            'Invalid item index: $itemIndex (order has ${orderItems.length} items)');
      }

      final item = orderItems[itemIndex];
      if (item == null) {
        throw Exception('Item at index $itemIndex is null');
      }
      if (item is! Map<String, dynamic>) {
        throw Exception(
            'Invalid item data at index $itemIndex: expected Map, got ${item.runtimeType}');
      }

      final productId = item['productId'] as String?;
      if (productId == null || productId.isEmpty) {
        throw Exception(
            'Product ID not found for selected item at index $itemIndex');
      }

      final resolvedVehicleId =
          _isSelfTransport ? 'SELF_TRANSPORT' : _selectedVehicle!.id;
      final resolvedVehicleNumber =
          _isSelfTransport ? 'Self Transport' : _selectedVehicle!.vehicleNumber;
      final resolvedSlot =
          _isSelfTransport ? _generateSelfTransportSlot() : _selectedSlot!;
      final resolvedSlotName =
          _isSelfTransport ? 'Self Transport' : 'Slot ${_selectedSlot!}';

      // Validate vehicle data
      if (resolvedVehicleId.isEmpty) {
        throw Exception('Vehicle ID is invalid');
      }

      if (resolvedVehicleNumber.isEmpty) {
        throw Exception('Vehicle number is invalid');
      }

      // Get orderId - could be in 'id', 'orderId', or document ID
      final orderId =
          widget.order['id'] as String? ?? widget.order['orderId'] as String?;

      if (orderId == null || orderId.isEmpty) {
        throw Exception(
            'Order ID not found. Order data may be incomplete. Please refresh and try again.');
      }

      await widget.scheduledTripsRepository.createScheduledTrip(
        organizationId: organization.id,
        orderId: orderId,
        clientId: widget.clientId,
        clientName: widget.clientName,
        customerNumber: _selectedPhoneNumber!,
        clientPhone: _selectedPhoneNumber!,
        paymentType: _paymentType,
        scheduledDate: _selectedDate!,
        scheduledDay: dayName,
        vehicleId: resolvedVehicleId,
        vehicleNumber: resolvedVehicleNumber,
        driverId: _isSelfTransport ? null : _selectedVehicle!.driver?.id,
        driverName: _isSelfTransport ? null : _selectedVehicle!.driver?.name,
        driverPhone: _isSelfTransport ? null : _selectedVehicle!.driver?.phone,
        slot: resolvedSlot,
        slotName: resolvedSlotName,
        deliveryZone:
            widget.order['deliveryZone'] as Map<String, dynamic>? ?? {},
        items: orderItems,
        priority: widget.order['priority'] as String? ?? 'normal',
        createdBy: currentUser.uid,
        itemIndex: itemIndex,
        productId: productId,
        meterType: _isSelfTransport ? null : _selectedVehicle!.meterType,
        transportMode: _isSelfTransport ? _transportSelf : _transportCompany,
      );

      if (mounted) {
        _triggerMediumHaptic();
        setState(() {
          _lastSlotLoadKey = null;
        });
        _showSnackBar('Trip scheduled successfully', isError: false);
        Navigator.of(context).pop();
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastSlotLoadKey = null;
        });
        String errorMessage;
        final errorStr = e.toString();
        if (errorStr.contains('Slot') &&
            errorStr.contains('no longer available')) {
          errorMessage =
              'Slot no longer available. Please select a different slot.';
        } else if (errorStr.contains('No trips remaining')) {
          errorMessage = 'No trips remaining to schedule for this item.';
        } else if (errorStr.contains('Order not found')) {
          errorMessage = 'Order not found. It may have been deleted.';
        } else if (errorStr.contains('Connection error') ||
            errorStr.contains('internet')) {
          errorMessage =
              'Connection error. Please check your internet and try again.';
        } else if (widget.errorFormatter != null) {
          errorMessage = widget.errorFormatter!(e);
        } else {
          errorMessage = 'Failed to schedule trip: $e';
        }
        _showSnackBar(errorMessage, isError: true, showRetry: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message,
      {required bool isError, bool showRetry = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: _textMainColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: _textMainColor),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: isError ? 4 : 2),
        action: showRetry
            ? SnackBarAction(
                label: 'Retry',
                textColor: _textMainColor,
                onPressed: _scheduleTrip,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAndroid) {
      return _buildAndroidModal(context);
    } else {
      return _buildWebModal(context);
    }
  }

  Widget _buildAndroidModal(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContactNumberSection(),
                    const SizedBox(height: 16),
                    if (_shouldShowProductSelection()) ...[
                      _buildProductSelectionSection(),
                      const SizedBox(height: 16),
                    ],
                    _buildPaymentTypeSection(),
                    const SizedBox(height: 16),
                    _buildDatePickerSection(),
                    const SizedBox(height: 16),
                    _buildTransportModeSection(),
                    if (!_isSelfTransport) ...[
                      const SizedBox(height: 16),
                      _buildVehicleSelectionSection(),
                      if (_selectedVehicle != null &&
                          _selectedDate != null) ...[
                        const SizedBox(height: 16),
                        _buildSlotSelectionSection(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebModal(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContactNumberSection(),
                    const SizedBox(height: 20),
                    if (_shouldShowProductSelection()) ...[
                      _buildProductSelectionSection(),
                      const SizedBox(height: 20),
                    ],
                    _buildPaymentTypeSection(),
                    const SizedBox(height: 20),
                    _buildDatePickerSection(),
                    const SizedBox(height: 20),
                    _buildTransportModeSection(),
                    if (!_isSelfTransport) ...[
                      const SizedBox(height: 20),
                      _buildVehicleSelectionSection(),
                      if (_selectedVehicle != null &&
                          _selectedDate != null) ...[
                        const SizedBox(height: 20),
                        _buildSlotSelectionSection(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isAndroid ? 16 : 24,
        vertical: _isAndroid ? 12 : 16,
      ),
      child: Row(
        children: [
          Text(
            'Schedule Trip',
            style: TextStyle(
              color: _textMainColor,
              fontSize: _isAndroid ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: _textMainColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(_isAndroid ? 16 : 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_isAndroid ? 16 : 16),
          bottomRight: Radius.circular(_isAndroid ? 16 : 16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _textSubColor)),
            ),
          ),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: (_isLoading || !_canSchedule())
                  ? null
                  : () {
                      _triggerHapticFeedback();
                      _scheduleTrip();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: _whiteColor,
                padding: EdgeInsets.symmetric(vertical: _isAndroid ? 12 : 14),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_whiteColor),
                      ),
                    )
                  : const Text('Schedule'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactNumberSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Number',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (!_isAddingNewPhone) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedPhoneNumber,
            decoration: InputDecoration(
              filled: true,
              fillColor: _surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _textMainColor.withOpacity(0.1)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            dropdownColor: _surfaceColor,
            style: TextStyle(color: _textMainColor),
            items: [
              ...widget.clientPhones.map((phone) {
                final number =
                    phone['e164'] as String? ?? phone['number'] as String?;
                return DropdownMenuItem(
                  value: number,
                  child: Text(number ?? ''),
                );
              }),
              DropdownMenuItem(
                value: '__add_new__',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: _primaryColor),
                    const SizedBox(width: 8),
                    const Text('Add New Number'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              _triggerHapticFeedback();
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
            style: TextStyle(color: _textMainColor),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: TextStyle(color: _textSubColor),
              filled: true,
              fillColor: _surfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _textMainColor.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _textMainColor.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _primaryColor, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              prefixIcon: Icon(Icons.add_call, color: _textSubColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(Icons.close, color: _textSubColor),
                onPressed: () {
                  setState(() {
                    _isAddingNewPhone = false;
                    _newPhoneController.clear();
                    if (widget.clientPhones.isNotEmpty) {
                      _selectedPhoneNumber = _isWeb
                          ? (widget.clientPhones.first['e164'] as String?) ??
                              (widget.clientPhones.first['number'] as String?)
                          : widget.clientPhones.first['number'] as String?;
                    }
                  });
                },
              ),
            ),
            onChanged: (value) {
              setState(
                  () => _selectedPhoneNumber = value.isEmpty ? null : value);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProductSelectionSection() {
    final orderItems = widget.order['items'] as List<dynamic>? ?? [];
    if (orderItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Product',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: _isAndroid ? 8 : 10),
        ...orderItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value as Map<String, dynamic>?;
          if (item == null) return const SizedBox.shrink();

          final productName =
              item['productName'] as String? ?? 'Unknown Product';
          final estimatedTrips = (item['estimatedTrips'] as int?) ?? 0;
          final isSelected = _selectedItemIndex == index;
          final isDisabled = estimatedTrips <= 0;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < orderItems.length - 1 ? (_isAndroid ? 8 : 10) : 0,
            ),
            child: GestureDetector(
              onTap: isDisabled
                  ? null
                  : () {
                      _triggerHapticFeedback();
                      setState(() {
                        _selectedItemIndex = index;
                        _selectedVehicle = null;
                        _selectedSlot = null;
                        _availableSlots = [];
                        _slotBookedStatus = {};
                      });
                      _loadEligibleVehicles();
                    },
              child: Container(
                padding: EdgeInsets.all(_isAndroid ? 12 : 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.2)
                      : _surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _primaryColor
                        : isDisabled
                            ? _textMainColor.withOpacity(0.1)
                            : _textMainColor.withOpacity(0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: TextStyle(
                              color: isDisabled
                                  ? _textMainColor.withOpacity(0.4)
                                  : _textMainColor,
                              fontSize: _isAndroid ? 14 : 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          SizedBox(height: _isAndroid ? 4 : 4),
                          Row(
                            children: [
                              Icon(
                                Icons.route_outlined,
                                size: _isAndroid ? 12 : 14,
                                color: isDisabled
                                    ? _textSubColor.withOpacity(0.3)
                                    : _textSubColor,
                              ),
                              SizedBox(width: _isAndroid ? 4 : 6),
                              Text(
                                '$estimatedTrips trips remaining',
                                style: TextStyle(
                                  color: isDisabled
                                      ? _textSubColor.withOpacity(0.3)
                                      : _textSubColor,
                                  fontSize: _isAndroid ? 11 : 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isDisabled) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _errorColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'No trips',
                          style: TextStyle(
                            color: _errorColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else if (isSelected) ...[
                      Icon(
                        Icons.check_circle,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPaymentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Type',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPaymentOption('pay_later', 'Pay Later'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPaymentOption('pay_on_delivery', 'Pay Now'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String value, String label) {
    final isSelected = _paymentType == value;
    return GestureDetector(
      onTap: () {
        _triggerHapticFeedback();
        setState(() => _paymentType = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.2) : _surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? _primaryColor : _textMainColor.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? _primaryColor : _textMainColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransportModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transport Mode',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTransportOption(
                _transportCompany,
                'Company Vehicle',
                'Use plant vehicle & slot',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTransportOption(
                _transportSelf,
                'Client Vehicle',
                'Self transport',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransportOption(String value, String label, String helper) {
    final isSelected = _transportMode == value;
    return GestureDetector(
      onTap: () {
        _triggerHapticFeedback();
        setState(() {
          _transportMode = value;
          if (_isSelfTransport) {
            _selectedVehicle = null;
            _selectedSlot = null;
            _availableSlots = [];
            _slotBookedStatus = {};
            _vehiclesError = null;
            _slotsError = null;
            _lastSlotLoadKey = null;
          }
        });
        if (!_isSelfTransport) {
          _loadEligibleVehicles();
          if (_selectedDate != null && _selectedVehicle != null) {
            _loadAvailableSlots(immediate: true);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.2) : _surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? _primaryColor : _textMainColor.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : _textMainColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                color: _textSubColor,
                fontSize: _isAndroid ? 10 : 11,
              ),
              textAlign: TextAlign.center,
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
        Text(
          'Scheduled Date',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
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
                    colorScheme: ColorScheme.light(
                      primary: _primaryColor,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
                _selectedSlot = null;
                _lastSlotLoadKey = null;
              });
              _loadAvailableSlots(immediate: true);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _textMainColor.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _textSubColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? _formatDate(_selectedDate!)
                      : 'Select date',
                  style: TextStyle(
                    color:
                        _selectedDate != null ? _textMainColor : _textSubColor,
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
        Text(
          'Vehicle',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingVehicles)
          const Center(child: CircularProgressIndicator())
        else if (_vehiclesError != null)
          Text(_vehiclesError!, style: TextStyle(color: _errorColor))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _eligibleVehicles.map((vehicle) {
              final isSelected = _selectedVehicle?.id == vehicle.id;
              return GestureDetector(
                onTap: () {
                  _triggerHapticFeedback();
                  setState(() {
                    _selectedVehicle = vehicle;
                    _selectedSlot = null;
                    _lastSlotLoadKey = null;
                  });
                  if (_selectedDate != null) {
                    _loadAvailableSlots(immediate: true);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isAndroid ? 14 : 16,
                    vertical: _isAndroid ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : _surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? _primaryColor
                          : _textMainColor.withOpacity(0.15),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    vehicle.vehicleNumber,
                    style: TextStyle(
                      color: isSelected ? _whiteColor : _textMainColor,
                      fontSize: _isAndroid ? 13 : 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSlotSelectionSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Slot',
          style: TextStyle(
            color: _textMainColor,
            fontSize: _isAndroid ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingSlots)
          const Center(child: CircularProgressIndicator())
        else if (_slotsError != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _slotsError!,
                style: TextStyle(
                    color: _errorColor, fontSize: _isAndroid ? 12 : 13),
              ),
              if (_slotsError!.contains('capacity configured'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Contact your administrator to configure vehicle capacity.',
                    style: TextStyle(
                        color: _textSubColor, fontSize: _isAndroid ? 11 : 12),
                  ),
                ),
            ],
          )
        else if (_availableSlots.isEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No slots available',
                style: TextStyle(color: _textSubColor),
              ),
              if (_slotBookedStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'All ${_slotBookedStatus.length} slots are booked for this day.',
                    style: TextStyle(
                        color: _textSubColor, fontSize: _isAndroid ? 11 : 12),
                  ),
                ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableSlots.map((slot) {
              final isBooked = _slotBookedStatus[slot] ?? false;
              final isSelected = _selectedSlot == slot;
              return GestureDetector(
                onTap: isBooked
                    ? null
                    : () {
                        _triggerHapticFeedback();
                        setState(() => _selectedSlot = slot);
                      },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isBooked
                        ? _surfaceColor
                        : isSelected
                            ? _primaryColor
                            : _surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isBooked
                          ? _textMainColor.withOpacity(0.1)
                          : isSelected
                              ? _primaryColor
                              : _textMainColor.withOpacity(0.15),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$slot',
                      style: TextStyle(
                        color: isBooked
                            ? _textSubColor.withOpacity(0.3)
                            : isSelected
                                ? _whiteColor
                                : _textMainColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
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
