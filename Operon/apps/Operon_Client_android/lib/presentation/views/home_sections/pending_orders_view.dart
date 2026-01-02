import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/clients_page/contact_page.dart';
import 'package:dash_mobile/presentation/views/orders/create_order_page.dart';
import 'package:dash_mobile/presentation/views/orders/select_customer_page.dart';
import 'package:dash_mobile/presentation/widgets/order_tile.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({super.key});

  static void showCustomerTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerTypeDialog(),
    );
  }

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  int _pendingOrdersCount = 0;
  int _totalPendingTrips = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  String? _currentOrgId;
  int? _selectedFixedQuantityFilter; // null means "All"

  @override
  void initState() {
    super.initState();
    _subscribeToOrders();
  }

  Future<void> _subscribeToOrders() async {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      await _ordersSubscription?.cancel();
      _ordersSubscription = null;
      _currentOrgId = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _orders = [];
          _pendingOrdersCount = 0;
          _totalPendingTrips = 0;
        });
      }
      return;
    }

    final orgId = organization.id;
    if (_currentOrgId == orgId && _ordersSubscription != null) {
      // Already subscribed
      return;
    }

    _currentOrgId = orgId;

    final repository = context.read<PendingOrdersRepository>();

    await _ordersSubscription?.cancel();
    _ordersSubscription = repository.watchPendingOrders(orgId).listen(
      (orders) {
        final tripsCount = orders.fold<int>(0, (total, order) {
          final totalScheduledTrips = (order['totalScheduledTrips'] as num?)?.toInt() ?? 0;
          final estimatedTrips = (order['estimatedTrips'] as num?)?.toInt() ??
              ((order['tripIds'] as List<dynamic>?)?.length ?? 0);
          return total + (totalScheduledTrips > 0 ? totalScheduledTrips : estimatedTrips);
        });
      
      if (mounted) {
        setState(() {
          _orders = orders;
            _pendingOrdersCount = orders.length;
            _totalPendingTrips = tripsCount;
          _isLoading = false;
        });
      }
      },
      onError: (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    if (_selectedFixedQuantityFilter == null) {
      return _orders;
    }
    
    return _orders.where((order) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return false;
      final firstItem = items.first as Map<String, dynamic>;
      final fixedQuantityPerTrip = firstItem['fixedQuantityPerTrip'] as int?;
      return fixedQuantityPerTrip == _selectedFixedQuantityFilter;
    }).toList();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganizationContextCubit, OrganizationContextState>(
      listener: (context, state) {
        if (state.organization != null) {
          _currentOrgId = null;
          _subscribeToOrders();
        }
      },
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat Tiles
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: 'Pending Orders',
                        value: _pendingOrdersCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatTile(
                        title: 'Pending Trips',
                        value: _totalPendingTrips.toString(),
                        backgroundColor: const Color(0xFF4CAF50).withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
                // Filters
                if (_orders.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _FixedQuantityFilter(
                    orders: _orders,
                    selectedValue: _selectedFixedQuantityFilter,
                    onFilterChanged: (value) {
                      setState(() {
                        _selectedFixedQuantityFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // Order Tiles
                if (_getFilteredOrders().isNotEmpty) ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                      itemCount: _getFilteredOrders().length,
                      itemBuilder: (context, index) {
                        return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                          child: OrderTile(
                            order: _getFilteredOrders()[index],
                            onTripsUpdated: () => _subscribeToOrders(),
                            onDeleted: () => _subscribeToOrders(),
                          ),
                        );
                      },
                    ),
                ] else if (!_isLoading && _orders.isEmpty) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'No pending orders',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FixedQuantityFilter extends StatelessWidget {
  const _FixedQuantityFilter({
    required this.orders,
    required this.selectedValue,
    required this.onFilterChanged,
  });

  final List<Map<String, dynamic>> orders;
  final int? selectedValue;
  final ValueChanged<int?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    // Extract unique fixedQuantityPerTrip values from orders
    final Set<int> uniqueQuantities = {};
    for (final order in orders) {
      final items = order['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final firstItem = items.first as Map<String, dynamic>;
        final fixedQuantityPerTrip = firstItem['fixedQuantityPerTrip'] as int?;
        if (fixedQuantityPerTrip != null && fixedQuantityPerTrip > 0) {
          uniqueQuantities.add(fixedQuantityPerTrip);
        }
      }
    }

    final sortedQuantities = uniqueQuantities.toList()..sort();

    if (sortedQuantities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" filter chip
          _FilterChip(
            label: 'All',
            isSelected: selectedValue == null,
            onTap: () => onFilterChanged(null),
          ),
          const SizedBox(width: 8),
          // Quantity filter chips
          ...sortedQuantities.map((quantity) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: quantity.toString(),
                  isSelected: selectedValue == quantity,
                  onTap: () => onFilterChanged(quantity),
                ),
              )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CAF50)
              : const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    this.backgroundColor,
  });

  final String title;
  final String value;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF131324),
        borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                  title,
              style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
              ),
            ),
                const SizedBox(height: 4),
            Text(
                  value,
              style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
          ),
        ],
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

class _CustomerTypeDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Customer Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _CustomerTypeOption(
              icon: Icons.person_add_outlined,
              title: 'New Customer',
              subtitle: 'Create a new customer profile',
              onTap: () async {
                Navigator.of(context).pop();
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ContactPage(),
                    fullscreenDialog: true,
                  ),
                );
                // If client was created successfully, fetch the most recent client and navigate to create order page
                if (result == true && context.mounted) {
                  final clientsRepository = context.read<ClientsRepository>();
                  try {
                    // Fetch the most recently created client
                    final recentClients = await clientsRepository.fetchRecentClients(limit: 1);
                    final createdClient = recentClients.isNotEmpty ? recentClients.first : null;
                    
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CreateOrderPage(client: createdClient),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  } catch (error) {
                    // If fetching fails, still navigate but without client
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateOrderPage(),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            _CustomerTypeOption(
              icon: Icons.person_outline,
              title: 'Existing Customer',
              subtitle: 'Select from existing customers',
              onTap: () {
                Navigator.of(context).pop();
                final clientsRepository = context.read<ClientsRepository>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => ClientsCubit(
                        repository: clientsRepository,
                      )..subscribeToRecent(),
                      child: const SelectCustomerPage(),
                    ),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTypeOption extends StatelessWidget {
  const _CustomerTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF131324),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF6F4BFF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}



