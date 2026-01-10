import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/blocs/delivery_memos/delivery_memos_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/dm_print_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DeliveryMemosView extends StatefulWidget {
  const DeliveryMemosView({super.key});

  @override
  State<DeliveryMemosView> createState() => _DeliveryMemosViewState();
}

class _DeliveryMemosViewState extends State<DeliveryMemosView> {
  late TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      context.read<DeliveryMemosCubit>().search(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<DeliveryMemosCubit>().search('');
  }

  @override
  Widget build(BuildContext context) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      return SectionWorkspaceLayout(
        panelTitle: 'Delivery Memos',
        currentIndex: 0,
        onNavTap: (value) => context.go('/home?section=$value'),
        child: const Center(
          child: Text(
            'Please select an organization',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) {
        developer.log('Creating DeliveryMemosCubit', name: 'DeliveryMemosView');
        developer.log('Organization ID: ${organization.id}', name: 'DeliveryMemosView');
        final repository = context.read<DeliveryMemoRepository>();
        developer.log('Repository obtained: ${repository.runtimeType}', name: 'DeliveryMemosView');
        final cubit = DeliveryMemosCubit(
          repository: repository,
          organizationId: organization.id,
        );
        developer.log('Calling load()', name: 'DeliveryMemosView');
        cubit.load();
        return cubit;
      },
      child: BlocListener<DeliveryMemosCubit, DeliveryMemosState>(
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.message != null) {
            DashSnackbar.show(context, message: state.message!, isError: true);
          }
        },
        child: SectionWorkspaceLayout(
          panelTitle: 'Delivery Memos',
          currentIndex: 0,
          onNavTap: (value) => context.go('/home?section=$value'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 20),
              // Filters
              _buildFilters(),
              const SizedBox(height: 20),
              // Delivery Memos List
              _buildDeliveryMemosList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: state.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: _clearSearch,
                    )
                  : null,
              hintText: 'Search by DM number, client, or vehicle...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isSelected: state.statusFilter == null,
                onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter(null),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Active',
                isSelected: state.statusFilter == 'active',
                onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('active'),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Cancelled',
                isSelected: state.statusFilter == 'cancelled',
                onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('cancelled'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeliveryMemosList() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final filteredMemos = state.filteredDeliveryMemos;

        if (filteredMemos.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                state.searchQuery.isNotEmpty
                    ? 'No delivery memos found for "${state.searchQuery}"'
                    : 'No delivery memos found',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          );
        }

        final orgContext = context.watch<OrganizationContextCubit>().state;
        final canCancelDM = orgContext.appAccessRole?.canDelete('deliveryMemos') ?? false;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.85,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: filteredMemos.length,
          itemBuilder: (context, index) {
            final dm = filteredMemos[index];
            return _DeliveryMemoTile(dm: dm, canCancel: canCancelDM);
          },
        );
      },
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6F4BFF).withValues(alpha: 0.2)
              : const Color(0xFF1B1B2C).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF6F4BFF)
                : Colors.white.withValues(alpha: 0.7),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DeliveryMemoTile extends StatefulWidget {
  const _DeliveryMemoTile({
    required this.dm,
    required this.canCancel,
  });

  final Map<String, dynamic> dm;
  final bool canCancel;

  @override
  State<_DeliveryMemoTile> createState() => _DeliveryMemoTileState();
}

