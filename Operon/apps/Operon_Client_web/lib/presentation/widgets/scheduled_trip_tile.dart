import 'dart:async';

import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_web/data/repositories/delivery_memo_repository.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/schedule_trip_modal.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart' hide LatLng;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ScheduledTripTile extends StatefulWidget {
  const ScheduledTripTile({
    super.key,
    required this.trip,
    this.onTripsUpdated,
    this.onTap,
  });

  final Map<String, dynamic> trip;
  final VoidCallback? onTripsUpdated;
  final VoidCallback? onTap;

  @override
  State<ScheduledTripTile> createState() => _ScheduledTripTileState();
}

class _ScheduledTripTileState extends State<ScheduledTripTile>
    with TickerProviderStateMixin {
  bool _isRescheduling = false;
  bool _isExpanded = false;
  late AnimationController _pulseController;
  late AnimationController _expansionController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  DriverLocation? _currentLocation;
  bool _hasLocationTracking = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Start pulsing if trip is overdue
    if (_isOverdue()) {
      _pulseController.repeat(reverse: true);
    }

    // Check for location tracking
    _checkLocationTracking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expansionController.dispose();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapLocation() {
    if (!mounted || _mapController == null || _currentLocation == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(
          _currentLocation!.lat,
          _currentLocation!.lng,
        ),
      ),
    );
  }

  Future<void> _checkLocationTracking() async {
    final driverId = widget.trip['driverId'] as String?;
    if (driverId == null || driverId.isEmpty) return;

    // Check if location tracking is active in RTDB
    if (!kIsWeb) return;

    try {
      final app = Firebase.app();
      final db = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: app.options.databaseURL ??
            'https://operonappsuite-default-rtdb.firebaseio.com',
      );

      final ref = db.ref('active_drivers/$driverId');
      _locationSubscription = ref.onValue.listen((event) {
        if (!mounted) return;

        final value = event.snapshot.value;
        if (value != null && value is Map) {
          if (!mounted) return;
          setState(() {
            _hasLocationTracking = true;
            try {
              final json = <String, dynamic>{};
              for (final kv in value.entries) {
                json[kv.key.toString()] = kv.value;
              }
              _currentLocation = DriverLocation.fromJson(json);
              // Update map if expanded
              if (_isExpanded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateMapLocation();
                });
              }
            } catch (e) {
              debugPrint('Error parsing location: $e');
            }
          });
        } else {
          if (!mounted) return;
          setState(() {
            _hasLocationTracking = false;
            _currentLocation = null;
          });
        }
      });
    } catch (e) {
      debugPrint('Error checking location tracking: $e');
    }
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expansionController.forward();
      } else {
        _expansionController.reverse();
      }
    });
  }

  String? _resolvePaymentAccountName(List<dynamic> paymentDetails) {
    for (final payment in paymentDetails) {
      if (payment is Map<String, dynamic>) {
        final name = payment['paymentAccountName'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    }
    return null;
  }

  Widget _paymentBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AuthColors.textMain),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    final tripStatus = widget.trip['tripStatus'] as String? ??
        widget.trip['orderStatus'] as String? ??
        'scheduled';
    switch (tripStatus.toLowerCase()) {
      case 'pending':
        return AuthColors.error;
      case 'scheduled':
        return AuthColors.error;
      case 'dispatched':
        return AuthColors.warning;
      case 'delivered':
        return AuthColors.info;
      case 'returned':
        return AuthColors.success;
      default:
        return AuthColors.error;
    }
  }

  int _getActiveStepCount() {
    final tripStatus = widget.trip['tripStatus'] as String? ??
        widget.trip['orderStatus'] as String? ??
        'scheduled';
    switch (tripStatus.toLowerCase()) {
      case 'scheduled':
        return 1;
      case 'dispatched':
        return 2;
      case 'delivered':
        return 3;
      case 'returned':
        return 4;
      default:
        return 1;
    }
  }

  bool _isOverdue() {
    final tripStatus = widget.trip['tripStatus'] as String? ??
        widget.trip['orderStatus'] as String? ??
        'scheduled';

    // Only check overdue for scheduled trips
    if (tripStatus.toLowerCase() != 'scheduled') {
      return false;
    }

    final transportMode = widget.trip['transportMode'] as String?;
    if (transportMode == 'self') {
      return false;
    }

    // Get scheduled date
    final scheduledDate = widget.trip['scheduledDate'];
    if (scheduledDate == null) return false;

    DateTime scheduledDateTime;
    if (scheduledDate is DateTime) {
      scheduledDateTime = scheduledDate;
    } else if (scheduledDate is Map) {
      // Handle Firestore Timestamp format
      final seconds = scheduledDate['_seconds'] as int?;
      if (seconds != null) {
        scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else {
        return false; // Can't determine, skip overdue check
      }
    } else {
      return false; // Can't determine, skip overdue check
    }

    // Get slot number (assuming slots are hourly, starting from 0 or 1)
    final slot = widget.trip['slot'] as int? ?? 0;

    // Calculate slot time (assuming 8 AM start, each slot is 1 hour)
    // Adjust this logic based on your actual slot system
    // For now, we'll use a simple approach: scheduled date + slot hours
    final slotTime = DateTime(
      scheduledDateTime.year,
      scheduledDateTime.month,
      scheduledDateTime.day,
      8 + slot, // Start at 8 AM, add slot hours
    );

    // Check if current time is past slot time
    return DateTime.now().isAfter(slotTime);
  }

  Future<void> _generateDM() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (organization == null || currentUser == null) {
      DashSnackbar.show(context,
          message: 'Organization or user not found', isError: true);
      return;
    }

    final tripId = widget.trip['id'] as String?;
    final scheduleTripId = widget.trip['scheduleTripId'] as String?;

    if (tripId == null || scheduleTripId == null) {
      DashSnackbar.show(context,
          message: 'Trip ID or Schedule Trip ID not found', isError: true);
      return;
    }

    try {
      final dmRepo = context.read<DeliveryMemoRepository>();

      if (!mounted) return;
      DashSnackbar.show(context, message: 'Generating DM...', isError: false);

      final dmId = await dmRepo.generateDM(
        organizationId: organization.id,
        tripId: tripId,
        scheduleTripId: scheduleTripId,
        tripData: widget.trip,
        generatedBy: currentUser.uid,
      );

      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'DM generated: $dmId', isError: false);

      if (widget.onTripsUpdated != null) {
        widget.onTripsUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'Failed to generate DM: $e', isError: true);
    }
  }

  Future<void> _cancelDM() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      DashSnackbar.show(context, message: 'User not found', isError: true);
      return;
    }

    final tripId = widget.trip['id'] as String?;

    if (tripId == null) {
      DashSnackbar.show(context, message: 'Trip ID not found', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Cancel DM',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to cancel this DM?',
          style: TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          DashButton(
            label: 'No',
            onPressed: () => Navigator.of(context).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Yes, Cancel',
            onPressed: () => Navigator.of(context).pop(true),
            variant: DashButtonVariant.text,
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dmRepo = context.read<DeliveryMemoRepository>();

      if (!mounted) return;
      DashSnackbar.show(context, message: 'Cancelling DM...', isError: false);

      await dmRepo.cancelDM(
        tripId: tripId,
        cancelledBy: currentUser.uid,
      );

      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'DM cancelled successfully', isError: false);

      if (widget.onTripsUpdated != null) {
        widget.onTripsUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(context,
          message: 'Failed to cancel DM: $e', isError: true);
    }
  }

  Future<void> _showPrintDialog(BuildContext context) async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      DashSnackbar.show(
        context,
        message: 'Organization not found',
        isError: true,
      );
      return;
    }

    final dmNumber = widget.trip['dmNumber'] as int?;
    final dmId = widget.trip['dmId'] as String?;

    if (dmNumber == null && dmId == null) {
      DashSnackbar.show(
        context,
        message: 'DM number or ID not found',
        isError: true,
      );
      return;
    }

    final resolvedDmNumber = dmNumber ?? (widget.trip['dmNumber'] as int?);
    if (resolvedDmNumber == null) {
      DashSnackbar.show(
        context,
        message: 'DM number required to print',
        isError: true,
      );
      return;
    }

    try {
      final printService = context.read<DmPrintService>();
      await printService.printDeliveryMemo(resolvedDmNumber);
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Print window opened');
      }
    } catch (e) {
      if (context.mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to print DM: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _rescheduleTrip() async {
    if (_isRescheduling) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AuthColors.surface,
            title: const Text(
              'Reschedule Trip',
              style: TextStyle(color: AuthColors.textMain),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will delete the current scheduled trip and allow you to reschedule it.',
                    style: TextStyle(color: AuthColors.textSub),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: AuthColors.textMain),
                    decoration: InputDecoration(
                      labelText: 'Reason for rescheduling *',
                      labelStyle: const TextStyle(color: AuthColors.textSub),
                      hintText: 'Enter reason...',
                      hintStyle:
                          TextStyle(color: AuthColors.textMainWithOpacity(0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: AuthColors.textMainWithOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AuthColors.warning),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: AuthColors.surface,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              DashButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(null),
                variant: DashButtonVariant.text,
              ),
              DashButton(
                label: 'Reschedule',
                onPressed: reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop({
                          'confirmed': true,
                          'reason': reasonController.text.trim(),
                        }),
                variant: DashButtonVariant.text,
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || confirmed['confirmed'] != true) {
      reasonController.dispose();
      return;
    }

    final rescheduleReason = confirmed['reason'] as String? ?? '';

    setState(() {
      _isRescheduling = true;
    });

    try {
      final tripId = widget.trip['id'] as String?;
      if (tripId == null) {
        DashSnackbar.show(context, message: 'Trip ID not found', isError: true);
        return;
      }

      final scheduledTripsRepo = context.read<ScheduledTripsRepository>();

      await scheduledTripsRepo.updateTripRescheduleReason(
        tripId: tripId,
        reason: rescheduleReason,
      );

      await scheduledTripsRepo.deleteScheduledTrip(tripId);

      final orderId = widget.trip['orderId'] as String?;
      final clientId = widget.trip['clientId'] as String?;
      final clientName = widget.trip['clientName'] as String? ?? 'N/A';
      final customerNumber = widget.trip['customerNumber'] as String? ??
          widget.trip['clientPhone'] as String?;

      if (orderId == null || clientId == null) {
        DashSnackbar.show(
          context,
          message: 'Order or client information not available',
          isError: true,
        );
        return;
      }

      final clientsRepo = context.read<ClientsRepository>();
      List<Map<String, dynamic>> clientPhones = [];

      if (customerNumber != null && customerNumber.isNotEmpty) {
        try {
          final orgId =
              context.read<OrganizationContextCubit>().state.organization?.id ??
                  '';
          final client =
              await clientsRepo.findClientByPhone(orgId, customerNumber);
          if (client != null) {
            clientPhones = client.phones;
            if (clientPhones.isEmpty && client.primaryPhone != null) {
              clientPhones.add({
                'e164': client.primaryPhone,
                'number': client.primaryPhone,
              });
            }
          }
        } catch (e) {
          clientPhones = [
            {
              'e164': customerNumber,
              'number': customerNumber,
            }
          ];
        }
      }

      final orderData = <String, dynamic>{
        'id': orderId,
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': customerNumber,
        'items': widget.trip['items'] as List<dynamic>? ?? [],
        'deliveryZone':
            widget.trip['deliveryZone'] as Map<String, dynamic>? ?? {},
        'pricing': widget.trip['pricing'] as Map<String, dynamic>? ?? {},
        'priority': widget.trip['priority'] as String? ?? 'normal',
      };

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierColor: AuthColors.background.withOpacity(0.7),
        builder: (context) => ScheduleTripModal(
          order: orderData,
          clientId: clientId,
          clientName: clientName,
          clientPhones: clientPhones,
          onScheduled: () {
            if (widget.onTripsUpdated != null) {
              widget.onTripsUpdated!();
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to reschedule trip: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRescheduling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.trip['clientName'] as String? ?? 'N/A';
    final clientPhone = (widget.trip['clientPhone'] as String?)?.trim() ??
        (widget.trip['customerNumber'] as String?)?.trim() ??
        (widget.trip['clientPhoneNumber'] as String?)?.trim() ??
        '';
    final vehicleNumber = widget.trip['vehicleNumber'] as String? ?? 'N/A';
    final slot = widget.trip['slot'] as int? ?? 0;
    final transportMode = widget.trip['transportMode'] as String?;
    final isSelfTransport = transportMode == 'self';
    final vehicleLabel = isSelfTransport ? 'Self Transport' : vehicleNumber;
    final slotLabel = isSelfTransport ? 'Self' : 'Slot $slot';
    final deliveryZone = widget.trip['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';

    final items = widget.trip['items'] as List<dynamic>? ?? [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip =
        firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final unitPrice = (firstItem?['unitPrice'] as num?)?.toDouble() ?? 0.0;

    final tripPricing = widget.trip['tripPricing'] as Map<String, dynamic>?;
    final tripSubtotal = (tripPricing?['subtotal'] as num?)?.toDouble() ?? 0.0;
    final tripGstAmount =
        (tripPricing?['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final tripTotal = (tripPricing?['total'] as num?)?.toDouble() ?? 0.0;
    final paymentType = widget.trip['paymentType'] as String? ?? 'pay_later';
    final paymentDetails = widget.trip['paymentDetails'] as List<dynamic>? ?? [];
    final paymentAccountName = _resolvePaymentAccountName(paymentDetails);
    final showCreditBatch = paymentType == 'pay_later';
    final showPaymentAccountBadge = paymentType == 'pay_on_delivery' &&
      (paymentAccountName?.isNotEmpty ?? false);

    final dmNumber = widget.trip['dmNumber'] as int?;
    final hasDM = dmNumber != null;

    final tripStatus = widget.trip['tripStatus'] as String? ??
        widget.trip['orderStatus'] as String? ??
        'scheduled';

    final showActions = tripStatus.toLowerCase() == 'scheduled' ||
        tripStatus.toLowerCase() == 'dispatched';

    // DM generation should only be available for scheduled trips (DM required before dispatch)
    final canGenerateDM = tripStatus.toLowerCase() == 'scheduled' && !hasDM;

    final isOverdue = _isOverdue();
    final activeStepCount = _getActiveStepCount();
    final statusColor = _getStatusColor();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: Container(
            padding:
                const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.background.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Stepper
                _TripStatusStepper(
                  activeStepCount: activeStepCount,
                  isOverdue: isOverdue,
                  pulseAnimation: isOverdue ? _pulseAnimation : null,
                ),
                const SizedBox(height: 16),

                // Location Tracking Expand Button (if active)
                if (_hasLocationTracking)
                  InkWell(
                    onTap: _toggleExpansion,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AuthColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AuthColors.success,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Location Tracking Active',
                            style: TextStyle(
                              color: AuthColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(
                              Icons.expand_more,
                              size: 20,
                              color: AuthColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_hasLocationTracking) const SizedBox(height: 12),

                // Overdue Badge
                if (isOverdue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuthColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: AuthColors.error,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Overdue',
                            style: TextStyle(
                              color: AuthColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Header: Client Name and Vehicle & Slot
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clientName,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AuthColors.textSub,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  zoneText,
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (clientPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: AuthColors.textSub,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    clientPhone,
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AuthColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.textMainWithOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_car,
                                size: 12,
                                color: AuthColors.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicleLabel,
                                style: const TextStyle(
                                  color: AuthColors.textSub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 12,
                                color: AuthColors.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                slotLabel,
                                style: const TextStyle(
                                  color: AuthColors.textSub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bricks, Fixed Quantity, Unit Price, DM Number
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuthColors.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: AuthColors.textSub,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            productName,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuthColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$fixedQuantityPerTrip',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuthColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.warning.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        '₹${unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasDM)
                      InkWell(
                        onTap: () => _showPrintDialog(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AuthColors.info.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AuthColors.info.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                size: 14,
                                color: Color(0xFF0D47A1),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$dmNumber',
                                style: const TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pricing Information
                if (tripTotal > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AuthColors.surface.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal:',
                              style: TextStyle(
                                color: AuthColors.textSub,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '₹${tripSubtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (tripGstAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GST:',
                                style: TextStyle(
                                  color: AuthColors.textSub,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '₹${tripGstAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AuthColors.textMain,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Divider(
                          color: AuthColors.textMainWithOpacity(0.1),
                          height: 1,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '₹${tripTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              paymentType == 'pay_on_delivery'
                                  ? Icons.money_outlined
                                  : Icons.credit_card_outlined,
                              size: 12,
                              color: AuthColors.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              paymentType == 'pay_on_delivery'
                                  ? 'Pay on Delivery'
                                  : 'Pay Later',
                              style: const TextStyle(
                                color: AuthColors.textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (showCreditBatch || showPaymentAccountBadge) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (showCreditBatch)
                                _paymentBadge(
                                  icon: Icons.credit_score_outlined,
                                  label: 'Credit Batch',
                                  color: AuthColors.secondary,
                                ),
                              if (showPaymentAccountBadge)
                                _paymentBadge(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: paymentAccountName ?? 'Account',
                                  color: AuthColors.info,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Divider before action buttons
                if (showActions) ...[
                  Divider(
                    color: AuthColors.textMainWithOpacity(0.15),
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons
                if (showActions) ...[
                  if (hasDM)
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.visibility_outlined,
                            label: 'View DM',
                            color: AuthColors.info.withOpacity(0.3),
                            onTap: () => _showPrintDialog(context),
                          ),
                        ),
                        // Only allow canceling DM if trip is still scheduled (DM required before dispatch)
                        if (tripStatus.toLowerCase() == 'scheduled') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.cancel_outlined,
                              label: 'Cancel DM',
                              color: AuthColors.warning.withOpacity(0.3),
                              onTap: _cancelDM,
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (canGenerateDM)
                    Column(
                      children: [
                        _ActionButton(
                          icon: Icons.receipt_long,
                          label: 'Generate DM',
                          color: AuthColors.info.withOpacity(0.3),
                          onTap: _generateDM,
                          isFullWidth: true,
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.schedule_outlined,
                          label: 'Reschedule',
                          color: AuthColors.warning.withOpacity(0.3),
                          onTap: _isRescheduling ? null : _rescheduleTrip,
                          isLoading: _isRescheduling,
                          isFullWidth: true,
                        ),
                      ],
                    )
                  else if (tripStatus.toLowerCase() == 'scheduled')
                    // Scheduled trip without DM (edge case) - only show reschedule
                    _ActionButton(
                      icon: Icons.schedule_outlined,
                      label: 'Reschedule',
                      color: AuthColors.warning.withOpacity(0.3),
                      onTap: _isRescheduling ? null : _rescheduleTrip,
                      isLoading: _isRescheduling,
                      isFullWidth: true,
                    ),
                ],

                // Expanded Location Map
                if (_hasLocationTracking)
                  SizeTransition(
                    sizeFactor: _expansionController,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Divider(color: AuthColors.textMainWithOpacity(0.1)),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AuthColors.textMainWithOpacity(0.1),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _currentLocation != null && kIsWeb
                              ? GoogleMap(
                                  key: ValueKey(
                                      'map_${_currentLocation!.lat}_${_currentLocation!.lng}'),
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      _currentLocation!.lat,
                                      _currentLocation!.lng,
                                    ),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId:
                                          const MarkerId('current_location'),
                                      position: LatLng(
                                        _currentLocation!.lat,
                                        _currentLocation!.lng,
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueGreen,
                                      ),
                                    ),
                                  },
                                  mapToolbarEnabled: false,
                                  zoomControlsEnabled: true,
                                  compassEnabled: true,
                                  onMapCreated: (controller) {
                                    if (!mounted) return;
                                    _mapController = controller;
                                    controller.setMapStyle(darkMapStyle);
                                    // Center on current location
                                    if (_currentLocation != null && mounted) {
                                      controller.animateCamera(
                                        CameraUpdate.newLatLng(
                                          LatLng(
                                            _currentLocation!.lat,
                                            _currentLocation!.lng,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                )
                              : Container(
                                  color: AuthColors.surface,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_off,
                                          size: 48,
                                          color: AuthColors.textSub,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Waiting for location...',
                                          style: TextStyle(
                                            color: AuthColors.textSub,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                ),
              )
            else
              Icon(icon, color: AuthColors.textMain, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripStatusStepper extends StatelessWidget {
  const _TripStatusStepper({
    required this.activeStepCount,
    required this.isOverdue,
    this.pulseAnimation,
  });

  final int activeStepCount;
  final bool isOverdue;
  final Animation<double>? pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Scheduled',
      'Dispatched',
      'Delivered',
      'Returned',
    ];

    // Use white tones so stepper is readable on any status card (red/orange/blue/green)
    const activeColor = Colors.white;
    final inactiveColor = Colors.white.withOpacity(0.35);

    Widget stepperWidget = Row(
      children: List.generate(steps.length, (index) {
        final isActive = index < activeStepCount;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              // Step segment
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Arrow connector (except for last step)
              if (!isLast)
                Container(
                  width: 8,
                  height: 4,
                  color: Colors.transparent,
                  child: CustomPaint(
                    painter: _ArrowPainter(
                      color: isActive && index + 1 < activeStepCount
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );

    // Apply pulsing animation if overdue
    if (isOverdue && pulseAnimation != null) {
      stepperWidget = AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) {
          return Opacity(
            opacity: pulseAnimation!.value,
            child: child,
          );
        },
        child: stepperWidget,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepperWidget,
        const SizedBox(height: 8),
        // Step labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(steps.length, (index) {
            final isActive = index < activeStepCount;
            return Expanded(
              child: Text(
                steps[index],
                style: TextStyle(
                  color: isActive ? activeColor : Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width - 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
