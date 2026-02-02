import 'package:flutter/material.dart';

import '../theme/auth_colors.dart';

enum DashButtonVariant { primary, outlined, text }

class DashButton extends StatelessWidget {
  const DashButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = DashButtonVariant.primary,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final DashButtonVariant variant;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );
    const minSize = Size(0, 52);

    if (variant == DashButtonVariant.text) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          foregroundColor: isDestructive ? AuthColors.error : null,
        ),
        child: child,
      );
    }

    if (variant == DashButtonVariant.outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          foregroundColor: isDestructive ? AuthColors.error : null,
          side: isDestructive
              ? const BorderSide(color: AuthColors.error)
              : null,
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        shape: shape,
        backgroundColor: isDestructive ? AuthColors.error : null,
        foregroundColor: isDestructive ? AuthColors.textMain : null,
      ),
      child: child,
    );
  }
}
