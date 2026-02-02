import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/logic/fleet/fleet_bloc.dart';
import 'package:flutter/material.dart';

/// Vehicle selector bar for live mode fleet map.
/// 
/// Displays horizontal scrollable buttons for selecting vehicles to zoom to.
/// Shows all available vehicles from the fleet with a "Show All" option.
class VehicleSelectorBar extends StatelessWidget {
  const VehicleSelectorBar({
    super.key,
    required this.drivers,
    required this.selectedVehicleId,
    required this.onVehicleSelected,
    required this.onShowAll,
    this.vehicleNumbers = const {},
  });

  /// List of available fleet drivers.
  final List<FleetDriver> drivers;

  /// Currently selected vehicle ID (null means "Show All").
  final String? selectedVehicleId;

  /// Callback when a vehicle is selected.
  final ValueChanged<String> onVehicleSelected;

  /// Callback when "Show All" is selected.
  final VoidCallback onShowAll;

  /// Map of driver UID to vehicle number.
  final Map<String, String> vehicleNumbers;

  String _getVehicleDisplayName(FleetDriver driver) {
    // Use vehicle number from map if available
    final vehicleNumber = vehicleNumbers[driver.uid];
    if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
      return vehicleNumber;
    }
    // Fallback to UID
    final uid = driver.uid;
    if (uid.length > 8) {
      return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
    }
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 1 + drivers.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _VehicleButton(
                  label: 'Show All',
                  isSelected: selectedVehicleId == null,
                  onTap: onShowAll,
                  backgroundColor: AuthColors.textSub,
                ),
              );
            }
            final driver = drivers[index - 1];
            final vehicleName = _getVehicleDisplayName(driver);
            final isSelected = selectedVehicleId == driver.uid;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _VehicleButton(
                label: vehicleName,
                isSelected: isSelected,
                onTap: () => onVehicleSelected(driver.uid),
                backgroundColor: driver.isOffline
                    ? AuthColors.textDisabled
                    : AuthColors.success,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VehicleButton extends StatelessWidget {
  const _VehicleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.backgroundColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 44,
            minWidth: 44,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? backgroundColor
                : AuthColors.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? backgroundColor?.withOpacity(0.5) ?? Colors.transparent
                  : AuthColors.textMainWithOpacity(0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AuthColors.surface : AuthColors.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
