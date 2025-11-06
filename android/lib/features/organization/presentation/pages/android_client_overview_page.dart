import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/app_theme.dart';
import '../../models/client.dart';
import '../../models/order.dart';
import '../../repositories/android_client_repository.dart';
import '../../repositories/android_order_repository.dart';
import 'android_client_detail_page.dart';
import 'android_create_order_page.dart';
import 'android_order_detail_page.dart';

class AndroidClientOverviewPage extends StatefulWidget {
  final String organizationId;
  final String clientId;

  const AndroidClientOverviewPage({
    super.key,
    required this.organizationId,
    required this.clientId,
  });

  @override
  State<AndroidClientOverviewPage> createState() => _AndroidClientOverviewPageState();
}

enum _ClientMenuAction { edit, delete, changePrimary }

class _AndroidClientOverviewPageState extends State<AndroidClientOverviewPage>
    with SingleTickerProviderStateMixin {
  final AndroidClientRepository _clientRepository = AndroidClientRepository();
  final AndroidOrderRepository _orderRepository = AndroidOrderRepository();
  static const int _pendingOrdersLimit = 20;
  
  late TabController _tabController;
  Client? _client;
  bool _isLoadingClient = true;
  bool _isLoadingOrders = true;
  List<Order> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClientAndOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClientAndOrders() async {
    setState(() {
      _isLoadingClient = true;
      _isLoadingOrders = true;
    });

    try {
      final results = await Future.wait([
        _clientRepository.getClient(
          widget.organizationId,
          widget.clientId,
        ),
        _orderRepository.getOrdersByClient(
          widget.organizationId,
          widget.clientId,
          status: OrderStatus.pending,
          limit: _pendingOrdersLimit,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _client = results[0] as Client?;
        _pendingOrders = results[1] as List<Order>;
        _isLoadingClient = false;
        _isLoadingOrders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClient = false;
        _isLoadingOrders = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading client data: $e')),
      );
    }
  }

  Future<void> _loadClient() async {
    setState(() {
      _isLoadingClient = true;
    });

    try {
      final client = await _clientRepository.getClient(
        widget.organizationId,
        widget.clientId,
      );

      setState(() {
        _client = client;
        _isLoadingClient = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingClient = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading client: $e')),
        );
      }
    }
  }

  Future<void> _loadPendingOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final List<Order> orders = await _orderRepository.getOrdersByClient(
        widget.organizationId,
        widget.clientId,
        status: OrderStatus.pending,
        limit: _pendingOrdersLimit,
      );

      setState(() {
        _pendingOrders = orders;
        _isLoadingOrders = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingOrders = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  void _handleMenuAction(_ClientMenuAction action) {
    switch (action) {
      case _ClientMenuAction.edit:
        _onEditClient();
        break;
      case _ClientMenuAction.delete:
        _confirmDeleteClient();
        break;
      case _ClientMenuAction.changePrimary:
        _showChangePrimaryNumberDialog();
        break;
    }
  }

  Future<void> _onEditClient() async {
    if (_client == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AndroidClientDetailPage(
          organizationId: widget.organizationId,
          existingClient: _client,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadClient();
    }
  }

  Future<void> _confirmDeleteClient() async {
    if (_client == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Client',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete ${_client!.name}? This action cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _clientRepository.deleteClient(
        widget.organizationId,
        widget.clientId,
      );

      if (!mounted) return;

      Navigator.of(context).pop(); // Close progress

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_client!.name} has been deleted'),
          backgroundColor: AppTheme.errorColor,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Close progress

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting client: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _showChangePrimaryNumberDialog() async {
    if (_client == null) return;

    final phoneNumbers = _getAvailablePhoneNumbers();

    if (phoneNumbers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No additional phone numbers available to set as primary'),
        ),
      );
      return;
    }

    final selectedNumber = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.borderColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Change Primary Number',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondaryColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: phoneNumbers.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppTheme.borderColor.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final number = phoneNumbers[index];
                    final isCurrentPrimary = number == _client!.phoneNumber;
                    return ListTile(
                      leading: Icon(
                        isCurrentPrimary ? Icons.star : Icons.phone,
                        color: isCurrentPrimary
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondaryColor,
                      ),
                      title: Text(
                        number,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: isCurrentPrimary
                          ? const Text(
                              'Current primary',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isCurrentPrimary
                          ? const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                            )
                          : const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                      onTap: isCurrentPrimary
                          ? null
                          : () => Navigator.of(context).pop(number),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedNumber == null || !mounted) return;

    await _updatePrimaryNumber(selectedNumber);
  }

  Future<void> _updatePrimaryNumber(String phoneNumber) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      await _clientRepository.updatePrimaryPhone(
        widget.organizationId,
        widget.clientId,
        phoneNumber,
        userId,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Primary number updated to $phoneNumber'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      await _loadClient();
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating primary number: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  List<String> _getAvailablePhoneNumbers() {
    if (_client == null) return [];

    final numbers = <String>[_client!.phoneNumber];
    final additionalNumbers = _client!.phoneList ?? [];

    for (final number in additionalNumbers) {
      if (!numbers.contains(number)) {
        numbers.add(number);
      }
    }

    return numbers;
  }

  String _formatAddress(ClientAddress? address) {
    if (address == null) return '';
    
    final parts = <String>[];
    if (address.street != null && address.street!.isNotEmpty) {
      parts.add(address.street!);
    }
    if (address.city != null && address.city!.isNotEmpty) {
      parts.add(address.city!);
    }
    if (address.state != null && address.state!.isNotEmpty) {
      parts.add(address.state!);
    }
    if (address.zipCode != null && address.zipCode!.isNotEmpty) {
      parts.add(address.zipCode!);
    }
    if (address.country != null && address.country!.isNotEmpty) {
      parts.add(address.country!);
    }
    
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _client?.name ?? 'Client Details',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          if (!_isLoadingClient && _client != null)
            PopupMenuButton<_ClientMenuAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: _handleMenuAction,
              itemBuilder: (context) {
                final canChangePrimary = _getAvailablePhoneNumbers().length > 1;
                return [
                  const PopupMenuItem<_ClientMenuAction>(
                    value: _ClientMenuAction.edit,
                    child: Text('Edit Client'),
                  ),
                  PopupMenuItem<_ClientMenuAction>(
                    value: _ClientMenuAction.changePrimary,
                    enabled: canChangePrimary,
                    child: Text(
                      'Change Primary Number',
                      style: TextStyle(
                        color: canChangePrimary
                            ? AppTheme.textPrimaryColor
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_ClientMenuAction>(
                    value: _ClientMenuAction.delete,
                    child: Text(
                      'Delete Client',
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                ];
              },
            ),
        ],
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
          ).then((result) {
            if (result == true) {
              _loadPendingOrders();
            }
          });
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: _isLoadingClient
            ? const Center(child: CircularProgressIndicator())
            : _client == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Client Not Found',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Client Info Header
                      Container(
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
                                  radius: 32,
                                  child: Text(
                                    _client!.name.isNotEmpty
                                        ? _client!.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _client!.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _client!.phoneNumber,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_client!.email != null && _client!.email!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email,
                                              size: 16,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _client!.email!,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppTheme.textSecondaryColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (_client!.address != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _formatAddress(_client!.address),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppTheme.textSecondaryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // TabBar below client info
                      Container(
                        color: AppTheme.surfaceColor,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppTheme.primaryColor,
                          labelColor: AppTheme.primaryColor,
                          unselectedLabelColor: AppTheme.textSecondaryColor,
                          tabs: const [
                            Tab(icon: Icon(Icons.summarize), text: 'Summary'),
                            Tab(icon: Icon(Icons.pending_actions), text: 'Pending Orders'),
                          ],
                        ),
                      ),
                      // Tab Content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSummaryTab(),
                            _buildPendingOrdersTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _loadClient,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Summary will be displayed here',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingOrdersTab() {
    return RefreshIndicator(
      onRefresh: _loadPendingOrders,
      child: Column(
        children: [
          // Summary Header - Enhanced Design
          Container(
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
                    const Text(
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
                  child: Text(
                    '${_pendingOrders.length}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : _pendingOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Pending Orders',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This client has no pending orders',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _pendingOrders.length,
                        itemBuilder: (context, index) {
                          final order = _pendingOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
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

  Widget _buildOrderCard(Order order) {
    // Get product names - show up to 2, with count if more
    final productNames = order.items.map((item) => item.productName).toList();
    final productDisplayText = productNames.length <= 2
        ? productNames.join(', ')
        : '${productNames.take(2).join(', ')} +${productNames.length - 2} more';

    final totalQuantity = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final orderAgeColor = _getOrderAgeColor(order.createdAt);

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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: orderAgeColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: orderAgeColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 0),
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
                  organizationId: widget.organizationId,
                  orderId: order.orderId,
                  order: order,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _loadPendingOrders();
              }
            });
          },
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Product and Trips aligned at top
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Info with Status Dot
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: orderAgeColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: orderAgeColor.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.shopping_cart_rounded,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  productDisplayText,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimaryColor,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (totalQuantity > 0) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 22),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$totalQuantity ${totalQuantity == 1 ? 'unit' : 'units'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Enhanced Trips Display - Aligned to top
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${order.trips}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              size: 13,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Trips',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Bottom Section: Location and Date - Better aligned
                Row(
                  children: [
                    if (order.region.isNotEmpty || order.city.isNotEmpty) ...[
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [order.region, order.city].where((s) => s.isNotEmpty).join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor,
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getRelativeTime(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd').format(order.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
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
}

