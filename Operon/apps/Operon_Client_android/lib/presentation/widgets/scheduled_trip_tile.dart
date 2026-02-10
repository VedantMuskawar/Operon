import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/repositories/delivery_memo_repository.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/dm_print_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class ScheduledTripTile extends StatelessWidget {
  const ScheduledTripTile({
    super.key,
    required this.trip,
    required this.onReschedule,
    this.onOpenDetails,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onReschedule;
  final VoidCallback? onOpenDetails;

  Future<void> _callClient(BuildContext context) async {
    final phone =
        trip['customerNumber'] as String? ?? trip['clientPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone app')),
        );
      }
    }
  }

  Color _getStatusColor() {
    final orderStatus = trip['orderStatus'] as String? ?? 'pending';
    switch (orderStatus.toLowerCase()) {
      case 'pending':
        return AuthColors.error;
      case 'scheduled':
        return AuthColors.error; // Scheduled status color
      case 'dispatched':
        return AuthColors.warning; // Dispatched status color
      case 'delivered':
        return AuthColors.info; // Blue color for delivered
      case 'returned':
        return AuthColors.success;
      default:
        return AuthColors.error; // Default to scheduled color
    }
  }

  Future<void> _openPrintDialog(BuildContext context) async {
    final org = context.read<OrganizationContextCubit>().state.organization;
    if (org == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization first')),
      );
      return;
    }
    final printService = context.read<DmPrintService>();
    final dmNumber = (trip['dmNumber'] as num?)?.toInt();
    if (dmNumber == null) return;
    final dmData = await printService.fetchDmByNumberOrId(
      organizationId: org.id,
      dmNumber: dmNumber,
      dmId: trip['dmId'] as String?,
      tripData: trip,
    );
    if (dmData == null || !context.mounted) return;
    await DmPrintDialog.show(
      context: context,
      dmPrintService: printService,
      organizationId: org.id,
      dmData: dmData,
      dmNumber: dmNumber,
    );
  }

  Future<void> _generateDM(BuildContext context) async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (organization == null || currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization or user not found')),
      );
      return;
    }

    final tripId = trip['id'] as String?;
    final scheduleTripId = trip['scheduleTripId'] as String?;
    final scheduledDate = trip['scheduledDate'];

    // Validate required fields
    if (tripId == null || tripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID not found')),
      );
      return;
    }

    if (scheduleTripId == null || scheduleTripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule Trip ID not found')),
      );
      return;
    }

    if (scheduledDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Scheduled date is missing from trip data')),
      );
      return;
    }

    try {
      final dmRepo = context.read<DeliveryMemoRepository>();

      // Show loading
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating DM...'),
          duration: Duration(seconds: 30), // Longer duration for network calls
        ),
      );

      final dmId = await dmRepo.generateDM(
        organizationId: organization.id,
        tripId: tripId,
        scheduleTripId: scheduleTripId,
        tripData: trip,
        generatedBy: currentUser.uid,
      );

      if (!context.mounted) return;
      // Hide previous snackbar and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DM generated successfully: $dmId'),
          backgroundColor: AuthColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      // Log the full error for debugging
      debugPrint('Error generating DM: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Trip data keys: ${trip.keys.toList()}');
      debugPrint('Trip ID: $tripId, Schedule Trip ID: $scheduleTripId');
      debugPrint(
          'Scheduled date: $scheduledDate (type: ${scheduledDate.runtimeType})');

      if (!context.mounted) return;

      // Provide more user-friendly error message
      String errorMessage = 'Failed to generate DM';
      if (e.toString().contains('scheduledDate')) {
        errorMessage = 'Invalid scheduled date format. Please try again.';
      } else if (e.toString().contains('already exists')) {
        errorMessage = 'DM already exists for this trip';
      } else if (e.toString().contains('Missing required')) {
        errorMessage =
            'Missing required trip information. Please refresh and try again.';
      } else {
        errorMessage =
            'Failed to generate DM: ${e.toString().split('\n').first}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AuthColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _cancelDM(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final tripId = trip['id'] as String?;

    if (tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip ID not found')),
      );
      return;
    }

    // Show confirmation dialog
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

      // Show loading
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelling DM...')),
      );

      await dmRepo.cancelDM(
        tripId: tripId,
        cancelledBy: currentUser.uid,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DM cancelled successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel DM: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = trip['clientName'] as String? ?? 'N/A';
    final vehicleNumber = trip['vehicleNumber'] as String? ?? 'N/A';
    final slot = trip['slot'] as int? ?? 0;
    final orderStatus = trip['orderStatus'] as String? ?? 'pending';
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final statusColor = _getStatusColor();

    // Get product info from items
    final items = trip['items'] as List<dynamic>? ?? [];
    final firstItem =
        items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip =
        firstItem?['fixedQuantityPerTrip'] as int? ?? 0;

    // Check if DM exists
    final dmNumber = trip['dmNumber'] as int?;
    final hasDM = dmNumber != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        color: statusColor, // Use solid status color for background
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        boxShadow: [
          BoxShadow(
            color: AuthColors.background.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tappable content area
          InkWell(
            onTap: onOpenDetails,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Client name and Vehicle/Slot info
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.paddingXS / 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AuthColors.textSub.withOpacity(0.6),
                              ),
                              const SizedBox(width: AppSpacing.paddingXS),
                              Expanded(
                                child: Text(
                                  zoneText,
                                  style: TextStyle(
                                    color: AuthColors.textSub.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.paddingSM),
                    // Vehicle and Slot info
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.paddingSM,
                          vertical: AppSpacing.paddingXS),
                      decoration: BoxDecoration(
                        color: AuthColors.backgroundAlt,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSM),
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
                              const SizedBox(width: AppSpacing.paddingXS),
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
                          const SizedBox(height: AppSpacing.paddingXS / 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 12,
                                color: AuthColors.textSub,
                              ),
                              const SizedBox(width: AppSpacing.paddingXS),
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
                const SizedBox(height: AppSpacing.paddingMD),
                // Product and quantity info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.paddingSM,
                          vertical: AppSpacing.paddingXS),
                      decoration: BoxDecoration(
                        color: AuthColors.backgroundAlt.withOpacity(0.5),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 12,
                            color: AuthColors.textSub,
                          ),
                          const SizedBox(width: AppSpacing.paddingXS),
                          Text(
                            productName,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gapSM),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gapSM,
                          vertical: AppSpacing.paddingXS),
                      decoration: BoxDecoration(
                        color: AuthColors.success.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                      child: Text(
                        'Qty: $fixedQuantityPerTrip',
                        style: const TextStyle(
                          color: AuthColors.successVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons for pending/scheduled/dispatched/delivered/returned orders (outside InkWell)
          if (orderStatus.toLowerCase() == 'pending' ||
              orderStatus.toLowerCase() == 'scheduled' ||
              orderStatus.toLowerCase() == 'dispatched' ||
              orderStatus.toLowerCase() == 'delivered' ||
              orderStatus.toLowerCase() == 'returned') ...[
            const SizedBox(height: AppSpacing.paddingMD),
            Column(
              children: [
                // Row 1: DM button (full width) - Always show DM number if it exists
                // For delivered and returned, always show DM number if it exists
                if (hasDM)
                  _ActionButton(
                    icon: Icons.receipt_long,
                    label: 'DM-$dmNumber',
                    color: AuthColors.info.withOpacity(0.3),
                    onTap: () => _openPrintDialog(context),
                  )
                else if (orderStatus.toLowerCase() != 'dispatched' &&
                    orderStatus.toLowerCase() != 'delivered' &&
                    orderStatus.toLowerCase() != 'returned')
                  _ActionButton(
                    icon: Icons.receipt_long,
                    label: 'Generate DM',
                    color: AuthColors.info.withOpacity(0.3),
                    onTap: () => _generateDM(context),
                  ),
                if (hasDM ||
                    (orderStatus.toLowerCase() != 'dispatched' &&
                        orderStatus.toLowerCase() != 'delivered' &&
                        orderStatus.toLowerCase() != 'returned'))
                  const SizedBox(height: AppSpacing.gapSM),
                // Row 2: Call and Cancel DM / Reschedule
                // Always show Call button for all statuses including delivered and returned
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        color: AuthColors.success.withOpacity(0.3),
                        onTap: () => _callClient(context),
                      ),
                    ),
                    if (orderStatus.toLowerCase() != 'dispatched' &&
                        orderStatus.toLowerCase() != 'delivered' &&
                        orderStatus.toLowerCase() != 'returned') ...[
                      const SizedBox(width: AppSpacing.gapSM),
                      Expanded(
                        child: _ActionButton(
                          icon: hasDM ? Icons.cancel_outlined : Icons.schedule,
                          label: hasDM ? 'Cancel DM' : 'Reschedule',
                          color: AuthColors.warning.withOpacity(0.3),
                          onTap:
                              hasDM ? () => _cancelDM(context) : onReschedule,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
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
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingSM, vertical: AppSpacing.gapSM),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AuthColors.textMain, size: 14),
            const SizedBox(width: AppSpacing.paddingXS),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
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
