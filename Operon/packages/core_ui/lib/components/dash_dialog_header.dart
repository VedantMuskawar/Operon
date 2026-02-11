import 'package:flutter/material.dart';
import 'package:core_ui/theme/auth_colors.dart';

/// Shared dialog header: icon, title, optional subtitle, and close button.
/// Use for consistent modal chrome across Operon dialogs.
class DashDialogHeader extends StatelessWidget {
  const DashDialogHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.onClose,
    this.primaryColor,
  });

  final String title;
  final Widget? subtitle;
  final IconData? icon;
  final VoidCallback onClose;

  /// Optional accent color for icon/container. Defaults to [AuthColors.primary].
  final Color? primaryColor;

  @override
  Widget build(BuildContext context) {
    final accent = primaryColor ?? AuthColors.primary;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: subtitle != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    subtitle!,
                  ],
                )
              : Text(
                  title,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: AuthColors.textSub),
        ),
      ],
    );
  }
}
