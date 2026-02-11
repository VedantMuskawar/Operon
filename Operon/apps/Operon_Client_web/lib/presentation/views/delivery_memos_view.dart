import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_ui/components/data_table.dart' as custom_table;
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/blocs/delivery_memos/delivery_memos_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/dm_export_dialog.dart';
import 'package:flutter/material.dart' hide DataTable;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

String _formatDmDate(dynamic date) {
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
    _searchController = TextEditingController()..addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      context.read<DeliveryMemosCubit>().search(q);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<DeliveryMemosCubit>().search('');
  }

  void _openExportDialog(BuildContext context) {
    final orgState = context.read<OrganizationContextCubit>().state;
    final org = orgState.organization;
    if (org == null) {
      DashSnackbar.show(context, message: 'Organization not found', isError: true);
      return;
    }
    final repo = context.read<DeliveryMemoRepository>();
    showDialog(
      context: context,
      builder: (_) => DmExportDialog(
        organizationId: org.id,
        repository: repo,
      ),
    );
  }

  void _openPrintDialog(BuildContext context, Map<String, dynamic> dm) {
    final orgState = context.read<OrganizationContextCubit>().state;
    final org = orgState.organization;
    if (org == null) {
      DashSnackbar.show(context, message: 'Organization not found', isError: true);
      return;
    }
    final dmNumber = dm['dmNumber'] as int?;
    if (dmNumber == null) {
      DashSnackbar.show(context, message: 'DM number required to print', isError: true);
      return;
    }
    final svc = context.read<DmPrintService>();
    svc.printDeliveryMemo(dmNumber).then((_) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Print window opened');
      }
    }).catchError((e) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Failed to open print: $e', isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgContext = context.watch<OrganizationContextCubit>().state;
    final organization = orgContext.organization;

    if (organization == null) {
      return SectionWorkspaceLayout(
        panelTitle: 'Delivery Memos',
        currentIndex: 0,
        onNavTap: (v) => context.go('/home?section=$v'),
        child: const Center(
          child: Text(
            'Please select an organization',
            style: TextStyle(color: AuthColors.textSub),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (ctx) {
        developer.log('Creating DeliveryMemosCubit', name: 'DeliveryMemosView');
        final repo = ctx.read<DeliveryMemoRepository>();
        final cubit = DeliveryMemosCubit(
          repository: repo,
          organizationId: organization.id,
        );
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
          onNavTap: (v) => context.go('/home?section=$v'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(),
              const SizedBox(height: 20),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 600;
            final count = state.status != ViewStatus.loading && state.deliveryMemos.isNotEmpty;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearch(true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilters(state),
                      const SizedBox(width: 12),
                      DashButton(
                        label: 'Export',
                        icon: Icons.download_outlined,
                        onPressed: () => _openExportDialog(context),
                        variant: DashButtonVariant.outlined,
                      ),
                      if (count) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${state.filteredDeliveryMemos.length} memos',
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                _buildSearch(false),
                const SizedBox(width: 16),
                _buildFilters(state),
                const SizedBox(width: 16),
                DashButton(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  onPressed: () => _openExportDialog(context),
                  variant: DashButtonVariant.outlined,
                ),
                const Spacer(),
                if (count)
                  Text(
                    '${state.filteredDeliveryMemos.length} memos',
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 13,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearch(bool narrow) {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        return SizedBox(
          width: narrow ? double.infinity : 320,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AuthColors.textMain, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by DM#, client, or vehicle…',
              hintStyle: TextStyle(color: AuthColors.textMainWithOpacity(0.4), fontSize: 14),
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(DeliveryMemosState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterPill(
          label: 'All',
          selected: state.statusFilter == null,
          onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter(null),
        ),
        const SizedBox(width: 8),
        _FilterPill(
          label: 'Active',
          selected: state.statusFilter == 'active',
          onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('active'),
        ),
        const SizedBox(width: 8),
        _FilterPill(
          label: 'Cancelled',
          selected: state.statusFilter == 'cancelled',
          onTap: () => context.read<DeliveryMemosCubit>().setStatusFilter('cancelled'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return BlocBuilder<DeliveryMemosCubit, DeliveryMemosState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.deliveryMemos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonLoader(
                    height: 40,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(8, (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SkeletonLoader(
                      height: 56,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )),
                ],
              ),
            ),
          );
        }

        final rows = state.filteredDeliveryMemos;
        final emptyMsg = state.searchQuery.isNotEmpty
            ? 'No memos match "${state.searchQuery}"'
            : 'No delivery memos yet';

        return AnimatedFade(
          duration: const Duration(milliseconds: 350),
          child: custom_table.DataTable<Map<String, dynamic>>(
            columns: _dmColumns,
            rows: rows,
            onRowTap: (dm, _) => _openPrintDialog(context, dm),
            emptyStateMessage: emptyMsg,
            emptyStateIcon: Icons.description_outlined,
            showHeader: true,
            borderRadius: 16,
            rowActions: [
              custom_table.DataTableRowAction<Map<String, dynamic>>(
                icon: Icons.print_outlined,
                tooltip: 'Print',
                onTap: (dm, _) => _openPrintDialog(context, dm),
              ),
            ],
          ),
        );
      },
    );
  }

  static final _dmColumns = <custom_table.DataTableColumn<Map<String, dynamic>>>[
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'DM',
      flex: 1,
      cellBuilder: (context, dm, _) {
        final n = dm['dmNumber'] as int?;
        final id = dm['dmId'] as String? ?? '-';
        final t = n != null ? 'DM-$n' : id;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AuthColors.info.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t,
            style: const TextStyle(
              color: AuthColors.info,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Client Name',
      flex: 3,
      cellBuilder: (_, dm, __) {
        final name = dm['clientName'] as String? ?? '—';
        return Text(
          name,
          style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'FixedQuantity',
      flex: 1,
      numeric: true,
      cellBuilder: (_, dm, __) {
        final items = dm['items'] as List<dynamic>? ?? [];
        final first = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
        final qty = (first?['fixedQuantityPerTrip'] ?? first?['quantity']) as num?;
        if (qty == null) return const Text('—', style: TextStyle(color: AuthColors.textSub, fontSize: 13));
        return Text(qty.toString(), style: const TextStyle(color: AuthColors.textMain, fontSize: 13));
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Unit Price',
      flex: 1,
      numeric: true,
      cellBuilder: (_, dm, __) {
        final items = dm['items'] as List<dynamic>? ?? [];
        final first = items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
        final price = first != null ? (first['unitPrice'] as num?)?.toDouble() : null;
        if (price == null || price <= 0) {
          return const Text('—', style: TextStyle(color: AuthColors.textSub, fontSize: 13));
        }
        return Text(
          '₹${price.toStringAsFixed(2)}',
          style: const TextStyle(color: AuthColors.textMain, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Delivery Date',
      flex: 1,
      cellBuilder: (_, dm, __) {
        final d = _formatDmDate(dm['scheduledDate']);
        return Text(
          d,
          style: const TextStyle(color: AuthColors.textSub, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Region, City',
      flex: 2,
      cellBuilder: (_, dm, __) {
        final zone = dm['deliveryZone'] as Map<String, dynamic>?;
        if (zone == null) return const Text('—', style: TextStyle(color: AuthColors.textSub, fontSize: 13));
        final region = zone['region'] as String? ?? '';
        final city = zone['city_name'] as String? ?? zone['city'] as String? ?? '';
        final text = [region, city].where((s) => s.isNotEmpty).join(', ');
        return Text(
          text.isEmpty ? '—' : text,
          style: const TextStyle(color: AuthColors.textSub, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Vehicle no.',
      flex: 1,
      cellBuilder: (_, dm, __) {
        final v = dm['vehicleNumber'] as String? ?? '—';
        return Text(
          v,
          style: const TextStyle(color: AuthColors.textSub, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    custom_table.DataTableColumn<Map<String, dynamic>>(
      label: 'Total',
      flex: 1,
      numeric: true,
      cellBuilder: (_, dm, __) {
        final tp = dm['tripPricing'] as Map<String, dynamic>?;
        final total = tp != null ? (tp['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
        if (total <= 0) {
          return const Text('—', style: TextStyle(color: AuthColors.textSub, fontSize: 13));
        }
        return Text(
          '₹${total.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AuthColors.successVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
  ];
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AuthColors.primary.withOpacity(0.2) : AuthColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AuthColors.primary : AuthColors.textMainWithOpacity(0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AuthColors.textMain : AuthColors.textSub,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
