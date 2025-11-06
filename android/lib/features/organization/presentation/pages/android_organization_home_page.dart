import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/call_detection_service.dart';
import '../../../auth/android_auth_bloc.dart';
import '../../../vehicle/presentation/pages/android_vehicle_management_page.dart';
import '../../../payment_accounts/presentation/pages/android_payment_account_management_page.dart';
import '../../../products/presentation/pages/android_product_management_page.dart';
import '../../../location_pricing/presentation/pages/android_location_pricing_management_page.dart';
import 'android_organization_settings_page.dart';
import 'android_clients_page.dart';
import 'android_add_client_page.dart';
import '../../repositories/android_order_repository.dart';
import '../../repositories/android_client_repository.dart';
import '../../models/order.dart';
import 'android_order_detail_page.dart';

class AndroidOrganizationHomePage extends StatefulWidget {
  final Map<String, dynamic> organization;

  const AndroidOrganizationHomePage({
    super.key,
    required this.organization,
  });

  @override
  State<AndroidOrganizationHomePage> createState() => _AndroidOrganizationHomePageState();
}

class _AndroidOrganizationHomePageState extends State<AndroidOrganizationHomePage> {
  int _currentBottomNavIndex = 0; // Default to Home (0), Settings is 4 (Home, Pending Orders, Scheduled Orders, Maps, Settings)
  final ScrollController _scrollController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();
  
  // Pending Orders state
  final AndroidOrderRepository _orderRepository = AndroidOrderRepository();
  final ScrollController _pendingOrdersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Set organization ID for call detection service
    final orgId = widget.organization['orgId'] ?? widget.organization['id'];
    if (orgId != null) {
      CallDetectionService.instance.setOrganizationId(orgId.toString());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _homeScrollController.dispose();
    _pendingOrdersScrollController.dispose();
    super.dispose();
  }
  
