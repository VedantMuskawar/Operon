import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/core/services/dm_print_helper.dart';
import 'package:operon_driver_android/core/utils/trip_status_utils.dart';
import 'package:operon_driver_android/presentation/widgets/driver_dm_print_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverMissionCard extends StatelessWidget {
  const DriverMissionCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  Future<void> _callClient(BuildContext context) async {
    final phone = trip['customerNumber'] as String? ?? trip['clientPhone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not available'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone app'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openPrintDm(BuildContext context) async {
    final org = context.read<OrganizationContextCubit>().state.organization;
    if (org == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select an organization first'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
      return;
    }
    final helper = context.read<DmPrintHelper>();
    final dmNumber = trip['dmNumber'] as int?;
    if (dmNumber == null) return;
    final dmData = await helper.fetchDmByNumberOrId(
      organizationId: org.id,
      dmNumber: dmNumber,
      dmId: trip['dmId'] as String?,
      tripData: trip,
    );
    if (dmData == null || !context.mounted) return;
    showDriverDmPrintSheet(
      context: context,
      organizationId: org.id,
      dmData: dmData,
      dmNumber: dmNumber,
      dmPrintHelper: helper,
    );
  }

  Future<void> _openMap(BuildContext context) async {
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>?;
    final region = deliveryZone?['region'] as String?;
    final city = deliveryZone?['city_name'] as String? ?? deliveryZone?['city'] as String?;

    String query = '';
    if (region != null && city != null) {
      query = '$region, $city';
    } else if (region != null) {
      query = region;
    } else if (city != null) {
      query = city;
    }

    if (query.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location details not available'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open maps app'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = trip['slot'] as int?;
    final slotName = trip['slotName'] as String?;
    final vehicleNumber = trip['vehicleNumber'] as String?;
    final clientName = (trip['clientName'] as String?) ?? 'Client';
    final status = getTripStatus(trip);
    final deliveryZone = trip['deliveryZone'] as Map<String, dynamic>?;
    final locationText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'Location details inside';
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor, // Use solid status color for background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: Colors.white60,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationText,
                                  style: const TextStyle(
                                    color: Colors.white60,
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
                    const SizedBox(width: 8),
                    // Vehicle and Slot info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B2C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
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
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicleNumber ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white70,
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
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                slot != null ? 'Slot $slot' : slotName ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.white70,
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
              ],
            ),
          ),
          // DM info (if generated)
          if (status == 'scheduled' || status == 'pending') ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final dmNumber = trip['dmNumber'] as int?;
                final hasDM = dmNumber != null;
                if (hasDM) {
                  return InkWell(
                    onTap: () => _openPrintDm(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DM-$dmNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.print_outlined,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'DM Required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
          // Action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  color: Colors.green.withOpacity(0.3),
                  onTap: () => _callClient(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.map,
                  label: 'Map',
                  color: Colors.blue.withOpacity(0.3),
                  onTap: () => _openMap(context),
                ),
              ),
            ],
          ),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
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
