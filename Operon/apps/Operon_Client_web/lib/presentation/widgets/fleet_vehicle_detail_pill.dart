import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:dash_web/logic/fleet/fleet_bloc.dart';
import 'package:dash_web/presentation/widgets/glass_info_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FleetVehicleDetailPill extends StatefulWidget {
  const FleetVehicleDetailPill({
    super.key,
    required this.driver,
    required this.vehicleNumber,
    this.onClose,
  });

  final FleetDriver driver;
  final String vehicleNumber;
  final VoidCallback? onClose;

  @override
  State<FleetVehicleDetailPill> createState() => _FleetVehicleDetailPillState();
}

class _FleetVehicleDetailPillState extends State<FleetVehicleDetailPill> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final speedKmH = (widget.driver.location.speed * 3.6).toStringAsFixed(1);
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(widget.driver.location.timestamp);
    final formattedTime = DateFormat('HH:mm').format(lastSeen);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
          width: _isExpanded ? 320 : 220,
          height: _isExpanded ? 320 : 44,
          margin: const EdgeInsets.only(bottom: 24),
          child: GlassPanel(
            padding: EdgeInsets.zero,
            child: _isExpanded
                ? _buildExpandedContent(speedKmH, formattedTime)
                : _buildIdleContent(speedKmH),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildIdleContent(String speed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vehicle icon in circular background (slightly overlaps pill left edge)
          Transform.translate(
            offset: const Offset(-4, 0),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AuthColors.textMain.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.local_shipping,
                color: widget.driver.isOffline ? AuthColors.textDisabled : AuthColors.success,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.vehicleNumber,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 14,
            color: AuthColors.textSub.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Text(
            '$speed km/h',
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(String speed, String time) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: widget.driver.isOffline ? AuthColors.textDisabled : AuthColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.vehicleNumber,
                          style: const TextStyle(
                            color: AuthColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.driver.isOffline ? 'Offline' : 'Online',
                          style: TextStyle(
                            color: widget.driver.isOffline ? AuthColors.textDisabled : AuthColors.success,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AuthColors.textSub, size: 20),
                    onPressed: () {
                      setState(() => _isExpanded = false);
                      widget.onClose?.call();
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              // Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.6,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MetricTile(
                      label: 'Last Ping',
                      value: time,
                      icon: Icons.access_time,
                    ),
                    _MetricTile(
                      label: 'Speed',
                      value: '$speed km/h',
                      icon: Icons.speed,
                    ),
                    _MetricTile(
                      label: 'Battery',
                      value: widget.driver.batteryLevel != null 
                          ? '${widget.driver.batteryLevel!.round()}%' 
                          : '--%',
                      icon: Icons.battery_std,
                    ),
                    _MetricTile(
                      label: 'Daily KM',
                      value: widget.driver.dailyDistanceKm != null 
                          ? '${widget.driver.dailyDistanceKm!.toStringAsFixed(1)} km' 
                          : '-- km',
                      icon: Icons.map,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AuthColors.textSub),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: AuthColors.textSub, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