  Stream<List<Order>> _getPendingOrdersStream() {
    final orgId = widget.organization['orgId'] ?? widget.organization['id'];
    if (orgId == null) {
      return Stream.value([]);
    }
    return _orderRepository.watchPendingOrders(orgId.toString());
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          widget.organization['orgName'] ?? 'OPERON',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.surfaceColor,
      ),
      drawer: _buildDrawer(context, firebaseUser),
      backgroundColor: AppTheme.backgroundColor,
      body: _buildBodyContent(context),
      bottomNavigationBar: _buildBottomNavigationBar(context),
      floatingActionButton: _currentBottomNavIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                final orgId = widget.organization['orgId'] ?? widget.organization['id'];
                if (orgId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AndroidAddClientPage(
                        organizationId: orgId.toString(),
                      ),
                    ),
                  );
                }
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildDrawer(BuildContext context, User? firebaseUser) {
    return Drawer(
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    firebaseUser?.phoneNumber ?? 'User',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (firebaseUser?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      firebaseUser!.email!,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleName(widget.organization['role']),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Organization Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organization',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.organization['orgName'] ?? 'N/A',
                    style: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${widget.organization['status'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.business, color: AppTheme.textPrimaryColor),
                    title: const Text(
                      'Switch Organization',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate back to organization selection
                      if (mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings, color: AppTheme.textPrimaryColor),
                    title: const Text(
                      'Settings',
                      style: TextStyle(color: AppTheme.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (mounted) {
                        final orgId = widget.organization['orgId'] ?? widget.organization['id'];
                        if (orgId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AndroidOrganizationSettingsPage(
                                organizationId: orgId.toString(),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final authBloc = context.read<AndroidAuthBloc>();
                    Navigator.pop(context);
                    if (mounted) {
                      authBloc.add(AndroidAuthLogoutRequested());
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    switch (_currentBottomNavIndex) {
      case 0:
        return _buildHomeContent(context);
      case 1:
        return _buildPendingOrdersContent(context);
      case 2:
        return _buildScheduledOrdersContent(context);
      case 3:
        return _buildMapsContent(context);
      case 4:
        return _buildNavigationList(context); // Show grid only when Settings is selected
      default:
        return _buildHomeContent(context);
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    final homeNavItems = [
      _NavItem(
        title: 'Clients',
        icon: Icons.people,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          if (orgId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidClientsPage(
                  organizationId: orgId.toString(),
                ),
              ),
            );
          }
        },
      ),
    ];

    return GridView.builder(
      controller: _homeScrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Square tiles
      ),
      itemCount: homeNavItems.length,
      itemBuilder: (context, index) {
        final item = homeNavItems[index];
        return _buildNavTile(context, item);
      },
    );
  }

  Widget _buildPendingOrdersContent(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _getPendingOrdersStream(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading orders',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Get orders from snapshot
        final pendingOrders = snapshot.data ?? [];

        // Empty state
        if (pendingOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Pending Orders',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All orders have been processed',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
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
                    child: Text(
                      '${pendingOrders.length}',
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
              child: ListView.builder(
                controller: _pendingOrdersScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: pendingOrders.length,
                itemBuilder: (context, index) {
                  final order = pendingOrders[index];
                  return _buildPendingOrderTile(context, order);
                },
              ),
            ),
          ],
        );
      },
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

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _handleScheduleOrder(Order order) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    try {
      final updatedOrder = order.copyWith(
        status: OrderStatus.confirmed,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _orderRepository.updateOrder(
        order.organizationId,
        order.orderId,
        updatedOrder,
        userId,
      );

      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling order: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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
        order.organizationId,
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

  Widget _buildPendingOrderTile(BuildContext context, Order order) {
    // Get product names - show up to 2, with count if more
    final productNames = order.items.map((item) => item.productName).toList();
    final productDisplayText = productNames.length <= 2
        ? productNames.join(', ')
        : '${productNames.take(2).join(', ')} +${productNames.length - 2} more';

    final totalQuantity = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final orderAgeColor = _getOrderAgeColor(order.createdAt);

    // Load client name
    final clientRepository = AndroidClientRepository();
    return FutureBuilder(
      future: clientRepository.getClient(order.organizationId, order.clientId),
      builder: (context, snapshot) {
        final clientName = snapshot.hasData ? snapshot.data!.name : 'Unknown Client';
        
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        // Top Row: Client/Product and Trips aligned at top
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Client and Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Client Info with Status Dot
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
                                        Icons.person_rounded,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          clientName,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimaryColor,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Product Info
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_rounded,
                                        size: 17,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productDisplayText,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimaryColor,
                                                letterSpacing: 0.1,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (totalQuantity > 0) ...[
                                              const SizedBox(height: 4),
                                              Container(
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
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
                        const SizedBox(height: 12),
                        // Action Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Schedule Button
                            _buildActionButton(
                              icon: Icons.event_available_rounded,
                              backgroundColor: AppTheme.successColor,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.successColor,
                                  AppTheme.successColor.withValues(alpha: 0.8),
                                ],
                              ),
                              onTap: () => _handleScheduleOrder(order),
                            ),
                            const SizedBox(width: 10),
                            // Delete Button
                            _buildActionButton(
                              icon: Icons.delete_outline_rounded,
                              backgroundColor: AppTheme.errorColor,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.errorColor,
                                  AppTheme.errorColor.withValues(alpha: 0.8),
                                ],
                              ),
                              onTap: () => _handleDeleteOrder(order),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduledOrdersContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Scheduled Orders',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsContent(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Maps',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList(BuildContext context) {
    final navItems = [
      _NavItem(
        title: 'Organization Manager',
        icon: Icons.storefront,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          if (orgId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidOrganizationSettingsPage(
                  organizationId: orgId.toString(),
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Vehicle Management',
        icon: Icons.two_wheeler,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidVehicleManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Payment Store',
        icon: Icons.account_balance,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidPaymentAccountManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Product Store',
        icon: Icons.shopping_cart,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidProductManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
      _NavItem(
        title: 'Region Store',
        icon: Icons.location_on,
        onTap: () {
          final orgId = widget.organization['orgId'] ?? widget.organization['id'];
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (orgId != null && userId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AndroidLocationPricingManagementPage(
                  organizationId: orgId.toString(),
                  userId: userId,
                ),
              ),
            );
          }
        },
      ),
    ];

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0, // Square tiles
      ),
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final item = navItems[index];
        return _buildNavTile(context, item);
      },
    );
  }

  Widget _buildNavTile(BuildContext context, _NavItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: AppTheme.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final navItems = [
      _BottomNavItem(icon: Icons.home, id: 'home'),
      _BottomNavItem(icon: Icons.pending_actions, id: 'pending_orders'),
      _BottomNavItem(icon: Icons.schedule, id: 'scheduled_orders'),
      _BottomNavItem(icon: Icons.map, id: 'maps'),
      _BottomNavItem(icon: Icons.settings, id: 'settings'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = index == _currentBottomNavIndex;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentBottomNavIndex = index;
                    });
                    _handleBottomNavTap(context, index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isSelected 
                          ? AppTheme.primaryGradient 
                          : null,
                      color: isSelected 
                          ? null 
                          : Colors.transparent,
                    ),
                    child: Icon(
                      item.icon,
                      color: isSelected 
                          ? Colors.white 
                          : AppTheme.textSecondaryColor,
                      size: 24,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    if (!mounted) return;
    
    // If navigating from Settings to another tab, pop any child pages first
    if (_currentBottomNavIndex == 4 && index != 4) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
    
    // If navigating to Settings, ensure we're on the home page
    if (index == 4) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // Scroll to top when Settings is selected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _getRoleName(dynamic role) {
    switch (role) {
      case 0:
        return 'Super Admin';
      case 1:
        return 'Admin';
      case 2:
        return 'Manager';
      case 3:
        return 'Driver';
      default:
        return 'Member';
    }
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _NavItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _BottomNavItem {
  final IconData icon;
  final String id;

  _BottomNavItem({
    required this.icon,
    required this.id,
  });
}

