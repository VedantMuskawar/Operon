import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/repositories/delivery_memo_repository.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/blocs/delivery_memos/delivery_memos_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/widgets/dm_print_dialog.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:dash_mobile/presentation/widgets/standard_chip.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'DM',
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.paddingLG),
                    child: Text(
                      'Please select an organization',
                      style: TextStyle(color: AuthColors.textSub),
                    ),
                  ),
                ),
              ),
              FloatingNavBar(
                items: const [
                  NavBarItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    heroTag: 'nav_home',
                  ),
                  NavBarItem(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    heroTag: 'nav_pending',
                  ),
                  NavBarItem(
                    icon: Icons.schedule_rounded,
                    label: 'Schedule',
                    heroTag: 'nav_schedule',
                  ),
                  NavBarItem(
                    icon: Icons.map_rounded,
                    label: 'Map',
                    heroTag: 'nav_map',
                  ),
                  NavBarItem(
                    icon: Icons.event_available_rounded,
                    label: 'Cash Ledger',
                    heroTag: 'nav_cash_ledger',
                  ),
                ],
                currentIndex: -1,
                onItemTapped: (value) => context.go('/home', extra: value),
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
          backgroundColor: AuthColors.background,
          appBar: const ModernPageHeader(
            title: 'DM',
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
                    builder: (context, state) {
                      final filteredMemos = state.filteredDeliveryMemos;
                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.paddingLG),
                              child: _buildSearchBar(),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.paddingXL)),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: _buildFilters(),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.paddingXL)),
                          if (state.status == ViewStatus.loading)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AuthColors.primary),
                              ),
                            )
                          else if (filteredMemos.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    state.searchQuery.isNotEmpty
                                        ? 'No delivery memos found for "${state.searchQuery}"'
                                        : 'No delivery memos found',
                                    style: const TextStyle(
                                        color: AuthColors.textSub),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final dm = filteredMemos[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 12),
                                      child: _DeliveryMemoTile(dm: dm),
                                    );
                                  },
                                  childCount: filteredMemos.length,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                FloatingNavBar(
                  items: const [
                    NavBarItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      heroTag: 'nav_home',
                    ),
                    NavBarItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      heroTag: 'nav_pending',
                    ),
                    NavBarItem(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      heroTag: 'nav_schedule',
                    ),
                    NavBarItem(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      heroTag: 'nav_map',
                    ),
                    NavBarItem(
                      icon: Icons.event_available_rounded,
                      label: 'Cash Ledger',
                      heroTag: 'nav_cash_ledger',
                    ),
                  ],
                currentIndex: -1,
                  onItemTapped: (value) => context.go('/home', extra: value),
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
          style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by DM#, client, or vehicle…',
            hintStyle: const TextStyle(color: AuthColors.textSub, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: AuthColors.textSub, size: 20),
            suffixIcon: state.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AuthColors.textSub, size: 20),
                    onPressed: _clearSearch,
                  )
                : null,
            filled: true,
            fillColor: AuthColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingMD),
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
              StandardChip(
                label: 'All',
                isSelected: state.statusFilter == null,
                onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter(null),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              StandardChip(
                label: 'Active',
                isSelected: state.statusFilter == 'active',
                onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('active'),
              ),
              const SizedBox(width: AppSpacing.paddingSM),
              StandardChip(
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

}

class _DeliveryMemoTile extends StatelessWidget {
  const _DeliveryMemoTile({required this.dm});

  final Map<String, dynamic> dm;

  Future<void> _openPrintDialog(BuildContext context) async {
    final org = context.read<OrganizationContextCubit>().state.organization;
    if (org == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization first')),
      );
      return;
    }
    final printService = context.read<DmPrintService>();
    final dmNumber = dm['dmNumber'] as int? ?? 0;
    final dmData = await printService.fetchDmByNumberOrId(
      organizationId: org.id,
      dmNumber: dmNumber,
      dmId: dm['dmId'] as String?,
      tripData: null,
    );
    if (dmData == null || !context.mounted) return;
    if (!context.mounted) return;
    await DmPrintDialog.show(
      context: context,
      dmPrintService: printService,
      organizationId: org.id,
      dmData: dmData,
      dmNumber: dmNumber,
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '—';
      }
      final now = DateTime.now();
      final d = now.difference(dateTime);
      if (d.inDays == 0) {
        final h = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final m = dateTime.minute.toString().padLeft(2, '0');
        final p = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $p';
      }
      if (d.inDays == 1) {
        final h = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final m = dateTime.minute.toString().padLeft(2, '0');
        final p = dateTime.hour >= 12 ? 'PM' : 'AM';
        return 'Yesterday, $h:$m $p';
      }
      if (d.inDays < 7) {
        const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final day = w[dateTime.weekday - 1];
        final h = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final m = dateTime.minute.toString().padLeft(2, '0');
        final p = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$day, $h:$m $p';
      }
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dmId = dm['dmId'] as String? ?? '—';
    final dmNumber = dm['dmNumber'] as int?;
    final clientName = dm['clientName'] as String? ?? '—';
    final vehicleNumber = dm['vehicleNumber'] as String? ?? '—';
    final status = (dm['status'] as String? ?? 'active').toLowerCase();
    final scheduledDate = dm['scheduledDate'];
    final tripPricing = dm['tripPricing'] as Map<String, dynamic>?;
    final total = tripPricing != null
        ? (tripPricing['total'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final items = dm['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
    final fixedQty = (firstItem?['fixedQuantityPerTrip'] ?? firstItem?['quantity']) as num?;
    final unitPrice = (firstItem?['unitPrice'] as num?)?.toDouble();
    final deliveryZone = dm['deliveryZone'] as Map<String, dynamic>?;
    final region = deliveryZone?['region'] as String? ?? '';
    final city = deliveryZone?['city_name'] as String? ?? deliveryZone?['city'] as String? ?? '';
    final regionCity = [region, city].where((s) => s.isNotEmpty).join(', ');

    final isCancelled = status == 'cancelled';
    final statusColor = isCancelled ? AuthColors.error : AuthColors.successVariant;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      child: Container(
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: isCancelled
                ? AuthColors.error.withValues(alpha: 0.25)
                : AuthColors.textMainWithOpacity(0.1),
          ),
        ),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              dmNumber != null ? 'DM-$dmNumber' : dmId,
                              style: const TextStyle(
                                color: AuthColors.textMain,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.paddingSM),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingSM, vertical: AppSpacing.paddingXS),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isCancelled ? 'Cancelled' : 'Active',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined),
                        onPressed: () => _openPrintDialog(context),
                        tooltip: 'Print DM',
                        style: IconButton.styleFrom(
                          foregroundColor: AuthColors.textSub,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapSM),
                  Text(
                    clientName,
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.paddingMD),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (fixedQty != null)
                        _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'Qty: $fixedQty',
                        ),
                      if (unitPrice != null && unitPrice > 0)
                        _InfoChip(
                          icon: Icons.attach_money,
                          label: '₹${unitPrice.toStringAsFixed(2)}/unit',
                        ),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(scheduledDate),
                      ),
                      if (regionCity.isNotEmpty)
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: regionCity,
                        ),
                      _InfoChip(
                        icon: Icons.local_shipping_outlined,
                        label: vehicleNumber,
                      ),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: AppSpacing.paddingMD),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSM, horizontal: AppSpacing.paddingMD),
                      decoration: BoxDecoration(
                        color: AuthColors.successVariant.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AuthColors.successVariant,
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
          ),
        ],
        ),
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
        Icon(icon, size: 16, color: AuthColors.textSub),
        const SizedBox(width: AppSpacing.paddingXS),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

