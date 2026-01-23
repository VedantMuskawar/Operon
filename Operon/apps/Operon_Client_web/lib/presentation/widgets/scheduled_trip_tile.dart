import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_web/data/repositories/delivery_memo_repository.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/widgets/dm_preview_modal.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/schedule_trip_modal.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class _ScheduledTripTileState extends State<ScheduledTripTile> {
  bool _isRescheduling = false;

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

  Future<void> _generateDM() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (organization == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization or user not found')),
      );
      return;
    }

    final tripId = widget.trip['id'] as String?;
    final scheduleTripId = widget.trip['scheduleTripId'] as String?;

    if (tripId == null || scheduleTripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID or Schedule Trip ID not found')),
      );
      return;
    }

    try {
      final dmRepo = context.read<DeliveryMemoRepository>();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating DM...')),
      );

      final dmId = await dmRepo.generateDM(
        organizationId: organization.id,
        tripId: tripId,
        scheduleTripId: scheduleTripId,
        tripData: widget.trip,
        generatedBy: currentUser.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DM generated: $dmId')),
      );
      
      if (widget.onTripsUpdated != null) {
        widget.onTripsUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate DM: $e')),
      );
    }
  }

  Future<void> _cancelDM() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final tripId = widget.trip['id'] as String?;

    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID not found')),
      );
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AuthColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dmRepo = context.read<DeliveryMemoRepository>();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelling DM...')),
      );

      await dmRepo.cancelDM(
        tripId: tripId,
        cancelledBy: currentUser.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DM cancelled successfully')),
      );
      
      if (widget.onTripsUpdated != null) {
        widget.onTripsUpdated!();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel DM: $e')),
      );
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

    try {
      final printService = context.read<DmPrintService>();
      
      // Load full DM document from Firestore
      final dmData = await printService.fetchDmByNumberOrId(
        organizationId: organization.id,
        dmNumber: dmNumber,
        dmId: dmId,
      );

      if (dmData == null) {
        DashSnackbar.show(
          context,
          message: 'DM not found',
          isError: true,
        );
        return;
      }

      // Show loading dialog while generating HTML
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            color: AuthColors.surface,
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AuthColors.info),
                  SizedBox(height: 16),
                  Text(
                    'Loading DM Preview...',
                    style: TextStyle(color: AuthColors.textMain),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        // Generate preview content (HTML for universal, PDF for custom)
        if (!mounted) return;
        final previewContent = await printService.generateDmPreviewContent(
          organizationId: organization.id,
          dmData: dmData,
        );
        
        // Close loading dialog
        if (!mounted) return;
        Navigator.of(context).pop();
        
        if (!mounted) return;
        // Show preview in modal
        await DmPreviewModal.show(
          context: context,
          htmlString: previewContent['type'] == 'html' 
              ? previewContent['content'] as String? 
              : null,
          pdfBytes: previewContent['type'] == 'pdf' 
              ? previewContent['content'] as Uint8List? 
              : null,
        );
      } catch (e) {
        // Close loading dialog on error
        if (mounted) {
          Navigator.of(context).pop();
        }
        rethrow;
      }
    } catch (e) {
      if (!mounted) return;
      DashSnackbar.show(
        context,
        message: 'Failed to print DM: ${e.toString()}',
        isError: true,
      );
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
                      hintStyle: TextStyle(color: AuthColors.textMainWithOpacity(0.3)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AuthColors.textMainWithOpacity(0.3)),
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop({
                          'confirmed': true,
                          'reason': reasonController.text.trim(),
                        }),
                child: const Text(
                  'Reschedule',
                  style: TextStyle(color: AuthColors.warning),
                ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip ID not found')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order or client information not available')),
        );
        return;
      }

      final clientsRepo = context.read<ClientsRepository>();
      List<Map<String, dynamic>> clientPhones = [];
      
      if (customerNumber != null && customerNumber.isNotEmpty) {
        try {
          final client = await clientsRepo.findClientByPhone(customerNumber);
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
        'deliveryZone': widget.trip['deliveryZone'] as Map<String, dynamic>? ?? {},
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule trip: $e')),
        );
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
    final vehicleNumber = widget.trip['vehicleNumber'] as String? ?? 'N/A';
    final slot = widget.trip['slot'] as int? ?? 0;
    final deliveryZone = widget.trip['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final statusColor = _getStatusColor();
    
    final items = widget.trip['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip = firstItem?['fixedQuantityPerTrip'] as int? ?? 0;

    final tripPricing = widget.trip['tripPricing'] as Map<String, dynamic>?;
    final tripSubtotal = (tripPricing?['subtotal'] as num?)?.toDouble() ?? 0.0;
    final tripGstAmount = (tripPricing?['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final tripTotal = (tripPricing?['total'] as num?)?.toDouble() ?? 0.0;
    final paymentType = widget.trip['paymentType'] as String? ?? 'pay_later';

    final dmNumber = widget.trip['dmNumber'] as int?;
    final hasDM = dmNumber != null;

    final tripStatus = widget.trip['tripStatus'] as String? ?? 
                       widget.trip['orderStatus'] as String? ?? 
                       'scheduled';

    final showActions = tripStatus.toLowerCase() == 'scheduled' || 
                        tripStatus.toLowerCase() == 'dispatched';
    
    // DM generation should only be available for scheduled trips (DM required before dispatch)
    final canGenerateDM = tripStatus.toLowerCase() == 'scheduled' && !hasDM;

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
            padding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 0),
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
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                vehicleNumber,
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
                                'Slot $slot',
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
                
                // Product and Quantity
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AuthColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AuthColors.success.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Qty: $fixedQuantityPerTrip',
                        style: TextStyle(
                          color: AuthColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // DM Information - Clickable DM Number (access point for printing)
                if (hasDM) ...[
                  InkWell(
                    onTap: () => _showPrintDialog(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            color: AuthColors.info,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'DM Generated: $dmNumber',
                            style: const TextStyle(
                              color: AuthColors.info,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                            onTap: () {
                              // TODO: Navigate to DM view
                            },
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
                  valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
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
