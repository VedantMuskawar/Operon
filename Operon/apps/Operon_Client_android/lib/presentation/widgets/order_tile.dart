import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/views/orders/pending_order_detail_page.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTile extends StatefulWidget {
  const OrderTile({
    super.key,
    required this.order,
    required this.onTripsUpdated,
    required this.onDeleted,
  });

  final Map<String, dynamic> order;
  final VoidCallback onTripsUpdated;
  final VoidCallback onDeleted;

  @override
  State<OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<OrderTile> {
  bool _isDeleting = false;

  Color _getPriorityBorderColor() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? const Color(0xFFD4AF37) // Gold
        : const Color(0xFFC0C0C0); // Silver
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as dynamic).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatETAText(DateTime etaDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final etaDay = DateTime(etaDate.year, etaDate.month, etaDate.day);
    final daysDiff = etaDay.difference(today).inDays;

    if (daysDiff == 0) {
      return 'Est. delivery: Today';
    } else if (daysDiff == 1) {
      return 'Est. delivery: Tomorrow';
    } else if (daysDiff < 0) {
      return 'Est. delivery: Overdue';
    } else {
      return 'Est. delivery: ${_formatDate(etaDate)}';
    }
  }

  Color _getETAColor(int daysDiff) {
    if (daysDiff < 0) {
      return Colors.red;
    } else if (daysDiff == 0 || daysDiff == 1) {
      return const Color(0xFF4CAF50);
    } else if (daysDiff <= 3) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }

  Widget _buildETALabel(dynamic timestamp) {
    if (timestamp == null) return const SizedBox.shrink();

    try {
      DateTime etaDate;
      if (timestamp is DateTime) {
        etaDate = timestamp;
      } else {
        etaDate = (timestamp as dynamic).toDate();
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final etaDay = DateTime(etaDate.year, etaDate.month, etaDate.day);
      final daysDiff = etaDay.difference(today).inDays;

      final color = _getETAColor(daysDiff);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              _formatETAText(etaDate),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }


  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF11111B),
        title: const Text('Delete Order', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this order?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final repository = context.read<PendingOrdersRepository>();
      await repository.deleteOrder(widget.order['id'] as String);
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _callClient() async {
    final phone = widget.order['clientPhone'] as String?;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone app')),
        );
      }
    }
  }

  Future<void> _openScheduleModal() async {
    final clientId = widget.order['clientId'] as String?;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    
    if (clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client information not available')),
      );
      return;
    }

    // Fetch client phones
    try {
      final clientService = ClientService();
      final client = await clientService.findClientByPhone(
        widget.order['clientPhone'] as String? ?? '',
      );
      
      if (client == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client not found')),
        );
        return;
      }

      // Get phone numbers from client
      final phones = client.phones;
      if (phones.isEmpty && client.primaryPhone != null) {
        phones.add({
          'number': client.primaryPhone,
          'normalized': client.primaryPhone,
        });
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => ScheduleTripModal(
          order: widget.order,
          clientId: clientId,
          clientName: clientName,
          clientPhones: phones,
          onScheduled: widget.onTripsUpdated,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open schedule modal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final estimatedTrips = firstItem?['estimatedTrips'] as int? ?? 0;
    final totalScheduledTrips = widget.order['totalScheduledTrips'] as int? ?? 0;
    final totalTrips = totalScheduledTrips + estimatedTrips;
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip = firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    final deliveryZone = widget.order['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final createdAt = widget.order['createdAt'];
    final priorityColor = _getPriorityBorderColor();
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    final estimatedDeliveryDate = autoSchedule?['estimatedDeliveryDate'];

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PendingOrderDetailPage(order: widget.order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131324),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: priorityColor.withOpacity(0.6),
            width: 1.5,
          ),
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
          // Header: Client name and Trip counter
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
                            zoneText,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (estimatedDeliveryDate != null) ...[
                      const SizedBox(height: 4),
                      _buildETALabel(estimatedDeliveryDate),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Scheduled trips counter (X/Y format)
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
                child: Text(
                  '$totalScheduledTrips/$totalTrips',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Product and quantity info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2C).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Qty: $fixedQuantityPerTrip',
                  style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Compact action buttons
          Row(
            children: [
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.red,
                  onTap: _isDeleting ? null : _deleteOrder,
                  isLoading: _isDeleting,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.phone_outlined,
                  label: 'Call',
                  color: Colors.green,
                  onTap: _callClient,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactActionButton(
                  icon: Icons.schedule_outlined,
                  label: 'Schedule',
                  color: Colors.blue,
                  onTap: estimatedTrips > 0 ? _openScheduleModal : null,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white70,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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

