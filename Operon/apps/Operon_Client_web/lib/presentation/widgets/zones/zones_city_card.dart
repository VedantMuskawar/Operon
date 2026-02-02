import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// City card for zones view; shows city name and region count with selection state.
class ZonesCityCard extends StatefulWidget {
  const ZonesCityCard({
    super.key,
    required this.city,
    required this.isSelected,
    required this.regionCount,
    required this.onTap,
    this.onLongPress,
  });

  final DeliveryCity city;
  final bool isSelected;
  final int regionCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<ZonesCityCard> createState() => _ZonesCityCardState();
}

class _ZonesCityCardState extends State<ZonesCityCard>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_controller.value * 0.02),
              child: Container(
                decoration: widget.isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AuthColors.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AuthColors.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: -3,
                          ),
                        ],
                      )
                    : null,
                child: DashCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AuthColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_city,
                          color: AuthColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.city.name,
                              style: TextStyle(
                                color: AuthColors.textMain,
                                fontWeight: FontWeight.w700,
                                fontSize: widget.isSelected ? 16 : 15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: AuthColors.textMain.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.regionCount} ${widget.regionCount == 1 ? 'region' : 'regions'}',
                                  style: TextStyle(
                                    color: AuthColors.textMain.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AuthColors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
