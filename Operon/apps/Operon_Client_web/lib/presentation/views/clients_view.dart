import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/widgets/client_detail_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ClientsPageContent extends StatefulWidget {
  const ClientsPageContent({super.key});

  @override
  State<ClientsPageContent> createState() => _ClientsPageContentState();
}

enum _ClientSortOption {
  nameAsc,
  nameDesc,
  ordersHigh,
  ordersLow,
  corporateFirst,
  individualFirst,
}

enum _ClientFilterType {
  all,
  corporate,
  individual,
}

class _ClientsPageContentState extends State<ClientsPageContent> {
  String _query = '';
  _ClientSortOption _sortOption = _ClientSortOption.nameAsc;
  _ClientFilterType _filterType = _ClientFilterType.all;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    // Load clients and recent clients on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientsCubit>()
        ..loadClients()
        ..loadRecentClients();
    });
  }

  List<Client> _applyFiltersAndSort(List<Client> clients) {
    // Create a mutable copy to avoid "Unsupported operation: sort" error in web
    var filtered = List<Client>.from(clients);

    // Apply search filter
    if (_query.isNotEmpty) {
      context.read<ClientsCubit>().search(_query);
      filtered = filtered
          .where((c) => 
              c.name.toLowerCase().contains(_query.toLowerCase()) ||
              (c.primaryPhone?.toLowerCase().contains(_query.toLowerCase()) ?? false) ||
              c.tags.any((tag) => tag.toLowerCase().contains(_query.toLowerCase()))
          )
          .toList();
    }

    // Apply type filter
    switch (_filterType) {
      case _ClientFilterType.corporate:
        filtered = filtered.where((c) => c.isCorporate).toList();
        break;
      case _ClientFilterType.individual:
        filtered = filtered.where((c) => !c.isCorporate).toList();
        break;
      case _ClientFilterType.all:
        break;
    }

    // Apply sorting (create new mutable list for sorting)
    final sortedList = List<Client>.from(filtered);
    switch (_sortOption) {
      case _ClientSortOption.nameAsc:
        sortedList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _ClientSortOption.nameDesc:
        sortedList.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case _ClientSortOption.ordersHigh:
        sortedList.sort((a, b) {
          final aOrders = (a.stats?['orders'] as num?)?.toInt() ?? 0;
          final bOrders = (b.stats?['orders'] as num?)?.toInt() ?? 0;
          return bOrders.compareTo(aOrders);
        });
        break;
      case _ClientSortOption.ordersLow:
        sortedList.sort((a, b) {
          final aOrders = (a.stats?['orders'] as num?)?.toInt() ?? 0;
          final bOrders = (b.stats?['orders'] as num?)?.toInt() ?? 0;
          return aOrders.compareTo(bOrders);
        });
        break;
      case _ClientSortOption.corporateFirst:
        sortedList.sort((a, b) {
          if (a.isCorporate && !b.isCorporate) return -1;
          if (!a.isCorporate && b.isCorporate) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case _ClientSortOption.individualFirst:
        sortedList.sort((a, b) {
          if (!a.isCorporate && b.isCorporate) return -1;
          if (a.isCorporate && !b.isCorporate) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsCubit, ClientsState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.clients.isEmpty) {
          return _LoadingState();
        }
        if (state.status == ViewStatus.failure && state.clients.isEmpty) {
          return _ErrorState(
            message: state.message ?? 'Failed to load clients',
            onRetry: () => context.read<ClientsCubit>()..loadClients()..loadRecentClients(),
          );
        }

        final allClients = _query.isEmpty
            ? state.clients
            : state.searchResults;

        if (_query.isNotEmpty) {
          context.read<ClientsCubit>().search(_query);
        }

        final filtered = _applyFiltersAndSort(allClients);

        return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Statistics Dashboard
            _ClientsStatsHeader(clients: state.clients),
            const SizedBox(height: 32),
            
            // Top Action Bar with Filters
            Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      onChanged: (v) {
                        setState(() => _query = v);
                        context.read<ClientsCubit>().search(v);
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search clients by name, phone, or tags...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Type Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_ClientFilterType>(
                      value: _filterType,
                      dropdownColor: const Color(0xFF1B1B2C),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: const [
                        DropdownMenuItem(
                          value: _ClientFilterType.all,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, size: 16, color: Colors.white70),
                              SizedBox(width: 6),
                              Text('All Clients'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: _ClientFilterType.corporate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business, size: 16, color: Colors.white70),
                              SizedBox(width: 6),
                              Text('Corporate'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: _ClientFilterType.individual,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.white70),
                              SizedBox(width: 6),
                              Text('Individual'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _filterType = value);
                        }
                      },
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Options
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_ClientSortOption>(
                          value: _sortOption,
                          dropdownColor: const Color(0xFF1B1B2C),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(
                              value: _ClientSortOption.nameAsc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Name (A-Z)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.nameDesc,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sort_by_alpha, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Name (Z-A)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.ordersHigh,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_down, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Orders (High to Low)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.ordersLow,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Orders (Low to High)'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.corporateFirst,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.business, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Corporate First'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: _ClientSortOption.individualFirst,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Individual First'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sortOption = value);
                            }
                          },
                          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.7), size: 20),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // View Toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewToggleButton(
                        icon: Icons.grid_view,
                        isSelected: !_isListView,
                        onTap: () => setState(() => _isListView = false),
                        tooltip: 'Grid View',
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _ViewToggleButton(
                        icon: Icons.list,
                        isSelected: _isListView,
                        onTap: () => setState(() => _isListView = true),
                        tooltip: 'List View',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Results count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'client' : 'clients'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add Client Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Client'),
                  onPressed: () => _showClientDialog(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6F4BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Client Grid/List
            if (filtered.isEmpty && (_query.isNotEmpty || _filterType != _ClientFilterType.all))
              _EmptySearchState(query: _query)
            else if (filtered.isEmpty)
              _EmptyClientsState(
                onAddClient: () => _showClientDialog(context, null),
              )
            else if (_isListView)
              _ClientListView(
                clients: filtered,
                onTap: (client) => _openClientDetail(client),
                onEdit: (client) => _showClientDialog(context, client),
                onDelete: (client) => _showDeleteConfirmation(context, client),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1400
                      ? 4
                      : constraints.maxWidth > 1050
                          ? 3
                          : constraints.maxWidth > 700
                              ? 2
                              : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _ClientCard(
                        client: filtered[index],
                        onTap: () => _openClientDetail(filtered[index]),
                        onEdit: () => _showClientDialog(context, filtered[index]),
                        onDelete: () => _showDeleteConfirmation(context, filtered[index]),
                      );
                    },
                  );
                },
              ),
            ],
          );
      },
    );
  }

  void _openClientDetail(Client client) {
    showDialog(
      context: context,
      builder: (dialogContext) => ClientDetailModal(
        client: client,
        onClientChanged: (updatedClient) {
          // Refresh clients list if needed
          context.read<ClientsCubit>().loadClients();
        },
        onEdit: () => _showClientDialog(context, client),
      ),
    );
  }
}

