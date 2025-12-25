import 'package:flutter/material.dart';

class CallOverlayWidget extends StatelessWidget {
  const CallOverlayWidget({
    super.key,
    required this.clientName,
    required this.clientPhone,
    required this.pendingOrders,
    required this.completedOrders,
    this.onDismiss,
  });

  final String clientName;
  final String clientPhone;
  final List<Map<String, dynamic>> pendingOrders;
  final List<Map<String, dynamic>> completedOrders;
  final VoidCallback? onDismiss;

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6F4BFF).withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              clientPhone,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onDismiss,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Orders
                    if (pendingOrders.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pending Orders (${pendingOrders.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...pendingOrders.take(5).map((order) {
                        final items = order['items'] as List<dynamic>? ?? [];
                        final firstItem = items.isNotEmpty
                            ? items.first as Map<String, dynamic>
                            : null;
                        final productName =
                            firstItem?['productName'] as String? ?? 'N/A';
                        final fixedQuantityPerTrip =
                            firstItem?['fixedQuantityPerTrip'] as int? ?? 0;
                        final trips = firstItem?['estimatedTrips'] as int? ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131324),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qty: $fixedQuantityPerTrip • $trips Trip${trips != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (pendingOrders.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+ ${pendingOrders.length - 5} more',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    // Completed Orders
                    if (completedOrders.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recent Completed (${completedOrders.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...completedOrders.map((order) {
                        final amount =
                            (order['amount'] as num?)?.toDouble() ?? 0.0;
                        final type = order['type'] as String? ?? 'N/A';
                        final date = order['transactionDate'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131324),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF4CAF50).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(date),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(amount),
                                style: const TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    // Empty state
                    if (pendingOrders.isEmpty && completedOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No orders found',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

