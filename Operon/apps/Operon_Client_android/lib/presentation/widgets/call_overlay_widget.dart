import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_bloc.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_state.dart';
import 'package:dash_mobile/shared/constants/app_colors.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:dash_mobile/shared/constants/app_typography.dart';
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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.paddingLG),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundElevated,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.borderDefault),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: BlocBuilder<CallOverlayBloc, CallOverlayState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(state),
                if (state.error != null) _buildError(state.error!),
                if (state.isLoadingClient)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  if (state.scheduledTrip != null)
                    _buildScheduledTrip(state.scheduledTrip!)
                  else if (state.pendingOrder != null && state.pendingOrder!.status != 'completed')
                    _buildPendingOrder(state.pendingOrder!),
                  if (state.lastTransaction != null) _buildLastTransaction(state.lastTransaction!),
                  if (state.isLoadingDetails)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.paddingSM),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(CallOverlayState state) {
    final name = state.clientName ?? '—';
    final number = state.clientNumber ?? '—';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: AppTypography.h3),
              const SizedBox(height: 2),
              Text(number, style: AppTypography.bodySmall),
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
    final unitStr = o.unitPrice != null ? '₹${o.unitPrice!.toStringAsFixed(0)}' : '—';
    final tripQtyStr = o.tripTimesFixedQty ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Order created $createdStr', style: AppTypography.bodySmall),
          Text('Zone $zoneStr', style: AppTypography.bodySmall),
          Row(
            children: [
              Text('Unit price $unitStr', style: AppTypography.bodySmall),
              const SizedBox(width: AppSpacing.paddingMD),
              Text('Trip×FixedQty $tripQtyStr', style: AppTypography.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTrip(CallerOverlayScheduledTrip t) {
    final dateStr = t.scheduledDate != null ? _formatDate(t.scheduledDate) : '—';
    final zoneStr = t.zone ?? '—';
    final statusStr = t.tripStatus ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Schedule $dateStr', style: AppTypography.bodySmall),
          Text('Zone $zoneStr', style: AppTypography.bodySmall),
          Text('Status $statusStr', style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildLastTransaction(CallerOverlayLastTransaction tx) {
    final dateStr = _formatDate(tx.date);
    final catStr = tx.category ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Last tx $dateStr', style: AppTypography.bodySmall),
          Row(
            children: [
              Text('$catStr ', style: AppTypography.bodySmall),
              Text('₹${tx.amount.toStringAsFixed(0)}', style: AppTypography.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
