import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/widgets/schedule_trip_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingOrderDetailPage extends StatefulWidget {
  const PendingOrderDetailPage({
    super.key,
    required this.order,
  });

  final Map<String, dynamic> order;

  @override
  State<PendingOrderDetailPage> createState() => _PendingOrderDetailPageState();
}

class _PendingOrderDetailPageState extends State<PendingOrderDetailPage> {
  List<Map<String, dynamic>> _scheduledTrips = [];
  bool _isLoadingTrips = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadScheduledTrips();
  }

  Future<void> _loadScheduledTrips() async {
    final orderId = widget.order['id'] as String?;
    if (orderId == null) {
      setState(() => _isLoadingTrips = false);
      return;
    }

    setState(() => _isLoadingTrips = true);
    try {
      final repository = context.read<ScheduledTripsRepository>();
      final trips = await repository.getScheduledTripsForOrder(orderId);
      if (mounted) {
        setState(() {
          _scheduledTrips = trips;
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrips = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
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

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = (timestamp as Timestamp).toDate();
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  Color _getPriorityColor() {
    final priority = widget.order['priority'] as String? ?? 'normal';
    return priority == 'high' || priority == 'priority'
        ? const Color(0xFFD4AF37)
        : const Color(0xFFC0C0C0);
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
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete order: $e')),
        );
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
          onScheduled: () {
            _loadScheduledTrips();
          },
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
    final totalScheduledTrips = widget.order['totalScheduledTrips'] as int? ?? 0;
    // Calculate total estimated trips from all items
    int totalEstimatedTrips = 0;
    for (final item in items) {
      final itemMap = item as Map<String, dynamic>;
      totalEstimatedTrips += (itemMap['estimatedTrips'] as int? ?? 0);
    }
    // If no estimated trips in items, fallback to tripIds length or first item
    if (totalEstimatedTrips == 0) {
      totalEstimatedTrips = firstItem?['estimatedTrips'] as int? ?? 
          (widget.order['tripIds'] as List<dynamic>?)?.length ?? 0;
    }
    final estimatedTrips = totalEstimatedTrips - totalScheduledTrips;
    final totalTrips = totalScheduledTrips + (estimatedTrips > 0 ? estimatedTrips : 0);
    final productName = firstItem?['productName'] as String? ?? 'N/A';
    final fixedQuantityPerTrip = firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
    final totalQuantity = estimatedTrips * fixedQuantityPerTrip;
    final clientName = widget.order['clientName'] as String? ?? 'N/A';
    final clientPhone = widget.order['clientPhone'] as String? ?? 'N/A';
    final deliveryZone = widget.order['deliveryZone'] as Map<String, dynamic>?;
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : 'N/A';
    final priorityColor = _getPriorityColor();
    final priority = widget.order['priority'] as String? ?? 'normal';
    final createdAt = widget.order['createdAt'];
    final updatedAt = widget.order['updatedAt'];
    final autoSchedule = widget.order['autoSchedule'] as Map<String, dynamic>?;
    final estimatedDeliveryDate = autoSchedule?['estimatedDeliveryDate'];

    return Scaffold(
      backgroundColor: const Color(0xFF010104),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${widget.order['id'] ?? 'N/A'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: priorityColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Info Card
                    _InfoCard(
                      title: 'Client Information',
                      children: [
                        _InfoRow(label: 'Name', value: clientName),
                        _InfoRow(
                          label: 'Phone',
                          value: clientPhone,
                          isTappable: true,
                          onTap: _callClient,
                        ),
                        _InfoRow(label: 'Zone', value: zoneText),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Order Summary Card
                    _InfoCard(
                      title: 'Order Summary',
                      children: [
                        _InfoRow(label: 'Product', value: productName),
                        _InfoRow(label: 'Qty/Trip', value: fixedQuantityPerTrip.toString()),
                        _InfoRow(label: 'Total Qty', value: totalQuantity.toString()),
                        _InfoRow(
                          label: 'GST Included',
                          value: (widget.order['includeGstInTotal'] as bool? ?? true)
                              ? 'Yes'
                              : 'No',
                        ),
                        if (estimatedDeliveryDate != null)
                          _InfoRow(
                            label: 'Est. Delivery',
                            value: _formatDate(estimatedDeliveryDate),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Trip Status Card
                    _InfoCard(
                      title: 'Trip Status',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatBox(
                                label: 'Scheduled',
                                value: totalScheduledTrips.toString(),
                                color: const Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatBox(
                                label: 'Pending',
                                value: estimatedTrips.toString(),
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatBox(
                                label: 'Total',
                                value: totalTrips.toString(),
                                color: const Color(0xFF6F4BFF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalTrips > 0 ? totalScheduledTrips / totalTrips : 0,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalScheduledTrips == totalTrips
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF6F4BFF),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Scheduled Trips Card
                    if (_isLoadingTrips)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_scheduledTrips.isNotEmpty) ...[
                      _InfoCard(
                        title: 'Scheduled Trips (${_scheduledTrips.length})',
                        children: [
                          ..._scheduledTrips.asMap().entries.map((entry) {
                            final index = entry.key;
                            final trip = entry.value;
                            final scheduledDate = trip['scheduledDate'];
                            final scheduledDay = trip['scheduledDay'] as String? ?? '';
                            final vehicleNumber = trip['vehicleNumber'] as String? ?? 'N/A';
                            final slot = trip['slot'] as int?;
                            final status = trip['tripStatus'] as String? ?? 'scheduled';

                            return Padding(
                              padding: EdgeInsets.only(bottom: index < _scheduledTrips.length - 1 ? 12 : 0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13131E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6F4BFF).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.schedule,
                                        color: Color(0xFF6F4BFF),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${scheduledDay.capitalizeFirst()} - ${_formatDate(scheduledDate)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                vehicleNumber,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              if (slot != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF6F4BFF).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Slot $slot',
                                                    style: const TextStyle(
                                                      color: Color(0xFF6F4BFF),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'in_progress'
                                            ? Colors.orange.withOpacity(0.2)
                                            : const Color(0xFF4CAF50).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status == 'in_progress' ? 'In Progress' : 'Scheduled',
                                        style: TextStyle(
                                          color: status == 'in_progress'
                                              ? Colors.orange
                                              : const Color(0xFF4CAF50),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Order Details Card
                    _InfoCard(
                      title: 'Order Details',
                      children: [
                        _InfoRow(label: 'Created', value: _formatDateTime(createdAt)),
                        if (updatedAt != null)
                          _InfoRow(label: 'Updated', value: _formatDateTime(updatedAt)),
                      ],
                    ),
                    const SizedBox(height: 80), // Space for bottom buttons
                  ],
                ),
              ),
            ),
            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131324),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: Colors.red,
                      onTap: _isDeleting ? null : _deleteOrder,
                      isLoading: _isDeleting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_outlined,
                      label: 'Call',
                      color: Colors.green,
                      onTap: _callClient,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.schedule_outlined,
                      label: 'Schedule',
                      color: Colors.blue,
                      onTap: estimatedTrips > 0 ? _openScheduleModal : null,
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
        color: const Color(0xFF131324),
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
    this.isTappable = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isTappable;
  final VoidCallback? onTap;

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
            style: TextStyle(
              color: isTappable ? const Color(0xFF6F4BFF) : Colors.white70,
              fontSize: 12,
              fontWeight: isTappable ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        if (isTappable)
          const Icon(
            Icons.phone,
            color: Color(0xFF6F4BFF),
            size: 16,
          ),
      ],
    );

    if (isTappable && onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: content,
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: onTap != null ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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

