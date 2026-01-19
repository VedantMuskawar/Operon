import 'package:flutter/material.dart';
import '../theme/auth_colors.dart';

/// Instagram DM-style DataList item widget
/// 
/// A minimal, sleek list item design matching Instagram's dark mode chat interface.
/// Features a large avatar with status ring, title, subtitle, and trailing actions.
class DataList extends StatelessWidget {
  const DataList({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.padding,
    this.statusRingColor,
    this.statusDotColor,
  });

  /// Main title text (required)
  final String title;

  /// Subtitle text (optional)
  final String? subtitle;

  /// Leading widget - typically an avatar with status ring
  final Widget? leading;

  /// Trailing widget - typically action icons
  final Widget? trailing;

  /// Callback when the item is tapped
  final VoidCallback? onTap;

  /// Background color (default: pure dark)
  final Color? backgroundColor;

  /// Padding around the content (default: 12px vertical, 16px horizontal)
  final EdgeInsets? padding;

  /// Color for the status ring around the avatar
  final Color? statusRingColor;

  /// Color for the status dot indicator
  final Color? statusDotColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? AuthColors.background;
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16);

    return ColoredBox(
      color: effectiveBackgroundColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: effectivePadding,
            child: Row(
              children: [
                // Leading widget (avatar with status ring)
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                // Center content (title and subtitle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AuthColors.textMain,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AuthColors.textSub,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing widget (status dot and actions)
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget to create an avatar with status ring
/// 
/// Used as the leading widget in DataList to show an avatar with a colored
/// status ring around it (like Instagram story rings).
class DataListAvatar extends StatelessWidget {
  const DataListAvatar({
    super.key,
    this.imageUrl,
    this.initial,
    this.radius = 30,
    this.statusRingColor,
    this.ringWidth = 2,
    this.gapWidth = 2,
  });

  /// Image URL for the avatar
  final String? imageUrl;

  /// Initial letter to display if no image
  final String? initial;

  /// Radius of the avatar (default: 30)
  final double radius;

  /// Color of the status ring (default: transparent)
  final Color? statusRingColor;

  /// Width of the status ring (default: 2px)
  final double ringWidth;

  /// Gap between ring and avatar (default: 2px)
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveInitial = initial ?? '?';
    final effectiveRingColor = statusRingColor ?? Colors.transparent;

    return Container(
      width: radius * 2 + (ringWidth + gapWidth) * 2,
      height: radius * 2 + (ringWidth + gapWidth) * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveRingColor,
          width: ringWidth,
        ),
      ),
      child: Center(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AuthColors.surface,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildInitialAvatar(effectiveInitial),
                  ),
                )
              : _buildInitialAvatar(effectiveInitial),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Center(
      child: Text(
        initial.toUpperCase(),
        style: TextStyle(
          color: AuthColors.textMain,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Helper widget to create a status dot indicator
/// 
/// Small solid circle used to indicate status (active, paused, etc.)
class DataListStatusDot extends StatelessWidget {
  const DataListStatusDot({
    super.key,
    this.color,
    this.size = 8,
  });

  /// Color of the status dot (default: Instagram blue)
  final Color? color;

  /// Size of the status dot (default: 8px)
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? AuthColors.primary,
      ),
    );
  }
}
