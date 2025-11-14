import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_theme.dart';
import '../../models/order.dart';
import '../../repositories/android_order_repository.dart';
import '../../repositories/android_scheduled_order_repository.dart';
import '../widgets/android_schedule_order_dialog.dart';
import 'android_create_order_page.dart';
import 'android_order_detail_page.dart';

class AndroidClientPendingOrdersPage extends StatefulWidget {
  final String organizationId;
  final String clientId;
  final String clientName;
  final String clientPhone;

  const AndroidClientPendingOrdersPage({
    super.key,
    required this.organizationId,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
  });

  @override
  State<AndroidClientPendingOrdersPage> createState() => _AndroidClientPendingOrdersPageState();
}

class _AndroidClientPendingOrdersPageState extends State<AndroidClientPendingOrdersPage> {
  final AndroidOrderRepository _orderRepository = AndroidOrderRepository();
  final AndroidScheduledOrderRepository _scheduledOrderRepository =
      AndroidScheduledOrderRepository();
  static const int _pageSize = 50;
  late final Stream<List<Order>> _pendingOrdersStream;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _pendingOrdersStream = _orderRepository.watchOrdersByClient(
      widget.organizationId,
      widget.clientId,
      status: OrderStatus.pending,
      limit: _pageSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Orders',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
      ),
      backgroundColor: AppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AndroidCreateOrderPage(
                organizationId: widget.organizationId,
                clientId: widget.clientId,
              ),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Order>>(
          stream: _pendingOrdersStream,
          builder: (context, snapshot) {
            final orders = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
            final Object? error = snapshot.error;

            return Column(
              children: [
                _buildClientHeader(),
                _buildSummarySection(orders, isLoading),
                if (error != null && orders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildOrdersInlineError(error),
                  ),
                Expanded(
                  child: _buildOrdersBody(
                    orders: orders,
                    isLoading: isLoading,
                    error: error,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildClientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: Text(
                  widget.clientName.isNotEmpty ? widget.clientName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.clientPhone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(List<Order> orders, bool isLoading) {
    final orderCount = orders.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.18),
            AppTheme.secondaryColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          ...AppTheme.cardShadow,
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.25),
                      AppTheme.secondaryColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.pending_actions_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Pending Orders',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading && orderCount == 0
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      '$orderCount',
                      key: ValueKey<int>(orderCount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersInlineError(Object error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppTheme.errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.toString(),
              style: const TextStyle(color: AppTheme.textPrimaryColor),
            ),
          ),
          TextButton(
            onPressed: _isRefreshing ? null : () => _forceRefreshPendingOrders(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceRefreshPendingOrders() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _orderRepository.getOrdersByClient(
        widget.organizationId,
        widget.clientId,
        status: OrderStatus.pending,
        limit: _pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh orders: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _buildOrdersBody({
    required List<Order> orders,
    required bool isLoading,
    required Object? error,
  }) {
    if (error != null && orders.isEmpty) {
      return _buildOrdersErrorState(error);
    }

    if (isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return _buildOrdersEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _forceRefreshPendingOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildPendingOrderTile(context, order);
        },
      ),
    );
  }

  Widget _buildOrdersErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading orders',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRefreshing ? null : () => _forceRefreshPendingOrders(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersEmptyState() {
    return RefreshIndicator(
      onRefresh: _forceRefreshPendingOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Icon(
            Icons.receipt_long,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          SizedBox(height: 16),
          Text(
            'No Pending Orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This client has no pending orders',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getOrderAgeColor(DateTime createdAt) {
    final daysSince = DateTime.now().difference(createdAt).inDays;
    if (daysSince <= 1) {
      return AppTheme.successColor;
    } else if (daysSince <= 3) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor.withValues(alpha: 0.8);
    }
  }

  Widget _buildRemainingTripsChip(int remainingTrips) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$remainingTrips',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildPendingOrderTile(BuildContext context, Order order) {
    final orderAgeColor = _getOrderAgeColor(order.createdAt);
    final clientName = (order.clientName?.trim().isNotEmpty ?? false)
        ? order.clientName!.trim()
        : widget.clientName;
    final regionAddress = [order.region, order.city]
        .where((value) => value.trim().isNotEmpty)
        .join(', ');
    final totalQuantity =
        order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final orderPlacedOn =
        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);
    final orderPhone = order.clientPhone?.trim() ?? '';
    final fallbackPhone = widget.clientPhone.trim();
    final callPhone =
        (orderPhone.isNotEmpty ? orderPhone : fallbackPhone).trim();
    final hasCallPhone = callPhone.isNotEmpty;

    TextStyle labelStyle(Color color) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.1,
        );
    TextStyle valueStyle(Color color) => TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        );

    Widget infoPair(
      String label,
      String value, {
      bool alignEnd = false,
      int maxLines = 1,
    }) {
      return Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle(AppTheme.textSecondaryColor)),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '—',
            style: valueStyle(AppTheme.textPrimaryColor),
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: orderAgeColor,
          width: 2,
        ),
        boxShadow: [
          ...AppTheme.cardShadow,
          BoxShadow(
            color: orderAgeColor.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidOrderDetailPage(
                  organizationId: order.organizationId,
                  orderId: order.orderId,
                  order: order,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoPair('Client Name', clientName, maxLines: 1),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: infoPair(
                                  'Region, Address',
                                  regionAddress,
                                  maxLines: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              infoPair(
                                'Quantity',
                                '$totalQuantity',
                                alignEnd: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildRemainingTripsChip(order.remainingTrips),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasCallPhone) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _callClient(callPhone),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                      icon: const Icon(Icons.call),
                      label: const Text(
                        'Call Client',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                infoPair('Order placed', orderPlacedOn, maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleScheduleOrder(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Schedule'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleDeleteOrder(order),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: AppTheme.errorColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callClient(String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client phone number unavailable')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open dialer')),
      );
    }
  }

  Future<void> _handleScheduleOrder(Order order) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AndroidScheduleOrderDialog(
        organizationId: widget.organizationId,
        order: order,
        userId: userId,
        scheduledOrderRepository: _scheduledOrderRepository,
      ),
      );

    if (!mounted || result != true) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Order scheduled successfully'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
  }

  Future<void> _handleDeleteOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Order?',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this order? This action cannot be undone.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.errorColor,
                  AppTheme.errorColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orderRepository.deleteOrder(
        widget.organizationId,
        order.orderId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Order deleted successfully'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}


