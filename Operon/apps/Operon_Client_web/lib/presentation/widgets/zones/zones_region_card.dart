import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Region card for zones view; shows zone region, city, status, and price count.
class ZonesRegionCard extends StatefulWidget {
  const ZonesRegionCard({
    super.key,
    required this.zone,
    required this.isSelected,
    required this.priceCount,
    required this.onTap,
    this.onEdit,
  });

  final DeliveryZone zone;
  final bool isSelected;
  final int priceCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  State<ZonesRegionCard> createState() => _ZonesRegionCardState();
}

class _ZonesRegionCardState extends State<ZonesRegionCard>
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
                          color: AuthColors.successVariant,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AuthColors.successVariant.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: -3,
                          ),
                        ],
                      )
                    : null,
                child: DashCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AuthColors.successVariant.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AuthColors.successVariant,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.zone.region,
                                  style: TextStyle(
                                    color: AuthColors.textMain,
                                    fontWeight: FontWeight.w700,
                                    fontSize: widget.isSelected ? 16 : 15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.zone.cityName,
                                  style: TextStyle(
                                    color: AuthColors.textMain.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                if (widget.zone.roundtripKm != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.straighten,
                                        size: 12,
                                        color: AuthColors.textMain.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.zone.roundtripKm!.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          color: AuthColors.textMain.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.zone.isActive
                                  ? AuthColors.successVariant.withValues(alpha: 0.2)
                                  : AuthColors.textMainWithOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: widget.zone.isActive
                                    ? AuthColors.successVariant.withValues(alpha: 0.3)
                                    : AuthColors.textMainWithOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.zone.isActive ? Icons.check_circle : Icons.pause_circle,
                                  size: 12,
                                  color: widget.zone.isActive
                                      ? AuthColors.successVariant
                                      : AuthColors.textMainWithOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.zone.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: widget.zone.isActive
                                        ? AuthColors.successVariant
                                        : AuthColors.textMainWithOpacity(0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isSelected && widget.onEdit != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                color: AuthColors.textSub,
                                onPressed: widget.onEdit,
                                tooltip: 'Edit Region',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AuthColors.textMain.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 12,
                              color: AuthColors.textMain.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.priceCount} ${widget.priceCount == 1 ? 'price' : 'prices'}',
                              style: TextStyle(
                                color: AuthColors.textMain.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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
