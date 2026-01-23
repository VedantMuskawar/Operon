import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/logic/fleet/fleet_status_filter.dart';
import 'package:flutter/material.dart';

/// Interactive status filter bar for fleet map.
/// 
/// Displays horizontal scrollable chips for filtering vehicles by status:
/// - All: Shows all vehicles
/// - Moving: Vehicles with speed > 1.0 m/s
/// - Idling: Vehicles with speed <= 1.0 m/s but online
/// - Offline: Vehicles that are offline
class FleetStatusFilterBar extends StatelessWidget {
  const FleetStatusFilterBar({
    super.key,
    required this.stats,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  /// Statistics about fleet status distribution.
  final FleetStats stats;

  /// Currently selected filter.
  final FleetStatusFilter selectedFilter;

  /// Callback when filter selection changes.
  final ValueChanged<FleetStatusFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            count: stats.total,
            isSelected: selectedFilter == FleetStatusFilter.all,
            onTap: () => onFilterChanged(FleetStatusFilter.all),
            backgroundColor: AuthColors.textSub,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Moving',
            count: stats.moving,
            isSelected: selectedFilter == FleetStatusFilter.moving,
            onTap: () => onFilterChanged(FleetStatusFilter.moving),
            backgroundColor: AuthColors.success,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Idling',
            count: stats.idling,
            isSelected: selectedFilter == FleetStatusFilter.idling,
            onTap: () => onFilterChanged(FleetStatusFilter.idling),
            backgroundColor: AuthColors.warning,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Offline',
            count: stats.offline,
            isSelected: selectedFilter == FleetStatusFilter.offline,
            onTap: () => onFilterChanged(FleetStatusFilter.offline),
            backgroundColor: AuthColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.backgroundColor,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AuthColors.surface : AuthColors.textSub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AuthColors.surface.withOpacity(0.3)
                    : AuthColors.textMainWithOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? AuthColors.surface : AuthColors.textSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AuthColors.surface.withOpacity(0.6),
        selectedColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? backgroundColor?.withOpacity(0.5) ?? Colors.transparent
                : AuthColors.textMainWithOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        elevation: isSelected ? 2 : 0,
      ),
    );
  }
}