class _DeliveryMemoTileState extends State<_DeliveryMemoTile>
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

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '-';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays == 0) {
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      } else if (difference.inDays == 1) {
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return 'Yesterday, $hour:$minute $period';
      } else if (difference.inDays < 7) {
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = weekdays[dateTime.weekday - 1];
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$dayName, $hour:$minute $period';
      } else {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[dateTime.month - 1];
        return '${dateTime.day} $month ${dateTime.year}';
      }
    } catch (e) {
      return '-';
    }
  }

  Color _getCardColor(int? dmNumber) {
    if (dmNumber == null) return const Color(0xFF2196F3);
    final hash = dmNumber.hashCode;
    final colors = [
      const Color(0xFF6F4BFF),
      const Color(0xFF5AD8A4),
      const Color(0xFFFF9800),
      const Color(0xFF2196F3),
      const Color(0xFFE91E63),
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final dm = widget.dm;
    final dmId = dm['dmId'] as String? ?? '-';
    final dmNumber = dm['dmNumber'] as int?;
    final clientName = dm['clientName'] as String? ?? '-';
    final vehicleNumber = dm['vehicleNumber'] as String? ?? '-';
    final status = (dm['status'] as String? ?? 'active').toLowerCase();
    final scheduledDate = dm['scheduledDate'];
    final tripPricing = dm['tripPricing'] as Map<String, dynamic>?;
    final total = tripPricing != null
        ? (tripPricing['total'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final isCancelled = status == 'cancelled';
    final statusColor = isCancelled ? const Color(0xFFFF6B6B) : const Color(0xFF5AD8A4);
    final cardColor = _getCardColor(dmNumber);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
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
                      ? cardColor.withValues(alpha: 0.5)
                      : isCancelled
                          ? statusColor.withValues(alpha: 0.3)
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
                      color: cardColor.withValues(alpha: 0.2),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                    cardColor,
                                    cardColor.withValues(alpha: 0.7),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cardColor.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'DM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: _showPrintDialog,
                                        borderRadius: BorderRadius.circular(4),
                                        child: Text(
                                          dmNumber != null ? 'DM-$dmNumber' : dmId,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            letterSpacing: -0.5,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.white54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: statusColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    clientName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
                                Icons.local_shipping,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  vehicleNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatDate(scheduledDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 12),
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
                                  Icons.currency_rupee,
                                  size: 16,
                                  color: Color(0xFF5AD8A4),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF5AD8A4),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isCancelled && widget.canCancel && _isHovered)
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
                        child: IconButton(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          color: Colors.redAccent,
                          onPressed: _showCancelDialog,
                          tooltip: 'Cancel DM',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPrintDialog() {
    final orgContext = context.read<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      DashSnackbar.show(
        context,
        message: 'Organization not found',
        isError: true,
      );
      return;
    }

    final dmNumber = widget.dm['dmNumber'] as int?;
    final dmId = widget.dm['dmId'] as String? ?? widget.dm['id'] as String?;

    if (dmNumber == null && dmId == null) {
      DashSnackbar.show(
        context,
        message: 'DM number or ID not found',
        isError: true,
      );
      return;
    }

    try {
      final printService = context.read<DmPrintService>();
      
      // Use the DM data directly (it's already loaded)
      showDialog(
        context: context,
        builder: (context) => DmPrintDialog(
          dmPrintService: printService,
          organizationId: organization.id,
          dmData: widget.dm,
          dmNumber: dmNumber ?? 0,
        ),
      );
    } catch (e) {
      DashSnackbar.show(
        context,
        message: 'Failed to show print dialog: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B2C),
        title: const Text(
          'Cancel Delivery Memo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to cancel this delivery memo? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _cancelDM();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDM() async {
    final cubit = context.read<DeliveryMemosCubit>();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      DashSnackbar.show(
        context,
        message: 'User not found. Please login again.',
        isError: true,
      );
      return;
    }

    try {
      final tripId = widget.dm['tripId'] as String?;
      final dmId = widget.dm['dmId'] as String?;

      if (tripId == null) {
        throw Exception('Trip ID not found');
      }

      await cubit.cancelDM(
        tripId: tripId,
        dmId: dmId,
        cancelledBy: currentUser.uid,
        cancellationReason: 'Cancelled by user',
      );

      if (context.mounted) {
        DashSnackbar.show(
          context,
          message: 'Delivery Memo cancelled successfully',
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to cancel DM: ${e.toString()}',
          isError: true,
        );
      }
    }
  }
}

