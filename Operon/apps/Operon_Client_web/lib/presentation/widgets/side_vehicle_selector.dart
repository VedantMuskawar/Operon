import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/logic/fleet/fleet_bloc.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:flutter/material.dart';

/// Responsive vehicle selector.
/// 
/// Desktop: Left-hand vertical sidebar (slim strip -> expands on hover).
/// Mobile (< 600px): Bottom-floating horizontal scroll.
class SideVehicleSelector extends StatefulWidget {
  const SideVehicleSelector({
    super.key,
    required this.drivers,
    required this.selectedVehicleId,
    required this.onVehicleSelected,
    required this.onShowAll,
    this.vehicleNumbers = const {},
  });

  final List<FleetDriver> drivers;
  final String? selectedVehicleId;
  final ValueChanged<String> onVehicleSelected;
  final VoidCallback onShowAll;
  final Map<String, String> vehicleNumbers;

  @override
  State<SideVehicleSelector> createState() => _SideVehicleSelectorState();
}

class _SideVehicleSelectorState extends State<SideVehicleSelector> {
  bool _isHovering = false;
  bool _isExpanded = false;

  String _getVehicleDisplayName(FleetDriver driver) {
    final vehicleNumber = widget.vehicleNumbers[driver.uid];
    if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
      return vehicleNumber;
    }
    final uid = driver.uid;
    if (uid.length > 8) {
      return '${uid.substring(0, 4)}...${uid.substring(uid.length - 4)}';
    }
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile Layout: Bottom Horizontal Scroll
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout();
        }
        // Desktop Layout: Left Sidebar
        return _buildDesktopLayout();
      },
    );
  }

  Widget _buildMobileLayout() {
    if (widget.drivers.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16), // Above detail pill
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 1 + widget.drivers.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _VehicleButton(
                  label: 'Show All',
                  isSelected: widget.selectedVehicleId == null,
                  onTap: widget.onShowAll,
                  backgroundColor: AuthColors.textSub,
                  isCompact: true,
                ),
              );
            }
            final driver = widget.drivers[index - 1];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _VehicleButton(
                label: _getVehicleDisplayName(driver),
                isSelected: widget.selectedVehicleId == driver.uid,
                onTap: () => widget.onVehicleSelected(driver.uid),
                backgroundColor: driver.isOffline
                    ? AuthColors.textDisabled
                    : AuthColors.success,
                isCompact: true,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    // Slim strip width = 64, Expanded = 240
    final width = _isHovering || _isExpanded ? 240.0 : 64.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        width: width,
        height: double.infinity,
        margin: const EdgeInsets.all(16),
        child: GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header / Toggle
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  height: 64,
                  alignment: Alignment.center,
                  child: Icon(
                    _isHovering || _isExpanded ? Icons.chevron_left : Icons.directions_car,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  itemCount: 1 + widget.drivers.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VehicleButton(
                          label: _isHovering || _isExpanded ? 'Show All' : 'All',
                          isSelected: widget.selectedVehicleId == null,
                          onTap: widget.onShowAll,
                          backgroundColor: AuthColors.textSub,
                          showLabel: _isHovering || _isExpanded,
                          icon: Icons.grid_view,
                        ),
                      );
                    }
                    final driver = widget.drivers[index - 1];
                    final name = _getVehicleDisplayName(driver);
                    final isSelected = widget.selectedVehicleId == driver.uid;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _VehicleButton(
                        label: _isHovering || _isExpanded ? name : (name.isNotEmpty ? name[0] : '?'),
                        isSelected: isSelected,
                        onTap: () => widget.onVehicleSelected(driver.uid),
                        backgroundColor: driver.isOffline
                            ? AuthColors.textDisabled
                            : AuthColors.success,
                        showLabel: _isHovering || _isExpanded,
                        icon: Icons.local_shipping, // Or dynamic icon
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
    this.showLabel = true,
    this.icon,
    this.isCompact = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final bool showLabel;
  final IconData? icon;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      // Mobile style pill
      return GlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        backgroundColor: isSelected ? backgroundColor?.withOpacity(0.8) : Colors.black.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    // Desktop sidebar item
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? backgroundColor?.withOpacity(0.8)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              mainAxisAlignment: showLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : AuthColors.textSub,
                  ),
                if (showLabel && icon != null) const SizedBox(width: 12),
                if (showLabel)
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
