import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/services/storage_service.dart';
import 'package:dash_mobile/data/utils/financial_year_utils.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/delivery_photo_dialog.dart';
import 'package:dash_mobile/presentation/widgets/return_payment_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ScheduleTripDetailPage extends StatefulWidget {
  const ScheduleTripDetailPage({
    super.key,
    required this.trip,
  });

  final Map<String, dynamic> trip;

  @override
  State<ScheduleTripDetailPage> createState() => _ScheduleTripDetailPageState();
}

class _ScheduleTripDetailPageState extends State<ScheduleTripDetailPage> {
  late Map<String, dynamic> _trip;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.trip);
  }


  Future<void> _showInitialReadingDialog(BuildContext context) async {
    final readingController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Enter Initial Reading',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter the odometer reading',
                style: TextStyle(color: AuthColors.textSub),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: readingController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Odometer Reading',
                  labelStyle: const TextStyle(color: AuthColors.textSub),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter odometer reading';
                  }
                  final reading = double.tryParse(value);
                  if (reading == null || reading < 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final reading = double.tryParse(readingController.text);
                if (reading != null) {
                  Navigator.of(context).pop(reading);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _dispatchTrip(context, result);
    }
  }

  Future<void> _dispatchTrip(BuildContext context, double initialReading) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    // Check if DM is generated (mandatory for dispatch)
    final dmNumber = _trip['dmNumber'] as num?;
    if (dmNumber == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DM must be generated before dispatching trip'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final userRole = orgContext.appAccessRole?.name ?? 'unknown';

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatching trip...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
        initialReading: initialReading,
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'dispatched';
        _trip['tripStatus'] = 'dispatched';
        _trip['initialReading'] = initialReading;
        _trip['dispatchedAt'] = DateTime.now();
        _trip['dispatchedBy'] = currentUser.uid;
        _trip['dispatchedByRole'] = userRole;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip dispatched successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dispatch trip: $e')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _showDeliveryPhotoDialog(BuildContext context) async {
    final result = await showDialog<File>(
      context: context,
      builder: (context) => const DeliveryPhotoDialog(),
    );

    if (result != null) {
      await _markAsDelivered(context, result);
    }
  }

  Future<void> _markAsDelivered(BuildContext context, File photoFile) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization not found')),
        );
      }
      return;
    }

    final userRole = orgContext.appAccessRole?.name ?? 'unknown';
    final orderId = _trip['orderId'] as String? ?? '';

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo and marking as delivered...')),
      );

      // Upload photo to Firebase Storage
      final storageService = StorageService();
      final photoUrl = await storageService.uploadDeliveryPhoto(
        imageFile: photoFile,
        organizationId: organization.id,
        orderId: orderId,
        tripId: tripId,
      );

      // Update trip status to delivered with photo URL
      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
        deliveryPhotoUrl: photoUrl,
        deliveredBy: currentUser.uid,
        deliveredByRole: userRole,
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'delivered';
        _trip['tripStatus'] = 'delivered';
        _trip['deliveryPhotoUrl'] = photoUrl;
        _trip['deliveredAt'] = DateTime.now();
        _trip['deliveredBy'] = currentUser.uid;
        _trip['deliveredByRole'] = userRole;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip marked as delivered successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as delivered: $e')),
      );
    }
  }

  Future<void> _undoDelivery_UNUSED(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Undo Delivery', style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to undo delivery? This will revert the trip status back to dispatched.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Undo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting delivery...')),
      );

      // Update trip status back to dispatched (remove delivery fields)
      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'dispatched';
        _trip['tripStatus'] = 'dispatched';
        _trip.remove('deliveryPhotoUrl');
        _trip.remove('deliveredAt');
        _trip.remove('deliveredBy');
        _trip.remove('deliveredByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to undo delivery: $e')),
      );
    }
  }

  // DEPRECATED: This method is no longer used. Use _markAsReturned instead.
  // Kept for reference but should not be called.
  @Deprecated('Use _markAsReturned instead. This method incorrectly creates credit transactions for pay_later on return.')
  Future<void> _showReturnDialog_UNUSED(BuildContext context) async {
    final readingController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Return Trip',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter the last odometer reading',
                style: TextStyle(color: AuthColors.textSub),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: readingController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Last Odometer Reading',
                  labelStyle: const TextStyle(color: AuthColors.textSub),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter odometer reading';
                  }
                  final reading = double.tryParse(value);
                  if (reading == null || reading < 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final reading = double.tryParse(readingController.text);
                if (reading != null) {
                  Navigator.of(context).pop(reading);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result != null) {
      // DEPRECATED: This calls the old _returnTrip method which incorrectly creates credit transactions
      // Use _markAsReturned instead (called from the active return flow)
      await _returnTrip(context, result);
    }
  }

  // DEPRECATED: This method is no longer used. Use _markAsReturned instead.
  // This method incorrectly creates credit transactions for pay_later trips on return.
  // Credit transactions should be created at DM generation (dispatch), not on return.
  @Deprecated('Use _markAsReturned instead. Credit transactions should be created at dispatch via DM generation.')
  Future<void> _returnTrip(BuildContext context, double finalReading) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization not found')),
        );
      }
      return;
    }

    final userRole = orgContext.appAccessRole?.name ?? 'unknown';
    final clientId = _trip['clientId'] as String? ?? '';
    final paymentType = _trip['paymentType'] as String? ?? '';
    final orderId = _trip['orderId'] as String? ?? '';
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Returning trip...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'returned',
        completedAt: DateTime.now(),
      );

      // DEPRECATED: Credit transactions should NOT be created here.
      // Order Credit transaction should already exist from DM generation (dispatch).
      // This code should never execute in the active flow, but kept for reference.
      // Removing the credit transaction creation logic to prevent duplicate transactions.
      // For pay_later: Credit was created at dispatch via DM generation.
      // For pay_on_delivery: Credit was created at dispatch via DM generation.

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'returned';
        _trip['tripStatus'] = 'returned';
        _trip['finalReading'] = finalReading;
        _trip['returnedAt'] = DateTime.now();
        _trip['returnedBy'] = currentUser.uid;
        _trip['returnedByRole'] = userRole;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip returned successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to return trip: $e')),
      );
    }
  }

  Future<void> _undoReturn_UNUSED(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Undo Return', style: TextStyle(color: AuthColors.textMain)),
        content: const Text(
          'Are you sure you want to undo return? This will revert the trip status back to delivered.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Undo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting return...')),
      );

      // Update trip status back to delivered (remove return fields)
      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'delivered';
        _trip['tripStatus'] = 'delivered';
        _trip.remove('finalReading');
        _trip.remove('returnedAt');
        _trip.remove('returnedBy');
        _trip.remove('returnedByRole');
        _trip.remove('paymentDetails');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to undo return: $e')),
      );
    }
  }

  Future<void> _undoDispatch_UNUSED(BuildContext context) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Undo Dispatch',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: const Text(
          'Are you sure you want to undo dispatch? This will revert all dispatch changes including initial reading, dispatch timestamp, and dispatcher information.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Undo Dispatch'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Undoing dispatch...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'scheduled',
      );

      // Update local state
      setState(() {
        _trip['tripStatus'] = 'scheduled';
        _trip['orderStatus'] = 'scheduled';
        _trip.remove('initialReading');
        _trip.remove('dispatchedAt');
        _trip.remove('dispatchedBy');
        _trip.remove('dispatchedByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispatch undone successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to undo dispatch: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
    final tripId = _trip['id'] as String? ?? 'N/A';
    final tripStatus = (_trip['orderStatus'] ?? _trip['tripStatus'] ?? 'pending')
        .toString()
        .toLowerCase();
    final statusColor = () {
      switch (tripStatus) {
        case 'delivered':
          return const Color(0xFF4CAF50);
        case 'dispatched':
          return const Color(0xFF6F4BFF);
        case 'returned':
          return Colors.orange;
        default:
          return Colors.blueGrey;
      }
    }();

    final items = _trip['items'] as List<dynamic>? ?? [];
    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final includeGstInTotal = _trip['includeGstInTotal'] as bool? ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Trip Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      tripStatus.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Reload trip data if needed
                  // For now, just trigger a rebuild
                  setState(() {});
                },
                color: const Color(0xFF6F4BFF),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopSection(),
                      const SizedBox(height: 12),
                      _buildInfoSection(),
                      const SizedBox(height: 12),
                      _buildOrderSummary(items, tripPricing, includeGstInTotal),
                      const SizedBox(height: 12),
                      _buildPaymentSummary(),
                      const SizedBox(height: 12),
                      _buildTripStatus(tripStatus, dmNumber),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    final driverPhone = _trip['driverPhone'] as String?;
    final clientPhone = _trip['clientPhone'] as String? ?? _trip['customerNumber'] as String?;
                              
    return Row(
                                children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: driverPhone != null && driverPhone.isNotEmpty
                ? () => _callNumber(driverPhone, 'Driver')
                : null,
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call Driver'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: clientPhone != null && clientPhone.isNotEmpty
                ? () => _callNumber(clientPhone, 'Customer')
                : null,
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call Customer'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
                                  ],
    );
  }

  Widget _buildInfoSection() {
    final scheduledDate = _trip['scheduledDate'];
    final slot = _trip['slot'] as int?;
    final vehicleNumber = _trip['vehicleNumber'] as String? ?? 'Not assigned';
    final deliveryZone = _trip['deliveryZone'] as Map<String, dynamic>? ?? {};
    final address = deliveryZone['region'] ??
        deliveryZone['zone'] ??
        deliveryZone['city'] ??
        deliveryZone['city_name'] ??
        'Not provided';
    final city = deliveryZone['city'] ?? deliveryZone['city_name'] ?? '';

    return _InfoCard(
      title: 'Trip Information',
      children: [
        // Date and Slot in a single row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 80,
                                        child: Text(
                  'Date',
                                          style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                  _formatDate(scheduledDate),
                                          style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                                          ),
                                        ),
                                      ),
              const SizedBox(width: 16),
              const SizedBox(
                width: 80,
                child: Text(
                  'Slot',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                    ),
              Expanded(
                child: Text(
                  slot != null ? 'Slot $slot' : 'Not set',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        _InfoRow(label: 'Vehicle', value: vehicleNumber),
        // Address and City in a single row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
                      children: [
              const SizedBox(
                width: 80,
                child: Text(
                  'Address',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                          ),
              if (city.isNotEmpty) ...[
                const SizedBox(width: 16),
                const SizedBox(
                  width: 80,
                  child: Text(
                    'City',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                            ),
                  ),
                ),
                Expanded(
                  child: Text(
                    city,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                            ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(List<dynamic> items, Map<String, dynamic> tripPricing, bool includeGstInTotal) {
    final subtotal = (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0;
    final gstAmount = (tripPricing['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final total = includeGstInTotal ? subtotal + gstAmount : subtotal;

    return _InfoCard(
      title: 'Order Summary',
                      children: [
        // Product rows
        ...items.map((item) {
          final m = item as Map<String, dynamic>;
          final productName = m['productName'] as String? ?? m['name'] as String? ?? 'Unknown';
          final qty = (m['fixedQuantityPerTrip'] as num?)?.toInt() ?? 0;
          final unitPrice = (m['unitPrice'] as num?)?.toDouble() ??
              (m['unit_price'] as num?)?.toDouble() ??
              0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
                          children: [
                Expanded(
                              child: Text(
                    productName,
                    style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                      fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                const SizedBox(width: 8),
                Text(
                  'Qty: $qty',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
          );
        }),
        const Divider(color: Colors.white24, height: 24),
        // Subtotal
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                'Subtotal',
                                  style: TextStyle(
                  color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
            Text(
              '₹${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
                              ),
                            ],
                          ),
        const SizedBox(height: 8),
        // GST
        Row(
                              children: [
            Expanded(
                                  child: Text(
                'GST ${includeGstInTotal ? "(Included)" : "(Excluded)"}',
                                    style: TextStyle(
                  color: includeGstInTotal ? Colors.greenAccent : Colors.white70,
                                      fontSize: 12,
                  fontWeight: includeGstInTotal ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
            Text(
              '₹${gstAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: includeGstInTotal ? Colors.greenAccent : Colors.white70,
                fontSize: 13,
                fontWeight: includeGstInTotal ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                                    ),
        const Divider(color: Colors.white24, height: 24),
        // Total
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                'Total',
                                  style: TextStyle(
                                    color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
            Text(
              '₹${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
                              ),
                            ],
                          ),
                        ],
    );
  }

  Widget _buildTripStatus(String tripStatus, int? dmNumber) {
    final isDispatched = tripStatus.toLowerCase() == 'dispatched';
    final isDelivered = tripStatus.toLowerCase() == 'delivered';
    final isReturned = tripStatus.toLowerCase() == 'returned';
    final isPending = tripStatus.toLowerCase() == 'pending' || tripStatus.toLowerCase() == 'scheduled';
    final hasDM = dmNumber != null;
    
    return _InfoCard(
      title: 'Trip Status',
                              children: [
        Row(
          children: [
                                const Expanded(
                                  child: Text(
                'Status',
                                    style: TextStyle(
                  color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
            Text(
              tripStatus.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                            ),
                          ),
          ],
        ),
                            const SizedBox(height: 12),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),
        Row(
                                      children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dispatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  if (!hasDM && isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Generate DM first',
                        style: TextStyle(
                          color: Colors.orange.withOpacity(0.8),
                          fontSize: 10,
                        ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
            Switch(
              value: isDispatched,
              onChanged: (isPending || isDispatched) && !isDelivered && hasDM
                  ? (value) async {
                      if (value) {
                        // Dispatch - show initial reading dialog
                        await _showInitialReadingDialog(context);
                      } else {
                        // Revert dispatch
                        await _revertDispatch(context);
                      }
                    }
                  : null,
              activeThumbColor: Colors.orange,
                                      ),
          ],
                                ),
        if (isDispatched || isDelivered || isReturned) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                  'Delivery',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Switch(
                value: isDelivered,
                onChanged: (isDispatched && !isDelivered && !isReturned) || (isDelivered && !isReturned)
                    ? (value) async {
                                        if (value) {
                          // Delivery - show delivery photo dialog
                          await _showDeliveryPhotoDialog(context);
                        } else {
                          // Revert delivery - go back to dispatched
                          await _revertDelivery(context);
                                        }
                                      }
                                    : null,
                activeThumbColor: Colors.green,
                              ),
                            ],
                          ),
                        ],
        if (isDelivered || isReturned) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Return',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Switch(
                                value: isReturned,
                onChanged: isDelivered && !isReturned
                    ? (value) async {
                        if (value) {
                          // Return - show final reading dialog
                          await _showFinalReadingDialog(context);
                        }
                      }
                    : isReturned
                        ? (value) async {
                                        if (!value) {
                              // Revert return - go back to delivered
                              await _revertReturn(context);
                                        }
                                      }
                                    : null,
                activeThumbColor: Colors.blue,
                              ),
                            ],
                          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSummary() {
    final paymentType = (_trip['paymentType'] as String?)?.toLowerCase() ?? '';
    if (paymentType.isEmpty) return const SizedBox.shrink();

    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final paymentDetails =
        (_trip['paymentDetails'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final totalPaidStored = (_trip['totalPaidOnReturn'] as num?)?.toDouble();
    final computedPaid = paymentDetails.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
    final totalPaid = totalPaidStored ?? computedPaid;
    final remainingStored = (_trip['remainingAmount'] as num?)?.toDouble();
    final remaining = remainingStored ?? (tripTotal - totalPaid);
    final status = (_trip['paymentStatus'] as String?) ??
        (remaining <= 0.001
            ? 'full'
            : totalPaid > 0
                ? 'partial'
                : 'pending');

    Color statusColor() {
      switch (status.toLowerCase()) {
        case 'full':
          return Colors.greenAccent;
        case 'partial':
          return Colors.orangeAccent;
        default:
          return Colors.white70;
      }
    }

    return _InfoCard(
      title: 'Payments',
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Payment Type',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              paymentType.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Status',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
                          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                color: statusColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor().withOpacity(0.6)),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoRow(
          label: 'Total',
          value: '₹${tripTotal.toStringAsFixed(2)}',
        ),
        _InfoRow(
          label: 'Paid',
          value: '₹${totalPaid.toStringAsFixed(2)}',
        ),
        if (remaining > 0.001)
          _InfoRow(
            label: 'Remaining',
            value: '₹${remaining.toStringAsFixed(2)}',
          ),
        if (paymentDetails.isNotEmpty) ...[
          const Divider(color: Colors.white24, height: 18),
          const Text(
            'Payment Entries',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 6),
          ...paymentDetails.map((p) {
            final name = p['paymentAccountName'] as String? ?? 'Account';
            final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
            final type = (p['paymentAccountType'] as String?) ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                  Expanded(
                                  child: Text(
                      '$name${type.isNotEmpty ? ' (${type.toUpperCase()})' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
            );
          }),
                        ],
                      ],
    );
  }

  Future<void> _revertDispatch(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Dispatch', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to revert dispatch? This will change the trip status back to scheduled.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revert', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting dispatch...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'scheduled',
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'scheduled';
        _trip['tripStatus'] = 'scheduled';
        _trip.remove('initialReading');
        _trip.remove('dispatchedAt');
        _trip.remove('dispatchedBy');
        _trip.remove('dispatchedByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispatch reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert dispatch: $e')),
      );
    }
  }

  Future<void> _revertDelivery(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Delivery', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to revert delivery? This will change the trip status back to dispatched.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revert', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting delivery...')),
      );

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'dispatched',
      );

      // Update local state - remove delivery fields but keep dispatch fields
      setState(() {
        _trip['orderStatus'] = 'dispatched';
        _trip['tripStatus'] = 'dispatched';
        _trip.remove('deliveryPhotoUrl');
        _trip.remove('deliveredAt');
        _trip.remove('deliveredBy');
        _trip.remove('deliveredByRole');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert delivery: $e')),
      );
    }
  }

  Future<void> _showFinalReadingDialog(BuildContext context) async {
    final readingController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Final Meter Reading',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: readingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Final Reading',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Enter final meter reading',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter final reading';
              }
              final reading = double.tryParse(value);
              if (reading == null || reading < 0) {
                return 'Please enter a valid reading';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reading = double.tryParse(readingController.text);
                if (reading != null) {
                  Navigator.of(context).pop(reading);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
                ),
            child: const Text('Submit'),
            ),
          ],
        ),
    );

    if (result != null) {
      await _markAsReturned(context, result);
    }
  }

  Future<void> _markAsReturned(BuildContext context, double finalReading) async {
    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
      return;
    }

    final orgContext = context.read<OrganizationContextCubit>().state;
    final userRole = orgContext.appAccessRole?.name ?? 'unknown';
    final organization = orgContext.organization;
    if (organization == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization not found')),
        );
      }
      return;
    }

    // Get initial reading to calculate distance
    final initialReading = _trip['initialReading'] as double?;
    if (initialReading == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initial reading not found. Cannot calculate distance.')),
        );
      }
      return;
    }

    // Calculate distance travelled
    final distanceTravelled = finalReading - initialReading;
    if (distanceTravelled < 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Final reading cannot be less than initial reading')),
        );
      }
      return;
    }

    // Pricing and payments
    final paymentType = (_trip['paymentType'] as String?)?.toLowerCase() ?? '';
    final tripPricing = _trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final tripTotal = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments =
        (_trip['paymentDetails'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final alreadyPaid = existingPayments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );

    List<Map<String, dynamic>> newPayments = [];
    double newPaidAmount = 0;

    // If pay_on_delivery, collect payment entries
    if (paymentType == 'pay_on_delivery') {
      // Fetch payment accounts
      try {
        final accountsRepo = context.read<PaymentAccountsRepository>();
        final accounts = await accountsRepo.fetchAccounts(organization.id);
        final activeAccounts = accounts.where((a) => a.isActive).toList();

        if (activeAccounts.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active payment accounts found')),
            );
          }
          return;
        }

        final result = await showDialog<List<Map<String, dynamic>>>(
          context: context,
          builder: (ctx) => ReturnPaymentDialog(
            paymentAccounts: activeAccounts,
            tripTotal: tripTotal,
            alreadyPaid: alreadyPaid,
          ),
        );

        if (result == null) {
          // User cancelled payment entry
          return;
        }

        newPayments = result
            .map((p) => {
                  ...p,
                  'paidAt': DateTime.now(),
                  'paidBy': currentUser.uid,
                  'returnPayment': true,
                })
            .toList();
        newPaidAmount = newPayments.fold<double>(
          0,
          (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load payment accounts: $e')),
          );
        }
        return;
      }
    }

    final totalPaidAfter = alreadyPaid + newPaidAmount;
    final double remainingAmount =
        (tripTotal - totalPaidAfter).clamp(0, double.infinity).toDouble();
    final paymentStatus = totalPaidAfter >= tripTotal - 0.001
        ? 'full'
        : totalPaidAfter > 0
            ? 'partial'
            : 'pending';

    // Create transactions for new payments and optional credit
    final transactionsRepo = context.read<TransactionsRepository>();
    final financialYear = FinancialYearUtils.getFinancialYear(DateTime.now());
    final dmNumber = (_trip['dmNumber'] as num?)?.toInt();
    final dmText = dmNumber != null ? 'DM-$dmNumber' : 'Order Payment';
    final clientId = _trip['clientId'] as String? ?? '';
    final orderId = _trip['orderId'] as String? ?? '';

    final List<String> transactionIds =
        (_trip['returnTransactions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

    Future<void> createPaymentTransaction(
      Map<String, dynamic> payment,
      int index,
    ) async {
      final amount = (payment['amount'] as num).toDouble();
      final txnId = await transactionsRepo.createTransaction(
        Transaction(
          id: '',
          organizationId: organization.id,
          clientId: clientId,
          ledgerType: LedgerType.clientLedger,
          type: TransactionType.debit, // Debit = client paid on delivery (decreases receivable)
          category: TransactionCategory.tripPayment, // Payment collected on delivery
          amount: amount,
          paymentAccountId: payment['paymentAccountId'] as String?,
          paymentAccountType: payment['paymentAccountType'] as String?,
          orderId: orderId,
          description: 'Trip Payment - $dmText',
          metadata: {
            'tripId': tripId,
            if (dmNumber != null) 'dmNumber': dmNumber,
            'paymentIndex': index,
            'returnPayment': true,
          },
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          financialYear: financialYear,
        ),
      );
      transactionIds.add(txnId);
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marking trip as returned...')),
      );

      // Create payment transactions (debit) for pay_on_delivery
      // Note: Order Credit transaction was already created at DM generation (dispatch)
      for (int i = 0; i < newPayments.length; i++) {
        await createPaymentTransaction(newPayments[i], i);
      }

      // For pay_on_delivery: Order Credit transaction was created at DM generation (dispatch)
      // Trip Payment (debit) transactions are created above when payment is received on return
      // If partial payment, the remaining amount is already covered by the credit transaction
      
      // For pay_later: Order Credit transaction was created at DM generation (dispatch)
      // No additional transactions needed at return (customer pays later via manual Debit Payment)

      // Update trip with status + payment info
      final repository = context.read<ScheduledTripsRepository>();
      final combinedPayments = [...existingPayments, ...newPayments];

      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'returned',
        finalReading: finalReading,
        distanceTravelled: distanceTravelled,
        returnedBy: currentUser.uid,
        returnedByRole: userRole,
        paymentDetails: combinedPayments,
        totalPaidOnReturn: totalPaidAfter,
        paymentStatus: paymentStatus,
        remainingAmount: paymentType == 'pay_on_delivery' ? remainingAmount : null,
        returnTransactions: transactionIds,
      );

      // Update local state
      setState(() {
        _trip['orderStatus'] = 'returned';
        _trip['tripStatus'] = 'returned';
        _trip['finalReading'] = finalReading;
        _trip['distanceTravelled'] = distanceTravelled;
        _trip['returnedAt'] = DateTime.now();
        _trip['returnedBy'] = currentUser.uid;
        _trip['returnedByRole'] = userRole;
        _trip['paymentDetails'] = combinedPayments;
        _trip['totalPaidOnReturn'] = totalPaidAfter;
        _trip['paymentStatus'] = paymentStatus;
        if (paymentType == 'pay_on_delivery') {
          _trip['remainingAmount'] = remainingAmount;
        } else {
          _trip.remove('remainingAmount');
        }
        _trip['returnTransactions'] = transactionIds;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trip marked as returned. Distance: ${distanceTravelled.toStringAsFixed(2)} km',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as returned: $e')),
      );
    }
  }

  Future<void> _revertReturn(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text('Revert Return', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to revert return? This will change the trip status back to delivered.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revert', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final tripId = _trip['id'] as String?;
    if (tripId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
      }
      return;
    }

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverting return...')),
      );

      // Cancel transactions created during return (if any)
      final transactionIds = (_trip['returnTransactions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final transactionsRepo = context.read<TransactionsRepository>();
        for (final txnId in transactionIds) {
          try {
            await transactionsRepo.cancelTransaction(
              transactionId: txnId,
              cancelledBy: currentUser.uid,
              cancellationReason: 'Return reverted - trip moved to delivered',
            );
          } catch (_) {
            // continue cancelling others
          }
        }
      }

      final repository = context.read<ScheduledTripsRepository>();
      await repository.updateTripStatus(
        tripId: tripId,
        tripStatus: 'delivered',
        paymentDetails: const [],
        totalPaidOnReturn: null,
        paymentStatus: null,
        remainingAmount: null,
        returnTransactions: const [],
        clearPaymentInfo: true,
      );

      // Update local state - remove return fields but keep delivery and dispatch fields
      setState(() {
        _trip['orderStatus'] = 'delivered';
        _trip['tripStatus'] = 'delivered';
        _trip.remove('finalReading');
        _trip.remove('distanceTravelled');
        _trip.remove('returnedAt');
        _trip.remove('returnedBy');
        _trip.remove('returnedByRole');
        _trip.remove('paymentDetails');
        _trip.remove('totalPaidOnReturn');
        _trip.remove('paymentStatus');
        _trip.remove('remainingAmount');
        _trip.remove('returnTransactions');
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return reverted successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revert return: $e')),
      );
    }
  }


  Future<void> _callNumber(String? phone, String label) async {
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label phone not available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not call $label')),
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.greenAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class _PaymentDetailsSection extends StatefulWidget {
  const _PaymentDetailsSection({
    required this.trip,
    required this.onPaymentUpdated,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onPaymentUpdated;

  @override
  State<_PaymentDetailsSection> createState() => _PaymentDetailsSectionState();
}

class _PaymentDetailsSectionState extends State<_PaymentDetailsSection> {
  List<PaymentAccount>? _paymentAccounts;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) return;

    try {
      setState(() => _isLoading = true);
      final repo = context.read<PaymentAccountsRepository>();
      final accounts = await repo.fetchAccounts(organization.id);
      // Filter only active accounts
      setState(() {
        _paymentAccounts = accounts.where((a) => a.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payment accounts: $e')),
        );
      }
    }
  }

  Future<void> _showAddPaymentDialog() async {
    if (_paymentAccounts == null || _paymentAccounts!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active payment accounts available')),
        );
      }
      return;
    }

    PaymentAccount? selectedAccount;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AuthColors.surface,
          title: const Text(
            'Add Payment',
            style: TextStyle(color: AuthColors.textMain),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<PaymentAccount>(
                    initialValue: selectedAccount,
                    decoration: InputDecoration(
                      labelText: 'Payment Account',
                      labelStyle: const TextStyle(color: AuthColors.textSub),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    items: _paymentAccounts!.map((account) {
                      return DropdownMenuItem<PaymentAccount>(
                        value: account,
                        child: Text('${account.name} (${account.type.name})'),
                      );
                    }).toList(),
                    onChanged: (account) {
                      setDialogState(() => selectedAccount = account);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a payment account';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: const TextStyle(color: AuthColors.textSub),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (shouldAdd == true && selectedAccount != null) {
      final amount = double.tryParse(amountController.text);
      if (amount != null && amount > 0) {
        await _addPayment(selectedAccount!, amount);
      }
    }
  }

  Future<void> _addPayment(PaymentAccount account, double amount) async {
    final tripId = widget.trip['id'] as String?;
    if (tripId == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) return;

    final tripPricing = widget.trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final totalAmount = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments = (widget.trip['paymentDetails'] as List<dynamic>?) ?? [];
    final paidAmount = existingPayments.fold<double>(
      0.0,
      (sum, payment) {
        final amount = (payment as Map<String, dynamic>)['amount'] as num?;
        return sum + (amount?.toDouble() ?? 0.0);
      },
    );

    if (paidAmount + amount > totalAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment amount exceeds total. Remaining: ₹${(totalAmount - paidAmount).toStringAsFixed(2)}')),
        );
      }
      return;
    }

    try {
      setState(() => _isSubmitting = true);

      final paymentDetail = {
        'paymentAccountId': account.id,
        'paymentAccountName': account.name,
        'paymentAccountType': account.type.name,
        'amount': amount,
        'paidAt': DateTime.now(),
        'paidBy': currentUser.uid,
      };

      // Create transaction
      final transactionsRepo = context.read<TransactionsRepository>();
      final financialYear = FinancialYearUtils.getFinancialYear(DateTime.now());
      final clientId = widget.trip['clientId'] as String? ?? '';
      final orderId = widget.trip['orderId'] as String? ?? '';
      final dmNumber = (widget.trip['dmNumber'] as num?)?.toInt();
      final dmText = dmNumber != null ? 'DM-$dmNumber' : 'Order Payment';

      await transactionsRepo.createTransaction(
        Transaction(
          id: '',
          organizationId: organization.id,
          clientId: clientId,
          ledgerType: LedgerType.clientLedger,
          type: TransactionType.debit, // Debit = client paid on delivery (decreases receivable)
          category: TransactionCategory.tripPayment, // Payment collected on delivery
          amount: amount,
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          financialYear: financialYear,
          paymentAccountId: account.id,
          paymentAccountType: account.type.name,
          orderId: orderId,
          description: 'Trip Payment - $dmText',
          metadata: {
            'tripId': tripId,
            if (dmNumber != null) 'dmNumber': dmNumber,
          },
        ),
      );

      // Update local state
      final updatedPayments = List<Map<String, dynamic>>.from(existingPayments);
      updatedPayments.add(paymentDetail);
      widget.trip['paymentDetails'] = updatedPayments;

      setState(() => _isSubmitting = false);
      widget.onPaymentUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add payment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripPricing = widget.trip['tripPricing'] as Map<String, dynamic>? ?? {};
    final totalAmount = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final existingPayments = (widget.trip['paymentDetails'] as List<dynamic>?) ?? [];
    final paidAmount = existingPayments.fold<double>(
      0.0,
      (sum, payment) {
        final amount = (payment as Map<String, dynamic>)['amount'] as num?;
        return sum + (amount?.toDouble() ?? 0.0);
      },
    );
    final remainingAmount = totalAmount - paidAmount;

    return _InfoCard(
      title: 'Payment Details',
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total Amount',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '₹${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Paid Amount',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '₹${paidAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: paidAmount > 0 ? Colors.green : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Remaining',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '₹${remainingAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: remainingAmount > 0 ? Colors.orange : Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (existingPayments.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          ...existingPayments.map((payment) {
            final paymentMap = payment as Map<String, dynamic>;
            final amount = (paymentMap['amount'] as num?)?.toDouble() ?? 0.0;
            final accountName = paymentMap['paymentAccountName'] as String? ?? 'Unknown';
            final accountType = paymentMap['paymentAccountType'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accountName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          accountType,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        if (remainingAmount > 0 && !_isSubmitting) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _showAddPaymentDialog,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Payment'),
            ),
          ),
        ],
        if (_isSubmitting) ...[
          const SizedBox(height: 12),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }
}


