import 'dart:async';

import 'package:core_ui/core_ui.dart' show AuthColors, DashSnackbar, EmptyState;
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/pending_order_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

enum SortOption {
  dateNewest,
  dateOldest,
  priorityHigh,
  clientNameAsc,
  clientNameDesc,
}

class PendingOrdersView extends StatefulWidget {
  const PendingOrdersView({super.key});

  @override
  State<PendingOrdersView> createState() => _PendingOrdersViewState();
}

class _PendingOrdersViewState extends State<PendingOrdersView> {
  int _pendingOrdersCount = 0;
  int _totalPendingTrips = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  bool _isEddRunning = false;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  String? _currentOrgId;
  final Set<int> _selectedFixedQuantityFilters = {}; // empty means "All"
  String _searchQuery = '';
  SortOption _sortOption = SortOption.dateNewest;
  final Set<String> _selectedOrderIds = {};
  final FocusNode _searchFocusNode = FocusNode();
  final Map<String, String> _searchIndexCache = {};
  String? _lastSearchIndexHash;

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
        // Pending Trips = remaining trips to schedule (sum of estimatedTrips per item)
        // Do NOT use totalTripsRequired — that's total; we need remaining only
        final tripsCount = orders.fold<int>(0, (total, order) {
          final items = order['items'] as List<dynamic>? ?? [];
          final firstItem =
              items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
          int remainingTrips = 0;
          for (final item in items) {
            final itemMap = item as Map<String, dynamic>;
            remainingTrips += (itemMap['estimatedTrips'] as int? ?? 0);
          }
          if (remainingTrips == 0 && firstItem != null) {
            remainingTrips = firstItem['estimatedTrips'] as int? ??
                (order['tripIds'] as List<dynamic>?)?.length ??
                0;
          }
          return total + remainingTrips;
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
    List<Map<String, dynamic>> filtered = _orders;

    // Filter by fixed quantity
    if (_selectedFixedQuantityFilters.isNotEmpty) {
      filtered = filtered.where((order) {
        final items = order['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) return false;
        final firstItem = items.first as Map<String, dynamic>;
        final fixedQuantityPerTrip = firstItem['fixedQuantityPerTrip'] as int?;
        return fixedQuantityPerTrip != null &&
            _selectedFixedQuantityFilters.contains(fixedQuantityPerTrip);
      }).toList();
    }

    // Filter by search query (client name)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final ordersHash = '${_orders.length}_${_orders.hashCode}';
      final searchIndex = _buildSearchIndex(_orders, ordersHash);
      filtered = filtered.where((order) {
        final orderId = order['id'] as String? ?? '';
        final indexText = searchIndex[orderId] ?? '';
        return indexText.contains(query);
      }).toList();
    }

    // Sort orders
    filtered = _sortOrders(filtered);

    return filtered;
  }

  Map<String, String> _buildSearchIndex(
    List<Map<String, dynamic>> orders,
    String ordersHash,
  ) {
    if (_lastSearchIndexHash == ordersHash && _searchIndexCache.isNotEmpty) {
      return _searchIndexCache;
    }

    _searchIndexCache.clear();
    for (final order in orders) {
      final orderId = order['id'] as String? ?? '';
      if (orderId.isEmpty) continue;
      final clientName = (order['clientName'] as String? ?? '').trim();
      _searchIndexCache[orderId] = clientName.toLowerCase();
    }

    _lastSearchIndexHash = ordersHash;
    return _searchIndexCache;
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    final sorted = List<Map<String, dynamic>>.from(orders);

    sorted.sort((a, b) {
      switch (_sortOption) {
        case SortOption.dateNewest:
          final dateA = _getDate(a['createdAt']);
          final dateB = _getDate(b['createdAt']);
          return dateB.compareTo(dateA);
        case SortOption.dateOldest:
          final dateA = _getDate(a['createdAt']);
          final dateB = _getDate(b['createdAt']);
          return dateA.compareTo(dateB);
        case SortOption.priorityHigh:
          final priorityA = _getPriorityValue(a['priority']);
          final priorityB = _getPriorityValue(b['priority']);
          if (priorityA != priorityB) return priorityB.compareTo(priorityA);
          // If same priority, sort by date (newest first)
          final dateA = _getDate(a['createdAt']);
          final dateB = _getDate(b['createdAt']);
          return dateB.compareTo(dateA);
        case SortOption.clientNameAsc:
          final nameA = (a['clientName'] as String? ?? '').toLowerCase();
          final nameB = (b['clientName'] as String? ?? '').toLowerCase();
          return nameA.compareTo(nameB);
        case SortOption.clientNameDesc:
          final nameA = (a['clientName'] as String? ?? '').toLowerCase();
          final nameB = (b['clientName'] as String? ?? '').toLowerCase();
          return nameB.compareTo(nameA);
      }
    });

    return sorted;
  }

  DateTime _getDate(dynamic timestamp) {
    if (timestamp == null) return DateTime(1970);
    try {
      if (timestamp is DateTime) return timestamp;
      return (timestamp as dynamic).toDate();
    } catch (_) {
      return DateTime(1970);
    }
  }

  int _getPriorityValue(String? priority) {
    if (priority == 'high' || priority == 'priority') return 2;
    if (priority == 'normal') return 1;
    return 0;
  }

  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final filtered = _getFilteredOrders();
      _selectedOrderIds.clear();
      _selectedOrderIds.addAll(filtered.map((o) => o['id'] as String));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedOrderIds.clear();
    });
  }

  Future<void> _runEddForAllOrders() async {
    if (_isEddRunning) return;

    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;
    if (organization == null) {
      DashSnackbar.show(context,
          message: 'Organization not selected', isError: true);
      return;
    }

    setState(() {
      _isEddRunning = true;
    });

    try {
      final repository = context.read<PendingOrdersRepository>();
      final result =
          await repository.calculateEddForAllPendingOrders(organization.id);
      final updatedOrders = result['updatedOrders'] ?? 0;
      DashSnackbar.show(context,
          message: 'EDD calculated for $updatedOrders order(s)');
    } catch (e) {
      DashSnackbar.show(context,
          message: 'Failed to calculate EDD: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isEddRunning = false;
        });
      }
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AuthColors.background,
        title: Text(
          'Delete ${_selectedOrderIds.length} Order${_selectedOrderIds.length > 1 ? 's' : ''}?',
          style: const TextStyle(color: AuthColors.textMain),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedOrderIds.length} selected order${_selectedOrderIds.length > 1 ? 's' : ''}? This action cannot be undone.',
          style: const TextStyle(color: AuthColors.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AuthColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = context.read<PendingOrdersRepository>();
      for (final orderId in _selectedOrderIds) {
        await repository.deleteOrder(orderId);
      }
      _deselectAll();
      DashSnackbar.show(
        context,
        message:
            '${_selectedOrderIds.length} order${_selectedOrderIds.length > 1 ? 's' : ''} deleted successfully',
      );
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to delete orders: $e', isError: true);
      }
    }
  }

  int _getColumnCount(double width) {
    if (width < 768) return 1;
    if (width < 1024) return 2;
    if (width < 1440) return 3;
    if (width < 1920) return 4;
    return 5;
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final keyboard = HardwareKeyboard.instance;
          final isMetaOrControl =
              keyboard.isMetaPressed || keyboard.isControlPressed;
          final isShift = keyboard.isShiftPressed;

          // Ctrl/Cmd + A to select all
          if (event.logicalKey == LogicalKeyboardKey.keyA && isMetaOrControl) {
            if (isShift) {
              _deselectAll();
            } else {
              _selectAll();
            }
          }
          // Escape to deselect all
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _deselectAll();
          }
          // Delete key to bulk delete
          if (event.logicalKey == LogicalKeyboardKey.delete &&
              _selectedOrderIds.isNotEmpty) {
            _bulkDelete();
          }
        }
      },
      child: BlocListener<OrganizationContextCubit, OrganizationContextState>(
        listener: (context, state) {
          if (state.organization != null) {
            _currentOrgId = null;
            _subscribeToOrders();
          }
        },
        child: _isLoading
            ? const _SkeletonLoader()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat Tiles
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          title: 'Pending Orders',
                          value: _pendingOrdersCount.toString(),
                          icon: Icons.pending_actions_outlined,
                          color: AuthColors.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatTile(
                          title: 'Pending Trips',
                          value: _totalPendingTrips.toString(),
                          icon: Icons.local_shipping_outlined,
                          color: AuthColors.success,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: (_isEddRunning || _orders.isEmpty)
                              ? null
                              : _runEddForAllOrders,
                          icon: _isEddRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.schedule_outlined),
                          label: Text(_isEddRunning
                              ? 'Calculating EDD...'
                              : 'Estimated Dates'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AuthColors.primary,
                            foregroundColor: AuthColors.textMain,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Search and Sort Bar
                  if (_orders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SearchAndSortBar(
                      searchQuery: _searchQuery,
                      sortOption: _sortOption,
                      onSearchChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                      onSortChanged: (option) {
                        setState(() {
                          _sortOption = option;
                        });
                      },
                      searchFocusNode: _searchFocusNode,
                    ),
                  ],
                  // Bulk Actions Bar
                  if (_selectedOrderIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BulkActionsBar(
                      selectedCount: _selectedOrderIds.length,
                      onSelectAll: _selectAll,
                      onDeselectAll: _deselectAll,
                      onBulkDelete: _bulkDelete,
                    ),
                  ],
                  // Filters
                  if (_orders.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _FixedQuantityFilter(
                      orders: _orders,
                      selectedValues: _selectedFixedQuantityFilters,
                      onFilterChanged: (values) {
                        setState(() {
                          _selectedFixedQuantityFilters
                            ..clear()
                            ..addAll(values);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Order Tiles - Responsive Grid Layout
                  if (_getFilteredOrders().isNotEmpty) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        var columnCount = _getColumnCount(screenWidth);
                        if (columnCount <= 0) {
                          columnCount = 1;
                        }
                        final filteredOrders = _getFilteredOrders();
                        const crossAxisSpacing = 20.0;
                        const mainAxisSpacing = 20.0;
                        final contentWidth = constraints.maxWidth;
                        final usableWidth =
                            contentWidth - crossAxisSpacing * (columnCount - 1);
                        final tileWidth = columnCount > 0
                            ? (usableWidth > 0
                                ? usableWidth / columnCount
                                : contentWidth / columnCount)
                            : contentWidth;

                        return AnimationLimiter(
                          child: Wrap(
                            spacing: crossAxisSpacing,
                            runSpacing: mainAxisSpacing,
                            children:
                                List.generate(filteredOrders.length, (index) {
                              final order = filteredOrders[index];
                              final orderId = order['id'] as String;
                              final isSelected =
                                  _selectedOrderIds.contains(orderId);

                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 200),
                                columnCount: columnCount,
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    curve: Curves.easeOut,
                                    child: SizedBox(
                                      width: tileWidth,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: PendingOrderTile(
                                          key: ValueKey(orderId),
                                          order: order,
                                          isSelected: isSelected,
                                          onTripsUpdated: () =>
                                              _subscribeToOrders(),
                                          onDeleted: () {
                                            _selectedOrderIds.remove(orderId);
                                            _subscribeToOrders();
                                          },
                                          onTap: () {
                                            // Toggle selection on tap
                                            _toggleOrderSelection(orderId);
                                          },
                                          onSelectionToggle: () =>
                                              _toggleOrderSelection(orderId),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ],
                  if (!_isLoading && _orders.isEmpty) ...[
                    const SizedBox(height: 48),
                    const EmptyState(
                      icon: Icons.pending_actions_outlined,
                      title: 'No Pending Orders',
                      message:
                          'All orders have been processed or there are no orders yet.',
                    ),
                  ],
                  if (!_isLoading &&
                      _getFilteredOrders().isEmpty &&
                      _orders.isNotEmpty) ...[
                    const SizedBox(height: 48),
                    EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No Orders Found',
                      message: _searchQuery.isNotEmpty
                          ? 'No orders match your search query.'
                          : 'No orders match the selected filter.',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AuthColors.textMainWithOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 28,
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

class _FixedQuantityFilter extends StatelessWidget {
  const _FixedQuantityFilter({
    required this.orders,
    required this.selectedValues,
    required this.onFilterChanged,
  });

  final List<Map<String, dynamic>> orders;
  final Set<int> selectedValues;
  final ValueChanged<Set<int>> onFilterChanged;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Quantity',
          style: TextStyle(
            color: AuthColors.textMainWithOpacity(0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "All" filter chip
                _FilterChip(
                  label: 'All',
                  isSelected: selectedValues.isEmpty,
                  onTap: () => onFilterChanged(<int>{}),
                ),
                const SizedBox(width: 8),
                // Quantity filter chips
                ...sortedQuantities.map((quantity) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: quantity.toString(),
                        isSelected: selectedValues.contains(quantity),
                        onTap: () {
                          final updated = Set<int>.from(selectedValues);
                          if (updated.contains(quantity)) {
                            updated.remove(quantity);
                          } else {
                            updated.add(quantity);
                          }
                          onFilterChanged(updated);
                        },
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AuthColors.primary : AuthColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AuthColors.primary
                  : AuthColors.textMainWithOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AuthColors.textMain : AuthColors.textSub,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchAndSortBar extends StatelessWidget {
  const _SearchAndSortBar({
    required this.searchQuery,
    required this.sortOption,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.searchFocusNode,
  });

  final String searchQuery;
  final SortOption sortOption;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SortOption> onSortChanged;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: TextField(
              focusNode: searchFocusNode,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by client name...',
                hintStyle: TextStyle(
                  color: AuthColors.textMainWithOpacity(0.5),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_outlined,
                  color: AuthColors.textMainWithOpacity(0.5),
                  size: 20,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AuthColors.textMainWithOpacity(0.5),
                          size: 20,
                        ),
                        onPressed: () => onSearchChanged(''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Sort Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: DropdownButton<SortOption>(
            value: sortOption,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.sort,
              color: AuthColors.textMainWithOpacity(0.7),
              size: 20,
            ),
            items: const [
              DropdownMenuItem(
                value: SortOption.dateNewest,
                child: Text('Date (Newest)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: SortOption.dateOldest,
                child: Text('Date (Oldest)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: SortOption.priorityHigh,
                child: Text('Priority (High)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: SortOption.clientNameAsc,
                child: Text('Client (A-Z)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: SortOption.clientNameDesc,
                child: Text('Client (Z-A)', style: TextStyle(fontSize: 13)),
              ),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulkActionsBar extends StatelessWidget {
  const _BulkActionsBar({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onBulkDelete,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onBulkDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AuthColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AuthColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSelectAll,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select All'),
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onDeselectAll,
            icon: const Icon(Icons.deselect, size: 18),
            label: const Text('Deselect'),
            style: TextButton.styleFrom(
              foregroundColor: AuthColors.textSub,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onBulkDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: AuthColors.error,
              foregroundColor: AuthColors.textMain,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        int columnCount;
        if (screenWidth < 768) {
          columnCount = 1;
        } else if (screenWidth < 1024) {
          columnCount = 2;
        } else if (screenWidth < 1440) {
          columnCount = 3;
        } else if (screenWidth < 1920) {
          columnCount = 4;
        } else {
          columnCount = 5;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat tiles skeleton
            Row(
              children: [
                Expanded(child: _SkeletonStatTile()),
                const SizedBox(width: 16),
                Expanded(child: _SkeletonStatTile()),
              ],
            ),
            const SizedBox(height: 24),
            // Search bar skeleton
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AuthColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 120,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AuthColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Grid skeleton - use fixed height so Column can shrink-wrap (no Expanded with unbounded height)
            SizedBox(
              height: 320,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: columnCount * 2, // Show 2 rows of skeletons
                itemBuilder: (context, index) => _SkeletonOrderTile(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonStatTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
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

class _SkeletonOrderTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // Product info skeleton
          Row(
            children: [
              Container(
                width: 100,
                height: 28,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar skeleton
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          // Buttons skeleton
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
