import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/repositories/delivery_memo_repository.dart';
import 'package:dash_mobile/presentation/blocs/delivery_memos/delivery_memos_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

class DeliveryMemosPage extends StatefulWidget {
  const DeliveryMemosPage({super.key});

  @override
  State<DeliveryMemosPage> createState() => _DeliveryMemosPageState();
}

class _DeliveryMemosPageState extends State<DeliveryMemosPage> {
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
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: const ModernPageHeader(
          title: 'DM',
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Please select an organization',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              QuickNavBar(
                currentIndex: 4,
                onTap: (value) => context.go('/home', extra: value),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) {
        final repository = context.read<DeliveryMemoRepository>();
        return DeliveryMemosCubit(
          repository: repository,
          organizationId: organization.id,
        )..load();
      },
      child: BlocListener<DeliveryMemosCubit, DeliveryMemosState>(
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message!)),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: const ModernPageHeader(
            title: 'DM',
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
            mainAxisSize: MainAxisSize.min,
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
                QuickNavBar(
                  currentIndex: 4,
                  onTap: (value) => context.go('/home', extra: value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return TextField(
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
            hintText: 'Search by DM number, client name, or vehicle',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1B1B2C),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  StandardChip(
                    label: 'All',
                    isSelected: state.statusFilter == null,
                    onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter(null),
                  ),
                  const SizedBox(width: 8),
                  StandardChip(
                    label: 'Active',
                    isSelected: state.statusFilter == 'active',
                    onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('active'),
                  ),
                  const SizedBox(width: 8),
                  StandardChip(
                    label: 'Cancelled',
                    isSelected: state.statusFilter == 'cancelled',
                    onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('cancelled'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryMemosList() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredMemos = state.filteredDeliveryMemos;

        if (filteredMemos.isEmpty) {
          return Center(
            child: Text(
              state.searchQuery.isNotEmpty
                  ? 'No delivery memos found for "${state.searchQuery}"'
                  : 'No delivery memos found',
              style: const TextStyle(color: Colors.white60),
            ),
          );
        }

        return AnimationLimiter(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredMemos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dm = filteredMemos[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 200),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    curve: Curves.easeOut,
                    child: _DeliveryMemoTile(dm: dm),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DeliveryMemoTile extends StatelessWidget {
  const _DeliveryMemoTile({required this.dm});

  final Map<String, dynamic> dm;

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
        // Today - show time only
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      } else if (difference.inDays == 1) {
        // Yesterday
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return 'Yesterday, $hour:$minute $period';
      } else if (difference.inDays < 7) {
        // This week - show day name
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = weekdays[dateTime.weekday - 1];
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$dayName, $hour:$minute $period';
      } else {
        // Older - show date
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final month = months[dateTime.month - 1];
        return '${dateTime.day} $month ${dateTime.year}';
      }
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final statusColor = isCancelled ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled ? Colors.red.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dmNumber != null ? 'DM-$dmNumber' : dmId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clientName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.local_shipping,
                label: vehicleNumber,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.calendar_today,
                label: _formatDate(scheduledDate),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

