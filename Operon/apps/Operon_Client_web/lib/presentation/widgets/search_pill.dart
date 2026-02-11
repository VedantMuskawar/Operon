import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';

/// Floating search pill widget for Fleet Map.
/// 
/// A capsule-shaped search bar that floats at the top center of the map,
/// providing a premium "Omnibox" style search interface.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    this.onTap,
    this.hintText = 'Search vehicle...',
    this.width,
  });

  /// Callback when the pill is tapped.
  final VoidCallback? onTap;

  /// Placeholder text to display. Defaults to "Search vehicle...".
  final String hintText;

  /// Width of the pill. Defaults to 320px, or responsive if null.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? 320.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: effectiveWidth,
          height: 48,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AuthColors.textMain.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AuthColors.textSub,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hintText,
                    style: const TextStyle(
                      color: AuthColors.textSub,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
