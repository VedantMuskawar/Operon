import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_bloc.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_state.dart';
import 'package:dash_mobile/shared/constants/app_colors.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Dark-themed, scannable Caller ID overlay card for incoming calls.
class CallOverlayWidget extends StatelessWidget {
  const CallOverlayWidget({super.key});

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}-${_month(d.month)}-$yy';
  }

  static String _month(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 420.0;
        return Material(
          color: AuthColors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: const EdgeInsets.all(AppSpacing.paddingLG),
            decoration: BoxDecoration(
              color: AppColors.cardBackgroundElevated,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.borderDefault),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.background.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: BlocBuilder<CallOverlayBloc, CallOverlayState>(
              builder: (context, state) {
                final detailWidgets = <Widget>[];
                if (state.scheduledTrip != null) {
                  detailWidgets
                    ..add(_buildScheduledTrip(state.scheduledTrip!))
                    ..add(const SizedBox(height: AppSpacing.paddingMD));
                }
                if (state.pendingOrder != null &&
                    state.pendingOrder!.status != 'completed') {
                  detailWidgets
                    ..add(_buildPendingOrder(state.pendingOrder!))
                    ..add(const SizedBox(height: AppSpacing.paddingMD));
                }
                if (state.lastTransaction != null) {
                  detailWidgets.add(_buildLastTransaction(state.lastTransaction!));
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(state),
                      if (state.error != null) _buildError(state.error!),
                      if (state.isLoadingClient)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.paddingMD),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else ...[
                        if (detailWidgets.isNotEmpty) ...detailWidgets,
                        if (state.isLoadingDetails)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.paddingSM),
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingMD),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
      child: Divider(
        color: AppColors.borderLight,
        height: 1,
      ),
    );
  }

  Widget _sectionCard({required Widget child, Color? accentColor}) {
    final accent = accentColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.paddingSM),
      padding: const EdgeInsets.all(AppSpacing.paddingMD),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            AppColors.cardBackgroundElevated.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _statusBadge({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingSM,
        vertical: AppSpacing.paddingXS,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.paddingXS / 2),
          Text(
            text,
            style: AppTypography.captionSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvTable(List<MapEntry<String, String>> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(0.9),
          1: FlexColumnWidth(1.1),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows
            .map(
              (row) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.paddingXS),
                    child: Text(
                      row.key,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.paddingXS),
                    child: Text(
                      row.value,
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHeader(CallOverlayState state) {
    final name = state.clientName ?? '—';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: AppTypography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            await FlutterOverlayWindow.closeOverlay();
          },
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(AppSpacing.paddingXS),
            minimumSize: const Size(36, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingSM),
      child: Text(
        message,
        style: AppTypography.bodySmall.copyWith(color: AppColors.error),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPendingOrder(CallerOverlayPendingOrder o) {
    final createdStr = o.createdAt != null ? _formatDate(o.createdAt) : '—';
    final zoneStr = o.zone ?? '—';
    final unitStr =
        o.unitPrice != null ? '₹${o.unitPrice!.toStringAsFixed(0)}' : '—';
    final tripQtyStr = o.tripTimesFixedQty ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Pending order'),
        _sectionCard(
          accentColor: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionDivider(),
              _kvTable([
                MapEntry('Created', createdStr),
                MapEntry('Zone', zoneStr),
                MapEntry('Unit price', unitStr),
                MapEntry('Trip×Qty', tripQtyStr),
                MapEntry('Amount', '₹${o.amount.toStringAsFixed(0)}'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledTrip(CallerOverlayScheduledTrip t) {
    final dateStr =
        t.scheduledDate != null ? _formatDate(t.scheduledDate) : '—';
    final zoneStr = t.zone ?? '—';
    final status = (t.tripStatus ?? 'scheduled').toLowerCase();
    final statusMeta = _tripStatusMeta(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader(
          'Scheduled trip',
          trailing: _statusBadge(
            text: statusMeta.text,
            color: statusMeta.color,
            icon: statusMeta.icon,
          ),
        ),
        _sectionCard(
          accentColor: statusMeta.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionDivider(),
              _kvTable([
                MapEntry('Schedule', dateStr),
                MapEntry('Zone', zoneStr),
                MapEntry('Status', statusMeta.text),
                MapEntry('Vehicle', t.vehicleNumber ?? '—'),
                MapEntry('Slot', t.slotName ?? '—'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLastTransaction(CallerOverlayLastTransaction tx) {
    final dateStr = _formatDate(tx.date);
    final catStr = tx.category ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Last transaction'),
        _sectionCard(
          accentColor: AppColors.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionDivider(),
              _kvTable([
                MapEntry('Date', dateStr),
                MapEntry('Category', catStr),
                MapEntry('Amount', '₹${tx.amount.toStringAsFixed(0)}'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  ({String text, Color color, IconData icon}) _tripStatusMeta(String status) {
    switch (status) {
      case 'delivered':
      case 'completed':
        return (
          text: 'Completed',
          color: AuthColors.success,
          icon: Icons.check_circle,
        );
      case 'in_progress':
      case 'dispatched':
        return (
          text: 'In progress',
          color: AuthColors.warning,
          icon: Icons.sync,
        );
      case 'returned':
        return (
          text: 'Returned',
          color: AuthColors.success,
          icon: Icons.check_circle,
        );
      case 'scheduled':
      default:
        return (
          text: 'Scheduled',
          color: AuthColors.primary,
          icon: Icons.schedule,
        );
    }
  }
}