class _ClientCard extends StatefulWidget {
  const _ClientCard({
    required this.client,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final Client client;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getClientColor() {
    if (widget.client.isCorporate) {
      return const Color(0xFF6F4BFF);
    }
    final hash = widget.client.name.hashCode;
    final colors = [
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final clientColor = _getClientColor();
    final orderCount = widget.client.stats?['orders'] ?? 0;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_controller.value * 0.02),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1F1F33),
                      Color(0xFF1A1A28),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHovered
                        ? clientColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: _isHovered ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                    if (_isHovered)
                      BoxShadow(
                        color: clientColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: -5,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header with Avatar
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      clientColor,
                                      clientColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: clientColor.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(widget.client.name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.client.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (widget.client.isCorporate)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: clientColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: clientColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.business,
                                              size: 12,
                                              color: Color(0xFF6F4BFF),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Corporate',
                                              style: TextStyle(
                                                color: clientColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Phone Info
                          if (widget.client.primaryPhone != null)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.client.primaryPhone!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Tags and Stats
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tags
                              if (widget.client.tags.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: widget.client.tags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (widget.client.tags.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${widget.client.tags.length - 3} more',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                              
                              // Stats
                              if (widget.client.stats != null && orderCount > 0) ...[
                                if (widget.client.tags.isNotEmpty) const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5AD8A4).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF5AD8A4).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 16,
                                        color: Color(0xFF5AD8A4),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$orderCount ${orderCount == 1 ? 'order' : 'orders'}',
                                        style: const TextStyle(
                                          color: Color(0xFF5AD8A4),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Action Buttons (appear on hover)
                    if (_isHovered)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B2C).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onTap != null)
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  color: Colors.white70,
                                  onPressed: widget.onTap,
                                  tooltip: 'View Details',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              if (widget.onEdit != null) ...[
                                if (widget.onTap != null)
                                  Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  color: Colors.white70,
                                  onPressed: widget.onEdit,
                                  tooltip: 'Edit',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                              if (widget.onDelete != null) ...[
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: Colors.redAccent,
                                  onPressed: widget.onDelete,
                                  tooltip: 'Delete',
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void _showClientDialog(BuildContext context, Client? client) {
  final cubit = context.read<ClientsCubit>();
  showDialog(
    context: context,
    builder: (dialogContext) => _ClientDialog(
      client: client,
      clientsCubit: cubit,
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, Client client) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: const Text(
        'Delete Client',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Are you sure you want to delete ${client.name}?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.read<ClientsCubit>().deleteClient(client.id);
            Navigator.of(dialogContext).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _ClientDialog extends StatefulWidget {
  const _ClientDialog({
    this.client,
    required this.clientsCubit,
  });

  final Client? client;
  final ClientsCubit clientsCubit;

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _nameController = TextEditingController(text: client?.name ?? '');
    _phoneController = TextEditingController(text: client?.primaryPhone ?? '');
    if (client != null) {
      _tags.addAll(client.tags);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF11111B),
              Color(0xFF0D0D15),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B1C2C),
                    Color(0xFF161622),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: const Color(0xFF6F4BFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Client' : 'Add Client',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Client name', Icons.person_outline),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter client name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Primary phone', Icons.phone_outlined),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter primary phone'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tags',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tagController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Enter tag and press Enter',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                prefixIcon: const Icon(Icons.tag, color: Colors.white54, size: 20),
                                filled: true,
                                fillColor: const Color(0xFF1B1B2C),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6F4BFF),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              onFieldSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _addTag,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6F4BFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6F4BFF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF6F4BFF).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeTag(tag),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(isEditing ? Icons.check : Icons.add, size: 18),
                    label: Text(isEditing ? 'Save Changes' : 'Create Client'),
                    onPressed: () {
                      if (!(_formKey.currentState?.validate() ?? false)) return;

                      if (widget.client == null) {
                        widget.clientsCubit.createClient(
                          name: _nameController.text.trim(),
                          primaryPhone: _phoneController.text.trim(),
                          phones: [],
                          tags: _tags,
                        );
                      } else {
                        final updatedClient = Client(
                          id: widget.client!.id,
                          name: _nameController.text.trim(),
                          primaryPhone: _phoneController.text.trim(),
                          phones: widget.client!.phones,
                          phoneIndex: widget.client!.phoneIndex,
                          tags: _tags,
                          status: widget.client!.status,
                          organizationId: widget.client!.organizationId,
                          createdAt: widget.client!.createdAt,
                          stats: widget.client!.stats,
                        );
                        widget.clientsCubit.updateClient(updatedClient);
                      }
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6F4BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF1B1B2C),
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF6F4BFF),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}

class _ClientsStatsHeader extends StatelessWidget {
  const _ClientsStatsHeader({required this.clients});

  final List<Client> clients;

  @override
  Widget build(BuildContext context) {
    final totalClients = clients.length;
    final corporateCount = clients.where((c) => c.isCorporate).length;
    final individualCount = totalClients - corporateCount;
    final totalOrders = clients.fold<int>(
      0,
      (sum, client) => sum + ((client.stats?['orders'] as num?)?.toInt() ?? 0),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_outline,
                      label: 'Total Clients',
                      value: totalClients.toString(),
                      color: const Color(0xFF6F4BFF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.business_outlined,
                      label: 'Corporate',
                      value: corporateCount.toString(),
                      color: const Color(0xFF5AD8A4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.person_outline,
                      label: 'Individual',
                      value: individualCount.toString(),
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Total Orders',
                      value: totalOrders.toString(),
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.people_outline,
                    label: 'Total Clients',
                    value: totalClients.toString(),
                    color: const Color(0xFF6F4BFF),
                  ),
                  _StatCard(
                    icon: Icons.business_outlined,
                    label: 'Corporate',
                    value: corporateCount.toString(),
                    color: const Color(0xFF5AD8A4),
                  ),
                  _StatCard(
                    icon: Icons.person_outline,
                    label: 'Individual',
                    value: individualCount.toString(),
                    color: const Color(0xFFFF9800),
                  ),
                  _StatCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Total Orders',
                    value: totalOrders.toString(),
                    color: const Color(0xFF2196F3),
                  ),
                ],
              );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1F1F33),
            Color(0xFF1A1A28),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Loading clients...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load clients',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState({required this.onAddClient});

  final VoidCallback onAddClient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B1B2C).withValues(alpha: 0.6),
              const Color(0xFF161622).withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6F4BFF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 40,
                color: Color(0xFF6F4BFF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No clients yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by adding your first client to the system',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Client'),
              onPressed: onAddClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6F4BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No clients match "$query"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _ClientListView extends StatelessWidget {
  const _ClientListView({
    required this.clients,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Client> clients;
  final ValueChanged<Client> onTap;
  final ValueChanged<Client> onEdit;
  final ValueChanged<Client> onDelete;

  Color _getClientColor(Client client) {
    if (client.isCorporate) {
      return const Color(0xFF6F4BFF);
    }
    final hash = client.name.hashCode;
    final colors = [
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: clients.map((client) {
        final clientColor = _getClientColor(client);
        final orderCount = client.stats?['orders'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F1F33),
                Color(0xFF1A1A28),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      clientColor,
                      clientColor.withValues(alpha: 0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(client.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Name and Type
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (client.isCorporate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: clientColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: clientColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.business,
                              size: 12,
                              color: Color(0xFF6F4BFF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Corporate',
                              style: TextStyle(
                                color: clientColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Phone
              Expanded(
                flex: 2,
                child: client.primaryPhone != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                client.primaryPhone!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox(),
              ),
              // Tags
              Expanded(
                flex: 2,
                child: client.tags.isNotEmpty
                    ? Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: client.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    : const SizedBox(),
              ),
              // Orders
              Expanded(
                flex: 1,
                child: orderCount > 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                                color: Color(0xFF5AD8A4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                orderCount.toString(),
                                style: const TextStyle(
                                  color: Color(0xFF5AD8A4),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox(),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    color: Colors.white70,
                    onPressed: () => onTap(client),
                    tooltip: 'View Details',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.white70,
                    onPressed: () => onEdit(client),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.redAccent,
                    onPressed: () => onDelete(client),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
